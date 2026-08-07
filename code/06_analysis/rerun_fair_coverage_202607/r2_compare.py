# -*- coding: utf-8 -*-
# r2_compare.py — R2: generic 3-way comparison (archive vs full-replicate vs fair).

import csv, io, os, math

BASE = r'C:\Users\胡克劳\Desktop\311工程\3 实证结果'
WS = os.path.join(BASE, '重跑_公平覆盖期_202607')
OUT = os.path.join(WS, '对比总账')
os.makedirs(OUT, exist_ok=True)

TOL = 1e-6

# (module, archive_rel, workspace_rel_under_{mode})
FILES = [
    # PPML suite
    ('PPML_01基准传导', r'3.3 政治经济组合分析PPMLHDFE\新PPMLHDFE\01_连续分数PPML\01_基准传导_季度冲击\检验结果CSV\GDELT\irf_all.csv', r'01_PPML套件\{m}\01_基准传导_季度冲击\检验结果CSV\GDELT\irf_all.csv'),
    ('PPML_01基准传导', r'3.3 政治经济组合分析PPMLHDFE\新PPMLHDFE\01_连续分数PPML\01_基准传导_季度冲击\检验结果CSV\ICEWS\irf_all.csv', r'01_PPML套件\{m}\01_基准传导_季度冲击\检验结果CSV\ICEWS\irf_all.csv'),
    ('PPML_01基准传导', r'3.3 政治经济组合分析PPMLHDFE\新PPMLHDFE\01_连续分数PPML\01_基准传导_季度冲击\检验结果CSV\Phoenix\irf_all.csv', r'01_PPML套件\{m}\01_基准传导_季度冲击\检验结果CSV\Phoenix\irf_all.csv'),
    ('PPML_01基准传导', r'3.3 政治经济组合分析PPMLHDFE\新PPMLHDFE\01_连续分数PPML\01_基准传导_季度冲击\检验结果CSV\Tsinghua\irf_all.csv', r'01_PPML套件\{m}\01_基准传导_季度冲击\检验结果CSV\Tsinghua\irf_all.csv'),
    ('PPML_03干净面板', r'3.3 政治经济组合分析PPMLHDFE\新PPMLHDFE\01_连续分数PPML\03_干净面板PPML\检验结果CSV\ppml_final.csv', r'01_PPML套件\{m}\03_干净面板PPML\检验结果CSV\ppml_final.csv'),
    ('PPML_04_AR1残差', r'3.3 政治经济组合分析PPMLHDFE\新PPMLHDFE\01_连续分数PPML\04_AR1残差回归\检验结果CSV\A_AR1.csv', r'01_PPML套件\{m}\04_AR1残差回归\检验结果CSV\A_AR1.csv'),
    ('PPML_05频率扫描', r'3.3 政治经济组合分析PPMLHDFE\新PPMLHDFE\01_连续分数PPML\05_频率响应扫描\检验结果CSV\B_freqscan.csv', r'01_PPML套件\{m}\05_频率响应扫描\检验结果CSV\B_freqscan.csv'),
    ('PPML_06前向效应', r'3.3 政治经济组合分析PPMLHDFE\新PPMLHDFE\01_连续分数PPML\06_前向效应\检验结果CSV\D_forward.csv', r'01_PPML套件\{m}\06_前向效应\检验结果CSV\D_forward.csv'),
    ('PPML_02方向分解', r'3.3 政治经济组合分析PPMLHDFE\新PPMLHDFE\01_连续分数PPML\02_方向分解\检验结果CSV\directional_decomp.csv', r'01_PPML套件\{m}\02_方向分解\检验结果CSV\directional_decomp.csv'),
    # event-study suite
    ('ES_01单国多类型', r'3.2 双边关系分析基于月度政治分数\全新事件研究法\01_单个国家内不同类型事件的反映\code\results\event_study_metrics.csv', r'02_事件研究套件\{m}\01_单个国家内不同类型事件的反映\code\results\event_study_metrics.csv'),
    ('ES_03联盟M3', r'3.2 双边关系分析基于月度政治分数\全新事件研究法\03_联盟政治与美国盟友对华反应同质性\code\results\alliance_effects.csv', r'02_事件研究套件\{m}\03_联盟政治与美国盟友对华反应同质性\code\results\alliance_effects.csv'),
    ('ES_05会晤M5', r'3.2 双边关系分析基于月度政治分数\全新事件研究法\05_领导人会晤效应与双边关系\code\results\direction_summary.csv', r'02_事件研究套件\{m}\05_领导人会晤效应与双边关系\code\results\direction_summary.csv'),
    ('ES_05会晤M5_robust', r'3.2 双边关系分析基于月度政治分数\全新事件研究法\05_领导人会晤效应与双边关系\robustness\m5_robustness_category4.csv', r'02_事件研究套件\{m}\05_领导人会晤效应与双边关系\robustness\m5_robustness_category4.csv'),
    ('ES_07信任M7', r'3.2 双边关系分析基于月度政治分数\全新事件研究法\07_政治信任非对称性\code\results\asymmetry.csv', r'02_事件研究套件\{m}\07_政治信任非对称性\code\results\asymmetry.csv'),
    ('ES_02断点', r'3.2 双边关系分析基于月度政治分数\全新事件研究法\02_国家层面双边关系结构性断点分析\results\breakpoints.csv', r'02_事件研究套件\{m}\02_国家层面双边关系结构性断点分析\code\results\breakpoints.csv'),
    ('ES_04换届', r'3.2 双边关系分析基于月度政治分数\全新事件研究法\04_领导人换届效应与双边关系波动\results\turnover_vol_corr.csv', r'02_事件研究套件\{m}\04_领导人换届效应与双边关系波动\code\results\turnover_vol_corr.csv'),
    ('ES_06跨国同类', r'3.2 双边关系分析基于月度政治分数\全新事件研究法\06_相同类型的事件在不同国家的反应\code\results\m6_detailed.csv', r'02_事件研究套件\{m}\06_相同类型的事件在不同国家的反应\code\results\m6_detailed.csv'),
    ('ES_08第三方M8', r'3.2 双边关系分析基于月度政治分数\全新事件研究法\08_中美竞争第三方效应与体系结构变迁\results\third_party_effects.csv', r'02_事件研究套件\{m}\08_中美竞争第三方效应与体系结构变迁\code\results\third_party_effects.csv'),
    ('ES_09命中率', r'3.2 双边关系分析基于月度政治分数\全新事件研究法\09_四库事件命中率测试\code\results\hit_rate_main.csv', r'02_事件研究套件\{m}\09_四库事件命中率测试\code\results\hit_rate_main.csv'),
    # revision suite
    ('REV_01同方程', r'修订补充检验_202607\01_同方程四库交叉验证\results\cross_db_same_equation.csv', r'03_修订检验\{m}\01_同方程四库交叉验证\results\cross_db_same_equation.csv'),
    ('REV_11_M1显著性', r'修订补充检验_202607\11_M1事件研究显著性补算\results\m1_irf_significance.csv', r'03_修订检验\{m}\11_M1事件研究显著性补算\results\m1_irf_significance.csv'),
    ('REV_16_test1', r'修订补充检验_202607\16_新增小节正式检验\test1_alliance\results\test1_lp_interaction.csv', r'03_修订检验\{m}\16_新增小节正式检验\test1_alliance\results\test1_lp_interaction.csv'),
    ('REV_16_test1perm', r'修订补充检验_202607\16_新增小节正式检验\test1_alliance\results\test1_permutation_summary.csv', r'03_修订检验\{m}\16_新增小节正式检验\test1_alliance\results\test1_permutation_summary.csv'),
    ('REV_16_test2A', r'修订补充检验_202607\16_新增小节正式检验\test2_spillover\results\test2_partA_nodelevel.csv', r'03_修订检验\{m}\16_新增小节正式检验\test2_spillover\results\test2_partA_nodelevel.csv'),
    ('REV_16_test2B', r'修订补充检验_202607\16_新增小节正式检验\test2_spillover\results\test2_partB_panel_lp.csv', r'03_修订检验\{m}\16_新增小节正式检验\test2_spillover\results\test2_partB_panel_lp.csv'),
    ('REV_16_test2perm', r'修订补充检验_202607\16_新增小节正式检验\test2_spillover\results\test2_permutation_summary.csv', r'03_修订检验\{m}\16_新增小节正式检验\test2_spillover\results\test2_permutation_summary.csv'),
    ('REV_16_test3wald', r'修订补充检验_202607\16_新增小节正式检验\test3_wald\results\test3_wald_symmetry.csv', r'03_修订检验\{m}\16_新增小节正式检验\test3_wald\results\test3_wald_symmetry.csv'),
    ('REV_03换届重估', r'修订补充检验_202607\03_换届与波动率重估\results\correlation_summary.csv', r'03_修订检验\{m}\03_换届波动率重估\results\correlation_summary.csv'),
    ('REV_04合作冲突', r'修订补充检验_202607\04_合作冲突分类命中率全表\results\hitrate_cooperation_vs_conflict.csv', r'03_修订检验\{m}\04_合作冲突分类命中率全表\results\hitrate_cooperation_vs_conflict.csv'),
]

