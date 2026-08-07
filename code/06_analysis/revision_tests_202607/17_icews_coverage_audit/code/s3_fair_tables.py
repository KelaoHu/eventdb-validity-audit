# -*- coding: utf-8 -*-
# s3_fair_tables.py — Appendix S3-1 rebuilt: fair (main) + full/public (reference).

import csv, io, os, sys

BASE = r'C:\Users\胡克劳\Desktop\311工程\3 实证结果'
SRC = BASE + r'\3.2 双边关系分析基于月度政治分数\全新事件研究法\09_四库事件命中率测试\code\results\hit_data_full.csv'
EVT = BASE + r'\3.2 双边关系分析基于月度政治分数\全新事件研究法\data\events_712.csv'
OUTDIR = BASE + r'\修订补充检验_202607\17_ICEWS覆盖期审计\results'

ev_date = {}
with io.open(EVT, encoding='utf-8-sig') as f:
    for r in csv.DictReader(f):
        ev_date[r['event_name']] = r['event_date']

CUTOFF = {'ICEWS': '2023-04', 'Phoenix': '2019-03'}
PUBLIC = '2019-03'

with io.open(SRC, encoding='utf-8-sig') as f:
    rows = list(csv.DictReader(f))
ev_sign = {}
recs = []
for r in rows:
    ev_sign[r['event_name']] = int(r['event_sign'])
    h = 1 if r['hit'] in ('TRUE', '1', 'True') else 0
    recs.append((r['db'], r['window'], r['event_name'], h))

def in_regime(db, ev, regime):
    ym = ev_date[ev][:7]
    if regime == 'full': return True
    if regime == 'public': return ym <= PUBLIC
    co = CUTOFF.get(db)
    return True if co is None else ym <= co

DBS = ['GDELT', 'ICEWS', 'Phoenix', 'Tsinghua']
WINS = ['W_strict', 'W_1m', 'W_2m']
GROUPS = {'Cooperation': 1, 'Conflict': -1, 'Overall': 0}

def cell(db, win, grp, regime):
    sel = [(e, h) for (d, w, e, h) in recs
           if d == db and w == win and in_regime(db, e, regime)
           and (GROUPS[grp] == 0 or ev_sign[e] == GROUPS[grp])]
    n_hit = sum(h for _, h in sel)
    n_ev = len({e for e, _ in sel})
    return n_hit, n_ev

# ---- validation gate: full regime must reproduce appendix v3 S3-1 (24 cells) ----
EXPECTED = {
 ('Cooperation','GDELT'):(112,106,103), ('Cooperation','ICEWS'):(87,74,72),
 ('Cooperation','Phoenix'):(69,66,63), ('Cooperation','Tsinghua'):(39,40,41),
 ('Conflict','GDELT'):(78,78,71), ('Conflict','ICEWS'):(70,64,65),
 ('Conflict','Phoenix'):(40,34,34), ('Conflict','Tsinghua'):(50,52,52)}
fails = []
for (grp, db), hits in EXPECTED.items():
    for j, w in enumerate(WINS):
        h, n = cell(db, w, grp, 'full')
        if h != hits[j]:
            fails.append((grp, db, w, h, hits[j]))
if fails:
    print('VALIDATION FAILED:', fails); sys.exit(1)
print('[GATE OK] full regime reproduces appendix v3 S3-1: 24/24 cells')

# ---- build tables ----
def build(regime):
    out = []
    for grp in GROUPS:
        for db in DBS:
            row = [grp, db]
            for w in WINS:
                h, n = cell(db, w, grp, regime)
                row.append((h, n, 100*h/n if n else float('nan')))
            out.append(row)
    return out

def fmt(t): return f'{t[0]}/{t[1]}（{t[2]:.1f}%）'

lines = []
all_rows = {}
for regime in ['fair', 'full', 'public']:
    t = build(regime)
    all_rows[regime] = t
    lines.append(f'== {regime} ==')
    for r in t:
        lines.append(f"{r[0]:12s}{r[1]:9s} " + '  '.join(fmt(x) for x in r[2:]))

# CSV: main (fair) + reference (full/public), long format
with io.open(os.path.join(OUTDIR, 's3_1_fair_main.csv'), 'w', encoding='utf-8-sig', newline='') as f:
    w = csv.writer(f)
    w.writerow(['group', 'db', 'window', 'n_hit', 'n_events', 'pct'])
    for r in all_rows['fair']:
        for j, win in enumerate(WINS):
            h, n, p = r[2 + j]
            w.writerow([r[0], r[1], win, h, n, f'{p:.1f}'])
with io.open(os.path.join(OUTDIR, 's3_1_full_public_reference.csv'), 'w', encoding='utf-8-sig', newline='') as f:
    w = csv.writer(f)
    w.writerow(['regime', 'group', 'db', 'window', 'n_hit', 'n_events', 'pct'])
    for regime in ['full', 'public']:
        for r in all_rows[regime]:
            for j, win in enumerate(WINS):
                h, n, p = r[2 + j]
                w.writerow([regime, r[0], r[1], win, h, n, f'{p:.1f}'])

print('\n'.join(lines))
print('\nsaved s3_1_fair_main.csv + s3_1_full_public_reference.csv')
