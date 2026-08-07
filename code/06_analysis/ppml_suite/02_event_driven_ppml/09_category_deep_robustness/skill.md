# 09_事件类型深度稳健性与动态分析

## 适用场景

当你已经发现 17 类事件存在某些显著但难以解释的结果（例如“经贸互利合作”对贸易为负）时，本模块提供一套更严谨的统计验证流程：

- 用多重检验校正和小样本推断评估显著性的稳健性；
- 用事前趋势、交互项、子样本分析解释反常系数；
- 用局部投影 IRF 刻画关键类别的动态路径；
- 用分样本检验判断异质性是否稳定。

## 模型

### 主模型

```r
fepois(Trade ~ Cat_1 + ... + Cat_16 + Controls | ISO + YearMonth, cluster = ~ISO)
```

以“高层互访”为参照组，`Cat_*` 为 17 类事件虚拟变量。

### 关键统计处理

1. **多重检验校正**：对 17 类 × 3 贸易变量使用 Benjamini-Hochberg FDR 与 Bonferroni 校正。
2. **小样本推断**：25 个国家聚类，报告 t_{G-1} 校正 p 值。
3. **事前趋势**：生成 h=-3,-2,-1 领先项，Wald 联合检验。
4. **交互效应**：`Cat × FTA`、`Cat × 国事访问`。
5. **分样本 Wald**：`H0: β_A = β_B`。

## 输出

| 文件 | 内容 |
|------|------|
| `09a_reliability_category_effects.csv` | FDR / Bonferroni / t_{G-1} / Leave-one-out |
| `09b_mechanism_economic_cooperation.csv` | 经贸互利合作：事前趋势、访问交互、FTA 交互 |
| `09c_robustness_economic_cooperation.csv` | 稳健性设定与逐事件剔除 |
| `09d_irf_key_categories.csv` | 关键类别 IRF 系数 |
| `09d_irf_key_categories_wald.csv` | IRF 预趋势与事后联合 Wald |
| `09e_subsample_heterogeneity.csv` | 分样本系数与 Wald 检验 |
| `09j_directional_sanction_import_response.csv` | 方向化制裁/科技管制对总贸易、出口、进口的影响 |
| `09k_directional_sanction_irf.csv` | 方向化制裁/科技管制 IRF（h=−3..12） |
| `09l_directional_sanction_country_response.csv` | 国家-特征交互项（发达/FTA/贸易依存度） |
| `09l_directional_sanction_descriptive.csv` | 国家特征描述统计 |
| `09m_directional_sanction_robustness.csv` | 方向化制裁稳健性设定 |
| `09m_directional_sanction_placebo_summary.csv` | 1000 次安慰剂检验摘要 |
| `09m_directional_sanction_placebo_draws.csv` | 1000 次安慰剂系数抽样 |

## 图片

- `fig09a_fdr_adjusted_forest.png`：FDR 校正后 17 类效应森林图
- `fig09b_mechanism_and_robustness.png`：经贸互利合作机制与稳健性
- `fig09c_irf_key_categories.png`：关键类别动态 IRF
- `fig09d_subsample_heatmap.png`：分样本异质性热力图
- `09n_directional_sanction_robustness_imports.png`：方向化制裁稳健性森林图（进口）
- `09n_directional_sanction_robustness_exports.png`：方向化制裁稳健性森林图（出口）
- `09o_directional_sanction_placebo.png`：方向化制裁安慰剂系数分布

## 解读要点

1. **统计显著 ≠ 因果**：本模块仍依赖双向固定效应识别，反常系数可能反映分类偏误或反向因果。
2. **事前趋势是关键**：若某类别在事件前即显著，说明效应可能不是事件本身导致。
3. **FDR 校正会削弱显著性**：17 类同时检验，原始 p<0.10 的系数很多经 FDR 后不再显著。
4. **子样本结果需谨慎**：分样本中稀疏类别常被剔除，且 FTA_Dummy 可能与国家 FE 共线性。

## 常见陷阱

- **换参照组不是稳健性检验**：系数会线性变换，但显著性不变。
- **小样本聚类**：25 个国家时，传统聚类 SE 可能偏误，应配合 t_{G-1} 或 Wild Bootstrap。
- **方向化制裁解释**：对华科技管制/经贸制裁在控制 `Event_Negative` 后对中国进口显著为正，但未控制负向事件时消失；说明该效应并非事件本身，而是与“整体关系恶化”背景相关，需谨慎归因。
- **过度解读边缘显著**：本模块大量 p≈0.10 结果，需在论文中明确标注。
