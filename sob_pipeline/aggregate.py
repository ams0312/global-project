"""Roll the patient-level SoB detail table up into the two report outputs:

  * strength_level()  -- one row per (Date, Regimen, Focus_Brand incl.
    strength+indication, Category, Before, Present) with summed
    Patient_Count / LRx_Projected. Matches the "strength level" screenshot.
  * brand_level()     -- one row per (Date, Regimen, Focus_Brand at brand
    level, incl. indication but no strength). Matches the "Regimen /
    Focus_Brand / Sum of LRx_Projected" pivot screenshot.

Also:
  * validate_regimen_mapping() fails loudly instead of allowing a blank
    Regimen or a brand split across two Regimens
    ("Regimen column has blank + one drug in multiple regimen, e.g. FIASP
    in both Basal insulin and Bolus insulin").
  * on_drug() computes "On Drug" as the literal sum of the seven positive
    SoB categories -- not a distinct-patient count
    ("On drug is still on distinct count. Could you please check?").
"""
from __future__ import annotations

import pandas as pd

from .classify import POSITIVE_CATEGORIES

STRENGTH_GROUP_COLS = [
    "Country",
    "Region",
    "Date",
    "Type",
    "Category_short",
    "Category_long",
    "Category",
    "Regimen",
    "Focus_Brand",
    "Before",
    "Present",
]

BRAND_GROUP_COLS = [
    "Country",
    "Region",
    "Date",
    "Type",
    "Category_short",
    "Category_long",
    "Category",
    "Regimen",
    "Focus_Brand",
]

SUM_COLS = ["Patient_Count", "LRx_Projected"]


def validate_regimen_mapping(detail: pd.DataFrame, brand_col: str = "Focus_Brand_Brand_Level") -> None:
    if detail[brand_col].isna().any() or (detail[brand_col].astype(str).str.strip() == "").any():
        raise ValueError(f"Blank {brand_col} found in detail rows")
    if detail["Regimen"].isna().any() or (detail["Regimen"].astype(str).str.strip() == "").any():
        blank = detail.loc[
            detail["Regimen"].isna() | (detail["Regimen"].astype(str).str.strip() == ""), brand_col
        ].unique()
        raise ValueError(f"Blank Regimen for brand(s): {sorted(blank)}")

    regimen_counts = detail.groupby(brand_col)["Regimen"].nunique()
    offenders = regimen_counts[regimen_counts > 1]
    if not offenders.empty:
        detail_map = {
            b: sorted(detail.loc[detail[brand_col] == b, "Regimen"].unique()) for b in offenders.index
        }
        raise ValueError(f"Brand(s) mapped to more than one Regimen: {detail_map}")


def strength_level(detail: pd.DataFrame) -> pd.DataFrame:
    return (
        detail.groupby(STRENGTH_GROUP_COLS, as_index=False)[SUM_COLS]
        .sum()
        .sort_values(STRENGTH_GROUP_COLS)
        .reset_index(drop=True)
    )


def brand_level(detail: pd.DataFrame) -> pd.DataFrame:
    """Brand-level rollup. Groups on Focus_Brand_Brand_Level (which already
    carries the indication suffix for Ozempic/Mounjaro/Wegovy, but no
    strength), so Diabetes and Obesity usage never blend into one total
    row -- fixes "on brand level we don't have diabetes and obesity split
    ... Ozempic is total"."""
    renamed = detail.drop(columns=["Focus_Brand"]).rename(columns={"Focus_Brand_Brand_Level": "Focus_Brand"})
    return (
        renamed.groupby(BRAND_GROUP_COLS, as_index=False)[SUM_COLS]
        .sum()
        .sort_values(BRAND_GROUP_COLS)
        .reset_index(drop=True)
    )


def on_drug(rolled_up: pd.DataFrame, group_cols: list[str]) -> pd.DataFrame:
    """On_Drug = sum of Patient_Count across exactly the seven positive
    SoB categories, grouped by `group_cols` (e.g. Regimen + Focus_Brand +
    Date). This is a plain sum, never patient.nunique() -- On Drug must
    equal the sum of Treatment naive first + Treatment naive +
    New to database + Insulin naive + Add on + Win + Repeat."""
    positive = rolled_up[rolled_up["Category"].isin(POSITIVE_CATEGORIES)]
    return (
        positive.groupby(group_cols, as_index=False)["Patient_Count"]
        .sum()
        .rename(columns={"Patient_Count": "On_Drug"})
    )
