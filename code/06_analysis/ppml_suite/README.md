# 新 PPMLHDFE

本文件夹使用 **PPML-HDFE（泊松伪最大似然估计 + 高维固定效应）** 框架，
分析政治关系冲击对中国与 25 个主要贸易伙伴双边贸易流量的影响，
并包含连续分数 PPML 的一系列稳健性检验。

> **当前状态**：
> - `01_连续分数PPML/`：基于连续政治分数的 PPML-HDFE 分析（7 个子项目）。
> - `02_事件驱动PPMLHDFE/`：基于 713 条人工标注事件的 PPML-HDFE 分析（11 个子项目：00–10，含 00c 方向化制裁面板）。
> - 每个子文件夹统一包含 `R语言工程文件/`、`图片/`、`检验结果CSV/`，部分还包含 `skill.md`。


## 目录结构

```
新PPMLHDFE/
├── README.md
├── data/
│   └── panel_clean.csv                    # 干净面板数据
├── archive/
│   ├── old_code/                          # 旧版集中式 code/ 归档（仅日志）
│   └── old_results/                       # 旧版 03–06 结果 CSV 备份
├── 01_连续分数PPML/                       # 连续政治分数分析
│   ├── 00_utils.R                         # 公共数据准备函数
│   ├── 99_master.R                        # 一键运行 01 全部脚本
│   ├── 01_连续分数PPML_结果说明.txt       # 通俗版结果说明
│   ├── 01_连续分数PPML_完整性检查.txt     # 各子文件夹完整性检查
│   ├── 01_基准传导_季度冲击/
│   │   ├── R语言工程文件/
│   │   │   ├── 01_run_irf.R              # 生成 IRF 与 scaling
│   │   │   └── 01_plot_irf_aggregate.R   # 绘制四库 aggregate IRF
│   │   ├── 图片/
│   │   │   ├── fig01_irf_aggregate_four_databases.png
│   │   │   └── 01_plot_irf_aggregate.R   # 图片对应 R 脚本副本
│   │   └── 检验结果CSV/
│   │       ├── GDELT/irf_all.csv
│   │       ├── ICEWS/irf_all.csv
│   │       ├── Phoenix/irf_all.csv
│   │       └── Tsinghua/irf_all.csv
│   ├── 02_方向分解/
│   │   ├── R语言工程文件/
│   │   │   ├── 02_generate_directional_csv.R
│   │   │   └── 02_plot_directional_decomp.R
│   │   ├── 图片/
│   │   │   ├── fig02_gdelt_directional_decomp.png
│   │   │   └── 02_plot_directional_decomp.R
│   │   └── 检验结果CSV/
│   │       └── directional_decomp.csv
│   ├── 03_干净面板PPML/
│   │   ├── R语言工程文件/
│   │   │   ├── 03_run_clean_panel_ppml.R
│   │   │   └── 03_plot_clean_panel.R
│   │   ├── 图片/
│   │   │   ├── fig03_clean_panel_ppml.png
│   │   │   └── 03_plot_clean_panel.R
│   │   └── 检验结果CSV/
│   │       └── ppml_final.csv
│   ├── 04_AR1残差回归/
│   │   ├── R语言工程文件/
│   │   │   ├── 04_run_ar1_residual_ppml.R
│   │   │   └── 04_plot_ar1_residual.R
│   │   ├── 图片/
│   │   │   ├── fig04_ar1_residual.png
│   │   │   └── 04_plot_ar1_residual.R
│   │   └── 检验结果CSV/
│   │       └── A_AR1.csv
│   ├── 05_频率响应扫描/
│   │   ├── R语言工程文件/
│   │   │   ├── 05_run_freq_scan.R
│   │   │   └── 05_plot_freq_scan.R
│   │   ├── 图片/
│   │   │   ├── fig05_freq_scan.png
│   │   │   └── 05_plot_freq_scan.R
│   │   └── 检验结果CSV/
│   │       └── B_freqscan.csv
│   ├── 06_前向效应/
│   │   ├── R语言工程文件/
│   │   │   ├── 06_run_forward_effects.R
│   │   │   └── 06_plot_forward_effects.R
│   │   ├── 图片/
│   │   │   ├── fig06_forward_effects.png
│   │   │   └── 06_plot_forward_effects.R
│   │   └── 检验结果CSV/
│   │       └── D_forward.csv
│   └── 07_信噪比效应量标度律/
│       ├── R语言工程文件/
│       │   └── 03_plot_scaling.R
│       ├── 图片/
│       │   ├── fig03_ar1_rho_comparison.png
│       │   └── 03_plot_scaling.R
│       └── 检验结果CSV/
│           └── C_scaling.csv
├── 02_事件驱动PPMLHDFE/                   # 713 条事件分析
│   ├── 00_事件面板构建/
│   │   └── R语言工程文件/
│   │       ├── 00_build_event_panel.R
│   │       └── 00c_build_directional_sanctions.R   # 方向化制裁/科技管制变量
│   ├── 01_事件基准效应/
│   ├── 02_正负向非对称与4类访问效应/
│   ├── 03_17类事件异质性/
│   ├── 04_国家异质性/
│   ├── 05_事件动态IRF/
│   ├── 06_事件强度与四库验证/
│   ├── 07_稳健性与安慰剂/
│   ├── 08_汇总报告与可视化/
│   ├── 09_事件类型深度稳健性与动态分析/   # 含 09a–09e、09j–09o
│   ├── 10_国家敏感度差异检验/             # 含 10a–10e
│   ├── 00_utils.R
│   └── 99_master.R
```


