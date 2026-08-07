# -*- coding: utf-8 -*-
# 07_方向一致率口径统一

import pandas as pd, numpy as np
from pathlib import Path

B = Path(r'C:\Users\胡克劳\Desktop\311工程\3 实证结果')
DATA = B / r'3.4 多个开源数据库的内容评估\新数据库异质性分析\00_数据与配置'
OUT = B / r'修订补充检验_202607\07_方向一致率口径统一\results'
OUT.mkdir(parents=True, exist_ok=True)

DBS3 = ['GDELT', 'ICEWS', 'Phoenix']
DBS4 = DBS3 + ['Tsinghua']

def add_direction(panel, lag=1, thr=1e-6):
    panel = panel.sort_values(['Country', 'YearMonth']).copy()
    for d in DBS4:
        col = f'Pol_Agg_{d}'
        diff = panel.groupby('Country')[col].diff(lag)
        panel[f'dir_{d}'] = np.where(diff > thr, 1, np.where(diff < -thr, -1, 0))
        panel.loc[diff.isna(), f'dir_{d}'] = np.nan
    return panel

def stats(df, dbs, exclude_zero):
    """返回 pooled 完全一致率/多数一致率/N 与逐国表"""
    cols = [f'dir_{d}' for d in dbs]
    sub = df.dropna(subset=cols)
    if exclude_zero:                      # 新口径：剔除任一库零变化月
        mask = sub[cols].ne(0).all(axis=1)
    else:                                 # 无条件：零变化月也计入（全零=一致）
        mask = pd.Series(True, index=sub.index)
    s = sub.loc[mask, cols]
    if len(s) == 0:
        return None
    full = (s.nunique(axis=1) == 1)
    maj = s.apply(lambda x: x.value_counts().iloc[0] / len(x) >= 0.5, axis=1)
    pooled = dict(Full_Agreement=full.mean(), Majority_Agreement=maj.mean(), N_Obs=len(s))
    # 逐国
    rows = []
    tmp = s.copy(); tmp['Country'] = sub.loc[mask, 'Country']
    for c, g in tmp.groupby('Country'):
        f = (g[cols].nunique(axis=1) == 1)
        m = g[cols].apply(lambda x: x.value_counts().iloc[0] / len(x) >= 0.5, axis=1)
        rows.append(dict(Country=c, Full_Agreement=f.mean(), Majority_Agreement=m.mean(), N_Obs=len(g)))
    by_c = pd.DataFrame(rows)
    return pooled, by_c

records = []
def emit(caliber, window, dbset, sample, scope, country, full, maj, n, source):
    records.append(dict(Caliber=caliber, Window=window, DB_Set=dbset, Sample=sample,
                        Scope=scope, Country=country,
                        Full_Agreement=round(full, 4) if pd.notna(full) else np.nan,
                        Majority_Agreement=round(maj, 4) if pd.notna(maj) else np.nan,
                        N_Obs=int(n) if pd.notna(n) else '', Source=source))

SRC05 = '新05模块重算(scripts/python/05_direction_consistency.py同算法)'

# ============ A. 11国面板（panel_2002_201903，复现05模块并补无条件对照） ============
p11 = pd.read_csv(DATA / 'panel_four_databases_2002_201903.csv', low_memory=False)
p11['YearMonth'] = pd.to_datetime(p11['YearMonth'])
for lag, wl in [(1, '1M'), (2, '2M')]:
    d = add_direction(p11, lag=lag)
    for dbs, dbset, sample in [(DBS3, '3DB', '11国(清华覆盖国)'), (DBS4, '4DB', '11国(清华覆盖国)')]:
        for ez, cal in [(True, '新口径(剔除零变化月)'), (False, '无条件(含零变化月)')]:
            pooled, by_c = stats(d, dbs, ez)
            emit(cal, wl, dbset, sample, 'pooled', 'ALL', pooled['Full_Agreement'], pooled['Majority_Agreement'], pooled['N_Obs'], SRC05)
            emit(cal, wl, dbset, sample, '逐国中位数', 'MEDIAN', by_c['Full_Agreement'].median(), by_c['Majority_Agreement'].median(), by_c['N_Obs'].sum(), SRC05)
            if wl == '1M':
                for _, r in by_c.iterrows():
                    emit(cal, wl, dbset, sample, '国别值', r['Country'], r['Full_Agreement'], r['Majority_Agreement'], r['N_Obs'], SRC05)

# ============ B. 25国面板（panel_2002_2025 截2002-01~2019-03，三库） ============
p25 = pd.read_csv(DATA / 'panel_four_databases_2002_2025.csv', low_memory=False)
p25['YearMonth'] = pd.to_datetime(p25['YearMonth'])
p25 = p25[p25['YearMonth'] <= '2019-03-01']
for lag, wl in [(1, '1M'), (2, '2M')]:
    d = add_direction(p25, lag=lag)
    for ez, cal in [(True, '新口径(剔除零变化月)'), (False, '无条件(含零变化月)')]:
        pooled, by_c = stats(d, DBS3, ez)
        emit(cal, wl, '3DB', '25国', 'pooled', 'ALL', pooled['Full_Agreement'], pooled['Majority_Agreement'], pooled['N_Obs'], SRC05)
        emit(cal, wl, '3DB', '25国', '逐国中位数', 'MEDIAN', by_c['Full_Agreement'].median(), by_c['Majority_Agreement'].median(), by_c['N_Obs'].sum(), SRC05)
        if wl == '1M':
            for _, r in by_c.iterrows():
                emit(cal, wl, '3DB', '25国', '国别值', r['Country'], r['Full_Agreement'], r['Majority_Agreement'], r['N_Obs'], SRC05)

# ============ C. 旧08模块口径（引用值，不重算） ============
SRC08 = '旧08模块 overall_consistency_report.csv(引用)'
emit('旧口径(08模块)', '1M', '3DB', '25国', 'pooled', 'ALL', 0.293078871210199, 0.9719477569887454, 5355, SRC08)
emit('旧口径(08模块)', '1M', '4DB', '11国(清华覆盖国)', 'pooled', 'ALL', 0.0724282143916917, 0.42724421437143084, np.nan, SRC08)
old25 = pd.read_csv(B / r'3.4 多个开源数据库的内容评估\旧数据库异质性分析\08_方向性检查\01_国家层面方向一致性统计\simultaneous_consistency_25.csv')
old25 = old25[old25['Partner'] != 'OVERALL']
emit('旧口径(08模块)', '1M', '3DB', '25国', '逐国中位数', 'MEDIAN', old25['all_same_rate'].median(), old25['majority_same_rate'].median(), int(old25['n_valid_months'].sum()), SRC08)
for _, r in old25.iterrows():
    emit('旧口径(08模块)', '1M', '3DB', '25国', '国别值', r['Partner'], r['all_same_rate'], r['majority_same_rate'], int(r['n_valid_months']), SRC08)

out = pd.DataFrame(records)
out.to_csv(OUT / 'direction_consistency_unified.csv', index=False, encoding='utf-8-sig')

# 打印关键数字供README使用
key = out[((out['Scope'].isin(['pooled', '逐国中位数'])) | (out['Country'].isin(['Japan', 'Brazil', 'Indonesia', 'United States'])))]
print(key.to_string(index=False))
print('\nrows:', len(out))
