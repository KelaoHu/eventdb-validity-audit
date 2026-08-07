# -*- coding: utf-8 -*-
# Recompute 04-module coop/conflict hit rates full vs truncated, from hit_data_full.csv.

import csv, io, math
BASE = r'C:\Users\胡克劳\Desktop\311工程\3 实证结果'
SRC = BASE + r'\3.2 双边关系分析基于月度政治分数\全新事件研究法\09_四库事件命中率测试\code\results\hit_data_full.csv'
EVT = BASE + r'\3.2 双边关系分析基于月度政治分数\全新事件研究法\data\events_712.csv'
OUT = r'C:\Users\胡克劳\Desktop\Python代码存放\tmp\audit_coop_conflict_out.txt'

ev_date = {}
with io.open(EVT, encoding='utf-8-sig') as f:
    for row in csv.DictReader(f): ev_date[row['event_name']] = row['event_date']

cutoff = {'ICEWS': '2023-04', 'Phoenix': '2019-03'}  # fair era
def ym(d): return d[:7]

def wilson(h, n, z=1.96):
    if n == 0: return (0, 0)
    p = h / n; den = 1 + z*z/n
    c = (p + z*z/(2*n)) / den
    m = z*math.sqrt(p*(1-p)/n + z*z/(4*n*n)) / den
    return (c-m, c+m)

with io.open(SRC, encoding='utf-8-sig') as f:
    rows = list(csv.DictReader(f))

lines = []
hdr = f"{'db':10s}{'win':9s}{'sign':10s}{'n_full':>7s}{'hit_full':>8s}{'full%':>8s}{'n_tr':>6s}{'hit_tr':>7s}{'trunc%':>8s}"
lines.append(hdr)
for db in ['GDELT', 'ICEWS', 'Phoenix', 'Tsinghua']:
    co = cutoff.get(db)
    for win in ['W_strict', 'W_1m', 'W_2m']:
        for sign, lab in [(1, 'Coop'), (-1, 'Conflict')]:
            sel = [r for r in rows if r['db'] == db and r['window'] == win and r['event_sign'] == str(sign)]
            # dedupe by event
            seen = {}
            for r in sel: seen[r['event_name']] = 1 if r['hit'] in ('TRUE','1','True') else 0
            nf = len(seen); hf = sum(seen.values())
            tr = {e: h for e, h in seen.items() if co is None or ym(ev_date[e]) <= co}
            nt = len(tr); ht = sum(tr.values())
            lines.append(f"{db:10s}{win:9s}{lab:10s}{nf:7d}{hf:8d}{(100*hf/nf if nf else 0):8.1f}{nt:6d}{ht:7d}{(100*ht/nt if nt else 0):8.1f}")

with io.open(OUT, 'w', encoding='utf-8') as f:
    f.write('04-module coop/conflict hit rates: FULL vs TRUNCATED (fair era)\n')
    f.write('\n'.join(lines))
print('written', OUT)
