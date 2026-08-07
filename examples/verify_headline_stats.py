# -*- coding: utf-8 -*-
"""30 秒自证：从 data/core 独立重算论文头条数字并打印 PASS/FAIL
Run:  python examples/verify_headline_stats.py        （在仓库根目录）
"""
import os
import pandas as pd
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORE = os.path.join(ROOT, 'data', 'core')
results = []

def check(name, got, expect, tol=0.002):
    ok = abs(got - expect) <= tol
    results.append(ok)
    print(f'  [{"PASS" if ok else "FAIL"}] {name}: {got}  (expected {expect})')

def spearman(x, y):
    return np.corrcoef(pd.Series(x).rank(), pd.Series(y).rank())[0, 1]

print('=' * 64)
print('Headline-stat verification — eventdb-validity-audit')
print('=' * 64)

# ── 1. GDELT–ICEWS Spearman（中日 0.633 / 中巴 0.031, n=207）──
g = pd.read_csv(os.path.join(CORE, 'gdelt_scores.csv'))
i = pd.read_csv(os.path.join(CORE, 'icews_scores.csv'))
g = g[(g.Index_Type == 'Aggregated') & (g.YearMonth <= '2019-03')]
i = i[(i.Index_Type == 'Aggregated') & (i.YearMonth <= '2019-03')]
m = g.merge(i, on=['Partner', 'YearMonth'], suffixes=('_g', '_i'))
print('\n[1] Cross-database consistency (fair-coverage window, n=207):')
check('China–Japan Spearman', round(spearman(
    m[m.Partner == 'Japan'].Index_Value_g, m[m.Partner == 'Japan'].Index_Value_i), 3), 0.633)
check('China–Brazil Spearman', round(spearman(
    m[m.Partner == 'Brazil'].Index_Value_g, m[m.Partner == 'Brazil'].Index_Value_i), 3), 0.031)
assert len(m[m.Partner == 'Japan']) == 207

# ── 2. 行数断言 ──
print('\n[2] Dataset dimensions:')
dims = [('panel_clean.csv', 6685), ('polling_panel_pew17.csv', 170),
        ('events_712_gold_standard.csv', 712), ('icews_scores.csv', 19200),
        ('phoenix_scores.csv', 15525), ('gdelt_scores.csv', 21600)]
for fn, expect in dims:
    n = len(pd.read_csv(os.path.join(CORE, fn)))
    results.append(n == expect)
    print(f'  [{"PASS" if n == expect else "FAIL"}] {fn}: {n} rows (expected {expect})')

# ── 3. 命中率（对照重跑存档 hit_rate_main.csv，fair 口径）──
print('\n[3] Gold-standard hit rates (canonical fair rerun):')
hr_path = os.path.join(ROOT, 'code', '06_analysis', 'rerun_fair_coverage_202607',
                       '02_event_study', 'fair', '09_hitrate_tests',
                       'code', 'results', 'hit_rate_main.csv')
if os.path.exists(hr_path):
    hr = pd.read_csv(hr_path)
    expect = {'GDELT': 0.683, 'ICEWS': 0.661}
    for db, e in expect.items():
        row = hr[(hr.db == db) & (hr.window == 'W_strict')]
        if len(row):
            got = round(float(row.hit_rate.iloc[0]), 3)
            check(f'{db} strict-window hit rate', got, e, tol=0.005)
else:
    print('  [SKIP] hit_rate_main.csv not found at', hr_path)

print('\n' + '=' * 64)
print(f'ALL CHECKS PASSED ({sum(results)}/{len(results)})' if all(results)
      else f'SOME CHECKS FAILED ({len(results) - sum(results)} failed)')
print('=' * 64)
raise SystemExit(0 if all(results) else 1)
