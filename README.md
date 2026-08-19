# HQ SoB Diabetes Report

A from-scratch pipeline that builds the HQ Source-of-Business (SoB) diabetes
report from raw patient-basket Rx data. It was written to resolve the full
list of review comments from the "HQ SoB diabetes report" feedback thread;
every comment is mapped to its fix and its test below.

## Pipeline

```
diabetes_batch.csv + obesity_batch.csv
    -> merge.merge_batches()          brand master lookup, indication tagging, Focus_Brand naming
    -> classify.classify()            per-patient SoB category (incl. negative SoB)
    -> aggregate.validate_regimen_mapping()   fail loud on blank/duplicate Regimen
    -> aggregate.strength_level() / aggregate.brand_level()
    -> capitalize.capitalize_all()
    -> export.to_csv()                comma-separated
```

Run it:

```python
import pandas as pd
from sob_pipeline import run_pipeline

diabetes = pd.read_csv("sample_data/diabetes_batch.csv")
obesity = pd.read_csv("sample_data/obesity_batch.csv")
history = pd.read_csv("sample_data/patient_history.csv")

run_pipeline(diabetes, obesity, history, out_dir="out/")
```

Run tests: `pytest tests/ -q` (30 tests, one or more per comment below).

## Input schema

`diabetes_batch.csv` / `obesity_batch.csv` (identical schema, unioned):