## 01 连续分数 PPML 子项目

| 序号 | 检验项目 | 状态 |
|------|----------|------|
| 01 | 基准传导_季度冲击 | ✅ 完整 |
| 02 | 方向分解 | ✅ 完整 |
| 03 | 干净面板PPML | ✅ 完整 |
| 04 | AR1 残差回归 | ✅ 完整 |
| 05 | 频率响应扫描 | ✅ 完整 |
| 06 | 前向效应 | ✅ 完整 |
| 07 | 信噪比效应量标度律 | ✅ 基本完整 |

## 02 事件驱动 PPMLHDFE 子项目

| 序号 | 检验项目 | 状态 |
|------|----------|------|
| 00 | 事件面板构建 | ✅ 完整 |
| 01 | 事件基准效应 | ✅ 完整 |
| 02 | 正负向非对称与 4 类访问效应 | ✅ 完整 |
| 03 | 17 类事件异质性 | ✅ 完整 |
| 04 | 国家异质性 | ✅ 完整 |
| 05 | 事件动态 IRF | ✅ 完整 |
| 06 | 事件强度与四库验证 | ✅ 完整 |
| 07 | 稳健性与安慰剂 | ✅ 完整 |
| 08 | 汇总报告与可视化 | ✅ 完整 |
| 09 | 事件类型深度稳健性与动态分析（含方向化制裁 09j–09o） | ✅ 完整 |
| 10 | 国家敏感度差异检验（10a–10e） | ✅ 完整 |


## 快速复现

### 运行 02 事件驱动 PPMLHDFE 全部脚本

```bash
cd "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.3 政治经济组合分析PPMLHDFE/新PPMLHDFE/02_事件驱动PPMLHDFE"
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 99_master.R
```

### 运行 01 连续分数 PPML 全部脚本

```bash
cd "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.3 政治经济组合分析PPMLHDFE/新PPMLHDFE/01_连续分数PPML"
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 99_master.R
```

### 单独运行某个子检验

```bash
cd "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.3 政治经济组合分析PPMLHDFE/新PPMLHDFE/01_连续分数PPML/01_基准传导_季度冲击/R语言工程文件"
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 01_run_irf.R
"C:/Program Files/R/R-4.6.1/bin/Rscript.exe" 01_plot_irf_aggregate.R
```


## 文件夹命名规范

每个检验统一采用：

- `R语言工程文件/` —— 该检验专用的 R 脚本
- `图片/` —— 该检验生成的图表，并附带生成图片的 R 脚本副本
- `检验结果CSV/` —— 该检验输出的结果表格


## 数据说明

