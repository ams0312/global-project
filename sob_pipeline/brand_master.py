"""Canonical brand reference data for the HQ SoB diabetes report.

This is the single source of truth for two things that were previously
inconsistent / duplicated in the report:

1. Brand -> Regimen. Every brand maps to *exactly one* Regimen bucket.
   (Fixes: "insulins under both Basal and Bolus", e.g. HUMULIN, FIASP,
   ACTRAPID; fixes: "Regimen column has blank".)
2. Which brands are "indication-aware" (their Focus_Brand name must carry
   a Diabetes / Obesity suffix): OZEMPIC, MOUNJARO, WEGOVY.

Regimen values are intentionally a closed set. Any brand encountered in
the data that is not in BRAND_REGIMEN is treated as an error rather than
silently left blank -- see aggregate.validate_regimen_mapping().
"""
from __future__ import annotations

BASAL_INSULIN = "BASAL INSULIN"
BOLUS_INSULIN = "BOLUS INSULIN"
PREMIX_INSULIN = "PREMIX INSULIN"
GLP1 = "GLP-1"
OAD = "OAD"

# Each brand appears exactly once. Do not add a brand to more than one
# regimen bucket -- that was the root cause of the "insulin appears under
# both Basal and Bolus" bug (HUMULIN, FIASP, ACTRAPID).
BRAND_REGIMEN: dict[str, str] = {
    # Basal (long-acting) insulins
    "LANTUS": BASAL_INSULIN,
    "LEVEMIR": BASAL_INSULIN,
    "TOUJEO": BASAL_INSULIN,
    "OPTISULIN": BASAL_INSULIN,
    "SEMGLEE": BASAL_INSULIN,
    "HUMAN_BASAL": BASAL_INSULIN,
    # Bolus (rapid/short-acting) insulins
    "APIDRA": BOLUS_INSULIN,
    "FIASP": BOLUS_INSULIN,
    "HUMALOG": BOLUS_INSULIN,
    "NOVORAPID": BOLUS_INSULIN,
    "ACTRAPID": BOLUS_INSULIN,
    "HUMAN_BOLUS": BOLUS_INSULIN,
    # Premix insulins (fixed-ratio basal+bolus combinations)
    "HUMALOG MIX25": PREMIX_INSULIN,
    "HUMALOG MIX50": PREMIX_INSULIN,
    "NOVOMIX": PREMIX_INSULIN,
    "MIXTARD": PREMIX_INSULIN,
    "RYZODEG": PREMIX_INSULIN,
    "HUMULIN": PREMIX_INSULIN,
    # GLP-1 receptor agonists
    "OZEMPIC": GLP1,
    "MOUNJARO": GLP1,
    "WEGOVY": GLP1,
    "BYDUREON": GLP1,
    "BYETTA": GLP1,
    # Oral anti-diabetics / other combos
    "OAD": OAD,
    "TRAJENTA": OAD,
    "JANUMET": OAD,
    "FORXIGA": OAD,
    "JARDIANCE": OAD,
    "VELMETIA": OAD,
    "SEGLUROMET": OAD,
    "STEGLATRO": OAD,
}

# Brands whose Focus_Brand name must carry an indication suffix
# ("DIABETES" / "OBESITY"), at both the strength level and the brand
# (rollup) level, on positive *and* negative SoB rows.
INDICATION_AWARE_BRANDS = {"OZEMPIC", "MOUNJARO", "WEGOVY"}

# WEGOVY is obesity-only in this market; it should never carry a
# T1D/T2D indication even if a source system mistags it.
SINGLE_INDICATION_BRANDS = {"WEGOVY": "OBESITY"}

# Data-availability constraints: a brand/indication combination has no
# real volume before this Date (YYYYMM, int), so it must not be
# fabricated/backfilled into earlier months.
EARLIEST_AVAILABLE_DATE = {
    ("MOUNJARO", "OBESITY"): 202605,
}


def regimen_for(brand: str) -> str:
    """Return the single canonical Regimen for `brand`.

    Raises KeyError for unmapped brands rather than returning a blank
    Regimen -- an unmapped brand must be added to BRAND_REGIMEN above.
    """
    brand = brand.strip().upper()
    if brand not in BRAND_REGIMEN:
        raise KeyError(f"Brand {brand!r} has no Regimen mapping in BRAND_REGIMEN")
    return BRAND_REGIMEN[brand]


def is_indication_aware(brand: str) -> bool:
    return brand.strip().upper() in INDICATION_AWARE_BRANDS


def focus_brand_name(brand: str, indication: str | None) -> str:
    """Build the Focus_Brand label, adding the indication suffix only for
    indication-aware brands (OZEMPIC, MOUNJARO, WEGOVY). Every other brand
    keeps its bare name -- e.g. TRAJENTA never gets a Diabetes/Obesity
    suffix, only the GLP-1 weight-management drugs do."""
    brand = brand.strip().upper()
    if brand in INDICATION_AWARE_BRANDS:
        forced = SINGLE_INDICATION_BRANDS.get(brand)
        ind = forced or (indication or "").strip().upper()
        if not ind:
            raise ValueError(f"Indication-aware brand {brand!r} is missing an Indication")
        return f"{brand} {ind}"
    return brand


def focus_brand_detail_name(brand: str, indication: str | None, strength: str | None) -> str:
    """Strength-level Focus_Brand label, e.g. "OZEMPIC 0.25,0.5MG, 1.5ML
    DIABETES". Falls back to the brand-level name when no strength is
    tracked for this brand (insulins, OADs in this dataset)."""
    brand = brand.strip().upper()
    strength = (strength or "").strip().upper()
    if brand in INDICATION_AWARE_BRANDS:
        forced = SINGLE_INDICATION_BRANDS.get(brand)
        ind = forced or (indication or "").strip().upper()
        if not ind:
            raise ValueError(f"Indication-aware brand {brand!r} is missing an Indication")
        return f"{brand} {strength} {ind}".strip() if strength else f"{brand} {ind}"
    return f"{brand} {strength}".strip() if strength else brand


def is_available(brand: str, indication: str | None, date: int) -> bool:
    """False if this brand/indication has no real volume yet at `date`."""
    brand = brand.strip().upper()
    ind = (SINGLE_INDICATION_BRANDS.get(brand) or (indication or "")).strip().upper()
    earliest = EARLIEST_AVAILABLE_DATE.get((brand, ind))
    return earliest is None or date >= earliest
