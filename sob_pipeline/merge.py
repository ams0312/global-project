"""Merge the diabetes and obesity Rx batches into a single long-format
basket table (one row per patient / month / before-or-present period /
brand), and resolve the Focus_Brand + Indication fields.

Input schema for both batches (identical):
    Country, Region, Date (YYYYMM int), Type (T1D/T2D/OBESITY),
    Patient_ID, Period (BEFORE/PRESENT), Brand, LRx_Projected

Resolves:
- "add Mounjaro and Ozempic Rx from obesity batch": obesity batch rows are
  concatenated into the same long table the rest of the pipeline reads.
- "add indication obesity for obesity usage": Indication is derived from
  which batch a row came from (or forced for single-indication brands
  like WEGOVY), not copied verbatim from a possibly-stale Type field.
- "rename Mounjaro and Ozempic based on usage": Focus_Brand becomes
  "MOUNJARO DIABETES" / "MOUNJARO OBESITY" etc. via brand_master.focus_brand_name.
- "focus = Ozempic obesity, indication is T1D/T2D is weird. Same for
  Wegovy": Type is overridden to match the resolved Indication for
  indication-aware brands, so it can never disagree with Focus_Brand.
- "Mounjaro obesity only appears in 202605": rows before the brand's
  earliest-available date are dropped, not backfilled.
"""
from __future__ import annotations

import pandas as pd

from . import brand_master

RAW_COLUMNS = [
    "Country",
    "Region",
    "Date",
    "Type",
    "Patient_ID",
    "Period",
    "Brand",
    "Strength",
    "LRx_Projected",
]


def _resolve_indication(row: pd.Series, source_batch: str) -> str:
    brand = row["Brand"].strip().upper()
    if brand not in brand_master.INDICATION_AWARE_BRANDS:
        return row["Type"]
    forced = brand_master.SINGLE_INDICATION_BRANDS.get(brand)
    if forced:
        return forced
    return "OBESITY" if source_batch == "obesity" else "DIABETES"


def _load(df: pd.DataFrame, source_batch: str) -> pd.DataFrame:
    missing = set(RAW_COLUMNS) - set(df.columns)
    if missing:
        raise ValueError(f"{source_batch} batch is missing columns: {sorted(missing)}")
    out = df[RAW_COLUMNS].copy()
    out["Brand"] = out["Brand"].astype(str).str.strip().str.upper()
    out["Strength"] = out["Strength"].fillna("").astype(str).str.strip().str.upper()
    out["Period"] = out["Period"].astype(str).str.strip().str.upper()
    out["Date"] = out["Date"].astype(int)
    out["Source_Batch"] = source_batch
    out["Indication"] = out.apply(lambda r: _resolve_indication(r, source_batch), axis=1)
    # Type must always agree with the resolved Indication for
    # indication-aware brands (fixes "focus=Ozempic obesity, indication
    # is T1D/T2D").
    aware = out["Brand"].isin(brand_master.INDICATION_AWARE_BRANDS)
    out.loc[aware, "Type"] = out.loc[aware, "Indication"]
    return out


def merge_batches(diabetes_df: pd.DataFrame, obesity_df: pd.DataFrame) -> pd.DataFrame:
    """Union the two batches and drop rows that aren't available yet
    (e.g. Mounjaro Obesity before 202605)."""
    diabetes = _load(diabetes_df, "diabetes")
    obesity = _load(obesity_df, "obesity")
    merged = pd.concat([diabetes, obesity], ignore_index=True)

    available_mask = merged.apply(
        lambda r: brand_master.is_available(r["Brand"], r["Indication"], r["Date"]),
        axis=1,
    )
    merged = merged[available_mask].reset_index(drop=True)

    merged["Regimen"] = merged["Brand"].map(brand_master.regimen_for)
    # Brand-level identity (no strength) -- used for SoB basket comparisons
    # (switching strengths of the same brand is never a Win/Loss) and for
    # the brand-level rollup, so it must already carry the indication
    # suffix for OZEMPIC/MOUNJARO/WEGOVY.
    merged["Brand_Key"] = merged.apply(
        lambda r: brand_master.focus_brand_name(r["Brand"], r["Indication"]), axis=1
    )
    # Strength-level display identity -- used for the detail report's
    # Focus_Brand and for the Before/Present basket strings.
    merged["Focus_Brand_Detail"] = merged.apply(
        lambda r: brand_master.focus_brand_detail_name(r["Brand"], r["Indication"], r["Strength"]),
        axis=1,
    )
    return merged
