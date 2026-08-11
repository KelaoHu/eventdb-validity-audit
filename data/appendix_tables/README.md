# 附录数据表 — 全部 CSV 文件清单

> 对应论文：311工程论文_EN_v5 / 附录_EN_v2（中文版_v49 / 附录_v32）
> 编号体系：S1–S12（与附录_EN_v2 一致，严格按正文首提顺序编号；2026-08-09 由 v31 体系重排）。
> 所有 CSV 为 UTF-8 with BOM，首行为注释行。

## 正文表底稿
| 文件 | 内容 |
|------|------|
| `Table_1_hit_rates.csv` | 正文 Table 1：四库黄金标准命中率（严格/公共/放宽三窗口） |
| `Table_3_trade_path.csv` | 正文 Table 3：Case 1 贸易路径结果汇总（LP/PPML/赛马/信号梯度） |
| `Table_4_opinion_path.csv` | 正文 Table 4：Case 2 民调路径结果汇总（Pew 17 国 × 13 波，N=170） |

## S4 从正文移入的表
| 文件 | 内容 |
|------|------|
| `Table_S4_1_sources_coverage.csv` | S4-1 四库来源与覆盖（GDELT 8,946,603 事件等） |
| `Table_S4_2_master_ledger.csv` | S4-2 四假说→证据→结论总账（fair 口径） |
| `Table_2_robustness_map.csv` | 正文 Table 2：GDELT 贸易效应稳健性地图 |

## S5 黄金标准事件库的信度检验
| 文件 | 内容 |
|------|------|
| `Table_S5_Intercoder_reliability.csv` | 编码者间信度汇总（Cohen's Kappa = 0.866，n=100） |
| `Table_S5_Intercoder_detail.csv` | 100 条抽样事件双编码明细 |

## S6 民意数据溯源与补充检验
| 文件 | 内容 |
|------|------|
| `Table_S6_1_sources.csv` | S6-1 六项民调来源元数据表 |
| `Table_S6_2_pew_ckan.csv` | S6-2 Pew 波次 CKAN 资源 ID 清单 |
| `Table_S6_3_gallup_datawrapper.csv` | S6-3 Gallup Datawrapper 图表 ID 清单 |
| `Table_S6_4_coverage.csv` | S6-4 21 国民调覆盖摘要 |
| `Table_S6_5_case_enumeration.csv` | S6-5 E5 个案枚举表（31 个稀疏类别事件，19 个负面预期个案有前后对照） |
| `Table_S6_6_robustness.csv` | S6-6 稳健性检验对照表（5 条件 × 7 检验） |
| `Table_S6_7_convergence.csv` | S6-7 四库-民意连续分数会聚度（对应正文 Table 4） |
| `Table_S6_8_events.csv` | S6-8 事件-民意年度共现（对应正文 Table 4） |

## S7 一致性测度、方向一致率口径与缺失值规则
| 文件 | 内容 |
|------|------|
| `Table_S7_Country_correlations.csv` | 逐国配对相关系数矩阵（汇总） |
| `Table_S7b_country_pair_correlations.csv` | 逐国 × 6 数据库配对 Pearson r / Spearman ρ（公平覆盖期公共窗口 2002-01 至 2019-03，Aggregated 口径） |

## S8 聚合算法的稳健性明细
| 文件 | 内容 |
|------|------|
| `Table_S8_1_Aggregation_shift.csv` | 偏移常数 +10.1~+15 稳健性 |
| `Table_S8_2_Aggregation_form.csv` | 四种替代聚合形式相关 |
| `Table_S8_3_PPML_sensitivity.csv` | 聚合选择的 PPML 灵敏度 |

## S9 命中率窗口与远程通话混淆核查
| 文件 | 内容 |
|------|------|
| `Table_S9_Hitrate_by_category.csv` | 16 类事件 × 四库 × 三窗口命中率 |
| `Table_S9_1R_Hitrate_comparison.csv` | 命中率对照口径表（全样本/公共窗口/fair 记录层） |
| `Table_S9_Remote_talk.csv` | 18 条远程通话事件混淆核查 |

## S11 完整 PPML 回归结果
| 文件 | 内容 |
|------|------|
| `Table_S11_Baseline_PPML_coefficients.csv` | S11-1 基线模型完整系数表 |
| `Table_S11a_LP_GDELT.csv` / `Table_S11b_LP_ICEWS.csv` / `Table_S11c_LP_Phoenix.csv` / `Table_S11d_LP_Tsinghua.csv` | S11-2a–d 四库 LP 估计汇总 |
| `Table_S11_Robustness_checks.csv` | S11-3 稳健性检验 |
| `Table_S11_Placebo_tests.csv` | S11-4 安慰剂检验 |

## S12 制裁事件进口方向可观察性检验
| 文件 | 内容 |
|------|------|
| `Table_S12a_Sanction_events.csv` | S12-1：22 个对华制裁/科技管制事件清单 |
| `Table_S12b_Sanction_direction.csv` | S12-2：方向分布与二项检验 |

## 重编号记录（2026-08-09，附录 v31→v32 / EN_v1→EN_v2）
1. **全面重编号**：按正文首提顺序（S1→S12 单调），旧→新：S11→S3、S12→S4、S3→S5、S4→S6、S5→S7、S6→S8、S7→S9、S8→S10、S10→S11、S9→S12（S1/S2 不变）；CSV 文件名与内嵌 "# Table" 注释行同步更新，数据内容不变。历史沿革：v30→v31（2026-08-05）曾重排一次。
2. **Table_S9_1R fair 行**：含 4 行 "Fair coverage (record-level)"（Overall × 四库 × 三窗口），数据来自公平覆盖期重跑 `hit_rate_main.csv`；记录层分母 GDELT 278 / ICEWS 236 / Phoenix 166 / Tsinghua 142（对应去重事件 275/233/163/142），表末注释行已标明。
3. **Table_S7b**：25 国 × 6 配对逐国 Pearson r 与 Spearman ρ（公平覆盖期，Aggregated，公共窗口 2002-01 至 2019-03）。闸门复核：GDELT–ICEWS Japan Spearman=0.633、Brazil=0.031 均复现。
4. **Table_S11a–d 内嵌注**：shock 定义为基准 LP 设定（系数与 `S4_02_lp_estimates.csv` 全部 252 格逐值一致）；星号图例 ***p<0.01, **p<0.05, *p<0.10；标准误国家层面聚类。
5. 安慰剂表内嵌注释旧编号残留（"# Table S7_Placebo"）已更正为 "# Table S11-4"。

详细溯源文档见 `docs/DATA_SOURCES.md`。
