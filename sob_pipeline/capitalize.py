"""Enforce uppercase on every text field before export ("capitalize all
the variables"). Numeric/date/bool columns are left untouched."""
from __future__ import annotations

import pandas as pd
from pandas.api.types import is_string_dtype


def capitalize_all(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    for col in out.columns:
        # pandas' modern string dtype (and plain object-dtype strings) both
        # need to be caught here -- a bare `dtype == object` check misses
        # the newer arrow-backed string dtype.
        if is_string_dtype(out[col]):
            out[col] = out[col].astype(str).str.strip().str.upper()
    return out
