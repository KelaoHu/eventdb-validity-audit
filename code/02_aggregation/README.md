# 02_aggregation — Day-to-Month Aggregation Lab

The paper's monthly political-relations indices are built here: daily events → monthly scores, **two-stage** (within-day first, then across days within a month), **geometric mean in log space** (scores shifted +11 so logged inputs are positive, shifted back after exponentiation).

## Contents

| Script | Role |
|---|---|
| `geometric_mean_day_to_month_v5.23_GDELT.py` | ★ Main line: GDELT geometric-mean aggregation, 2002–2025 (paper §Methods) |
| `three_db_five_algorithms_v6.3_optimized.py` | ★ Three databases (GDELT/ICEWS/Phoenix) × five algorithms, fair-coverage window |
| `arithmetic_mean_day_to_month_v4.22.py` | Alternative algorithm 1: arithmetic mean (robustness, SI S6) |
| `median_day_to_month_v5.21.py` | Alternative algorithm 2: median (robustness, SI S6) |
| `quadratic_mean_day_to_month_v5.21.py` | Alternative algorithm 3: quadratic mean (robustness, SI S6) |
| `abs_value_weighted_day_to_month_v4.22.py` | Alternative algorithm 4: absolute-value weighting (robustness, SI S6) |

Every conclusion in the paper holds under all five algorithms (direction and sign unchanged); definitions and full robustness in **Supplementary Note S6**. Earlier experimental variants (Z-Score forms, severity weighting, rolling-window experiments, …) are archived in the Zenodo full package, not here.
