# 03_响应速度复现

本文件夹按照 `PPMLHDFE图表解读报告.docx` 中的方法，使用 **GDELT / ICEWS / Phoenix / Tsinghua 四个数据库** 的连续政治分数，复现政治关系对中国与 25 个贸易伙伴双边贸易的**响应速度**分析。

## 方法

- **模型**：PPMLHDFE（泊松伪最大似然 + 高维固定效应）
- **分布滞后**：L0–L6（当月及前 6 个月）
- **滚动窗口**：60 个月窗口，步进 12 个月，共 20 个窗口
- **固定效应**：ISO（国家）+ YearMonth（年月）
- **聚类**：国家层面
- **政治变量**：
  - `Pol_Agg`：综合政治指数（四库均有）
  - `Pol_CHN_Partner`：中国→伙伴方向（GDELT/ICEWS/Phoenix）
  - `Pol_Partner_CHN`：伙伴→中国方向（GDELT/ICEWS/Phoenix）
- **贸易变量**：`Trade_Total`（总贸易）、`Trade_Exports`（出口）、`Trade_Imports`（进口）
- **控制变量**：`ln_GDP_product`、`ln_ER`、`FTA_Dummy`

## 响应速度指标

| 指标 | 计算方式 |
|------|----------|
| 平均响应滞后 | `Σ \|β_h\| · h / Σ \|β_h\|` |
| 即时效应占比 | `\|β_0\| / Σ \|β_h\|` |
| 峰值滞后 | `argmax_h \|β_h\|` |
| 显著滞后数 | `Σ 1(p_h < 0.05)` |

## 文件结构

```
03_响应速度复现/
├── R语言工程文件/
│   ├── 00_prepare_data.R          # 数据准备、生成滞后、定义窗口
│   ├── 01_run_rolling_window.R    # 滚动窗口回归
│   ├── 02_compute_response_speed.R # 计算响应速度指标
│   ├── 03_plot_response_speed.R   # 绘图
│   └── 99_run_all.R               # 一键运行
├── 检验结果CSV/
│   ├── window_coefficients.csv    # 各窗口 L0-L6 系数
│   ├── full_sample_baseline.csv   # 全样本基准系数
│   ├── response_speed_metrics.csv # 响应速度指标（长格式）
│   └── response_speed_metrics_wide.csv # 响应速度指标（宽格式）
├── 图片/
│   ├── fig01_response_lag_trend.png   # 折线图：响应速度时变
│   ├── fig02_slope_early_recent.png   # 斜率图：早期 vs 近期
│   ├── fig03_ridge_heatmap.png        # 山脊热力图：Pol_Agg
│   └── fig04_ridge_directional.png    # 山脊热力图：方向指数
├── 中间数据/
│   ├── panel_with_scores_and_lags.csv # 合并后的面板 + 滞后项
│   └── windows.csv                    # 滚动窗口定义
└── README.md
```

## 快速复现

```bash
cd "03_响应速度复现/R语言工程文件"
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 99_run_all.R
```

或分步运行：

```bash
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 00_prepare_data.R
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 01_run_rolling_window.R
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 02_compute_response_speed.R
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 03_plot_response_speed.R
```

## 依赖

- R ≥ 4.5
- R 包：`fixest`、`data.table`、`dplyr`、`tidyr`、`ggplot2`

## 说明

- 政治分数使用原值进入回归，以贴近 docx 的方法（选项 A）。
- Tsinghua 数据库只有综合指数，因此 `fig01` / `fig02` 中 Tsinghua 面板只有“综合指数”一条线。
- 某些窗口-数据库-变量组合可能因样本不足或共线性而无法估计，结果 CSV 中相应行缺失。
