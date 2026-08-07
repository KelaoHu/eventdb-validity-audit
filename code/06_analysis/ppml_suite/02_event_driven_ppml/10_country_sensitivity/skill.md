# 10_国家敏感度差异检验

## 目的

在 `04_国家异质性` 得到“各国对政治事件的敏感度排名”之后，进一步系统检验：**中国对贸易伙伴政治事件的贸易反应，是否在国家之间存在结构性差异**，并判断这些差异是国家特征的稳健调节作用，还是由少数高杠杆国家或随机分组驱动。

本模块采用 **三层递进 + 两组稳健性/交叉验证** 的设计：

1. **连续交互项 + Jackknife（10a）**：在国家-月度面板内，将事件虚拟变量与国家层面的连续/离散特征（贸易依存度、FTA、发达程度、对美盟友）交互，估计调节效应；并通过 leave-one-country-out 检验系数稳定性。
2. **两阶段 Meta-回归（10b）**：把 `04_国家异质性` 中各国的正负事件系数聚合成敏感度指数 `β_Negative − β_Positive`，再用国家特征解释国家间差异。
3. **国家标签置换安慰剂（10c）**：在同区域内随机打乱国家特征标签，生成交互项的零分布，判断观测到的调节效应是否超出随机范围。
4. **分组动态 IRF 与累积敏感度（10d）**：按发达程度、FTA、贸易依存度分组，估计正/负/中性事件的动态 IRF（h = 0,1,3,6,12），做组间 Wald 检验，并计算 12 期累积敏感度。
5. **四库交叉验证（10e）**：将事件驱动国家敏感度与 GDELT/ICEWS/Phoenix/Tsinghua 四库政治分数的波动率做 Spearman 秩相关，验证事件结果与连续分数结果的一致性。

## 数据与变量

- 主面板：`02_事件驱动PPMLHDFE/00_事件面板构建/中间数据/event_panel_ready.csv`
- 国家异质性系数：`02_事件驱动PPMLHDFE/04_国家异质性/检验结果CSV/04_country_heterogeneity.csv`
- 四库政治分数：`../../3.2 双边关系分析基于月度政治分数/全新事件研究法/data/{gdelt_scores.csv, icews_scores.csv, phoenix_scores.csv, tsinghua_scores.csv}`

**国家特征（在 10a–10e 中计算）**：

| 特征 | 计算方式 | 说明 |
|------|----------|------|
| `z_trade_dep` | 各国 `Trade_Total` 样本均值，再按截面 z-score 标准化 | 对华贸易规模/依存度的代理 |
| `FTA_Dummy` / `ever_fta` | 样本期内是否与中国签订 FTA（月度虚拟变量 / 是否曾经签订） | 10a/10c/10d 使用不同形式 |
| `developed` | 0/1，发达经济体列表见脚本 | 美国、日本、德国、英国、法国、意大利、加拿大、澳大利亚、西班牙、荷兰、比利时、韩国、新加坡 |
| `us_ally` | 0/1，对美盟友列表见脚本 | 美国、日本、澳大利亚、加拿大、英国、韩国、德国、法国、意大利、西班牙、荷兰、比利时 |
| `region` | 亚洲/中东、欧洲、美洲、其他 | 用于 Jackknife 标注与标签置换的分层 |

为便于比较，连续特征在交互项与 meta 回归中均已标准化（z-score），`developed`、`FTA`/`ever_fta`、`us_ally` 保持 0/1。

## 核心模型

### 10a 连续国家特征交互项

对总贸易、出口、进口分别估计：

```r
fepois(Trade ~ Event_Positive + Event_Negative + Event_Neutral +
                Event_Positive_x_z_trade_dep + Event_Negative_x_z_trade_dep + Event_Neutral_x_z_trade_dep +
                Event_Positive_x_FTA_Dummy + Event_Negative_x_FTA_Dummy + Event_Neutral_x_FTA_Dummy +
                Event_Positive_x_developed + Event_Negative_x_developed + Event_Neutral_x_developed +
                Event_Positive_x_us_ally   + Event_Negative_x_us_ally   + Event_Neutral_x_us_ally   +
                ln_GDP_product + ln_ER + FTA_Dummy |
       ISO + YearMonth,
       data = dt, cluster = ~ISO, glm.iter = 100)
```

