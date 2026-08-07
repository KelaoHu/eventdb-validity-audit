# 04_稳健性与因果识别补充

本模块是 `03_响应速度复现` 的下游稳健性与因果识别补充，目标是为论文中“政治关系冲击的响应速度”结论提供多方面的统计支撑。

## 模块结构

```text
04_稳健性与因果识别补充/
├── R语言工程文件/
│   ├── 00_prepare_data.R          # 构建统一分析面板
│   ├── 01_irf_response_speed.R    # 局部投影 IRF + 响应速度指标
│   ├── 02_standardization_robustness.R  # Raw / Z-Score / AR(1) 残差稳健性
│   ├── 03_window_lag_robustness.R       # 窗口长度与滞后阶数稳健性
│   ├── 04_event_study_did.R             # FTA 事件研究 + DID
│   └── 99_run_all.R                     # 一键运行全部脚本
├── 中间数据/
│   ├── panel_for_robustness.csv
│   └── robustness_windows_36_60_84.csv
├── 检验结果CSV/
│   ├── irf_coefficients.csv
│   ├── irf_response_speed.csv
│   ├── irf_vs_dl_comparison.csv
│   ├── robustness_standardization_metrics.csv
│   ├── robustness_standardization_correlation.csv
│   ├── robustness_window_lag_coefficients.csv
│   ├── robustness_window_lag_metrics.csv
│   ├── robustness_window_lag_summary.csv
│   ├── robustness_window_lag_vs_baseline.csv
│   ├── fta_event_study_coefficients.csv
│   ├── fta_did_main_results.csv
│   └── fta_did_placebo_results.csv
└── 图片/
    ├── fig01_irf_vs_dl_comparison.png
    ├── fig02_standardization_stability.png
    ├── fig03_window_lag_robustness.png
    ├── fig04_window_lag_heatmap.png
    ├── fig05_fta_event_study.png
    ├── fig06_fta_did_effect.png
    └── fig07_fta_did_placebo.png
```

## 环境依赖

- R >= 4.0
- 必要 R 包：`fixest`、`data.table`、`dplyr`、`ggplot2`、`tidyr`

首次运行会自动从 CRAN 镜像安装缺失包。

## 核心输入

- `data/panel_clean.csv`：经济基本面与贸易面板
- `../../3.2 双边关系分析基于月度政治分数/全新事件研究法/data/{gdelt_scores.csv, icews_scores.csv, phoenix_scores.csv, tsinghua_scores.csv}`：四库政治分数
- `02_事件驱动PPMLHDFE/00_事件面板构建/中间数据/event_panel_ready.csv`：事件类别面板
- `02_事件驱动PPMLHDFE/00_事件面板构建/中间数据/event_panel_with_directional_sanctions.csv`：带方向制裁信息的事件面板
- `03_响应速度复现/中间数据/windows.csv`：基准 60 个月滚动窗口定义
- `03_响应速度复现/检验结果CSV/response_speed_metrics.csv`：基准 Raw 方法响应速度指标
- `03_响应速度复现/检验结果CSV/full_sample_baseline.csv`：基准全样本 DL 系数

## 运行方式

在 `R语言工程文件/` 目录下执行：

```bash
Rscript 99_run_all.R
```

或按顺序单独运行各脚本：

```bash
Rscript 00_prepare_data.R
Rscript 01_irf_response_speed.R
Rscript 02_standardization_robustness.R
Rscript 03_window_lag_robustness.R
Rscript 04_event_study_did.R
```

## 各模块说明

### 00_prepare_data.R

- 合并经济面板与 GDELT、ICEWS、Phoenix、Tsinghua 四库政治分数。
- 生成 z-score 标准化政治分数 `PolZ_*` 与 AR(1) 残差冲击 `u_*`。
- 计算每个国家的 FTA 首次生效月份 `fta_date`，以及 `Post_FTA`、`Has_FTA` 虚拟变量。
- 输出统一数据集 `panel_for_robustness.csv`。

### 01_irf_response_speed.R

- 使用 z-score 政治分数，生成 L1–L6 滞后冲击。
- 对 `Trade_Total / Trade_Exports / Trade_Imports` 分别做局部投影（LP-IRF），回归控制 `ln_GDP_product + ln_ER + FTA_Dummy`，并包含国家、时间双向固定效应。
- 计算 `avg_response_lag`、`immediate_share`、`peak_lag`、`sig_lags_count` 等响应速度指标。
- 与 `03_响应速度复现` 的分布滞后全样本结果对比，绘制 IRF vs DL 散点图。

### 02_standardization_robustness.R

- 在 60 个月滚动窗口内，比较三种政治分数处理方式：
  - Raw（原值）
  - Z-Score（滚动 z-score）
  - AR(1) Residual（AR(1) 残差）
- 对每种方法估计 L0–L6 分布滞后，计算响应速度指标。
- 输出跨方法相关系数，绘制滚动窗口平均响应滞后时序图。

### 03_window_lag_robustness.R

- 构造 36、60、84 个月三种滚动窗口。
- 在每个窗口内分别估计分布滞后阶数为 3、6、12 的 PPML 模型。
- 计算响应速度指标，输出汇总表，并绘制稳健性图与热力图。
- 同时计算各配置与基准（60 个月窗口 + 6 阶滞后）的相关性。

### 04_event_study_did.R

- 利用 FTA 生效时间构造事件时间 `event_time`。
- 在 [-24, +24] 个月窗口内，估计事件研究模型（以 -1 期为参照），绘制动态处理效应图。
- 估计经典 DID 模型，输出 `Post_FTA` 的平均处理效应。
- 进行 Placebo 检验：将 FTA 生效时间整体推后 24 个月，比较真实效应与 Placebo 效应。

## 重要说明

1. **Tsinghua 数据库**：仅包含综合指数 `Pol_Agg`，不包含方向变量 `Pol_CHN_Partner` 与 `Pol_Partner_CHN`。所有脚本均已做相应跳过处理。
2. **FTA_Dummy 共线性**：在部分短窗口或事件研究子样本中，`FTA_Dummy` 可能因变异不足被国家固定效应吸收，`fixest` 会自动删除该变量并提示 `collinearity`。这是预期行为，不影响核心滞后系数估计。
3. **响应速度指标**：定义为 `sum(|β_h| * h) / sum(|β_h|)`，衡量系数绝对值加权的平均响应滞后；`immediate_share` 为当期系数绝对值占总绝对值之比。
4. **事件研究**：事件研究模型中由于已包含 FTA 生效前后各期虚拟变量，不再额外控制 `FTA_Dummy`，以避免完全共线性。

## 输出用途

本模块生成的 CSV 与图片可直接用于 docx 论文的“稳健性检验”与“因果识别”部分，补充主回归的响应速度结论。
