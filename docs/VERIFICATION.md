# Verification Record（复现验证记录）

**Date**: 2026-08-07 · **Scope**: every layer of this repository · **Method**: md5 lineage checks, row-count assertions, statistic recomputation, and end-to-end re-execution.

## A-level: file integrity & lineage (all passed)

| Check | Result |
|---|---|
| 7 release CSVs vs production sources (md5) | identical ✓ |
| Row counts: panel 6,685 / Pew panel 170 / gold-standard events 712 / ICEWS fair 19,200 / Phoenix fair 15,525 / GDELT 21,600 | all exact ✓ |
| Archived retrieval scripts vs final pipeline versions (v4.14 GDELT, v4.17 ICEWS), line-by-line diff | same version ✓ |
| Raw retrieval CSVs (GDELT 2.36 GB, ICEWS 210 MB) vs timestamped final-retrieval outputs (md5) | identical ✓ |

## B-level: statistic recomputation (all passed)

| Statistic | Recomputed | Published |
|---|---|---|
| GDELT–ICEWS Spearman ρ, China–Japan (n = 207) | **0.633** | 0.633 ✓ |
| GDELT–ICEWS Spearman ρ, China–Brazil (n = 207) | **0.031** | 0.031 ✓ |
| Gold-standard hit rates (GDELT 68.3%, ICEWS 66.1%, Phoenix 65.1%, Tsinghua 62.7%) | consistent with fair-coverage rerun `hit_rate_main.csv` | ✓ |

## C-level: end-to-end re-execution (all passed)

| Test | Result |
|---|---|
| `fig02_v3.R` re-run **using only files in this package** (paths remapped) | built-in QA gates all passed: hit rates 67.5 / 51.3 / 75.8; Phoenix IRF h=0: −1.87 (neg) / +0.43 (pos); M1-fair consistency ✓ |
| `geometric_mean_day_to_month_v5.23_GDELT.py` re-run on the full 2.36 GB raw CSV | output **byte-identical** (md5 `7cd1a31c…`) to the released GDELT scores ✓ |

**2026-08-08 update**: the lean edition was re-verified after restructuring — `fig02_v3.R` re-run again on the new paths, all QA gates passed; all kept Python scripts compile; row-count assertions re-passed.

## D-level: documented gates (on file, not re-run)

- Fair-coverage build gate G0 (2026-07-29): zero mismatches (`03` layer `_build_log.txt`)
- Canonical rerun comparison ledger (`code/06_analysis/rerun_fair_coverage_202607/comparison_ledger/`): 13 PASS / 10 DIFF — all DIFFs trace to the documented 713→712 event-library revision

## Known notes

- `events_713.csv` files were superseded archival versions (713 events) and are **not included** in this lean edition; the current gold standard is 712.
- Figure scripts read appendix CSVs via `data/appendix_tables/` (2026-08-09 renumbering: `Table_S9_1R...`, `Table_S6_5/6_7/6_8...`; legacy `311工程\` prefix removed).
