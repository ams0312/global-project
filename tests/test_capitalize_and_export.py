"""Covers: "capitalize all the variables" / "export csv file using comma
separated format"."""
import pandas as pd

from sob_pipeline import capitalize, export


def test_capitalize_all_uppercases_string_columns():
    df = pd.DataFrame({"Focus_Brand": ["ozempic diabetes", "Lantus"], "Patient_Count": [1, 2]})
    out = capitalize.capitalize_all(df)
    assert list(out["Focus_Brand"]) == ["OZEMPIC DIABETES", "LANTUS"]
    assert list(out["Patient_Count"]) == [1, 2]  # numeric untouched


def test_export_uses_comma_separator(tmp_path):
    df = pd.DataFrame({"Focus_Brand": ["OZEMPIC DIABETES"], "Patient_Count": [3]})
    path = tmp_path / "out.csv"
    export.to_csv(df, path)
    text = path.read_text(encoding="utf-8")
    header = text.splitlines()[0]
    assert "," in header
    assert "\t" not in header
    assert ";" not in header
    round_tripped = pd.read_csv(path, sep=",")
    pd.testing.assert_frame_equal(round_tripped, df)
