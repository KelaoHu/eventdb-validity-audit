# -*- coding: utf-8 -*-
# hitrate_fair_era.py — Option A: fair-era hit-rate tables (09-module definition, from hit_data_full.csv)

import csv, io, math, os

BASE = r'C:\Users\胡克劳\Desktop\311工程\3 实证结果'
SRC = BASE + r'\3.2 双边关系分析基于月度政治分数\全新事件研究法\09_四库事件命中率测试\code\results\hit_data_full.csv'
EVT = BASE + r'\3.2 双边关系分析基于月度政治分数\全新事件研究法\data\events_712.csv'
OUTDIR = BASE + r'\修订补充检验_202607\17_ICEWS覆盖期审计\results'

ev_date = {}
with io.open(EVT, encoding='utf-8-sig') as f:
    for row in csv.DictReader(f):
        ev_date[row['event_name']] = row['event_date']

CUTOFF = {'ICEWS': '2023-04', 'Phoenix': '2019-03'}
PUBLIC = '2019-03'

def wilson(h, n, z=1.959964):
    if n == 0: return (float('nan'), float('nan'))
    p = h / n; den = 1 + z*z/n
    c = (p + z*z/(2*n)) / den
    m = z*math.sqrt(p*(1-p)/n + z*z/(4*n*n)) / den
    return (c-m, c+m)

with io.open(SRC, encoding='utf-8-sig') as f:
    rows = list(csv.DictReader(f))

# row-level (09-module definition: hit_rate = mean(hit) over event-country rows; some events map to >1 country)
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

out_rows, lines = [], []
lines.append(f"{'regime':7s} {'db':9s} {'window':9s} {'n':>4s} {'hit':>4s} {'rate%':>7s}")
for regime in ['full', 'fair', 'public']:
    for db in DBS:
        for w in WINS:
            sel = [(e, h) for (d, ww, e, h) in recs if d == db and ww == w and in_regime(db, e, regime)]
            n, hit = len(sel), sum(h for _, h in sel)
            n_ev = len({e for e, _ in sel})
            lo, hi = wilson(hit, n)
            rate = hit / n if n else float('nan')
            out_rows.append([regime, db, w, n_ev, n, hit, f'{rate:.4f}', f'{lo:.4f}', f'{hi:.4f}'])
            lines.append(f"{regime:7s} {db:9s} {w:9s} {n:4d} {hit:4d} {100*rate:7.1f}")

with io.open(os.path.join(OUTDIR, 'hitrate_fair_era.csv'), 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f); w.writerow(['regime', 'db', 'window', 'n_distinct_events', 'n_rows', 'n_hit', 'hit_rate', 'ci_lo', 'ci_hi']); w.writerows(out_rows)

# coop/conflict version
cc_rows = []
for regime in ['full', 'fair', 'public']:
    for db in DBS:
        for w in WINS:
            for sign, lab in [(1, 'Cooperation'), (-1, 'Conflict')]:
                sel = [(e, h) for (d, ww, e, h) in recs
                       if d == db and ww == w and ev_sign.get(e) == sign and in_regime(db, e, regime)]
                n, hit = len(sel), sum(h for _, h in sel)
                lo, hi = wilson(hit, n)
                n_ev = len({e for e, _ in sel})
                cc_rows.append([regime, db, w, lab, n_ev, n, hit, f'{hit/n:.4f}' if n else '', f'{lo:.4f}', f'{hi:.4f}'])

with io.open(os.path.join(OUTDIR, 'hitrate_coop_conflict_fair_era.csv'), 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f); w.writerow(['regime', 'db', 'window', 'group', 'n_distinct_events', 'n_rows', 'n_hit', 'hit_rate', 'ci_lo', 'ci_hi']); w.writerows(cc_rows)

print('\n'.join(lines))
print('saved hitrate_fair_era.csv + hitrate_coop_conflict_fair_era.csv')
