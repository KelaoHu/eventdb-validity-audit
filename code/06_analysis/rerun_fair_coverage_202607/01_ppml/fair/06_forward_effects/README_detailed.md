# 06_前向效应

## 一、数据来源

### 1. 经济面板数据

- **文件位置**：`../../data/panel_clean.csv`
- **主要字段**：`ISO`、`Country`、`month`、`Trade_Total`、`Trade_Exports`、`Trade_Imports`、`ln_GDP_product`、`ln_ER`、`FTA_Dummy`
- **数据来源说明**：贸易额、GDP、汇率、FTA 等变量来源于 `3 实证结果/数据/经济数据库/`。

### 2. 政治关系分数

- **文件位置**：`../../../3.2 双边关系分析基于月度政治分数/全新事件研究法/data/gdelt_scores.csv`
- **重要说明**：本检验只使用 GDELT 的 Aggregate 分数，**不直接采用 `自建事件库_25国_17类_713条事件.csv`**。


## 二、操作方式

### 步骤 1：数据准备

1. 读取 `panel_clean.csv` 和 `gdelt_scores.csv`。
2. 合并为 GDELT 子样本。
3. 生成标准化分数和 AR(1) 残差 `u_Agg`。
4. 生成 `u_Agg` 的 1–6 期滞后变量（h = 1..6）。
5. 生成 `u_Agg` 的 1–3 期前导变量（h = -1, -2, -3）。

### 步骤 2：对每个 h 单独跑回归

为避免联合回归中的多重共线性，对每个 `h ∈ {-3, -2, -1, 0, 1, 2, 3, 4, 5, 6}` 单独估计：

```
Trade_Total_t = β_h * u_Agg_{t-h} + γ * Controls_t + FE_ISO + FE_YearMonth + ε_t
```

其中：

- h < 0：`u_Agg_{t-h}` 为未来冲击（lead）
- h = 0：`u_Agg_t` 为当期冲击
- h > 0：`u_Agg_{t-h}` 为过去冲击（lag）

### 步骤 3：保存与绘图

保存为 `D_forward.csv`，绘制领先滞后系数图，标注显著性。


## 三、运行结果

生成 `D_forward.csv`，共 10 行（h = -3 到 6）。

主要发现：

- 所有 h（包括 -3 到 6）的系数均为正，且多数显著。
- 这意味着 GDELT 的政治冲击与当前、过去、未来贸易都呈正相关。
- 可能解释：
  1. **反向因果**：贸易增长 → 政治关系改善。
  2. **共同趋势**：全球经济景气同时推动贸易和政治关系分数上升。
- 因此不能简单解释为“政治冲击导致贸易增加”。


## 四、生成的文件与文件夹结构

```
06_前向效应/
├── R语言工程文件/
│   ├── 06_run_forward_effects.R     # 主分析脚本
│   └── 06_plot_forward_effects.R    # 绘图脚本
├── 检验结果CSV/
│   ├── D_forward.csv
│   └── README.md
└── 图片/
    ├── fig06_forward_effects.png
    ├── 06_plot_forward_effects.R    # 图片对应脚本副本
    └── README.md
```

运行命令：

```bash
cd "06_前向效应/R语言工程文件"
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 06_run_forward_effects.R
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 06_plot_forward_effects.R
```