| Column | Meaning |
|---|---|
| Country, Region | geography |
| Date | YYYYMM int |
| Type | source-tagged indication (T1D/T2D/OBESITY) -- may be stale, see below |
| Patient_ID | patient identifier |
| Period | BEFORE or PRESENT (the patient's basket in the prior vs. current period) |
| Brand | drug brand, e.g. OZEMPIC, LANTUS, OAD |
| Strength | SKU/dosage string, only populated for Ozempic/Mounjaro/Wegovy in this dataset |
| LRx_Projected | prescription volume |

`patient_history.csv`: Patient_ID, Date, Is_First_Ever_Record, Is_New_To_Database
-- flags used to distinguish Treatment Naive First / New To Database / Treatment Naive.

## Every comment, mapped to its fix

### Round 1

- **"add Mounjaro and Ozempic Rx from obesity batch"** -> `merge.merge_batches()`
  concatenates `diabetes_batch` and `obesity_batch` into one long table.
  Test: `test_merge.py::test_obesity_batch_rows_are_included`.
- **"add indication obesity for obesity usage"** -> `merge._resolve_indication()`
  tags every row's `Indication` from which batch it came from.
  Test: `test_merge.py::test_obesity_usage_is_tagged_and_renamed`.
- **"rename Mounjaro and Ozempic based on usage"** -> `brand_master.focus_brand_name()`
  builds `"MOUNJARO DIABETES"` / `"MOUNJARO OBESITY"` etc. Same test as above.
- **"capitalize all the variables"** -> `capitalize.capitalize_all()` uppercases
  every string-valued column right before export.
  Test: `test_capitalize_and_export.py::test_capitalize_all_uppercases_string_columns`.
- **"export csv file using comma separated format"** -> `export.to_csv()` writes
  with an explicit `sep=","`. Test: `test_capitalize_and_export.py::test_export_uses_comma_separator`.
- **"correct to see Ozempic diabetes in Focus_Brand, but not in Before/Present"**
  -- raised in round 1, then reversed in the clarifying Q&A (Q4): the final,
  authoritative instruction is that Before/Present *should* include the
  indication suffix, at both strength and brand level. Implemented that way;
  see the switching section below and `test_classify.py::test_before_present_columns_are_unchanged_free_text`.
- **"focus = Ozempic obesity, indication is T1D/T2D... same for Wegovy"** ->
  `merge._load()` forces `Type` to match the resolved `Indication` for every
  indication-aware brand, and Wegovy is hard-coded single-indication (Obesity).
  Test: `test_merge.py::test_focus_brand_never_shows_wrong_indication_type`.
- **"I see some insulins under both basal and bolus"** -> `brand_master.BRAND_REGIMEN`
  is a single dict, one Regimen per brand, by construction (HUMULIN -> Premix
  Insulin only, FIASP/ACTRAPID -> Bolus Insulin only).
  Test: `test_brand_master.py::test_every_brand_has_exactly_one_regimen`.
- **"Mounjaro and Ozempic don't have indication label in Focus_Brand for all
  negative SoB"** -> the same `Focus_Brand` field (already indication-suffixed)
  is used for positive *and* negative category rows -- there's no separate
  code path for negative rows to fall out of sync.
  Test: `test_classify.py::test_mounjaro_negative_sob_keeps_indication_label`.
- **"Mounjaro obesity only appear in 202605"** -> `brand_master.EARLIEST_AVAILABLE_DATE`
  + `is_available()` drops any Mounjaro-Obesity row dated before 202605
  instead of backfilling it. Test: `test_merge.py::test_mounjaro_obesity_only_from_202605`.
- **"I can still see insulin under both Basal and Bolus, such as ACTRAPID"** ->
  same single-dict fix as above; explicitly asserted for ACTRAPID.
- **"Repeat patients... Before doesn't have Ozempic, seems like add-on to me"**
  / **"add-on patients now have Ozempic in both Before and Present"** ->
  `classify._classify_one()`: Repeat requires the focus brand in *both*
  Before and Present; Add-on requires it in Present only, with at least one
  other prior brand persisting. These are mutually exclusive by construction.
  Tests: `test_classify.py::test_repeat_before_includes_focus_brand`,
  `test_classify.py::test_add_on_before_excludes_focus_brand`.
- **"very limited patients under Ozempic/Mounjaro obesity (<100/month)"** --
  acknowledged, not a bug: the pipeline applies no volume-based suppression
  anywhere, so small-but-real cohorts are never dropped or floored.
- **"Ozempic diabetes and Ozempic obesity don't have negative SoB"** -> negative
  categories (Loss, Drop Out, Discontinued) are computed by the same symmetric
  rule set as positive ones, for every brand including Ozempic/Mounjaro.
  Test: `test_classify.py::test_ozempic_diabetes_and_obesity_have_negative_sob`.

### Switching / Win-Lose logic (clarifying Q&A)

Validated directly against the user's own worked example ("diagram #1"):
Jan `Ozempic+OAD` -> Feb `Ozempic` (repeat) / `OAD` (drop out) -> Mar `OAD`
(win from Ozempic) / `Ozempic` (loss to OAD) -> Apr `OAD` (repeat) /
`Ozempic` (add-on to OAD). See `test_classify.py::test_diagram_1_worked_example`.

1. *"If Ozempic is added on top of OAD and OAD stays active, is that still
   Add-on?"* -> **Yes.** `ADD_ON` fires whenever some other Before brand
   persists into Present.
2. *"Does win-from apply to any drug class, or just OAD?"* -> **Any class.**
   `_classify_one()` has no brand-specific logic anywhere; Win/Loss is pure
   basket-overlap comparison. Test: `test_classify.py::test_win_from_any_drug_class_generic`.
3. *"Do you want a mirrored Lose entry?"* -> **Yes.** Because every brand in
   the patient's basket is classified independently with the same symmetric
   rule, a Win for the incoming brand always produces a Loss (or Drop Out)
   row for the outgoing brand automatically. Test: `test_classify.py::test_win_has_mirrored_lose_entry`.
4. *"Should Before/Present stay as-is, and should Ozempic/Mounjaro include
   indication at both levels?"* -> **Yes to both.** Before/Present remain
   plain combo strings (no literal "X win from Y" text); Category is the only
   new signal. Ozempic/Mounjaro/Wegovy carry their indication suffix in
   Before/Present at strength level (e.g. `"OZEMPIC 0.25,0.5MG, 1.5ML
   DIABETES"`) and the Brand_Key used for Win/Loss/rollups already carries it
   at brand level (e.g. `"OZEMPIC DIABETES"`).
   Test: `test_classify.py::test_before_present_columns_are_unchanged_free_text`.

### Round 2 / Round 3 (after SoB categories were confirmed fixed)

- **"Mounjaro obesity and Ozempic obesity is missing"** -> not a special case;
  same obesity-batch merge as above. Verified end to end in `test_pipeline.py`.
- **"BYDUREON, BYETTA, SEGLUROMET and STEGLATRO are missing"** -> added to
  `brand_master.BRAND_REGIMEN` (previously they had no Regimen mapping at
  all, so any pipeline that required a Regimen would silently or loudly drop
  them). Also confirmed the pipeline applies no static month/brand allowlist
  anywhere -- brands are read from whatever's in the data each month, so a
  brand with volume only in 202605 (as the user confirmed for these four)
  still appears that month and no other.
  Test: `test_aggregate.py::test_previously_missing_brands_appear_in_may_only`.
- **"Regimen column has blank + one drug in multiple regimen"** ->
  `aggregate.validate_regimen_mapping()` runs before any rollup and raises
  immediately on either condition instead of letting a blank or split
  Regimen reach the report.
  Tests: `test_aggregate.py::test_validate_regimen_mapping_rejects_blank_regimen`,
  `test_aggregate.py::test_validate_regimen_mapping_rejects_split_brand`.
- **"On drug is not equal to sum of all positive SoB" / "on drug should be
  the sum of [the 7 categories]" / "On drug is still on distinct count"**
  -> `aggregate.on_drug()` is a literal `.sum()` over
  `Treatment naive first, Treatment naive, New to database, Insulin naive,
  Add on, Win, Repeat` -- never `nunique()`/`DISTINCTCOUNT` on Patient_ID,
  and never collapsed across months.
  Tests: `test_aggregate.py::test_on_drug_is_sum_of_seven_positive_categories`,
  `test_aggregate.py::test_on_drug_is_a_per_month_sum_not_a_cross_month_distinct_count`.
- **"There is one insulin (HUMULIN) that's both basal and bolus"** -> same
  single-dict Regimen fix; HUMULIN is Premix Insulin only.
- **"Ozempic and Mounjaro on strength level is good, but on brand level we
  don't have diabetes and obesity split... Ozempic is total"** ->
  `aggregate.brand_level()` groups on `Focus_Brand_Brand_Level`, which is
  computed once in `merge.py` and already carries the indication suffix
  (with no strength) -- so `OZEMPIC DIABETES` and `OZEMPIC OBESITY` are
  always two separate rows at every rollup level, never blended into one
  `OZEMPIC` total. Test: `test_aggregate.py::test_ozempic_brand_level_splits_diabetes_and_obesity`.

## Files

- `sob_pipeline/brand_master.py` -- canonical brand -> Regimen map, indication-aware brands
- `sob_pipeline/merge.py` -- batch union, indication tagging, Focus_Brand naming
- `sob_pipeline/classify.py` -- per-patient SoB category assignment
- `sob_pipeline/aggregate.py` -- rollups, Regimen validation, On_Drug
- `sob_pipeline/capitalize.py` -- uppercase all string values
- `sob_pipeline/export.py` -- comma-separated CSV export
- `sob_pipeline/pipeline.py` -- orchestrator
- `sample_data/` -- fixtures reproducing every scenario above
- `tests/` -- 30 tests, one or more per comment
