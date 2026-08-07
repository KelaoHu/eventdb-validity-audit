# -*- coding: utf-8 -*-
# r2_key2.py — precise 3-way extraction of text-cited numbers (fixed selectors).

import csv, io, os

BASE = r'C:\Users\胡克劳\Desktop\311工程\3 实证结果'
WS = os.path.join(BASE, '重跑_公平覆盖期_202607')
OUT = os.path.join(WS, '对比总账')
ARC_ES = os.path.join(BASE, r'3.2 双边关系分析基于月度政治分数\全新事件研究法')
ARC_REV = os.path.join(BASE, '修订补充检验_202607')
ARC_PPML = os.path.join(BASE, r'3.3 政治经济组合分析PPMLHDFE\新PPMLHDFE\01_连续分数PPML')

def load(p):
    if not os.path.exists(p): return []
    with io.open(p, encoding='utf-8-sig') as f:
        return list(csv.DictReader(f))

def fmt(v):
    try: return f'{float(v):.4g}'
    except (ValueError, TypeError): return str(v)

def tbl(title, rowsA, rowsF, rowsT, keyfn, cols):
    L = [f'### {title}']
    dA = {keyfn(r): r for r in rowsA}; dF = {keyfn(r): r for r in rowsF}; dT = {keyfn(r): r for r in rowsT}
    L.append('\t'.join(['item'] + [f'{c}|arc' for c in cols] + [f'{c}|full' for c in cols] + [f'{c}|fair' for c in cols]))
    for k in dF.keys() or dA.keys():
        ra, rf, rt = dA.get(k, {}), dF.get(k, {}), dT.get(k, {})
        L.append('\t'.join([k] + [fmt(src.get(c, '-')) for src in (ra, rf, rt) for c in cols]))
    return L

out = []

# 1) PPML irf_all ICEWS/Phoenix h=0 all specs
for db in ['ICEWS', 'Phoenix']:
    a = load(os.path.join(ARC_PPML, rf'01_基准传导_季度冲击\检验结果CSV\{db}\irf_all.csv'))
    f = load(os.path.join(WS, rf'01_PPML套件\full\01_基准传导_季度冲击\检验结果CSV\{db}\irf_all.csv'))
    t = load(os.path.join(WS, rf'01_PPML套件\fair\01_基准传导_季度冲击\检验结果CSV\{db}\irf_all.csv'))
    sel = lambda rows: [r for r in rows if r['h'] == '0']
    out += tbl(f'PPML irf_all {db} h=0', sel(a), sel(f), sel(t),
               lambda r: f"{r['spec']}|{r['trade']}", ['Est', 'pv', 'n'])

# 2) M1 all db x direction h=0 (focus Phoenix neg)
a = load(os.path.join(ARC_REV, r'11_M1事件研究显著性补算\results\m1_irf_significance.csv'))
f = load(os.path.join(WS, r'03_修订检验\full\11_M1事件研究显著性补算\results\m1_irf_significance.csv'))
t = load(os.path.join(WS, r'03_修订检验\fair\11_M1事件研究显著性补算\results\m1_irf_significance.csv'))
sel = lambda rows: [r for r in rows if r['h'] in ('0', '6')]
out += tbl('M1 significance h=0,6', sel(a), sel(f), sel(t),
           lambda r: f"{r['db']}|{r['direction']}|h{r['h']}", ['response', 'p_boot', 'p_ttest', 'n_events'])

# 3) M7 asymmetry
a = load(os.path.join(ARC_ES, r'07_政治信任非对称性\code\results\asymmetry.csv'))
f = load(os.path.join(WS, r'02_事件研究套件\full\07_政治信任非对称性\code\results\asymmetry.csv'))
t = load(os.path.join(WS, r'02_事件研究套件\fair\07_政治信任非对称性\code\results\asymmetry.csv'))
out += tbl('M7 asymmetry', a, f, t,
           lambda r: f"{r['db']}|{r['valence']}|m{r['post_month']}", ['mean_shock', 'n'])