- `data/panel_clean.csv`：干净面板，包含 `ISO`、`Country`、`month`、`Trade_Exports`、`Trade_Imports`、`Trade_Total`、`ln_GDP_product`、`ln_ER`、`FTA_Dummy`。
- 政治分数来源：`../../3.2 双边关系分析基于月度政治分数/全新事件研究法/data/{gdelt_scores.csv, icews_scores.csv, phoenix_scores.csv, tsinghua_scores.csv}`
- 事件库来源：`../../3.2 双边关系分析基于月度政治分数/自建事件库_25国_17类_713条事件.csv`（仅用于 `02_事件驱动PPMLHDFE/`）


## 依赖

- R ≥ 4.5
- R 包：`fixest`、`data.table`、`dplyr`、`readr`、`tidyr`、`ggplot2`


## 已知问题

1. **Tsinghua 使用一阶差分处理单位根**：由于清华指数是专家平滑序列，本版本对 Tsinghua 使用 `ΔScore` 代替水平值，`C_scaling.csv` 中 Tsinghua 的 `rho ≈ 0.21`。
2. **01_run_irf.R 的 normalizePath 警告**：使用 `source(..., chdir = TRUE)` 时会出现 `--file=99_master.R 系统找不到指定的文件` 的警告，不影响结果输出。
3. **新版结果与旧版备份不完全一致**：03–06 的生成脚本已重新编写，旧版结果备份在 `archive/old_results/` 中，新版结果在数值上可能与旧版有差异。
4. **事件驱动分析的解读需注意**：01 事件基准效应中，正/负/中性事件在加总层面均不显著，说明离散事件 dummy 难以捕捉平均贸易效应；显著结果更多出现在 4 类访问、17 类异质性和国家异质性层面，需在论文中综合讨论。17 类中的“经贸互利合作”出现负系数，可能与事件同期性、领导人访问伴随的协议滞后兑现或控制变量吸收有关，建议结合 IRF 与稳健性检验进一步分析。
5. **方向化制裁/科技管制**：在 `02_事件驱动PPMLHDFE/09_事件类型深度稳健性与动态分析/` 中，对华科技管制与经贸制裁在控制 `Event_Negative` 后显著推高中国从伙伴国的进口（约 +23%），1000 次安慰剂检验 p 值分别为 0.005 与 0.004；排除美国、伊朗、疫情期及双向聚类后结论保持稳健。
6. **国家敏感度差异检验（10a–10e）**：结构性特征（FTA、发展水平、贸易依存度）对事件—贸易关系存在调节作用，但标签置换安慰剂显示多数交互项不能显著超出随机范围；事件驱动敏感度与 GDELT/ICEWS/Phoenix 政治分数波动率亦无显著相关，仅 Tsinghua 进口维度边缘显著（ρ = −0.58，p = 0.066）。论文中应避免“国家 A 比国家 B 更敏感”的绝对排名表述，改为讨论结构性调节。

## 详细说明与 Skill

每个子项目都有独立的详细说明文档：

- `01_连续分数PPML/01_基准传导_季度冲击/README_detailed.md`
- `01_连续分数PPML/02_方向分解/README_detailed.md`
- `01_连续分数PPML/03_干净面板PPML/README_detailed.md`
- `01_连续分数PPML/04_AR1残差回归/README_detailed.md`
- `01_连续分数PPML/05_频率响应扫描/README_detailed.md`
- `01_连续分数PPML/06_前向效应/README_detailed.md`
- `01_连续分数PPML/07_信噪比效应量标度律/README_detailed.md`

整体方法论 Skill：

- `01_连续分数PPML/PPMLHDFE_连续分数分析_skill.md`
- `02_事件驱动PPMLHDFE/` 下各子项目的 `skill.md`

数据使用的重要说明：

- 经济变量来源于 `data/panel_clean.csv`，其上游为 `3 实证结果/数据/经济数据库/`。
- 政治分数来源于 `3.2 双边关系分析基于月度政治分数/全新事件研究法/data/` 下的 GDELT/ICEWS/Phoenix/Tsinghua 分数文件。
- **`01_连续分数PPML` 不直接采用 `自建事件库_25国_17类_713条事件.csv`**；该事件库用于 `02_事件驱动PPMLHDFE/` 以及 `3.2 双边关系分析基于月度政治分数/` 下的事件研究法。
