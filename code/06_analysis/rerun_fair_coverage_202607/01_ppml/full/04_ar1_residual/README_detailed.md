# 04_AR1残差回归

## 一、数据来源

### 1. 经济面板数据

- **文件位置**：`../../data/panel_clean.csv`
- **主要字段**：`ISO`、`Country`、`month`、`Trade_Total`、`Trade_Exports`、`Trade_Imports`、`ln_GDP_product`、`ln_ER`、`FTA_Dummy`
- **数据来源说明**：贸易额、GDP、汇率、FTA 等变量来源于 `3 实证结果/数据/经济数据库/`。

### 2. 政治关系分数

- **文件位置**：`../../../3.2 双边关系分析基于月度政治分数/全新事件研究法/data/`
- **四个数据库**：`gdelt_scores.csv`、`icews_scores.csv`、`phoenix_scores.csv`、`tsinghua_scores.csv`
- **重要说明**：本检验使用政治分数的 AR(1) 残差作为冲击，**不直接采用 `自建事件库_25国_17类_713条事件.csv`**。


## 二、操作方式

### 步骤 1：数据准备

1. 读取 `panel_clean.csv` 和四个政治分数文件。
2. 合并为 `panel_db`。
3. 对政治分数做 z-score 标准化。
4. 对 Tsinghua 做一阶差分后再标准化。
5. 对每个国家-数据库组合拟合 AR(1) 模型，提取残差作为意外冲击：
   - `u_Agg`
   - `u_CHN_Partner`
   - `u_Partner_CHN`
6. 生成冲击的 1–6 期滞后变量。

### 步骤 2：联合分布滞后 PPML 回归

对每个数据库和规格，估计：

```
Trade_t = Σ_{h=0}^{6} β_h * u_{t-h} + γ * Controls_t + FE_ISO + FE_YearMonth + ε_t
```

规格包括：

- `AR-Total`：`u_Agg` 对 `Trade_Total`
- `c-Export`：`u_CHN_Partner` 对 `Trade_Exports`
- `p-Import`：`u_Partner_CHN` 对 `Trade_Imports`

### 步骤 3：提取结果

- `h0`：h=0 系数
- `cum`：h=0..6 系数累计和
- `h0p`：h=0 系数的 p 值

### 步骤 4：保存与绘图

保存为 `A_AR1.csv`，并绘制各数据库累计效应柱状图。


## 三、运行结果

生成 `A_AR1.csv`，共 10 行。

主要发现：

- **GDELT**：总贸易、出口、进口均有正影响，部分显著。
- **ICEWS**：结果较弱，方向不稳定。
- **Phoenix**：结果较弱。
- **Tsinghua**：总贸易负影响，但不显著。


## 四、生成的文件与文件夹结构

```
04_AR1残差回归/
├── R语言工程文件/
│   ├── 04_run_ar1_residual_ppml.R    # 主分析脚本
│   └── 04_plot_ar1_residual.R        # 绘图脚本
├── 检验结果CSV/
│   ├── A_AR1.csv
│   └── README.md
└── 图片/
    ├── fig04_ar1_residual.png
    ├── 04_plot_ar1_residual.R        # 图片对应脚本副本
    └── README.md
```

运行命令：

```bash
cd "04_AR1残差回归/R语言工程文件"
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 04_run_ar1_residual_ppml.R
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 04_plot_ar1_residual.R
```
