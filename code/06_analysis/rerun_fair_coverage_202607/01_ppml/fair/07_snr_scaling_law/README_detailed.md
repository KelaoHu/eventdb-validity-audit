# 07_信噪比效应量标度律

## 一、数据来源

### 1. 政治关系分数

- **文件位置**：`../../../3.2 双边关系分析基于月度政治分数/全新事件研究法/data/`
- **四个数据库**：`gdelt_scores.csv`、`icews_scores.csv`、`phoenix_scores.csv`、`tsinghua_scores.csv`
- **重要说明**：本检验使用连续政治分数，**不直接采用 `自建事件库_25国_17类_713条事件.csv`**。

### 2. IRF 结果（间接输入）

- **文件位置**：`../01_基准传导_季度冲击/检验结果CSV/{db}/irf_all.csv`
- 用于计算 `cum_d3`：每个数据库总贸易在 h=0..3 的累计效应。


## 二、操作方式

### 步骤 1：计算 AR(1) rho

对每个数据库、每个国家的标准化政治分数 `PolZ_Agg` 拟合 AR(1) 模型：

```
PolZ_t = ρ * PolZ_{t-1} + ε_t
```

提取 `ρ` 系数。`ρ` 越接近 1，表示政治关系分数记忆性越强、变化越慢；`ρ` 越接近 0，表示波动越大、噪声越多。

对 Tsinghua 使用一阶差分后的序列计算 rho。

### 步骤 2：汇总 scaling 报告

按数据库汇总：

- 平均 `rho`
- 国家数
- 观测数
- `cum_d3`：GDELT/ICEWS/Phoenix/Tsinghua 各自总贸易 IRF 在 h=0..3 的累计效应

### 步骤 3：绘图

绘制四个数据库 `rho` 的柱状图，并用红色虚线标注单位根边界 `rho=1`。


## 三、运行结果

生成 `C_scaling.csv`。

四个数据库的 rho 值：

| 数据库 | rho |
|--------|-----|
| GDELT | ~0.35 |
| ICEWS | ~0.34 |
| Phoenix | ~0.47 |
| Tsinghua | ~0.21 |

主要发现：

- Phoenix 的政治分数记忆性最强（最稳定），Tsinghua 最弱（最波动）。
- 但 rho 大小与贸易效应之间没有呈现明显的规律性。
- `C_scaling.csv` 中的 `cum_ar` 列目前为 NA，需要进一步计算 AR 修正后的累计效应才能填满。


## 四、生成的文件与文件夹结构

```
07_信噪比效应量标度律/
├── R语言工程文件/
│   └── 03_plot_scaling.R              # 绘图脚本
├── 检验结果CSV/
│   ├── C_scaling.csv                  # 由 01_run_irf.R 生成
│   └── README.md
└── 图片/
    ├── fig03_ar1_rho_comparison.png
    ├── 03_plot_scaling.R              # 图片对应脚本副本
    └── README.md
```

运行命令：

```bash
cd "07_信噪比效应量标度律/R语言工程文件"
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 03_plot_scaling.R
```

注意：`C_scaling.csv` 由 `01_基准传导_季度冲击/R语言工程文件/01_run_irf.R` 在生成 IRF 时一并写入。
