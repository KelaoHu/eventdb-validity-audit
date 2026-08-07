# 图件 QA Notes（v2 迭代，2026-08-01）

> 对应 qa-contract.md 统计/导出最低项。六图全部 R/ggplot2（backend 排他），脚本位于各 `fig0X_*/fig0X_v3.R`，每脚本内置 stopifnot QA 闸门（关键数值断言），重跑即复核。
> 本轮迭代：图文一致性（P0/P1 见 `图文对账表_20260801.md`）+ 结构可读性 + 精修导出。

## 尺寸/字号/导出
- 全部 180 mm 宽（双栏），300 dpi PNG（投稿用）、TIFF 600 lzw、SVG、PDF、preview 五格式由 `save_pub()` 同捆输出。
- 最小注释字号 1.9–2.2 mm ≈ 5.4–6.3 pt ≥ 5 pt 地板线；面板标签 a/b/c 粗体左上。
- 灰度与色盲（deutan/protan，Machado 2009 矩阵）模拟输出于 `_cvd_out/`，逐图目检通过；已知残余：GDELT 蓝与 Phoenix 紫在 deutan 下明度接近，由固定纵向偏移+直接数值标注+分面条带三重冗余兜底；红负/蓝正语义在 deutan 下为橄榄 vs 蓝，可区分。

## 逐图统计最低项
| 图 | n 定义 | 中心/离散 | 检验 | 数据源 |
|---|---|---|---|---|
| 1a | 25 国，公共窗口 2002-01–2019-03（n=207 月） | Spearman ρ | — | country_level_correlations.csv（Geometric Mean+Aggregated+GDELT_vs_ICEWS） |
| 1b | 712 条事件年度计数 | — | — | events_712.csv |
| 2a | 事件类型分组命中率（合作/冲突冲击） | 严格窗口命中率 % | 口径：GDELT/清华全样本、ICEWS/Phoenix fair | Table_S4_1R + hitrate_coop_conflict_fair_era.csv |
| 2b | 各分面 n 标注于图内（GDELT/ICEWS/清华 41 neg/58 pos；Phoenix 37/55） | 均值响应 + bootstrap CI | bootstrap 显著（p_boot<0.05，实心/空心编码） | data_fair 重算 + m1_irf_significance.csv（重算一致性断言） |
| 3a | PPML-HDFE LP，h=0–6 | 系数热图 | * = p<0.05 | irf_all.csv（fair） |
| 3b | 22 个制裁/管制事件 | 组内中位数（图内标注） | 方向二分类 | event_import_changes.csv（16/22 闸门） |
| 4a | 各类别 n 标注于轴标签（GDELT/ICEWS：121/100、159/129、134/108、18/10） | 均值 + 95% CI | CI 跨零标 n.s. | direction_summary.csv |
| 4b | GDELT/ICEWS 分数维度 | β_h + 95% CI | Wald 对称性检验（图内标注 p） | test3_wald_symmetry.csv |
| 4c | 美国盟友六国（日韩澳英加菲）vs 非盟友 | β_h + 95% CI | 交互项检验（图内标注 −0.45, p=0.005） | test1_lp_interaction.csv（M3_six） |
| 5a | 频率扫描 k=1–24 | 累计系数 | p<0.05 实心/空心（图例在图） | B_freqscan.csv |
| 5b | 前向效应 h=−3..+6 | 系数 + 95% CI | 空心点标 n.s. | D_forward.csv |
| 5c | AR(1) 残差回归 | 累计效应 + 95% CI | — | A_AR1.csv（清华仅总贸易，分流向未估计） |
| 6a | Pew 17 国 170 国家-年（清华 10 国标注探索性） | between ρ（95% CI）/ within FE β | 显著性星号 | Table_S8_7 |
| 6b | 左：GDELT 方向梯度（n 见图 4a）；右：Pew 访问级别 FE β | 点估计 | n.s. 标注（第三方会晤 p=0.120） | direction_summary.csv + Table_S8_8 |
| 6c | 3 个负面事件个案（20/25=80% 标注） | 民调 z 分前后对比 | — | Table_S8_5（端点=真实调查波次年） |

## 本轮修改清单（before → after）
- fig01：锚点虚线改 segment（不再穿字）；UAE 引线改道阿拉伯海。
- fig02：轴标签去代码风（W_strict 删除）；灰条语义注记；b 面板补 n。
- fig03：b 面板 x 轴截断 ±[−45%,+55%]+离群注记（India +76%、Canada +55%）；中位数数值标注（t=+1 −1.2% / t=+2 +5.8%，已核 CSV）。
- fig04：a 轴标签补 n；c 图例 "Allies (M3 six)"→"US allies (n=6)"；盟友配色红→墨色（消除与"负面=红"语义冲突）。
- fig05：a/b 色带可见化（#E3E3E3 α0.55，原 #F2F2F2 α0.35 不可见）；a 补显著性图例；b 空心点标 n.s.；c "AR1"→"AR(1)"、数值标签防碰。
- fig06：b 面板镜像轴→左右分面（Pew 第三方会晤 −0.21 n.s. 不再越界入左区）；左梯度注记单行下移防碰。

## 已知保留项（有意为之）
- 图 6b 左右构念不同（方向 vs 级别），并置为示意——caption 明示 "not a like-for-like test"。
- 图 4b/2b 红蓝在灰度下明度接近，但语义由零线上下方位冗余承载。
- 图 5b "No anticipation" 色带指 h<0 前向区（诊断预期污染），与正文双向因果讨论并存不矛盾。
