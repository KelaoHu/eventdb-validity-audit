# 附录数据表 — 全部 CSV 文件清单

> 对应论文：311工程论文初稿_修订版_202607_v45 / 附录_v31
> 编号体系：S1–S12（与附录 v31 一致，按正文首提顺序编号）。所有 CSV 为 UTF-8 with BOM，首行为注释行。

## S3 黄金标准事件库的信度检验
| 文件 | 内容 |
|------|------|
| `Table_S3_Intercoder_reliability.csv` | 编码者间信度汇总（Cohen's Kappa = 0.866，n=100） |
| `Table_S3_Intercoder_detail.csv` | 100 条抽样事件双编码明细 |

## S4 民意数据溯源与补充检验
| 文件 | 内容 |
|------|------|
| `Table_S4_1_sources.csv` | S4-1 六项民调来源元数据表 |
| `Table_S4_2_pew_ckan.csv` | S4-2 Pew 波次 CKAN 资源 ID 清单 |
| `Table_S4_3_gallup_datawrapper.csv` | S4-3 Gallup Datawrapper 图表 ID 清单 |
| `Table_S4_4_coverage.csv` | S4-4 21 国民调覆盖摘要 |
| `Table_S4_5_case_enumeration.csv` | S4-5 E5 个案枚举表（31 个稀疏类别事件，19 个负面预期个案有前后对照） |
| `Table_S4_6_robustness.csv` | S4-6 稳健性检验对照表（5 条件 × 7 检验） |
| `Table_S4_7_convergence.csv` | S4-7 四库-民意连续分数会聚度（对应正文表 4） |
| `Table_S4_8_events.csv` | S4-8 事件-民意年度共现（对应正文表 4） |

## S5 一致性测度、方向一致率口径与缺失值规则
| 文件 | 内容 |
|------|------|
| `Table_S5_Country_correlations.csv` | 逐国配对相关系数矩阵（汇总） |
| `Table_S5b_country_pair_correlations.csv` | 逐国 × 6 数据库配对 Pearson r / Spearman ρ（公平覆盖期公共窗口 2002-01 至 2019-03，Aggregated 口径） |

## S6 聚合算法的稳健性明细
| 文件 | 内容 |
|------|------|
| `Table_S6_1_Aggregation_shift.csv` | 偏移常数 +10.1~+15 稳健性 |
| `Table_S6_2_Aggregation_form.csv` | 四种替代聚合形式相关 |
| `Table_S6_3_PPML_sensitivity.csv` | 聚合选择的 PPML 灵敏度 |

## S7 命中率窗口与远程通话混淆核查
| 文件 | 内容 |
|------|------|
| `Table_S7_Hitrate_by_category.csv` | 16 类事件 × 四库 × 三窗口命中率 |
| `Table_S7_1R_Hitrate_comparison.csv` | 命中率对照口径表（全样本/公共窗口/fair 记录层） |
| `Table_S7_Remote_talk.csv` | 18 条远程通话事件混淆核查 |

## S9 制裁事件进口方向可观察性检验
| 文件 | 内容 |
|------|------|
| `Table_S9a_Sanction_events.csv` | 22 个对华制裁/科技管制事件清单 |
| `Table_S9b_Sanction_direction.csv` | 方向分布与二项检验 |

## S10 完整 PPML 回归结果
| 文件 | 内容 |
|------|------|
| `Table_S10_Baseline_PPML_coefficients.csv` | S10-1 基线模型完整系数表 |
| `Table_S10a_LP_GDELT.csv` / `Table_S10b_LP_ICEWS.csv` / `Table_S10c_LP_Phoenix.csv` / `Table_S10d_LP_Tsinghua.csv` | S10-2a–d 四库 LP 估计汇总 |
| `Table_S10_Robustness_checks.csv` | S10-3 稳健性检验 |
| `Table_S10_Placebo_tests.csv` | S10-4 安慰剂检验 |

## 2026-08-05 修复与重编号记录
1. **全面重编号（附录 v30→v31）**：CSV 文件名随附录节号按正文首提顺序重编（旧 S1→S3、S2→S6、S3→S5、S4→S7、S6→S9、S7→S10、S8→S4），文件内容除内嵌注释行外不变；内嵌 "# Table" 注释行同步更新为新编号。
2. **Table_S7_1R fair 行**：含 4 行 "Fair coverage (record-level)"（Overall × 四库 × 三窗口），数据来自公平覆盖期重跑 `hit_rate_main.csv`；记录层分母 GDELT 278 / ICEWS 236 / Phoenix 166 / Tsinghua 142（对应去重事件 275/233/163/142），表末注释行已标明。
3. **Table_S5b**（27 个 CSV 之一）：25 国 × 6 配对逐国 Pearson r 与 Spearman ρ（公平覆盖期，Aggregated，公共窗口 2002-01 至 2019-03）。闸门复核：GDELT–ICEWS Japan Spearman=0.633、Brazil=0.031 均复现。
4. **Table_S10a–d 内嵌注**：shock 定义为基准 LP 设定（系数与 `S4_02_lp_estimates.csv` 全部 252 格逐值一致）；星号图例 ***p<0.01, **p<0.05, *p<0.10；标准误国家层面聚类。
5. S8 节旧描述"34 个负面事件"已更正为 E5 口径（31 个稀疏类别事件 / 19 个负面预期个案）。

详细溯源文档见 `07_数据库与民调/民调数据源与引用完整文件.md` 与 `中国与各国互相好感度_来路说明辅助.md`。
