# 05_频率响应扫描

## 一、数据来源

### 1. 经济面板数据

- **文件位置**：`../../data/panel_clean.csv`
- **主要字段**：`ISO`、`Country`、`month`、`Trade_Total`、`Trade_Exports`、`Trade_Imports`、`ln_GDP_product`、`ln_ER`、`FTA_Dummy`
- **数据来源说明**：贸易额、GDP、汇率、FTA 等变量来源于 `3 实证结果/数据/经济数据库/`。

### 2. 政治关系分数

- **文件位置**：`../../../3.2 双边关系分析基于月度政治分数/全新事件研究法/data/`
- **四个数据库**：`gdelt_scores.csv`、`icews_scores.csv`、`phoenix_scores.csv`、`tsinghua_scores.csv`
- **重要说明**：本检验使用政治分数的 AR(1) 残差 `u_Agg` 的累计值，**不直接采用 `自建事件库_25国_17类_713条事件.csv`**。


## 二、操作方式

### 步骤 1：数据准备

1. 读取 `panel_clean.csv` 和四个政治分数文件。
2. 合并为 `panel_db`。
3. 生成标准化分数和 AR(1) 残差 `u_Agg`。
4. 为 `u_Agg` 生成最多 23 期滞后变量，以支持 k=24 的累计窗口。

### 步骤 2：构造累计冲击变量

对每个窗口长度 `k ∈ {1, 2, 3, 4, 6, 12, 24}`，构造累计冲击：

```
u_Agg_cum_k(t) = u_Agg(t) + u_Agg(t-1) + ... + u_Agg(t-k+1)
```

### 步骤 3：对每个 k 跑 PPML 回归

```
Trade_Total_t = β_k * u_Agg_cum_k(t) + γ * Controls_t + FE_ISO + FE_YearMonth + ε_t
```

对每个数据库、每个 k 单独估计。

### 步骤 4：保存与绘图

保存为 `B_freqscan.csv`，绘制“累计效应随窗口长度 k 变化”的折线图。


## 三、运行结果

生成 `B_freqscan.csv`，共 28 行（4 个数据库 × 7 个窗口长度）。

主要发现：

- **GDELT**：短期（k=1 到 k=6）有显著正影响，窗口拉长到 12、24 个月后效应逐渐衰减，但仍为正。
- **ICEWS、Phoenix、Tsinghua**：效应较弱，不显著或仅在个别窗口显著。


## 四、生成的文件与文件夹结构

```
05_频率响应扫描/
├── R语言工程文件/
│   ├── 05_run_freq_scan.R        # 主分析脚本
│   └── 05_plot_freq_scan.R       # 绘图脚本
├── 检验结果CSV/
│   ├── B_freqscan.csv
│   └── README.md
└── 图片/
    ├── fig05_freq_scan.png
    ├── 05_plot_freq_scan.R       # 图片对应脚本副本
    └── README.md
```

运行命令：

```bash
cd "05_频率响应扫描/R语言工程文件"
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 05_run_freq_scan.R
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 05_plot_freq_scan.R
```
