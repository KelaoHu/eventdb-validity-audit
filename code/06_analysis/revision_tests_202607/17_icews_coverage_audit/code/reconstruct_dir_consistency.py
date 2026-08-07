# -*- coding: utf-8 -*-
# reconstruct_dir_consistency.py — B4: try to reproduce 19.4% (neg) / 33.5% (pos) cross-DB

import csv, io, itertools
from collections import defaultdict

BASE = r'C:\Users\胡克劳\Desktop\311工程\3 实证结果\3.2 双边关系分析基于月度政治分数\全新事件研究法\data'

# ---- load scores (Aggregated) into {(db, country, ym): value}
def load(fn, dbname, long=True):
    out = {}
    with io.open(fn, encoding='utf-8-sig') as f:
        for r in csv.DictReader(f):
            if long:
                if r.get('Index_Type') != 'Aggregated':
                    continue
                c, ym, v = r['Partner'], r['YearMonth'], r['Index_Value']
            else:
                c, ym, v = r['Country'], r['YearMonth'], r['Score']
            if v in ('', 'NA', None):
                continue
            out[(dbname, c, ym)] = float(v)
    return out

S = {}
S.update(load(BASE + r'\gdelt_scores.csv', 'GDELT'))
S.update(load(BASE + r'\icews_scores.csv', 'ICEWS'))
S.update(load(BASE + r'\phoenix_scores.csv', 'Phoenix'))
S.update(load(BASE + r'\tsinghua_scores.csv', 'Tsinghua', long=False))

# ---- events
evs = []
with io.open(BASE + r'\events_712.csv', encoding='utf-8-sig') as f:
    for r in csv.DictReader(f):
        if r['impact'] not in ('positive', 'negative'):
            continue
        evs.append(dict(country=r['country_en'], ym=r['event_date'][:7],
                        sign=1 if r['impact'] == 'positive' else -1,
                        visit=(r['event_type_original'] == 'leader_visit')))

def shift(ym, k):
    y, m = int(ym[:4]), int(ym[5:7]) + k
    y += (m - 1) // 12; m = (m - 1) % 12 + 1
    return f'{y:04d}-{m:02d}'

def get(db, c, ym):
    return S.get((db, c, ym))

def delta(db, c, ym, kind):
    if kind == 'point':      # v(+2) - v(-2)
        a, b = get(db, c, shift(ym, -2)), get(db, c, shift(ym, 2))
        return None if a is None or b is None else b - a
    if kind == 'win_vs_pre': # mean[0..+2] - mean[-2..-1]
        post = [get(db, c, shift(ym, k)) for k in (0, 1, 2)]
        pre = [get(db, c, shift(ym, k)) for k in (-2, -1)]
        post = [x for x in post if x is not None]; pre = [x for x in pre if x is not None]
        if not post or not pre: return None
        return sum(post)/len(post) - sum(pre)/len(pre)
    if kind == 'win_vs_base':# mean[0..+2] - mean[-12..-7]
        post = [get(db, c, shift(ym, k)) for k in (0, 1, 2)]
        base = [get(db, c, shift(ym, -k)) for k in range(7, 13)]
        post = [x for x in post if x is not None]; base = [x for x in base if x is not None]
        if len(post) < 2 or len(base) < 4: return None
        return sum(post)/len(post) - sum(base)/len(base)

def sgn(x, zero_ok=False):
    if x is None: return None
    if abs(x) < 1e-12: return 0
    return 1 if x > 0 else -1

def agree(signs, ev_sign, rule):
    if any(s is None for s in signs): return None
    nz = [s for s in signs if s != 0]
    if rule == 'all_match_event':
        return all(s == ev_sign for s in signs)          # zeros count as disagreement
    if rule == 'unanimous':
        return len(set(nz)) == 1 and len(nz) == len(signs)
    if rule == 'unanimous_zero_ok':
        return len(set(nz)) <= 1
    if rule == 'pairwise':
        pairs = [(a, b) for a, b in itertools.combinations(signs, 2)]
        return sum(1 for a, b in pairs if a == b) / len(pairs)

DBSETS = {'3DB': ['GDELT', 'ICEWS', 'Phoenix'], '4DB': ['GDELT', 'ICEWS', 'Phoenix', 'Tsinghua']}
print(f"{'delta':12s}{'rule':20s}{'dbset':6s}{'events':10s}{'neg%':>8s}{'pos%':>8s}{'n_neg':>6s}{'n_pos':>6s}")
best = []
for kind in ('point', 'win_vs_pre', 'win_vs_base'):
    for rule in ('all_match_event', 'unanimous', 'unanimous_zero_ok', 'pairwise'):
        for ds_name, dbs in DBSETS.items():
            for evset_name, ev_filter in (('nonvisit', lambda e: not e['visit']), ('all', lambda e: True)):
                res = {-1: [], 1: []}
                for e in evs:
                    if not ev_filter(e): continue
                    signs = [sgn(delta(db, e['country'], e['ym'], kind)) for db in dbs]
                    a = agree(signs, e['sign'], rule)
                    if a is None: continue
                    res[e['sign']].append(1.0 if a is True else (a if rule == 'pairwise' else 0.0))
                if not res[-1] or not res[1]: continue
                neg = 100*sum(res[-1])/len(res[-1]); pos = 100*sum(res[1])/len(res[1])
                tag = ''
                if abs(neg-19.4) < 1.5 and abs(pos-33.5) < 1.5: tag = '  <<< MATCH'
                print(f"{kind:12s}{rule:20s}{ds_name:6s}{evset_name:10s}{neg:8.1f}{pos:8.1f}{len(res[-1]):6d}{len(res[1]):6d}{tag}")
                if tag: best.append((kind, rule, ds_name, evset_name, neg, pos, len(res[-1]), len(res[1])))
print('\nMATCHES:', best if best else 'NONE')