交互系数反映：**国家特征每增加 1 个单位（或 1 个标准差），事件对贸易的边际效应如何变化**。

> 注：`Event_Neutral_x_us_ally` 等部分交互项可能因与 ISO 固定效应或控制变量共线而被 `fixest` 自动删除，不影响核心交互项的解释。

### 10b 两阶段 Meta-回归

第一阶段：从 `04_country_heterogeneity.csv` 提取各国 `Event_Positive` 与 `Event_Negative` 系数。

第二阶段：构造国家敏感度指数：

```
sensitivity_i = β_Negative_i − β_Positive_i
SE_sens_i     = sqrt(SE_Neg_i² + SE_Pos_i²)
```

然后用 **OLS** 与 **精度加权 WLS（权重 = 1 / SE_sens²）** 回归：

```r
lm(sensitivity ~ FTA + developed + z_trade_dep, data = d, weights = precision)           # 模型 1
lm(sensitivity ~ FTA + developed + z_trade_dep + factor(region), data = d, weights = precision)  # 模型 2
lm(sensitivity ~ FTA + developed + z_trade_dep, data = d)                               # 模型 3（不加权稳健性）
```

> 注：正/负事件系数可能相关，此处假设协方差为 0，`SE_sens` 是近似值。

### 10c 国家标签置换安慰剂

真实模型（以总贸易为例）：

```r
Trade_Total ~ Event_Positive + Event_Negative + Event_Neutral +
              Event_Positive_x_z_trade_dep + Event_Negative_x_z_trade_dep +
              Event_Positive_x_FTA + Event_Negative_x_FTA +
              Event_Positive_x_developed + Event_Negative_x_developed +
              controls | ISO + YearMonth
```

在同 `region` 内随机打乱 `z_trade_dep`、`FTA`、`developed` 的国家标签，重复 `N_PERM = 500` 次，得到置换分布。安慰剂 p 值：

```
placebo_p = mean(|placebo_coef| ≥ |actual_coef|)
```

### 10d 分组局部投影 IRF

对国家分组 `G` 内的子样本，分别估计：

```r
Y_{t+h} ~ Event_t + controls | ISO + YearMonth
```

其中 `h = 0,1,3,6,12`，`Event` 包括 `Event_Positive`、`Event_Negative`、`Event_Neutral`。

组间差异通过全样本交互项做 Wald 检验：

```r
Y ~ Event_t + Event_t × G + controls | ISO + YearMonth
wald(fit, "Event_t:G")
```

累积敏感度指数：

```
cum_sensitivity = Σ_h β_h
cum_SE          = sqrt(Σ_h SE_h²)
```

### 10e 四库交叉验证

1. 对四库 `Pol_Agg` 计算各国标准差 `vol_db`。
2. 将 `sensitivity_i = β_Negative_i − β_Positive_i` 与 `vol_db` 做 Spearman 秩相关：

```r
cor.test(sensitivity, volatility, method = "spearman")
```

## 输出文件

### CSV

| 文件 | 内容 |
|------|------|
| `10a_interactions.csv` | 连续国家特征交互项系数、标准误、p 值、样本量 |
| `10a_jackknife.csv` | 每次剔除一国后各交互项的系数、p 值、显著性 |
| `10a_jackknife_summary.csv` | 各交互项在 Jackknife 中的符号变化次数、显著性丧失次数、系数范围 |
| `10b_country_sensitivity_for_meta.csv` | 各国敏感度指数 `β_Neg − β_Pos`、标准误、精度、国家特征 |
| `10b_meta_regression.csv` | 加权/不加权、含/不含 region 的 meta 回归系数、R²、F 统计量 |
| `10c_label_placebo_draws.csv` | 500 次置换的交互项系数分布（长格式） |
| `10c_label_placebo_summary.csv` | 真实系数、置换均值/标准差、安慰剂 p 值 |
| `10d_group_irf.csv` | 分组 IRF 系数、95% CI、样本量、国家数 |
| `10d_group_irf_wald.csv` | 组间差异 Wald 检验 p 值 |
| `10d_cumulative_sensitivity.csv` | 分组 12 期累积敏感度指数、p 值 |
| `10e_cross_db_data.csv` | 各国事件敏感度与四库波动率合并数据 |
| `10e_cross_db_correlation.csv` | Spearman ρ、p 值、样本量 |

