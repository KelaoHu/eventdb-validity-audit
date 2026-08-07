# -*- coding: utf-8 -*-
"""r2_key_numbers.py — extract text-cited key numbers as archive/full/fair 3-col table."""
import csv, io, os

BASE = r'C:\Users\胡克劳\Desktop\311工程\3 实证结果'
WS = os.path.join(BASE, '重跑_公平覆盖期_202607')
OUT = os.path.join(WS, '对比总账')

def load(p):
    if not os.path.exists(p): return None
    with io.open(p, encoding='utf-8-sig') as f:
        return list(csv.DictReader(f))

ARC_ES = os.path.join(BASE, r'3.2 双边关系分析基于月度政治分数\全新事件研究法')
ARC_REV = os.path.join(BASE, '修订补充检验_202607')
ARC_PPML = os.path.join(BASE, r'3.3 政治经济组合分析PPMLHDFE\新PPMLHDFE\01_连续分数PPML')

def paths(arc, ws):
    return (arc,
            os.path.join(WS, ws.replace('{m}', 'full')),
            os.path.join(WS, ws.replace('{m}', 'fair')))

def show(title, arc_p, full_p, fair_p, rowfn, cols, keydesc):
    """rowfn(rows) -> list of (keylabel, rowdict) selected rows"""
    lines = [f'### {title}']
    A, F, T = load(arc_p), load(full_p), load(fair_p)
    lines.append(f'file: {os.path.basename(arc_p)}  rows arc/full/fair = '
                 f'{len(A) if A else "?"}/{len(F) if F else "?"}/{len(T) if T else "?"}')
    selA = {k: r for k, r in rowfn(A)} if A else {}
    selF = {k: r for k, r in rowfn(F)} if F else {}
    selT = {k: r for k, r in rowfn(T)} if T else {}
    hdr = ['item'] + [f'{c}_arc' for c in cols] + [f'{c}_full' for c in cols] + [f'{c}_fair' for c in cols]
    lines.append('\t'.join(hdr))
    for k, kd in keydesc:
        ra, rf, rt = selA.get(k, {}), selF.get(k, {}), selT.get(k, {})
        row = [kd]
        for src in (ra, rf, rt):
            for c in cols:
                v = src.get(c, '-')
                try: v = f'{float(v):.4g}'
                except (ValueError, TypeError): pass
                row.append(v)
        lines.append('\t'.join(row))
    return lines

out = []

# 1) hit rate main (W_strict rows)
p = paths(os.path.join(ARC_ES, r'09_四库事件命中率测试\code\results\hit_rate_main.csv'),
          r'02_事件研究套件\{m}\09_四库事件命中率测试\code\results\hit_rate_main.csv')
def hit_sel(rows):
    return [(r['db'], r) for r in rows if r.get('window') == 'W_strict' or r.get('variant') == 'W_strict']
cols_hit = [c for c in (load(p[0])[0].keys() if load(p[0]) else []) ]
out += show('1 hit_rate W_strict (4db)', *p, hit_sel,
            ['n_events', 'n_hit', 'hit_rate'],
            [(d, d) for d in ['GDELT', 'ICEWS', 'Phoenix', 'Tsinghua']])

# 2) PPML irf_all ICEWS & Phoenix h=0..4 (shock rows)
for db in ['ICEWS', 'Phoenix', 'GDELT']:
    p = paths(os.path.join(ARC_PPML, rf'01_基准传导_季度冲击\检验结果CSV\{db}\irf_all.csv'),
              rf'01_PPML套件\{{m}}\01_基准传导_季度冲击\检验结果CSV\{db}\irf_all.csv')
    rows0 = load(p[0])
    if not rows0: continue
    keycol = [c for c in rows0[0].keys() if c.lower() in ('h', 'horizon', 'lag')]
    numcols = [c for c in rows0[0].keys() if c.lower() in ('beta', 'coef', 'estimate', 'irf', 'p', 'p_value', 'pval', 'n', 'n_obs', 'se')]
    kc = keycol[0] if keycol else None
    def irf_sel(rows, kc=kc):
        return [(r[kc], r) for r in rows] if kc else []
    ks = [(str(h), f'h={h}') for h in ['0', '1', '2', '3', '4']]
    out += show(f'2 PPML irf_all {db}', *p, irf_sel, numcols[:6], ks)

# 3) asymmetry.csv means (h=0 and h=6)
p = paths(os.path.join(ARC_ES, r'07_政治信任非对称性\code\results\asymmetry.csv'),
          r'02_事件研究套件\{m}\07_政治信任非对称性\code\results\asymmetry.csv')
def asy_sel(rows):
    return [(f"{r['db']}|{r['valence']}|h{r['h'] if 'h' in r else r.get('horizon','')}", r) for r in rows]
keys_asy = []
A = load(p[0])
if A:
    hcol = 'h' if 'h' in A[0] else 'horizon'
    for db in ['GDELT', 'ICEWS']:
        for v in ['negative', 'positive']:
            for h in ['0', '6']:
                keys_asy.append((f'{db}|{v}|h{h}', f'{db} {v} h={h}'))
    out += show('3 M7 asymmetry mean_shock', *p, asy_sel, ['mean_shock', 'n'], keys_asy)

