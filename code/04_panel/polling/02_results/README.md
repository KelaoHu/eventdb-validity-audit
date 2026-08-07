# 02_分析结果 — 产出说明

## 分析配置

| 参数 | 值 |
|------|-----|
| 主分析窗口 | Pew 17国面板, 2005-2019 |
| 民调来源 | Pew Global Attitudes 四级好感度%, 窗口内重新z-score |
| 政治分数 | 公平覆盖期口径, 年度均值（月几何平均→年算术平均） |
| 回归设定 | country FE + year FE, SE clustered by country |
| N | 170 country-years, 17 countries |
| 排除国家 | 4国无民调（Iran, Saudi Arabia, Singapore, UAE）<br>4国观测不足（Belgium 1, Thailand 1, Malaysia 2, Vietnam 2） |
| 软件 | R 4.6.1（fixest, data.table, boot） |
| 产出日期 | 2026-07-30 |
| 统计标准 | Nature-statistics compliant: effect sizes + CIs + exact p + BH correction + unit definitions |

---

## 文件清单

### 面板数据

| 文件 | 说明 |
|------|------|
| `paired_panel_events.csv` | 配对面板 + 事件变量（170行 × 所有变量） |

### Tier 1：连续分数会聚度

| 文件 | 检验 | 说明 |
|------|------|------|
| `T1.1_between_country_rho.csv` | 会聚度-国家间 | 每库 between-country Spearman ρ + bootstrap 95% CI（N=17国） |
| `T1.1_within_country_rho.csv` | 会聚度-国家内 | 每库 within-country Spearman ρ 均值 + SD（N=17国） |
| `T1.2_country_level_spearman.csv` | 国别梯度 | 每库×每国 Spearman ρ（逐国） |
| `T1.3_asymmetry.csv` | 方向不对称 | 负面vs正面年份 Δpolling_z，国家单元 t-test + Wilcoxon（修正后） |
| `T1.4_fe_regression.csv` | FE面板回归 | polling_z ~ score + country FE + year FE, clustered SE |
| `BH_correction.csv` | 多重比较校正 | T1.3 + T1.4 + E1-E4 全族 Benjamini-Hochberg |

### Tier 2：事件分类分析

| 文件 | 检验 | 发现 |
|------|------|------|
| `E1a_event_presence.csv` | 事件存在性交互 | score×has_any_event 三库全不显著(p>0.09) |
| `E2a_signal_gradient_3level.csv` | 信号成本梯度 | 反转: gov_head(0.277) > state_head(0.157) |
| `E3_negative_events.csv` | 负面事件效应 | has_negative β=-0.190, p=0.016（显著） |
| `E4_moderation.csv` | 事件类型调节 | 12/12交互全n.s., BH后全FAIL |
| `E5_case_enumeration.csv` | 个案枚举 | **2026-08-04 已按现行 712 库重跑：31 个负面事件，19 个有民调前后对照，15/19（78.9%）↓**（旧值 34/25/20(80%) 为 713 库口径，正文 v41 起已更正） |

### 稳健性

| 文件 | 条件 | 核心结论 |
|------|------|---------|
| `robustness_checks.csv` | R1-R5 全部5条件 | T1.4 5/5稳定；T1.3 ICEWS 4/5失效；E3 依赖2019 |

---

## 结果速查表

### T1.1 会聚度（between vs within）

| 数据库 | between ρ [95% CI] | within ρ mean (SD) | N国 |
|--------|-------------------|---------------------|-----|
| GDELT | +0.132 [-0.413, +0.589] | +0.402 (0.359) | 17 |
| ICEWS | -0.005 [-0.589, +0.541] | +0.347 (0.324) | 17 |
| Phoenix | +0.348 [-0.194, +0.749] | +0.349 (0.312) | 17 |
| Tsinghua* | +0.394 [-0.463, +0.951] | +0.315 (0.382) | 10 |

*Tsinghua 仅10国，标注"探索性"

### T1.4 FE面板回归

| 数据库 | β | SE | p | R² | N | 国家数 |
|--------|-----|-----|------|-----|---|--------|
| GDELT | 0.240 | 0.066 | 0.002 | 0.074 | 170 | 17 |
| ICEWS | 0.191 | 0.050 | 0.002 | 0.089 | 170 | 17 |
| Phoenix | 0.120 | 0.025 | <0.001 | 0.111 | 170 | 17 |
| Tsinghua* | 0.141 | 0.053 | 0.027 | 0.120 | 113 | 10 |

### T1.5 同方程交叉验证

| 规格 | GDELT | ICEWS | Phoenix | R² | N |
|------|-------|-------|---------|-----|---|
| 三库 | 0.111 (p=0.204) | 0.077 (p=0.256) | **0.090 (p=0.002)** | 0.153 | 170 |

### E1-E4 汇总

| 检验 | GDELT | ICEWS | Phoenix | 结论 |
|------|-------|-------|---------|------|
| E1a score×has_any_event | p=0.507 | p=0.091 | p=0.594 | 全n.s. |
| E2 n_state_head | β=0.157 p=0.016 | — | — | 梯度反转 |
| E2 n_gov_head | β=0.277 p=0.002 | — | — | 梯度反转 |
| E3 has_negative | β=-0.190 p=0.016 | — | — | **显著** |
| E4a score×has_positive | p=0.534 | p=0.207 | p=0.749 | 全n.s. |
| E4b score×has_conflict | p=0.584 | p=0.872 | p=0.882 | 全n.s. |

---

## 复现命令

```r
# 完整分析（需先运行 phase0_clean.py 和 E0_events_merge.R）
source("C:/Users/胡克劳/Desktop/311工程数据/07_数据库与民调/analysis.R")
source("C:/Users/胡克劳/Desktop/311工程数据/07_数据库与民调/E1_event_presence.R")
source("C:/Users/胡克劳/Desktop/311工程数据/07_数据库与民调/E2_signal_gradient.R")
source("C:/Users/胡克劳/Desktop/311工程数据/07_数据库与民调/E3_negative_events.R")
source("C:/Users/胡克劳/Desktop/311工程数据/07_数据库与民调/E4_moderation.R")
source("C:/Users/胡克劳/Desktop/311工程数据/07_数据库与民调/E5_case_enumeration.R")
source("C:/Users/胡克劳/Desktop/311工程数据/07_数据库与民调/robustness.R")
```

## 方法论注意事项

- 所有结果均为关联性(associational)，非因果
- Tsinghua 仅10国 → 聚类标准误不可靠 → 全文标注"探索性"
- Phoenix 2019年度均值仅3个月（数据止于2019-03） → 标注+稳健性排除
- between-country所有CI跨零 → N=17国检验力不足，措辞为"insufficient power"非"no effect"
- T1.3不对称性ICEWS脆弱 → 4/5稳健性条件失效 → 结论限定为GDELT
- E3负面事件效应依赖2019 → 排除2019后p=0.162 → 结论限定为"全样本中成立"
- 年度民调频率 → 事件层面仅能识别共现，非因果 → 全文语言降级
