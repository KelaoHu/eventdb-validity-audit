# 08a 排除美国

## ① 检验目的与对应初稿问题（C13）

初稿 [145] 称"排除美国后 GDELT 仍然显著（β=0.0091, p=0.042）"，但无对应输出文件可溯源（C13）。本子检验在新版基准管线（01_run_irf.R）上剔除美国重估 GDELT 连续分数 LP-IRF，验证该数字是否可复现。

## ② 数据与模型设定

- 与 `新PPMLHDFE/01_连续分数PPML/01_基准传导_季度冲击/R语言工程文件/01_run_irf.R` 完全一致：`panel_clean.csv` + `gdelt_scores.csv`（Aggregated/CHN→Partner/Partner→CHN 三方向），逐国 z-score → AR(1) 残差冲击 u_Agg/u_CHN_Partner/u_Partner_CHN → `fepois(trade ~ shock_Lh + ln_GDP_product + ln_ER + FTA_Dummy | ISO + YearMonth)`，cluster=~ISO，glm.iter=100，h=0..6，三因变量，三个 spec（GD-Total/Export/Import）。
- 唯一差异：估计样本剔除 ISO=="US"（24 国）。由于 z-score 与 AR(1) 均逐国计算，剔除美国不影响其余国家的冲击构造。
- 代码：`code/08a_irf_exclude_usa.R`；输出 `results/irf_exclude_usa.csv`（63 行）。

## ③ 结果解读

排除美国后 GD-Total spec：

| trade | h=0 β | h=0 p | h 范围显著性 |
|---|---|---|---|
| Trade_Total | **0.01151** | **0.0382** | h=0,1,2,5,6 显著(p<0.05)；h=3 p=0.143；h=4 p=0.071 |
| Trade_Exports | 0.01101 | 0.0039 | h=0,1,4 显著(p<0.05)；h=2 p=0.057；h=3,5,6 不显著 |
| Trade_Imports | 0.01491 | 0.1012 | 仅 h=5,6 显著(p=0.050/0.042)；h=0..4 不显著 |

与全样本基准（Trade_Total h=0 β=0.01274, p=0.0262）相比，系数仅下降约 10%，仍为显著正效应——"排除美国后 GDELT 仍然显著"的**结论成立**。但初稿给出的具体数字 **β=0.0091 (p=0.042) 不可复现**，应以新数字 β=0.0115 (p=0.038) 为准（差异可能来自初稿写作时使用的旧版面板/分数）。

## ④ 文本修改建议

- [145] "排除美国后 GDELT 仍然显著（β=0.0091, p=0.042）" → 改为："排除美国后 GDELT 仍然显著（β=0.0115, p=0.038；h=0–6 全为正，5/7 期 p<0.05）"。
