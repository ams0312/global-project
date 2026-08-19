"""Patient-level Source-of-Business (SoB) classification.

For every patient/month, and for every brand the patient touched (either
in their Before basket or their Present basket), this assigns exactly one
SoB category by comparing the two baskets.

Positive categories (patient is "on drug" for that Focus_Brand in Present):
    TREATMENT NAIVE FIRST, TREATMENT NAIVE, NEW TO DATABASE, INSULIN NAIVE,
    ADD ON, WIN, REPEAT
Negative categories (patient was on that Focus_Brand in Before, isn't now):
    LOSS, DROP OUT, DISCONTINUED

Rules (validated against the user's worked example, diagram #1):
  F in Before AND F in Present                              -> REPEAT
  F in Present only, Before empty, first-ever record         -> TREATMENT NAIVE FIRST
  F in Present only, Before empty, new-to-database           -> NEW TO DATABASE
  F in Present only, Before empty, otherwise                 -> TREATMENT NAIVE
  F in Present only, F is insulin, no insulin in Before       -> INSULIN NAIVE
  F in Present only, some other Before brand persists         -> ADD ON
  F in Present only, no Before brand persists (full swap)     -> WIN
  F in Before only, Present empty                             -> DISCONTINUED
  F in Before only, some other Before brand persists          -> DROP OUT
  F in Before only, no Before brand persists (full swap)      -> LOSS

Because this is evaluated independently for *every* brand touched, a WIN
for the incoming brand and a LOSS/DROP OUT for the outgoing brand fall out
of the same symmetric rule set automatically -- there is no special-cased
"OAD" anywhere, so "win from" logic applies to any drug class being
replaced (per clarification: "win from should apply to any drug, OAD is
just an example"), and a Win always has a mirrored Loss/Drop Out entry on
the losing brand's side (per clarification: "we need to lose").

Before/Present output strings use the same Focus_Brand token as the rest
of the report -- i.e. Ozempic/Mounjaro/Wegovy items carry their indication
suffix in Before/Present too, at both strength and brand level (per
clarification: "make sure for Ozempic and Mounjaro also include the
indication... for both brand level and strength level").
"""
from __future__ import annotations

import pandas as pd

from . import brand_master

INSULIN_REGIMENS = {brand_master.BASAL_INSULIN, brand_master.BOLUS_INSULIN, brand_master.PREMIX_INSULIN}

TREATMENT_NAIVE_FIRST = "TREATMENT NAIVE FIRST"
TREATMENT_NAIVE = "TREATMENT NAIVE"
NEW_TO_DATABASE = "NEW TO DATABASE"
INSULIN_NAIVE = "INSULIN NAIVE"
ADD_ON = "ADD ON"
WIN = "WIN"
REPEAT = "REPEAT"
LOSS = "LOSS"
DROP_OUT = "DROP OUT"
DISCONTINUED = "DISCONTINUED"

POSITIVE_CATEGORIES = [
    TREATMENT_NAIVE_FIRST,
    TREATMENT_NAIVE,
    NEW_TO_DATABASE,
    INSULIN_NAIVE,
    ADD_ON,
    WIN,
    REPEAT,
]
NEGATIVE_CATEGORIES = [LOSS, DROP_OUT, DISCONTINUED]


def _basket(rows: pd.DataFrame, period: str) -> dict[str, str]:
    """Brand_Key -> Regimen for every item in that period's basket.
    Brand_Key is the brand-level identity (indication-suffixed for
    OZEMPIC/MOUNJARO/WEGOVY, no strength) -- switching strengths of the
    same brand must never look like a Win/Loss."""
    sub = rows[rows["Period"] == period]
    return dict(zip(sub["Brand_Key"], sub["Regimen"]))


def _detail_basket(rows: pd.DataFrame, period: str) -> dict[str, str]:
    """Brand_Key -> Focus_Brand_Detail (strength-level display string) for
    that period's basket."""
    sub = rows[rows["Period"] == period]
    return dict(zip(sub["Brand_Key"], sub["Focus_Brand_Detail"]))


def _classify_one(focus_brand: str, before: dict[str, str], present: dict[str, str],
                   is_first_ever: bool, is_new_to_db: bool) -> str:
    in_before = focus_brand in before
    in_present = focus_brand in present

    if in_before and in_present:
        return REPEAT

    if in_present and not in_before:
        if not before:
            if is_first_ever:
                return TREATMENT_NAIVE_FIRST
            if is_new_to_db:
                return NEW_TO_DATABASE
            return TREATMENT_NAIVE
        regimen = present[focus_brand]
        if regimen in INSULIN_REGIMENS and not any(r in INSULIN_REGIMENS for r in before.values()):
            return INSULIN_NAIVE
        other_before_persists = any(b in present for b in before if b != focus_brand)
        return ADD_ON if other_before_persists else WIN

    # in_before and not in_present
    if not present:
        return DISCONTINUED
    other_before_persists = any(b in present for b in before if b != focus_brand)
    return DROP_OUT if other_before_persists else LOSS


def classify(merged: pd.DataFrame, patient_history: pd.DataFrame) -> pd.DataFrame:
    """Build the strength-level SoB detail table.

    `merged` is the long basket table from merge.merge_batches().
    `patient_history` has columns Patient_ID, Date, Is_First_Ever_Record,
    Is_New_To_Database (booleans) describing each patient's status as of
    that month.
    """
    history = patient_history.set_index(["Patient_ID", "Date"])
    rows = []

    group_cols = ["Country", "Region", "Date", "Patient_ID"]
    for (country, region, date, patient_id), g in merged.groupby(group_cols, sort=False):
        before = _basket(g, "BEFORE")
        present = _basket(g, "PRESENT")
        before_detail = _detail_basket(g, "BEFORE")
        present_detail = _detail_basket(g, "PRESENT")
        try:
            hist = history.loc[(patient_id, date)]
            is_first_ever = bool(hist["Is_First_Ever_Record"])
            is_new_to_db = bool(hist["Is_New_To_Database"])
        except KeyError:
            is_first_ever = False
            is_new_to_db = False

        before_str = " + ".join(sorted(before_detail.values())) if before_detail else ""
        present_str = " + ".join(sorted(present_detail.values())) if present_detail else ""

        for brand_key in sorted(set(before) | set(present)):
            regimen = present.get(brand_key) or before.get(brand_key)
            category = _classify_one(brand_key, before, present, is_first_ever, is_new_to_db)
            period_for_volume = "PRESENT" if category in POSITIVE_CATEGORIES else "BEFORE"
            item_rows = g[(g["Brand_Key"] == brand_key) & (g["Period"] == period_for_volume)]
            lrx = item_rows["LRx_Projected"].sum()
            type_ = g.loc[g["Brand_Key"] == brand_key, "Type"].iloc[0]
            focus_brand_detail = present_detail.get(brand_key) or before_detail.get(brand_key)
            rows.append(
                {
                    "Country": country,
                    "Region": region,
                    "Date": date,
                    "Type": type_,
                    "Category_short": category,
                    "Category_long": category,
                    "Category": category,
                    "Regimen": regimen,
                    "Focus_Brand": focus_brand_detail,
                    "Focus_Brand_Brand_Level": brand_key,
                    "Patient_ID": patient_id,
                    "Before": before_str,
                    "Present": present_str,
                    "Patient_Count": 1,
                    "LRx_Projected": lrx,
                }
            )

    return pd.DataFrame(rows)
