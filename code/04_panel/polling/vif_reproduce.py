# -*- coding: utf-8 -*-
# vif_reproduce.py — 同方程三库 VIF 可复现计算（附录 S8 引用）

import pandas as pd
import numpy as np
import os

HERE = os.path.dirname(os.path.abspath(__file__))
df = pd.read_csv(os.path.join(HERE, '02_分析结果', 'paired_panel_events.csv'))
sub = df[['gdelt_mean', 'icews_mean', 'phoenix_mean']].dropna()
assert len(sub) == 170, len(sub)

def vif(col):
    y = sub[col].values
    X = np.column_stack([np.ones(len(sub))] + [sub[c].values for c in sub.columns if c != col])
    _, res, *_ = np.linalg.lstsq(X, y, rcond=None)
    r2 = 1 - res[0] / np.sum((y - y.mean()) ** 2)
    return r2, 1 / (1 - r2)

for c in sub.columns:
    r2, v = vif(c)
    print(f'{c}: R2={r2:.3f}, VIF={v:.2f}')
