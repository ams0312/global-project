"""Covers the switching / SoB-category feedback thread, validated against
the user's own worked example (diagram #1: Jan Ozempic+OAD -> Feb Ozempic
(repeat)/OAD (drop out) -> Mar OAD (win from Ozempic)/Ozempic (loss to
OAD) -> Apr OAD (repeat)/Ozempic (addon to OAD)), plus:
"Repeat patients... Before doesn't have Ozempic, seems like add-on to me"
/ "add-on patients now have Ozempic in both Before and Present" /
"Ozempic diabetes and Ozempic obesity don't have negative SoB" / "Mounjaro
and Ozempic don't have indication label in the focus brand for all
negative SoB"."""
from sob_pipeline import classify


def _row(detail, patient_id, date, focus_brand):
    match = detail[
        (detail["Patient_ID"] == patient_id)
        & (detail["Date"] == date)
        & (detail["Focus_Brand_Brand_Level"] == focus_brand)
    ]
    assert len(match) == 1, f"expected exactly one row for {patient_id}/{date}/{focus_brand}, got {len(match)}"
    return match.iloc[0]


def test_diagram_1_worked_example(detail):
    # Feb: Ozempic repeat, OAD drop out
    assert _row(detail, "P1", 202402, "OZEMPIC DIABETES")["Category"] == classify.REPEAT
    assert _row(detail, "P1", 202402, "OAD")["Category"] == classify.DROP_OUT

    # Mar: OAD win from Ozempic, Ozempic loss to OAD
    assert _row(detail, "P1", 202403, "OAD")["Category"] == classify.WIN
    assert _row(detail, "P1", 202403, "OZEMPIC DIABETES")["Category"] == classify.LOSS

    # Apr: OAD repeat, Ozempic addon to OAD
    assert _row(detail, "P1", 202404, "OAD")["Category"] == classify.REPEAT
    assert _row(detail, "P1", 202404, "OZEMPIC DIABETES")["Category"] == classify.ADD_ON


def test_repeat_before_includes_focus_brand(detail):
    """A Repeat row's Before basket string must contain the focus brand
    itself -- it was wrongly excluded, which made Repeat patients look
    like Add-on."""
    row = _row(detail, "P1", 202402, "OZEMPIC DIABETES")
    assert row["Category"] == classify.REPEAT
    assert "OZEMPIC" in row["Before"]


def test_add_on_before_excludes_focus_brand(detail):
    """An Add-on row's Before must NOT contain the focus brand -- it
    wasn't there yet, that's what makes it an add-on."""
    row = _row(detail, "P1", 202404, "OZEMPIC DIABETES")
    assert row["Category"] == classify.ADD_ON
    assert "OZEMPIC" not in row["Before"]
    assert "OZEMPIC" in row["Present"]


def test_win_from_any_drug_class_generic(detail):
    """Win/Loss is generic: OAD winning from Ozempic is classified purely
    from basket overlap, with no brand-specific special-casing."""
    assert _row(detail, "P1", 202403, "OAD")["Category"] == classify.WIN


def test_win_has_mirrored_lose_entry(detail):
    win_row = _row(detail, "P1", 202403, "OAD")
    lose_row = _row(detail, "P1", 202403, "OZEMPIC DIABETES")
    assert win_row["Category"] == classify.WIN
    assert lose_row["Category"] == classify.LOSS
    assert win_row["Date"] == lose_row["Date"]


def test_before_present_columns_are_unchanged_free_text(detail):
    """Clarification #4: Before/Present stay as combo strings (not a
    literal "X win from Y" label) -- only the Category field changes."""
    row = _row(detail, "P1", 202403, "OAD")
    assert row["Before"] == "OZEMPIC 0.25,0.5MG, 1.5ML DIABETES"
    assert row["Present"] == "OAD"


def test_ozempic_diabetes_and_obesity_have_negative_sob(detail):
    diabetes_negative = detail[
        (detail["Focus_Brand_Brand_Level"] == "OZEMPIC DIABETES")
        & (detail["Category"].isin(classify.NEGATIVE_CATEGORIES))
    ]
    assert not diabetes_negative.empty

    obesity = detail[detail["Focus_Brand_Brand_Level"] == "OZEMPIC OBESITY"]
    assert not obesity.empty  # sanity: obesity rows exist at all


def test_mounjaro_negative_sob_keeps_indication_label(detail):
    row = _row(detail, "P11", 202605, "MOUNJARO OBESITY")
    assert row["Category"] == classify.DISCONTINUED
    assert row["Focus_Brand_Brand_Level"] == "MOUNJARO OBESITY"
    assert "OBESITY" in row["Focus_Brand"]


def test_insulin_naive(detail):
    row = _row(detail, "P15", 202401, "LANTUS")
    assert row["Category"] == classify.INSULIN_NAIVE


def test_treatment_naive_first_vs_new_to_database_vs_treatment_naive(detail):
    assert _row(detail, "P1", 202401, "OZEMPIC DIABETES")["Category"] == classify.TREATMENT_NAIVE_FIRST
    assert _row(detail, "P13", 202401, "LANTUS")["Category"] == classify.NEW_TO_DATABASE
    assert _row(detail, "P14", 202401, "TRAJENTA")["Category"] == classify.TREATMENT_NAIVE
