"""End-to-end smoke test wiring every module together."""
import pandas as pd

from sob_pipeline import pipeline


def test_run_pipeline_end_to_end(diabetes_batch, obesity_batch, patient_history, tmp_path):
    result = pipeline.run_pipeline(diabetes_batch, obesity_batch, patient_history, tmp_path)

    assert (tmp_path / "sob_strength_level.csv").exists()
    assert (tmp_path / "sob_brand_level.csv").exists()

    strength = pd.read_csv(tmp_path / "sob_strength_level.csv")
    brand = pd.read_csv(tmp_path / "sob_brand_level.csv")

    # Capitalization applied end to end (values, not headers, are uppercased).
    assert (strength["Focus_Brand"].str.upper() == strength["Focus_Brand"]).all()
    assert (brand["Focus_Brand"].str.upper() == brand["Focus_Brand"]).all()

    # Every category present is a known positive or negative SoB category.
    from sob_pipeline.classify import NEGATIVE_CATEGORIES, POSITIVE_CATEGORIES

    known = set(POSITIVE_CATEGORIES) | set(NEGATIVE_CATEGORIES)
    assert set(brand["Category"].unique()) <= known

    # Mounjaro obesity pre-launch patient never made it through.
    assert "P8" not in result["detail"]["Patient_ID"].values
