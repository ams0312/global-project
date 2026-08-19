"""Covers: "Regimen column has blank + one drug in multiple regimen" /
"On drug is not equal to sum of all positive SoB" / "On drug is still on
distinct count" / "on brand level we don't have diabetes and obesity
split" / missing brands (BYDUREON, BYETTA, SEGLUROMET, STEGLATRO)."""
import pandas as pd
import pytest

from sob_pipeline import aggregate, classify, merge


def test_validate_regimen_mapping_passes_on_clean_detail(detail):
    aggregate.validate_regimen_mapping(detail)  # must not raise


def test_validate_regimen_mapping_rejects_blank_regimen(detail):
    bad = detail.copy()
    bad.loc[bad.index[0], "Regimen"] = ""
    with pytest.raises(ValueError, match="Blank Regimen"):
        aggregate.validate_regimen_mapping(bad)


def test_validate_regimen_mapping_rejects_split_brand(detail):
    """The exact bug from the screenshots: one brand mapped to two
    different Regimen values (e.g. FIASP under both Basal and Bolus)."""
    humulin_rows = detail[detail["Focus_Brand_Brand_Level"] == "HUMULIN"]
    if humulin_rows.empty:
        pytest.skip("fixture has no HUMULIN rows")
    conflicting = humulin_rows.iloc[[0]].copy()
    conflicting["Regimen"] = "BASAL INSULIN"  # HUMULIN is really PREMIX INSULIN
    bad = pd.concat([detail, conflicting], ignore_index=True)
    with pytest.raises(ValueError, match="more than one Regimen"):
        aggregate.validate_regimen_mapping(bad)


def test_previously_missing_brands_appear_in_may_only(detail):
    strength = aggregate.strength_level(detail)
    for brand in ["BYDUREON", "BYETTA", "SEGLUROMET", "STEGLATRO"]:
        rows = strength[strength["Focus_Brand"] == brand]
        assert not rows.empty, f"{brand} is missing from the report"
        assert set(rows["Date"]) == {202605}


def test_ozempic_brand_level_splits_diabetes_and_obesity(detail):
    brand = aggregate.brand_level(detail)
    at_month = brand[brand["Date"] == 202410]
    focus_brands = set(at_month["Focus_Brand"])
    assert "OZEMPIC DIABETES" in focus_brands
    assert "OZEMPIC OBESITY" in focus_brands
    assert "OZEMPIC" not in focus_brands  # never a blended total row

    diabetes_total = at_month.loc[at_month["Focus_Brand"] == "OZEMPIC DIABETES", "Patient_Count"].sum()
    obesity_total = at_month.loc[at_month["Focus_Brand"] == "OZEMPIC OBESITY", "Patient_Count"].sum()
    assert diabetes_total == 1
    assert obesity_total == 1


def test_on_drug_is_sum_of_seven_positive_categories(detail):
    brand = aggregate.brand_level(detail)
    result = aggregate.on_drug(brand, ["Regimen", "Focus_Brand", "Date"])
    row = result[(result["Focus_Brand"] == "OZEMPIC DIABETES") & (result["Date"] == 202401)]
    expected = brand[
        (brand["Focus_Brand"] == "OZEMPIC DIABETES")
        & (brand["Date"] == 202401)
        & (brand["Category"].isin(classify.POSITIVE_CATEGORIES))
    ]["Patient_Count"].sum()
    assert row["On_Drug"].iloc[0] == expected


def test_on_drug_is_a_per_month_sum_not_a_cross_month_distinct_count(diabetes_batch, obesity_batch, patient_history):
    """A patient Repeat-ing on the same brand across two different months
    must be counted once *per month* in On Drug, not deduplicated across
    months the way a naive DISTINCTCOUNT(Patient_ID) measure would."""
    two_month = pd.concat(
        [
            diabetes_batch,
            pd.DataFrame(
                [
                    {
                        "Country": "USA", "Region": "ALL", "Date": 202501, "Type": "T2D",
                        "Patient_ID": "PX", "Period": "PRESENT", "Brand": "LANTUS",
                        "Strength": "", "LRx_Projected": 1,
                    },
                    {
                        "Country": "USA", "Region": "ALL", "Date": 202502, "Type": "T2D",
                        "Patient_ID": "PX", "Period": "BEFORE", "Brand": "LANTUS",
                        "Strength": "", "LRx_Projected": 1,
                    },
                    {
                        "Country": "USA", "Region": "ALL", "Date": 202502, "Type": "T2D",
                        "Patient_ID": "PX", "Period": "PRESENT", "Brand": "LANTUS",
                        "Strength": "", "LRx_Projected": 1,
                    },
                ]
            ),
        ],
        ignore_index=True,
    )
    merged = merge.merge_batches(two_month, obesity_batch)
    det = classify.classify(merged, patient_history)
    brand = aggregate.brand_level(det)
    result = aggregate.on_drug(brand, ["Regimen", "Focus_Brand", "Date"])
    px_rows = result[(result["Focus_Brand"] == "LANTUS") & (result["Date"].isin([202501, 202502]))]
    # Two distinct months -> On Drug = 1 + 1 = 2, never collapsed to a
    # single cross-month distinct-patient count of 1.
    assert px_rows["On_Drug"].sum() == 2
