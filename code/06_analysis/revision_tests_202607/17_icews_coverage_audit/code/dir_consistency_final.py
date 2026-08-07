# -*- coding: utf-8 -*-
# dir_consistency_final.py — v8 replacement number for para 95/96 fifth evidence.

import csv, io

BASE = r'C:\Users\胡克劳\Desktop\311工程\3 实证结果\3.2 双边关系分析基于月度政治分数\全新事件研究法\data'
OUT = r'C:\Users\胡克劳\Desktop\311工程\3 实证结果\修订补充检验_202607\17_ICEWS覆盖期审计\results\dir_consistency_final.csv'

def load(fn, dbname, long=True):
    out = {}
    with io.open(fn, encoding='utf-8-sig') as f:
        for r in csv.DictReader(f):
            if long:
                if r.get('Index_Type') != 'Aggregated': continue
                c, ym, v = r['Partner'], r['YearMonth'], r['Index_Value']
            else:
                c, ym, v = r['Country'], r['YearMonth'], r['Score']
            if v in ('', 'NA', None): continue
            out[(dbname, c, ym)] = float(v)
    return out

S = {}
S.update(load(BASE + r'\gdelt_scores.csv', 'GDELT'))
S.update(load(BASE + r'\icews_scores.csv', 'ICEWS'))
S.update(load(BASE + r'\phoenix_scores.csv', 'Phoenix'))

evs = []
with io.open(BASE + r'\events_712.csv', encoding='utf-8-sig') as f:
    for r in csv.DictReader(f):
        if r['impact'] in ('positive', 'negative') and r['event_type_original'] != 'leader_visit':
            evs.append(dict(country=r['country_en'], ym=r['event_date'][:7],
                            sign=1 if r['impact'] == 'positive' else -1))

def shift(ym, k):
    y, m = int(ym[:4]), int(ym[5:7]) + k
    y += (m - 1) // 12; m = (m - 1) % 12 + 1
    return f'{y:04d}-{m:02d}'

DBS = ['GDELT', 'ICEWS', 'Phoenix']
CUTOFF = {'ICEWS': '2023-04', 'Phoenix': '2019-03'}

def in_regime(ym, regime):
    if regime == 'full': return True
    if regime == 'public': return ym <= '2019-03'
    # fair: event must be within ALL three DBs' true coverage -> Phoenix binds
    return ym <= '2019-03'  # 3DB intersection requires Phoenix anyway

rows_out = []
for regime in ['full', 'public']:
    res = {-1: [], 1: []}
    for e in evs:
        if not in_regime(e['ym'], regime): continue
        signs = []
        ok = True
        for db in DBS:
            pre = [S.get((db, e['country'], shift(e['ym'], k))) for k in (-2, -1)]
            post = [S.get((db, e['country'], shift(e['ym'], k))) for k in (0, 1, 2)]
            pre = [x for x in pre if x is not None]; post = [x for x in post if x is not None]
            if not pre or not post: ok = False; break
            d = sum(post)/len(post) - sum(pre)/len(pre)
            signs.append(0 if abs(d) < 1e-12 else (1 if d > 0 else -1))
        if not ok: continue
        nz = [s for s in signs if s != 0]
        agree = len(nz) == 3 and len(set(nz)) == 1
        res[e['sign']].append(1.0 if agree else 0.0)
    for sgn, lab in [(-1, 'negative'), (1, 'positive')]:
        n = len(res[sgn]); pct = 100*sum(res[sgn])/n if n else float('nan')
        print(f"{regime:8s} {lab:9s} n={n:4d} unanimous={pct:.1f}%")
        rows_out.append([regime, lab, n, f'{pct:.1f}'])

with io.open(OUT, 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f); w.writerow(['regime', 'sign', 'n_events', 'unanimous_pct']); w.writerows(rows_out)
print('saved', OUT)