### PNG

| 文件 | 内容 |
|------|------|
| `10a_jackknife_stability.png` | 显著交互项的 leave-one-country-out 系数稳定性 |
| `10b_meta_fitted_vs_observed.png` | Meta-回归拟合敏感度 vs 观测敏感度（点大小 = 精度） |
| `10c_label_placebo.png` | 国家标签置换的零分布与真实系数对比 |
| `10d_group_irf.png` | 发达/发展中、FTA/非 FTA、高/中/低贸易依存度分组 IRF |
| `10e_cross_db_correlation.png` | 事件敏感度 vs 四库政治分数波动率散点与相关系数 |

## 主要发现与解释边界

1. **连续交互项（10a）**
   - 贸易依存度越高，负向事件对出口的抑制越强。
   - FTA 对正向事件有显著正向调节。
   - 部分交互项在 Jackknife 中符号或显著性发生变化，说明估计受个别国家样本影响较大。

2. **Meta-回归（10b）**
   - 加权 WLS 中，FTA 对总贸易和出口的敏感度显著为负，即 FTA 国家相对更不敏感。
   - 加入 `region` 后模型解释力有所提升，但整体国家特征对国家敏感度差异的解释力有限。
   - 04 的逐国敏感度排名受伊朗（UN 多边制裁）和稀疏事件主导，不能作为国家间“绝对敏感程度”的稳健结论。

3. **标签置换安慰剂（10c）**
   - 多数交互项的安慰剂 p 值不显著（0.07–0.76）。
   - 因此**不能**强有力地声称国家特征差异显著超出随机分组范围，需谨慎解释。

4. **分组 IRF（10d）**
   - 发展中国家对负向事件的进口和总贸易累积敏感度显著高于发达国家。
   - FTA 国家在负向事件后的进口反应显著强于非 FTA 国家。
   - 高贸易依存度国家在负向事件后总贸易下降更显著。
   - 按 FTA 分组时，`FTA_Dummy` 在组内为常数，会被 `fixest` 自动删除，属于预期行为。

5. **四库交叉验证（10e）**
   - 事件驱动敏感度与 GDELT、ICEWS、Phoenix 政治分数波动率无显著 Spearman 相关。
   - 仅 Tsinghua 进口相关系数为 −0.58（p = 0.066），处于边缘显著水平。
   - 事件库与连续分数库刻画的是不同维度的政治关系，缺乏显著相关并不否定事件库在特定制裁/科技管制场景下的识别价值。

## 论文表述建议

- **避免绝对排名**：不要写“国家 A 比国家 B 对政治事件更敏感”。
- **强调结构性调节**：应表述为“FTA、发展水平、贸易依存度等结构性特征调节了事件—贸易关系”。
- **承认稳健性边界**：标签置换与四库交叉验证显示国家敏感度差异并非强信号，需与 09 方向化制裁结果、04 国家异质性结果相互印证，而非单独作为核心因果结论。

## 归档说明

`_archive/` 中存放了本模块早期的探索性脚本与输出（如 `10a_country_sensitivity_continuous_interactions.R`、`10b_country_sensitivity_jackknife.R` 等）。它们与当前 `99_master.R` 中调用的 10a–10e 脚本不再保持一致，仅供参考，正式复现请以本 `skill.md` 与 `99_master.R` 为准。
