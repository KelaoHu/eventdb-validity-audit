# 01_基准传导_季度冲击

## 一、数据来源

本检验使用两类数据：

### 1. 经济面板数据

- **文件位置**：`../../data/panel_clean.csv`（即 `新PPMLHDFE/data/panel_clean.csv`）
- **内容**：包含中国与 25 个主要贸易伙伴的双边贸易数据、GDP、汇率、FTA 虚拟变量等
- **主要字段**：
  - `ISO` / `Country`：国家代码与名称
  - `month` / `YearMonth`：月度时间戳
  - `Trade_Exports`：中国对伙伴国出口额
  - `Trade_Imports`：中国从伙伴国进口额
  - `Trade_Total`：双边贸易总额
  - `ln_GDP`：伙伴国 GDP 对数
  - `ln_GDP_product`：中国与伙伴国 GDP 乘积的对数
  - `ln_ER`：汇率对数
  - `FTA_Dummy`：是否签订 FTA 的虚拟变量
- **数据来源说明**：`panel_clean.csv` 中的贸易额、GDP、汇率、FTA 等经济变量来源于项目 `3 实证结果/数据/经济数据库/` 下的 IMF 数据库、WTO RTA 数据等。该文件是已经清洗合并好的面板输入。

### 2. 政治关系分数

- **文件位置**：`../../../3.2 双边关系分析基于月度政治分数/全新事件研究法/data/`
- **四个数据库**：
  - `gdelt_scores.csv`：GDELT 全球事件数据库月度聚合分数
  - `icews_scores.csv`：ICEWS 国际事件数据库月度聚合分数
  - `phoenix_scores.csv`：Phoenix 人工编码事件数据库月度聚合分数
  - `tsinghua_scores.csv`：清华中外关系指数
- **重要说明**：本检验使用的是**连续的政治关系分数**，不是离散事件。这些分数由 GDELT/ICEWS/Phoenix/Tsinghua 原始事件数据或专家指数聚合而来，**不直接采用 `自建事件库_25国_17类_713条事件.csv` 中的人工标注事件**。713 事件库主要用于事件研究法（event study）分析，已在本项目其他模块或已删除的 02–06 模块中使用。


## 二、操作方式

### 步骤 1：读取并合并数据

1. 读取 `panel_clean.csv`，整理国家、时间、贸易变量和控制变量。
2. 读取四个政治分数文件，统一为长格式：`Country` × `YearMonth` × `Index_Type` × `Index_Value`。
3. 将政治分数按国家、月份合并到经济面板上。

### 步骤 2：生成标准化分数与冲击

1. 对每个国家-数据库组合的政治分数做 z-score 标准化，得到 `PolZ_Agg`、`PolZ_CHN_Partner`、`PolZ_Partner_CHN`。
2. 对 Tsinghua 指数进行一阶差分处理（因为原序列接近单位根），再标准化。
3. 对每个国家的标准化分数拟合 AR(1) 模型，提取残差作为“意外冲击”：
   - `u_Agg`：Aggregate 方向的意外冲击
   - `u_CHN_Partner`：中国 → 伙伴国方向的意外冲击
   - `u_Partner_CHN`：伙伴国 → 中国方向的意外冲击

### 步骤 3：运行 PPML 局部投影 IRF

对每个数据库（GDELT / ICEWS / Phoenix / Tsinghua）、每种贸易变量（Total / Exports / Imports）、每个冲击方向（Total / Export / Import），在每个滞后阶数 `h = 0, 1, ..., 6` 上分别估计：

```
Trade_{t+h} = β_h * Shock_t + γ * Controls_t + FE_ISO + FE_YearMonth + ε_t
```

- 估计方法：`fixest::fepois`（PPML）
- 固定效应：国家（ISO）+ 年月（YearMonth）
- 聚类标准误：国家层面
- 控制变量：`ln_GDP_product`、`ln_ER`、`FTA_Dummy`

### 步骤 4：保存结果

将每个数据库的 IRF 系数保存为 `irf_all.csv`，并生成 scaling 报告 `C_scaling.csv` 供 07 使用。


## 三、运行结果

运行成功后，每个数据库得到 63 行 IRF 结果（3 个贸易变量 × 3 个冲击方向 × 7 个滞后阶数）。

主要发现：

- **GDELT**：政治关系意外变好 → 贸易显著增加，效应在 0–6 个月都稳定存在，对出口、进口均显著。
- **ICEWS**：总体效应不显著，对出口有一些正向但不稳健的影响。
- **Phoenix**：总贸易不显著，出口方向偏负，进口方向偏正，信号较弱。
- **Tsinghua**：对出口有显著负影响（关系变差 → 出口下降），但样本仅 11 国，解释需谨慎。


## 四、生成的文件与文件夹结构

```
01_基准传导_季度冲击/
├── R语言工程文件/
│   ├── 01_run_irf.R              # 主分析脚本
│   └── 01_plot_irf_aggregate.R   # 绘图脚本
├── 检验结果CSV/
│   ├── GDELT/irf_all.csv
│   ├── ICEWS/irf_all.csv
│   ├── Phoenix/irf_all.csv
│   ├── Tsinghua/irf_all.csv
│   └── README.md
└── 图片/
    ├── fig01_irf_aggregate_four_databases.png
    ├── 01_plot_irf_aggregate.R   # 图片对应脚本副本
    └── README.md
```

运行命令：

```bash
cd "01_基准传导_季度冲击/R语言工程文件"
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 01_run_irf.R
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 01_plot_irf_aggregate.R
```
