"""Covers: "I see some insulins under both basal and bolus, please
correct it" / "I can still see insulin under both Basal and Bolus, such
as ACTRAPID" / "HUMULIN are both basal and bolus insulin" and
"BYDUREON, BYETTA, SEGLUROMET and STEGLATRO are missing"."""
from sob_pipeline import brand_master


def test_every_brand_has_exactly_one_regimen():
    # BRAND_REGIMEN is a plain dict, so duplicate keys are structurally
    # impossible -- this asserts the previously-duplicated brands are
    # present and resolve to a single value each.
    for brand in ["HUMULIN", "FIASP", "ACTRAPID"]:
        assert brand_master.regimen_for(brand) in {
            brand_master.BASAL_INSULIN,
            brand_master.BOLUS_INSULIN,
            brand_master.PREMIX_INSULIN,
        }
    assert brand_master.regimen_for("HUMULIN") == brand_master.PREMIX_INSULIN
    assert brand_master.regimen_for("FIASP") == brand_master.BOLUS_INSULIN
    assert brand_master.regimen_for("ACTRAPID") == brand_master.BOLUS_INSULIN


def test_previously_missing_brands_are_mapped():
    for brand in ["BYDUREON", "BYETTA", "SEGLUROMET", "STEGLATRO"]:
        # Must not raise, and must not be blank.
        assert brand_master.regimen_for(brand)


def test_unmapped_brand_raises_instead_of_blank():
    import pytest

    with pytest.raises(KeyError):
        brand_master.regimen_for("SOME_UNKNOWN_BRAND")


def test_wegovy_is_always_obesity():
    assert brand_master.focus_brand_name("WEGOVY", "T2D") == "WEGOVY OBESITY"
    assert brand_master.focus_brand_name("WEGOVY", None) == "WEGOVY OBESITY"


def test_non_indication_aware_brand_has_no_suffix():
    assert brand_master.focus_brand_name("TRAJENTA", "T2D") == "TRAJENTA"


def test_mounjaro_obesity_not_available_before_launch():
    assert brand_master.is_available("MOUNJARO", "OBESITY", 202604) is False
    assert brand_master.is_available("MOUNJARO", "OBESITY", 202605) is True
    # Mounjaro Diabetes has no such constraint.
    assert brand_master.is_available("MOUNJARO", "DIABETES", 202401) is True
