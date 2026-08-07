# 02_事件驱动 PPMLHDFE

本文件夹系统分析 **713 条人工标注事件** 对中国与 25 个贸易伙伴双边贸易的影响，与 `01_连续分数PPML/` 形成方法论互补：前者用离散事件，后者用连续政治分数。

## 目录结构

```
02_事件驱动PPMLHDFE/
├── 00_事件面板构建/          # 构建事件-面板主数据集
│   └── R语言工程文件/
│       ├── 00_build_event_panel.R
│       └── 00c_build_directional_sanctions.R   # 方向化制裁/科技管制变量
├── 01_事件基准效应/          # 正/负/中性事件对贸易的平均效应
├── 02_正负向非对称与4类访问效应/  # 正负非对称 + 图例 4 类领导人访问
├── 03_17类事件异质性/        # 17 类事件类型效应
├── 04_国家异质性/            # 各国事件敏感度排名
├── 05_事件动态IRF/           # 事件后 h=0,1,3,6,12 个月动态效应
├── 06_事件强度与四库验证/    # 四库分数变化验证事件强度
├── 07_稳健性与安慰剂/        # 稳健性 + 安慰剂检验
├── 08_汇总报告与可视化/      # 综合图表与 report.md
├── 09_事件类型深度稳健性与动态分析/  # FDR、机制解释、IRF、分样本异质性、方向化制裁
│   └── R语言工程文件/
│       ├── 09a_reliability_seventeen_categories.R
│       ├── 09b_mechanism_economic_cooperation.R
│       ├── 09c_robustness_economic_cooperation.R
│       ├── 09d_irf_key_categories.R
│       ├── 09e_subsample_heterogeneity.R
│       ├── 09j_directional_sanction_import_response.R
│       ├── 09k_directional_sanction_irf.R
│       ├── 09l_directional_sanction_country_response.R
│       ├── 09m_directional_sanction_robustness.R
│       ├── 09n_directional_sanction_plot_robustness.R
│       └── 09o_directional_sanction_plot_placebo.R
├── 10_国家敏感度差异检验/    # 国家间事件敏感度差异：连续交互、刀切法、meta 回归、分组 IRF、标签置换、四库交叉验证
│   ├── R语言工程文件/
│   │   ├── 10a_country_sensitivity_interactions_and_jackknife.R
│   │   ├── 10b_country_sensitivity_meta_regression.R
│   │   ├── 10c_country_label_placebo.R
│   │   ├── 10d_group_irf_cumulative_sensitivity.R
│   │   └── 10e_cross_database_sensitivity_validation.R
│   ├── 检验结果CSV/
│   ├── 图片/
│   ├── skill.md
│   └── _archive/             # 旧版探索性脚本与输出（已归档）
├── 00_utils.R                # 公共工具函数
├── 99_master.R               # 一键运行全部（共 20 步）
└── README.md                 # 本文件
```

## 快速复现

### 一键运行全部

```bash
cd "02_事件驱动PPMLHDFE"
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 99_master.R
```

### 单独运行某个子项目

```bash
cd "01_事件基准效应/R语言工程文件"
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 01_run_baseline_ppml.R
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 01_plot_baseline_effects.R
```

## 数据依赖

- 经济面板：`../data/panel_clean.csv`
- 713 事件库：`../../3.2 双边关系分析基于月度政治分数/自建事件库_25国_17类_713条事件.csv`
- 四库分数：`../../3.2 双边关系分析基于月度政治分数/全新事件研究法/data/{gdelt_scores.csv, icews_scores.csv, phoenix_scores.csv, tsinghua_scores.csv}`

## 核心方法

所有核心回归采用 PPML-HDFE：

```
fepois(Trade ~ Event_Dummies + ln_GDP_product + ln_ER + FTA_Dummy | ISO + YearMonth,
       data = dt, cluster = ~ISO, glm.iter = 100)
```

- **ISO 固定效应**：吸收国家层面不随时间变化的贸易成本。
- **YearMonth 固定效应**：吸收共同时间趋势与全球需求冲击。
- **聚类到 ISO**：处理国家层面序列相关。

## 主要产出

| 类型 | 数量 |
|------|------|
| R 生成脚本 | 44 个 |
| CSV 结果表格 | 41 张（不含 00 中间数据） |
| PNG 图表 | 31 张 |
| 子项目 skill.md | 11 份 |
| Markdown 汇总报告 | 1 份 |

## 注意事项

1. **07 安慰剂检验**：默认 `N_PERM = 100`，如需更严格的安慰剂 p 值，可在 `07_run_robustness_and_placebo.R` 中提高该值（计算时间线性增长）。
2. **06 事件强度**：`Delta_*` 为事件前后 4 个月（t−3 到 t+0）四库 z-score 变化；Tsinghua 为差分后序列，解释需谨慎。
3. **03 17 类事件**：部分稀疏类别（如战略定位负面、安全威胁）可能因与高维固定效应共线而被自动剔除。
4. **09 深度稳健性**：FDR 校正后，17 类中仅少数类别保持显著；经贸互利合作的负系数主要反映事前趋势与美国样本驱动，不宜直接解释为因果效应。
5. **方向化制裁/科技管制**：在控制 `Event_Negative` 后，对华科技管制与经贸制裁均显著推高中国从伙伴国的进口（约 +23%），安慰剂检验 p 值分别为 0.005 与 0.004；排除美国、伊朗、疫情期及双向聚类后结论保持稳健。
6. **10 国家敏感度差异——连续交互与刀切法**：贸易依存度显著放大负向事件对出口的抑制；部分交互项在 Jackknife 中符号或显著性发生变化，说明估计受个别国家样本影响。
7. **10 国家敏感度差异——meta 回归**：加权 WLS 中 FTA 对总贸易与出口的敏感度显著为负（FTA 国家相对更不敏感），但加入区域后解释力提升；整体国家特征对敏感度差异的解释力有限。
8. **10 国家敏感度差异——标签置换安慰剂**：多数交互项的安慰剂 p 值不显著（0.07–0.76），提示当前国家特征调节效应在随机 shuffle 下不够稳健，需谨慎解释。
9. **10 国家敏感度差异——分组 IRF**：发展中国家对负向事件的进口与总贸易累积敏感度显著高于发达国家；FTA 国家在负向事件后的进口反应显著强于非 FTA 国家；高贸易依存度国家在负向事件后总贸易下降更显著。
10. **10 国家敏感度差异——四库交叉验证**：事件驱动国家敏感度与 GDELT/ICEWS/Phoenix 政治分数波动率无显著 Spearman 相关；仅 Tsinghua 进口相关系数为 −0.58（p = 0.066），处于边缘显著水平。