# 4) cross_db all 21 rows
a = load(os.path.join(ARC_REV, r'01_同方程四库交叉验证\results\cross_db_same_equation.csv'))
f = load(os.path.join(WS, r'03_修订检验\full\01_同方程四库交叉验证\results\cross_db_same_equation.csv'))
t = load(os.path.join(WS, r'03_修订检验\fair\01_同方程四库交叉验证\results\cross_db_same_equation.csv'))
out += tbl('cross_db_same_equation', a, f, t,
           lambda r: f"{r['spec']}|{r['trade']}|{r['db']}", ['coef', 'p', 'sig', 'n', 'sample_end'])

# 5) test3 files all rows
for fn in ['test3_joint_pos_h3_6.csv', 'test3_wald_symmetry.csv']:
    a = load(os.path.join(ARC_REV, rf'16_新增小节正式检验\test3_wald\results\{fn}'))
    f = load(os.path.join(WS, rf'03_修订检验\full\16_新增小节正式检验\test3_wald\results\{fn}'))
    t = load(os.path.join(WS, rf'03_修订检验\fair\16_新增小节正式检验\test3_wald\results\{fn}'))
    if a:
        k0 = [c for c in a[0].keys()]
        numc = [c for c in k0 if c not in ('db', 'spec', 'trade', 'sig', 'sample_start', 'sample_end')]
        out += tbl(fn, a, f, t, lambda r: '|'.join(r.get(c, '') for c in ('db', 'spec', 'trade') if c in r),
                   numc[:7])

# 6) ES_06 significant rows (m6_detailed)
a = load(os.path.join(ARC_ES, r'06_相同类型的事件在不同国家的反应\code\results\m6_detailed.csv'))
f = load(os.path.join(WS, r'02_事件研究套件\full\06_相同类型的事件在不同国家的反应\code\results\m6_detailed.csv'))
t = load(os.path.join(WS, r'02_事件研究套件\fair\06_相同类型的事件在不同国家的反应\code\results\m6_detailed.csv'))
if f:
    sigcol = [c for c in f[0].keys() if 'sig' in c.lower()]
    def sig_rows(rows):
        return [r for r in rows if any(str(r.get(c, '')).strip().lower() in ('true', '1', 'yes', '*', '**', '***') or '*' in str(r.get(c, '')) for c in sigcol)]
    out.append(f'### ES_06 m6_detailed sig columns: {sigcol}')
    out.append(f'  arc sig rows={len(sig_rows(a))} / full={len(sig_rows(f))} / fair={len(sig_rows(t))}')
    for lbl, rows in (('full', sig_rows(f)), ('fair', sig_rows(t))):
        for r in rows[:10]:
            out.append(f'  [{lbl}] ' + '|'.join(f'{k}={fmt(v)}' for k, v in r.items() if k in ('db', 'version', 'country', 'event_type', 'shock', 'p_value', 'p', 'significant', 'sig')))

# 7) test1 lp interaction key rows (GDELT h=1 neg interaction cited p=0.028)
a = load(os.path.join(ARC_REV, r'16_新增小节正式检验\test1_alliance\results\test1_lp_interaction.csv'))
f = load(os.path.join(WS, r'03_修订检验\full\16_新增小节正式检验\test1_alliance\results\test1_lp_interaction.csv'))
t = load(os.path.join(WS, r'03_修订检验\fair\16_新增小节正式检验\test1_alliance\results\test1_lp_interaction.csv'))
if f:
    k0 = list(f[0].keys())
    keycols = [c for c in k0 if c in ('db', 'h', 'horizon', 'valence', 'direction', 'sign', 'group')]
    numc = [c for c in k0 if c not in keycols]
    out += tbl('test1_lp_interaction', a, f, t, lambda r: '|'.join(r.get(c, '') for c in keycols), numc[:7])

rep = '\n'.join(out)
with io.open(os.path.join(OUT, 'key_numbers_3way_v2.txt'), 'w', encoding='utf-8') as fp:
    fp.write(rep)
print(rep[:8000])
print('---saved key_numbers_3way_v2.txt')
