# Replication Package — Measuring Validity of Political Event Databases: An Audience-Specific Audit

> Anonymous replication package for double-anonymised peer review. No author-identifying information is included.
> 匿名复现包（双盲审稿用）。本包不含任何作者身份信息。

## Contents

### `附录数据表/` (27 CSV files)
All numerical tables cited in the manuscript's Supplementary Information (Tables S1–S8): inter-coder reliability, aggregation robustness, country-level correlations, hit rates, remote-talk checks, sanctions direction tests, full PPML results, and polling convergence/event tables. See `附录数据表/README.md` for the file-by-file index.

### `数据/` (core datasets)
- `events_712_gold_standard.csv` — 712 hand-curated gold-standard bilateral events (17 categories, 2002–2025, China (mainland) × 25 partners), with date, category, direction, and source.
- `gdelt_scores.csv / icews_scores.csv / phoenix_scores.csv / tsinghua_scores.csv` — monthly political-relations indices for the four databases, fair-coverage window (ICEWS ≤ 2023-04, Phoenix ≤ 2019-03).
- `panel_clean.csv` — PPML estimation panel (25 partners × monthly, n = 6,685): trade, GDP, exchange rate, FTA dummy, and the four political scores.
- `polling_panel_pew17.csv` — Pew polling panel (17 countries × 13 wave years, N = 170 country-years) with annual means of the four political scores and event-year merges.

### `代码/` (reproduction code)
- `fig01_v3.R` … `fig06_v3.R`, `figS1_v3.R` … `figS3_v1.R`, `00_theme_v4.R` — all figure scripts (R/ggplot2; each contains a numeric QA gate against the shipped CSVs).
- `vif_reproduce.py` — VIF computation for the three-database same-equation check (GDELT 1.96 / ICEWS 1.89 / Phoenix 1.34).

## Reproduction notes
- R scripts require R ≥ 4.4 with ggplot2, patchwork, sf, rnaturalearth, data.table, ragg, svglite. Paths at the top of each script point to the package root.
- All reported statistics are reproducible from the shipped CSVs; the pipeline stages are: raw events → monthly scores (5 aggregation algorithms) → panels → PPML-HDFE (fixest::fepois) and event-window analyses → polling fixed-effects regressions.

## License
CC-BY 4.0 (datasets and code, to be confirmed at deposit).
