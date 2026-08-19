"""Covers: "add Mounjaro and Ozempic Rx from obesity batch" / "add
indication obesity for obesity usage" / "rename Mounjaro and Ozempic
based on the usage" / "focus = Ozempic obesity, indication is T1D/T2D...
Same for Wegovy" / "Mounjaro obesity only appear in 202605"."""
from sob_pipeline import merge


def test_obesity_batch_rows_are_included(diabetes_batch, obesity_batch):
    merged = merge.merge_batches(diabetes_batch, obesity_batch)
    assert (merged["Patient_ID"] == "P7").any()  # Ozempic obesity patient
    assert (merged["Patient_ID"] == "P9").any()  # Mounjaro obesity patient


def test_obesity_usage_is_tagged_and_renamed(diabetes_batch, obesity_batch):
    merged = merge.merge_batches(diabetes_batch, obesity_batch)
    ozempic_obesity = merged[merged["Patient_ID"] == "P7"]
    assert (ozempic_obesity["Indication"] == "OBESITY").all()
    assert (ozempic_obesity["Brand_Key"] == "OZEMPIC OBESITY").all()

    ozempic_diabetes = merged[merged["Patient_ID"] == "P10"]
    assert (ozempic_diabetes["Indication"] == "DIABETES").all()
    assert (ozempic_diabetes["Brand_Key"] == "OZEMPIC DIABETES").all()


def test_focus_brand_never_shows_wrong_indication_type(diabetes_batch, obesity_batch):
    """"it is a bit weird to see focus = Ozempic obesity, indication is
    T1D/T2D. Same for Wegovy" -- Type must always agree with the brand's
    resolved indication for Ozempic/Mounjaro/Wegovy."""
    merged = merge.merge_batches(diabetes_batch, obesity_batch)

    obesity_rows = merged[merged["Brand_Key"].str.endswith("OBESITY")]
    assert (obesity_rows["Type"] == "OBESITY").all()

    # P12's raw Type was T2D but Brand is WEGOVY -> must be forced OBESITY.
    wegovy_rows = merged[merged["Patient_ID"] == "P12"]
    assert (wegovy_rows["Type"] == "OBESITY").all()
    assert (wegovy_rows["Brand_Key"] == "WEGOVY OBESITY").all()


def test_mounjaro_obesity_only_from_202605(diabetes_batch, obesity_batch):
    merged = merge.merge_batches(diabetes_batch, obesity_batch)
    # P8 was dated 202604, one month before launch -> must be dropped entirely.
    assert not (merged["Patient_ID"] == "P8").any()
    # P9/P11 dated 202605 -> must be kept.
    assert (merged["Patient_ID"] == "P9").any()
    assert (merged["Patient_ID"] == "P11").any()
