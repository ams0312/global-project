"""CSV export -- explicit comma-separated format
("export csv file using comma separated format")."""
from __future__ import annotations

from pathlib import Path

import pandas as pd


def to_csv(df: pd.DataFrame, path: str | Path) -> None:
    df.to_csv(path, sep=",", index=False, encoding="utf-8")
