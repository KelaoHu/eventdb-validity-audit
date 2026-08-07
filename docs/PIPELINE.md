# Pipeline Lineage（数据血缘图）

Six stages from raw downloads to published numbers. File paths refer to this repository unless marked **[Zenodo]** (raw layer, 3.5 GB).

```
[Stage 1] Acquisition
  code/01_acquisition/gdelt/gdelt_download_zips_v4.12.py      → GDELT event zips (data.gdeltproject.org)
  code/01_acquisition/icews/icews_download_dataverse_v4.14.py → ICEWS zips (Harvard Dataverse DVN/28075)
  Phoenix / Tsinghua / polling: manual downloads (see docs/DATA_SOURCES.md)

[Stage 2] Dyad retrieval (China × 25 partners, strict actor-country matching)
  code/01_acquisition/gdelt/gdelt_retrieve_china_25partners_v4.14.py → [Zenodo] GDELT raw bilateral CSV (2.36 GB)
  code/01_acquisition/icews/icews_retrieve_25partners_v4.17.py      → [Zenodo] ICEWS raw bilateral CSV (210 MB)
  Phoenix: [Zenodo] Phoenix数据来源/ → 整理脚本 → Phoenix 双边检索 CSV (31.9 MB)

[Stage 3] Day-to-month aggregation (geometric mean, log space, +11 shift, two-stage day→month)
  code/02_aggregation/geometric_mean_day_to_month_v5.23_GDELT.py (main line)
  code/02_aggregation/three_db_five_algorithms_v6.3_optimized.py (3 databases × 5 algorithms)
  + 26 alternative/robustness scripts in code/02_aggregation/
  → data/scores_full/ (full coverage) → fair-coverage truncation (ICEWS ≤ 2023-04, Phoenix ≤ 2019-03)
  → data/core/{gdelt,icews,phoenix,tsinghua}_scores.csv  ★ the paper's fair-coverage caliber

[Stage 4] Panels
  code/04_panel/build_panel_with_lags.py
    (IMF DOTS trade + 4-database scores + QNEA GDP + REER + WTO FTA dummies, lags L0–L6)
    → data/core/panel_clean.csv (n = 6,685)
  code/04_panel/polling/phase0_clean.py → E0_events_merge.R
    → data/core/polling_panel_pew17.csv (17 countries × 13 waves, N = 170)

[Stage 5] Estimation & audit (R 4.6, fixest)
  code/06_analysis/ppml_suite/            continuous-score PPML-HDFE, LP h=0–6, AR(1), freq scan, forward effects
  code/06_analysis/event_study_suite/     9 modules: hit rates, signal gradient, trust asymmetry, alliance, …
  code/06_analysis/revision_tests_202607/ 17 modules: horse race, breakpoints, remote-talk confounds, sanctions, …
  code/06_analysis/19_sanction_observability/ , 20_full_ppml_tables/
  code/06_analysis/rerun_fair_coverage_202607/  ★ canonical full/fair double rerun + comparison ledger
    (对比总账/compare_summary.csv: 13 PASS / 10 DIFF, all DIFFs = documented 713→712 event revision)

[Stage 6] Figures & tables
  code/07_figures/fig01–06_v3.R, figS1–S3 → figures/ (300 dpi)
  data/appendix_tables/ 27 CSVs (Table S3–S12 series)
```

## Path remapping notes

Scripts carry the author's machine paths. To re-run against this repo:
- repo root ↔ author's `311工程数据\`
- `data/appendix_tables/` ↔ author's `05_文档/附录数据表/`
- `code/06_analysis/` ↔ author's `03_检验与分析套件/`
- two figure scripts cite the pre-rename `Table_S4_1R_Hitrate_comparison.csv` → use `data/appendix_tables/Table_S7_1R_Hitrate_comparison.csv`
- raw retrieval inputs → Zenodo archive (see `docs/DATA_SOURCES.md`)
