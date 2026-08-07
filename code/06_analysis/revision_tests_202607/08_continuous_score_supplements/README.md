# 08 连续分数补充检验包（总 README）

对应初稿核查问题 **C13**：初稿 4.4/4.5 节关于连续分数 PPML 的三项稳健性表述（排除美国、9 组合安慰剂、访问效应排除疫情期）缺失或无法溯源。本包在新版基准管线（`新PPMLHDFE/01_连续分数PPML/01_基准传导_季度冲击/R语言工程文件/01_run_irf.R`：GDELT 逐国 z-score → AR(1) 残差冲击 → fepois PPML，FE=ISO+YearMonth，cluster=~ISO，控制 ln_GDP_product+ln_ER+FTA_Dummy；基准 Trade_Total h=0 β=0.01274, p=0.0262）上统一重跑。

## 子检验一览

| 子检验 | 初稿表述 | 新结果 | 结论 |
|---|---|---|---|
| **08a 排除美国** | [145] β=0.0091 (p=0.042) | β=**0.0115** (p=**0.038**)，h=0–6 全正、5/7 期 p<0.05 | 结论成立；具体数字不可复现，以新数字为准 |
| **08b 新版安慰剂9组合** | [135] 9 种组合 p 均为 0.000 | h=0：Country_Label 与 Random_Shock 六组合 p=0.000，Time_Block 三组合 p=**0.005**；全部 63 单元最大 p=0.020 | 通过全部安慰剂检验；"均为 0.000"需修正 |
| **08c 访问效应排除疫情期** | [145] 排除疫情期后访问效应方向与显著性不变 | 进口：出访 0.0563 (p=0.002)、来访 0.0277 (p=0.172)、远程通话 −0.0998 (p=0.012)，方向与显著性全部不变 | 成立；且远程通话负效应剔疫情期后略增，与"危机混淆"解释（见 05 模块）方向相反 |

## 目录结构

```
08a_排除美国/           code/08a_irf_exclude_usa.R        results/irf_exclude_usa.csv
08b_新版安慰剂9组合/     code/08b_placebo_new_spec.R       results/placebo_new_spec.csv, placebo_draws.csv
08c_访问效应排除疫情期/  code/08c_visit_effects_excl_covid.R results/visit_effects_excl_covid.csv
```

各子目录 README.md 含四段式详情（目的/设定/结果/文本修改建议）。运行方式：`Rscript code/<脚本名>.R`（R 4.6.1，依赖 fixest/data.table/parallel）。
