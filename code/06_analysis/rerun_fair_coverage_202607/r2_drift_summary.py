# -*- coding: utf-8 -*-
# r2_drift_summary.py — quantify G1 drift (archive vs full-replicate) per module.

import csv, io, os, glob

OUT = r'C:\Users\胡克劳\Desktop\311工程\3 实证结果\重跑_公平覆盖期_202607\对比总账'

def fnum(x):
    try: return float(x)
    except (ValueError, TypeError): return None

def stars(p):
    return '*' if p < .05 else ('.' if p < .1 else '')

lines = []
for path in sorted(glob.glob(os.path.join(OUT, 'G1DIFF_*.csv'))):
    with io.open(path, encoding='utf-8-sig') as f:
        rows = list(csv.DictReader(f))
    diffs, signflips, pcross, missing = [], 0, 0, 0
    worst = []
    for r in rows:
        col = r.get('col', '')
        a, b = fnum(r.get('archive', '')), fnum(r.get('full_repl', ''))
        if a is None or b is None:
            missing += 1; continue
        d = abs(b - a)
        diffs.append(d)
        worst.append((d, col, a, b, r))
        if a * b < 0: signflips += 1
        if 'p' in col.lower() and stars(a) != stars(b):
            pcross += 1
            worst.append((9e9 + d, col, a, b, r))  # pin p-crossings to top
    diffs.sort()
    n = len(diffs)
    med = diffs[n // 2] if n else 0
    mx = diffs[-1] if diffs else 0
    lines.append(f"== {os.path.basename(path)}")
    lines.append(f"   diff_cells={n} row_missing={missing} signflips={signflips} p_star_crossings={pcross} median|d|={med:.4g} max|d|={mx:.4g}")
    worst.sort(key=lambda t: -t[0])
    for d, col, a, b, r in worst[:6]:
        keystr = '|'.join(list(r.values())[:3])
        lines.append(f"     {keystr} :: {col}: {a:.5g} -> {b:.5g}")
    lines.append('')

rep = '\n'.join(lines)
with io.open(os.path.join(OUT, 'drift_summary.txt'), 'w', encoding='utf-8') as f:
    f.write(rep)
print(rep)
