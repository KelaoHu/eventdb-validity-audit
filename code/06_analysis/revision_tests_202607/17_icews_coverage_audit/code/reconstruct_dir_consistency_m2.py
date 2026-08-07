# -*- coding: utf-8 -*-
# reconstruct_dir_consistency_m2.py — B4 round 2: monthly-pooled definitions.

import csv, io

BASE = r'C:\Users\胡克劳\Desktop\311工程\3 实证结果\3.2 双边关系分析基于月度政治分数\全新事件研究法\data'

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
S.update(load(BASE + r'\tsinghua_scores.csv', 'Tsinghua', long=False))

evs = []
with io.open(BASE + r'\events_712.csv', encoding='utf-8-sig') as f:
    for r in csv.DictReader(f):
        if r['impact'] in ('positive', 'negative'):
            evs.append(dict(country=r['country_en'], ym=r['event_date'][:7],
                            sign=1 if r['impact'] == 'positive' else -1,
                            visit=(r['event_type_original'] == 'leader_visit')))

def shift(ym, k):
    y, m = int(ym[:4]), int(ym[5:7]) + k
    y += (m - 1) // 12; m = (m - 1) % 12 + 1
    return f'{y:04d}-{m:02d}'

def get(db, c, ym): return S.get((db, c, ym))

def baseline(db, c, ym):
    xs = [get(db, c, shift(ym, -k)) for k in range(7, 13)]
    xs = [x for x in xs if x is not None]
    return None if len(xs) < 4 else sum(xs)/len(xs)

def sgn(x):
    if x is None: return None
    if abs(x) < 1e-12: return 0
    return 1 if x > 0 else -1

DBSETS = {'3DB': ['GDELT', 'ICEWS', 'Phoenix'], '4DB': ['GDELT', 'ICEWS', 'Phoenix', 'Tsinghua']}
print(f"{'rule':16s}{'dbset':6s}{'events':10s}{'neg%':>8s}{'pos%':>8s}{'nneg':>6s}{'npos':>6s}")
matches = []
for rule in ('match_event', 'unanimous'):
    for ds, dbs in DBSETS.items():
        for evname, ef in (('nonvisit', lambda e: not e['visit']), ('all', lambda e: True)):
            cells = {-1: [], 1: []}
            for e in evs:
                if not ef(e): continue
                bl = {db: baseline(db, e['country'], e['ym']) for db in dbs}
                for k in range(-2, 3):
                    signs = []
                    ok = True
                    for db in dbs:
                        if bl[db] is None: ok = False; break
                        v = get(db, e['country'], shift(e['ym'], k))
                        if v is None: ok = False; break
                        signs.append(sgn(v - bl[db]))
                    if not ok or any(s is None for s in signs): continue
                    nz = [s for s in signs if s != 0]
                    if rule == 'match_event':
                        c = all(s == e['sign'] for s in signs)
                    else:
                        c = len(set(nz)) == 1 and len(nz) == len(signs)
                    cells[e['sign']].append(1.0 if c else 0.0)
            if not cells[-1] or not cells[1]: continue
            neg = 100*sum(cells[-1])/len(cells[-1]); pos = 100*sum(cells[1])/len(cells[1])
            tag = '  <<< MATCH' if abs(neg-19.4) < 1.5 and abs(pos-33.5) < 1.5 else ''
            if tag: matches.append((rule, ds, evname, neg, pos))
            print(f"{rule:16s}{ds:6s}{evname:10s}{neg:8.1f}{pos:8.1f}{len(cells[-1]):6d}{len(cells[1]):6d}{tag}")
print('\nMATCHES:', matches if matches else 'NONE')
