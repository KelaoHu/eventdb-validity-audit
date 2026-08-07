# 全新事件研究法

本文件夹系统分析 712 条自建双边事件对月度政治分数的冲击效应（2026-07-28 起；剔除 1 条 2001-10 日本越界事件，原 713），涵盖 9 个主题模块，对应论文/报告的 8 张主图与 1 个四库命中率测试。

## 目录结构

```
全新事件研究法/
├── README.md
├── data/                              # 共享输入数据
│   ├── events_712.csv                 # 712 条自建事件（25 国、17 类，2002-01 起），现行版本
│   ├── events_713.csv                 # 旧版存档（含 1 条 2001-10 越界事件，勿用于新分析）
│   ├── gdelt_scores.csv               # GDELT 月度分数（25 国，2002–2025）
│   ├── icews_scores.csv               # ICEWS 月度分数（25 国，2002–2025）
│   ├── phoenix_scores.csv             # Phoenix 月度分数（25 国，2002–2019）
│   ├── tsinghua_scores.csv            # 清华月度分数（大国，1950–2025.08）
│   ├── scores_v1_4DB_2019.csv         # 4 库标准化面板（12 国，2002–2019）
│   ├── scores_v2_3DB_2025.csv         # 3 库标准化面板（12 国，2002–2025/8）
│   ├── scores_v3_GDELT_ICEWS_2025.csv # 2 库标准化面板（25 国，2002–2025）
│   ├── leaders.csv                    # 各国领导人任期
│   └── us_china_nodes.csv             # 中美关系关键节点
├── figures/                           # 8 张汇总可视化（m1–m8）
├── 01_单个国家内不同类型事件的反映/
│   ├── code/generate.R
│   ├── README.txt
│   ├── results/
│   └── robustness/
├── 02_国家层面双边关系结构性断点分析/
├── 03_联盟政治与美国盟友对华反应同质性/
├── 04_领导人换届效应与双边关系波动/
├── 05_领导人会晤效应与双边关系/
├── 06_相同类型的事件在不同国家的反应/
├── 07_政治信任非对称性/
├── 08_中美竞争第三方效应与体系结构变迁/
└── 09_四库事件命中率测试/
    ├── code/generate.R
    ├── figures/                       # 6 张命中率测试图
    ├── results/
    └── 四库命中率测试报告.txt
```

## 模块说明

| 模块 | 脚本入口 | 研究问题 | 对应图 |
|------|----------|----------|--------|
| 01 单个国家内不同类型事件的反映 | `01_.../code/generate.R` | 非领导人访问事件对分数的短期冲击 | `figures/m1_irf_top6.png` |
| 02 国家层面双边关系结构性断点分析 | `02_.../code/generate.R` | 滚动波动率识别高波动断点 | `figures/m2_breakpoints.png` |
| 03 联盟政治与美国盟友对华反应同质性 | `03_.../code/generate.R` | 美国盟友 vs 非盟友对华事件反应 | `figures/m3_alliance_irf.png` |
| 04 领导人换届效应与双边关系波动 | `04_.../code/generate.R` | 换届次数与分数波动率相关性 | `figures/m4_turnover_volatility.png` |
| 05 领导人会晤效应与双边关系 | `05_.../code/generate.R` | 4 类领导人互动（出访/来访/第三方/远程）对分数的即时与滞后冲击 | `robustness/m5_robustness_category4.png` |
| 06 相同类型的事件在不同国家的反应 | `06_.../code/generate.R` | 按事件类别聚合跨国冲击 | `figures/m6_forest.png` |
| 07 政治信任非对称性 | `07_.../code/generate.R` | 积极 vs 消极事件冲击幅度不对称 | `figures/m7_asymmetry_irf.png` |
| 08 中美竞争第三方效应与体系结构变迁 | `08_.../code/generate.R` | 中美关系节点对第三国溢出效应 | `figures/m8_node_spillover.png`、`m8_spillover_heatmap.png` |
| 09 四库事件命中率测试 | `09_.../code/generate.R` | 四库对 278 条非访问事件的命中率 | `09_.../figures/*.png` |

## 快速复现

### 1. 单独运行某个模块

```bash
cd "01_单个国家内不同类型事件的反映/code"
Rscript generate.R
```

### 2. 批量运行全部 9 个模块

可在本目录下新建一个 `run_all.R` 或 shell 脚本循环调用：

```bash
for d in 0*/code; do
  (cd "$d" && Rscript generate.R)
done
```

## 数据说明

- 共享数据已统一放在 `data/`。
- 各模块 `code/generate.R` 中通过 `SD <- "../../data"` 引用。
- 三个标准化面板：
  - `scores_v1_4DB_2019.csv`：4 库、12 国、2002–2019
  - `scores_v2_3DB_2025.csv`：3 库、12 国、2002–2025/8
  - `scores_v3_GDELT_ICEWS_2025.csv`：GDELT+ICEWS、25 国、2002–2025

## 已知问题

1. **图表不可由当前脚本直接复现**：01–08 的 `generate.R` 只生成 `results/*.csv`，不生成 `figures/` 中的汇总图与 `robustness/` 中的稳健性文件。
2. **旧版文件已归档**：原 `results/` 中的旧版 `mX_*.csv` 已移至 `archive/old_mx_results/`，当前 `results/` 只保留新版输出。
3. **模块间分数版本不一致**：01 同时用 v1/v2/v3；02–08 只用 v3；09 直接读 4 个原始分数文件。
4. **部分脚本中文注释乱码**：03、04、07、08 的 `generate.R` 首行中文注释显示为乱码，不影响逻辑。
5. **09 报告占位符**：`四库命中率测试报告.txt` 中 McNemar 检验段落仍有 `b 个事件 / c 个事件` 占位符未填。

## 主要结论

- **四库命中率（严格窗口）**：GDELT 68% > Tsinghua 63% > Phoenix 60% > ICEWS 56%。
- **联盟效应**：美国盟友对华事件的平均冲击为负（约 -0.41），非盟友接近 0。
- **政治信任非对称**：消极事件引起的分数下降幅度普遍大于积极事件的上升幅度。
- **第三方效应**：中美关系负面节点对第三国产生平均约 -0.047 的溢出效应。