# 4) test2 partA + permutation
p = paths(os.path.join(ARC_REV, r'16_新增小节正式检验\test2_spillover\results\test2_partA_nodelevel.csv'),
          r'03_修订检验\{m}\16_新增小节正式检验\test2_spillover\results\test2_partA_nodelevel.csv')
A = load(p[0])
if A:
    k0 = list(A[0].keys())
    def t2_sel(rows): return [(r[k0[0]], r) for r in rows]
    out += show('4 test2 partA nodelevel', *p, t2_sel, k0[1:], [(r[k0[0]], r[k0[0]]) for r in A])

# 5) M5 direction_summary all 8 rows
p = paths(os.path.join(ARC_ES, r'05_领导人会晤效应与双边关系\code\results\direction_summary.csv'),
          r'02_事件研究套件\{m}\05_领导人会晤效应与双边关系\code\results\direction_summary.csv')
A = load(p[0])
if A:
    def m5_sel(rows): return [(f"{r['db']}|{r['category_4']}", r) for r in rows]
    out += show('5 M5 direction_summary', *p, m5_sel, ['mean', 'n', 'ci_lower', 'ci_upper'],
                [(f"{r['db']}|{r['category_4']}", f"{r['db']}|{r['category_4']}") for r in A])

# 6) M1 Phoenix neg rows
p = paths(os.path.join(ARC_REV, r'11_M1事件研究显著性补算\results\m1_irf_significance.csv'),
          r'03_修订检验\{m}\11_M1事件研究显著性补算\results\m1_irf_significance.csv')
A = load(p[0])
if A:
    k0 = list(A[0].keys())
    def m1_sel(rows):
        return [(f"{r.get('db','')}|{r.get('valence','')}|h{r.get('h', r.get('horizon',''))}", r)
                for r in rows if r.get('db') == 'Phoenix']
    numc = [c for c in k0 if c.lower() in ('mean', 'shock', 'p', 'p_value', 'pval', 'n', 't', 'ci_lower', 'ci_upper', 'beta')]
    sel = m1_sel(A)
    out += show('6 M1 Phoenix', *p, m1_sel, numc[:6], [(k, k) for k, _ in sel])

# 7) cross-db same equation: GDELT import rows + Phoenix export rows
p = paths(os.path.join(ARC_REV, r'01_同方程四库交叉验证\results\cross_db_same_equation.csv'),
          r'03_修订检验\{m}\01_同方程四库交叉验证\results\cross_db_same_equation.csv')
A = load(p[0])
if A:
    k0 = list(A[0].keys())
    def cd_sel(rows):
        outr = []
        for i, r in enumerate(rows):
            lbl = '|'.join(r.get(c, '') for c in k0[:4])
            outr.append((f'row{i:02d}|{lbl}', r))
        return outr
    numc = [c for c in k0 if c.lower() in ('beta', 'coef', 'estimate', 'se', 'p', 'p_value', 'n', 'n_country')]
    sel = cd_sel(A)
    out += show('7 cross_db_same_equation (all rows)', *p, cd_sel, numc[:6], [(k, k) for k, _ in sel])

# 8) turnover corr (REV_03)
p = paths(os.path.join(ARC_REV, r'03_换届与波动率重估\results\correlation_summary.csv'),
          r'03_修订检验\{m}\03_换届波动率重估\results\correlation_summary.csv')
A = load(p[0])
if A:
    def tv_sel(rows): return [(f"{r['db']}|{r['vol_measure']}", r) for r in rows]
    out += show('8 turnover-vol corr', *p, tv_sel, ['pearson_r', 'pearson_p'],
                [(f"{r['db']}|{r['vol_measure']}", f"{r['db']}|{r['vol_measure']}") for r in A])

# 9) test3 joint pos h3:6 (the Wald p=0.025 cited in v8?)
for fn in ['test3_joint_pos_h3_6.csv', 'test3_wald_symmetry.csv']:
    p = paths(os.path.join(ARC_REV, rf'16_新增小节正式检验\test3_wald\results\{fn}'),
              rf'03_修订检验\{{m}}\16_新增小节正式检验\test3_wald\results\{fn}')
    A = load(p[0])
    if A:
        k0 = list(A[0].keys())
        def t3_sel(rows, k0=k0):
            return [(f'row{i:02d}|' + '|'.join(r.get(c, '') for c in k0[:3]), r) for i, r in enumerate(rows)]
        numc = [c for c in k0 if c.lower() in ('wald', 'stat', 'p', 'p_value', 'chi2', 'beta', 'joint', 'n')]
        sel = t3_sel(A)
        out += show(f'9 {fn}', *p, t3_sel, numc[:6] if numc else k0[3:9], [(k, k) for k, _ in sel])

rep = '\n'.join(out)
with io.open(os.path.join(OUT, 'key_numbers_3way.txt'), 'w', encoding='utf-8') as f:
    f.write(rep)
print(rep[:6000])
print('...\nsaved key_numbers_3way.txt')
