# 03_干净面板PPML

## 一、数据来源

### 1. 经济面板数据

- **文件位置**：`../../data/panel_clean.csv`
- **主要字段**：`ISO`、`Country`、`month`、`Trade_Total`、`Trade_Exports`、`Trade_Imports`、`ln_GDP_product`、`ln_ER`、`FTA_Dummy`
- **数据来源说明**：贸易额、GDP、汇率、FTA 等变量来源于 `3 实证结果/数据/经济数据库/`（IMF、WTO 等）。

### 2. 政治关系分数

- **文件位置**：`../../../3.2 双边关系分析基于月度政治分数/全新事件研究法/data/`
- **四个数据库**：`gdelt_scores.csv`、`icews_scores.csv`、`phoenix_scores.csv`、`tsinghua_scores.csv`
- **重要说明**：本检验使用连续政治分数的水平值，**不直接采用 `自建事件库_25国_17类_713条事件.csv`**。


## 二、操作方式

### 步骤 1：数据准备

1. 读取 `panel_clean.csv` 和四个政治分数文件。
2. 合并为 `panel_db`，按国家和数据库分组排序。
3. 对政治分数做 z-score 标准化，生成 `PolZ_Agg`、`PolZ_CHN_Partner`、`PolZ_Partner_CHN`。
4. 对 Tsinghua 做一阶差分后再标准化。
5. 为水平分数生成 1–6 期滞后变量，并生成对应的绝对值变量。

### 步骤 2：联合分布滞后 PPML 回归

对每个数据库、每个贸易变量、每种分数变体，估计如下模型：

```
Trade_t = Σ_{h=0}^{6} β_h * PolZ_{t-h} + γ * Controls_t + FE_ISO + FE_YearMonth + ε_t
```

尝试的分数变体包括：

- 原始分数（signed）：`PolZ_Agg`、`PolZ_CHN_Partner`、`PolZ_Partner_CHN`
- 绝对值分数（abs）：`|PolZ_Agg|`、`|PolZ_CHN_Partner|`、`|PolZ_Partner_CHN|`

### 步骤 3：提取结果

- `h0`：当期（h=0）系数
- `cum`：h=0 到 h=6 七个系数的累计和
- `h0p`：h=0 系数的 p 值

### 步骤 4：保存与绘图

将结果保存为 `ppml_final.csv`，并绘制按数据库分面的累计效应柱状图。


## 三、运行结果

生成 `ppml_final.csv`，共 60 行（4 个数据库 × 多种变体 × 3 个贸易变量）。

主要发现：

- **GDELT**：原始分数对总贸易、出口、进口都有显著正影响；绝对值分数影响为负，说明方向很重要。
- **ICEWS**：结果较弱，部分出口方向显著为正。
- **Phoenix**：结果较弱，显著性不系统。
- **Tsinghua**：原始分数对总贸易和出口有负影响，绝对值分数有正影响；但样本仅 11 国。


## 四、生成的文件与文件夹结构

```
03_干净面板PPML/
├── R语言工程文件/
│   ├── 03_run_clean_panel_ppml.R    # 主分析脚本
│   └── 03_plot_clean_panel.R        # 绘图脚本
├── 检验结果CSV/
│   ├── ppml_final.csv
│   └── README.md
└── 图片/
    ├── fig03_clean_panel_ppml.png
    ├── 03_plot_clean_panel.R        # 图片对应脚本副本
    └── README.md
```

运行命令：

```bash
cd "03_干净面板PPML/R语言工程文件"
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 03_run_clean_panel_ppml.R
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 03_plot_clean_panel.R
```
