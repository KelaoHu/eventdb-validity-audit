# 02_方向分解

## 一、数据来源

本检验基于 01_基准传导_季度冲击 已经生成的 GDELT IRF 结果，不再重新读取原始经济和政治数据。

### 直接输入

- **文件位置**：`../01_基准传导_季度冲击/检验结果CSV/GDELT/irf_all.csv`
- **内容**：GDELT 数据库下，Aggregate / CHN→Partner / Partner→CHN 三个方向冲击对 Total / Exports / Imports 在 h=0..6 的 IRF 系数。

### 上游数据来源（间接）

- 经济面板：`../../data/panel_clean.csv`
- 政治分数：`../../../3.2 双边关系分析基于月度政治分数/全新事件研究法/data/gdelt_scores.csv`
- **未使用**：`自建事件库_25国_17类_713条事件.csv`


## 二、操作方式

### 步骤 1：读取 GDELT IRF 结果

从 `../01_基准传导_季度冲击/检验结果CSV/GDELT/irf_all.csv` 读取全部 IRF 系数。

### 步骤 2：提取方向性规格

根据 `spec` 列筛选：

- `-Export` 结尾：表示 `CHN → Partner` 方向冲击
- `-Import` 结尾：表示 `Partner → CHN` 方向冲击

生成新的 `direction` 列，并将 `trade` 重新标记为 Total / Exports / Imports。

### 步骤 3：生成 CSV 与绘图

1. 将方向分解后的系数表保存为 `directional_decomp.csv`。
2. 绘制分面图：横轴为滞后阶数 `h`，纵轴为系数 `Est`，按贸易流向（Total / Exports / Imports）分面，两条线分别代表两个政治冲击方向。
3. 添加 95% 置信区间（`Est ± 1.96 × SE`）。


## 三、运行结果

- 生成 `directional_decomp.csv`，共 42 行（2 个方向 × 3 个贸易变量 × 7 个滞后阶数）。
- 生成 `fig02_gdelt_directional_decomp.png`。

主要发现：

- 在 GDELT 数据里，中国对伙伴国发出的政治信号（CHN → Partner）和伙伴国对中国发出的政治信号（Partner → CHN）对贸易的影响方向基本一致。
- 整体呈现“关系好 → 贸易增加”的模式。
- 两个方向对出口、进口的差异化影响不明显。


## 四、生成的文件与文件夹结构

```
02_方向分解/
├── R语言工程文件/
│   ├── 02_generate_directional_csv.R    # 生成方向分解 CSV
│   └── 02_plot_directional_decomp.R     # 绘图脚本
├── 检验结果CSV/
│   ├── directional_decomp.csv
│   └── README.md
└── 图片/
    ├── fig02_gdelt_directional_decomp.png
    ├── 02_plot_directional_decomp.R     # 图片对应脚本副本
    └── README.md
```

运行命令：

```bash
cd "02_方向分解/R语言工程文件"
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 02_generate_directional_csv.R
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 02_plot_directional_decomp.R
```