def load(path):
    with io.open(path, encoding='utf-8-sig') as f:
        r = csv.DictReader(f)
        return r.fieldnames, list(r)

def is_num(x):
    try:
        float(x); return True
    except (ValueError, TypeError):
        return False

report, summary = [], []
for module, arc_rel, ws_rel in FILES:
    arc_p = os.path.join(BASE, arc_rel)
    full_p = os.path.join(WS, ws_rel.format(m='full'))
    fair_p = os.path.join(WS, ws_rel.format(m='fair'))
    name = f"{module}:{os.path.basename(arc_rel)}"
    if not (os.path.exists(arc_p) and os.path.exists(full_p)):
        report.append(f"[SKIP] {name} (missing archive or full)")
        continue
    af, ar = load(arc_p); ff, fr = load(full_p)
    g1 = 'PASS' if ar == fr else f'DIFF'
    if g1 == 'DIFF':  # dump cell-level archive-vs-full detail for drift attribution
        det = []
        keys0 = [c for c in ff if not all(is_num(r.get(c, '')) for r in fr if r.get(c, '') != '')]
        def kset(rows): return {tuple(r.get(c, '') for c in keys0): r for r in rows}
        ka, kf = kset(ar), kset(fr)
        num0 = [c for c in ff if c not in keys0]
        for k, ra in ka.items():
            rf = kf.get(k)
            if rf is None:
                det.append(list(k) + ['<ROW_MISSING_IN_FULL>', '', '']); continue
            for c in num0:
                va, vf = ra.get(c, ''), rf.get(c, '')
                if is_num(va) and is_num(vf):
                    if abs(float(va) - float(vf)) > TOL:
                        det.append(list(k) + [c, va, vf])
                elif va != vf:
                    det.append(list(k) + [c, va, vf])
        for k in kf:
            if k not in ka: det.append(list(k) + ['<ROW_MISSING_IN_ARCHIVE>', '', ''])
        dp = os.path.join(OUT, f'G1DIFF_{module}_{os.path.basename(arc_rel)}')
        with io.open(dp, 'w', encoding='utf-8-sig', newline='') as f:
            w = csv.writer(f); w.writerow(keys0 + ['col', 'archive', 'full_repl']); w.writerows(det)
        report.append(f'  -> G1 detail: {len(det)} diff cells -> {os.path.basename(dp)}')
    # numeric diff fair vs full
    n_diff = '-'
    if os.path.exists(fair_p):
        _, tr = load(fair_p)
        keys = [c for c in ff if not all(is_num(r.get(c, '')) for r in fr if r.get(c, '') != '')]
        def keyset(rows): return {tuple(r.get(c, '') for c in keys): r for r in rows}
        ks_f, ks_t = keyset(fr), keyset(tr)
        diff_cells = 0; tot_cells = 0
        num_cols = [c for c in ff if c not in keys]
        for k, rf in ks_f.items():
            rt = ks_t.get(k)
            if rt is None:
                diff_cells += len(num_cols); tot_cells += len(num_cols); continue
            for c in num_cols:
                vf, vt = rf.get(c, ''), rt.get(c, '')
                tot_cells += 1
                if is_num(vf) and is_num(vt):
                    if abs(float(vf) - float(vt)) > TOL: diff_cells += 1
                elif vf != vt:
                    diff_cells += 1
        n_diff = f'{diff_cells}/{tot_cells}'
    summary.append([module, os.path.basename(arc_rel), len(ar), len(fr), g1, n_diff])
    report.append(f"{name}: rows arc={len(ar)} full={len(fr)} G1={g1} fair_diff_cells={n_diff}")

with io.open(os.path.join(OUT, 'compare_summary.csv'), 'w', encoding='utf-8-sig', newline='') as f:
    w = csv.writer(f)
    w.writerow(['module', 'file', 'rows_archive', 'rows_full_repl', 'G1_full_eq_archive', 'fair_diff_cells'])
    w.writerows(summary)
print('\n'.join(report))
print('saved compare_summary.csv')
