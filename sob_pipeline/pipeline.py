"""End-to-end orchestrator for the HQ SoB diabetes report.

    diabetes_batch + obesity_batch
        -> merge.merge_batches()          (union, indication tagging, Focus_Brand naming)
        -> classify.classify()            (per-patient SoB category, incl. negative SoB)
        -> aggregate.validate_regimen_mapping()  (fail loud on blank/duplicate Regimen)
        -> aggregate.strength_level() / aggregate.brand_level()
        -> capitalize.capitalize_all()
        -> export.to_csv()
"""
from __future__ import annotations

from pathlib import Path

import pandas as pd

from . import aggregate, capitalize, classify, export, merge


def run_pipeline(
    diabetes_batch: pd.DataFrame,
    obesity_batch: pd.DataFrame,
    patient_history: pd.DataFrame,
    out_dir: str | Path,
) -> dict[str, pd.DataFrame]:
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    merged = merge.merge_batches(diabetes_batch, obesity_batch)
    detail = classify.classify(merged, patient_history)
    aggregate.validate_regimen_mapping(detail)

    strength = aggregate.strength_level(detail)
    brand = aggregate.brand_level(detail)

    strength_out = capitalize.capitalize_all(strength)
    brand_out = capitalize.capitalize_all(brand)

    export.to_csv(strength_out, out_dir / "sob_strength_level.csv")
    export.to_csv(brand_out, out_dir / "sob_brand_level.csv")

    return {"detail": detail, "strength_level": strength_out, "brand_level": brand_out}
