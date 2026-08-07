# v8 数字替换包：ICEWS/Phoenix 公平覆盖期口径（选项 A 执行单）

**生成**：2026-07-27 · **数据源**：`17_ICEWS覆盖期审计/results/`（hitrate_fair_era.csv、hitrate_coop_conflict_fair_era.csv、ppml_icews_truncation_variants.csv、test3_wald_full_vs_trunc.csv、m5_visits_archived_full_vs_trunc.csv、test2_permutation_full_vs_trunc.csv）
**口径**：fair = 各库真实覆盖期（ICEWS 事件/样本 ≤2023-04；Phoenix ≤2019-03；GDELT/清华不变）。full 口径已逐条复制验证与 v7 存档一致。

## 需替换的正文数字（5 处）

| 段落 | v7 原文 | v8 新值 | 依据 |
|---|---|---|---|
| para 1（摘要） | 以黄金标准衡量，GDELT 命中率最高（68.3%） | 以黄金标准衡量、按各库真实覆盖期评估，GDELT 命中率最高（68.3%） | 加限定语；fair 排序 GDELT 仍居首 |
| para 76 | 四库命中率排序为：GDELT 68.3%、清华 62.7%、Phoenix 60.9%、ICEWS 56.5% | 按各库真实覆盖期评估（ICEWS 事件截至 2023-04、Phoenix 截至 2019-03，剔除填充段的机械不命中），四库命中率排序为：GDELT 68.3%、ICEWS 66.1%、Phoenix 65.1%、清华 62.7%；在 2002-01 至 2019-03 公共窗口内四库几乎持平（65.1%/65.1%/65.1%/64.5%） | hitrate_fair_era.csv：fair W_strict 156/236=66.1、108/166=65.1；public 108/166=65.1×3、60/93=64.5 |
| para 76 | 清华命中率升至 65.5%，GDELT 与 ICEWS 反而降至 62.6% 与 49.3% | 清华命中率升至 65.5%，GDELT 与 ICEWS 反而降至 62.6% 与 57.6% | fair W_2m：GDELT 62.59、ICEWS 57.63 |
| para 82 | ICEWS 对总贸易的 h=0 系数为 0.0021（p=0.781） | ICEWS 对总贸易的 h=0 系数为 0.0024（p=0.608，截断至 2023-04，n=6005） | ppml_icews_truncation_variants.csv 口径 C |
| para 82 | ICEWS 命中率最低、月度指数信噪比不足 | ICEWS 月度指数信噪比不足 | fair 口径 ICEWS 命中率 66.1% 居第二，"最低"不成立 |
| para 93 | 1,000 次事件时间置换 p=0.55/0.37，GDELT/ICEWS | 1,000 次事件时间置换 p=0.55/0.40，GDELT/ICEWS | test2_permutation：ICEWS trunc p_one=0.401（GDELT 全真保持 0.55） |
| para 94 | GDELT −0.428 vs +0.260；ICEWS −0.710 vs +0.252 | GDELT −0.428 vs +0.260；ICEWS −0.812 vs +0.309（截断口径） | test3_wald trunc：beta_neg −0.8117、beta_pos +0.3088 |
| para 94 | 对称性 Wald 检验在 ICEWS 上拒绝对称（p=0.019） | 对称性 Wald 检验在 ICEWS 上拒绝对称（p=0.025） | wald_p_sym 0.0252 |

## 已核对无需改动的段落（结论保持）

- **para 27**：覆盖声明本就声明"以截断为准"——v8 起该声明与实际一致，不改。
- **para 78**：合作/冲突比较优势（GDELT 67.5% 合作居首、清华 75.8% 冲突居首）——fair 口径 ICEWS 合作 62.1%、冲突 71.9%，正文未引 ICEWS 数字，排序结论保持。
- **para 92**：test1 GDELT −0.451（p=0.005）全真不受污染；"ICEWS 不复现"两口径一致（trunc 交互 −0.296，p=0.410）。
- **para 95/96**：M5 梯度"出访>来访>会晤>通话，ICEWS 下排序相同"——截断 ICEWS 出访 0.346>来访 0.316>会晤 0.192>通话 n.s.，排序保持（附录数字更新见下）。
- **para 97**："ICEWS…全部频率窗口下均不显著"——h=0..6 截断 p∈[0.52,0.99] 验证通过。
- **para 107/113**：叙事与局限声明保持。

## 附录 S3 及配套材料更新清单

| 材料 | 旧源 | 新源 |
|---|---|---|
| 附录 S3 命中率全表（4 库×3 窗口） | 09 模块 hit_rate_main.csv（full） | `hitrate_fair_era.csv` fair 行（含 n_hit/n_rows 分子分母与 Wilson CI；建议并列 full 与 public 列） |
| 附录 S3 合作/冲突分组表 | 04 模块 hitrate_cooperation_vs_conflict.csv（full） | `hitrate_coop_conflict_fair_era.csv` fair 行 |
| M5 附图/附表（4 类×2 库） | 05 模块 robustness/m5_robustness_category4.csv | `m5_visits_archived_full_vs_trunc.csv` trunc 行（ICEWS：0.346/0.316/0.192/0.518 n.s.，n=100/129/108/10） |
| M7/test3 附表 | 全期 | `test3_wald_full_vs_trunc.csv`、`m7_asymmetry_full_vs_trunc.csv` trunc 行 |
| PPML 附表 ICEWS 行 | β=0.0021 (0.781) n=6683 | β=0.0024 (0.608) n=6005（口径 C；口径 B 0.0012/0.795 可作稳健性脚注） |

## 图件影响

- **fig04 面板 a（M1 箱线阵）**：数据源 scores_v1（≤2019）——不受污染，无需重绘。
- **fig04 面板 b（PPML 点须）**：ICEWS 点须应改用截断口径 β=0.0024（CI 由 SE=0.0047 给出），并加脚注 "ICEWS truncated at 2023-04 (post-coverage months forward-filled)"。
- **fig05（M5 箱线+访问点须）**：ICEWS 点须改用 trunc 行。
- **fig03（效度/命中率）**：若含命中率排序，按 fair 口径重绘。

## 执行记录（2026-07-27）

- 正文 8 处替换已全部落入 `311工程论文_文稿合集\311工程论文初稿_修订版_202607_v8.docx`（v7 未动；脚本 `tmp\make_v8_icews.py`，逐段 before/after 日志 `tmp\make_v8_log.txt`）。
- 替换后全文复扫：旧数字（56.5%/49.3%/0.0021/命中率最低/0.55-0.37/−0.710/p=0.019）零残留。
- 待办：附录 S3 表重排（fair/public 并列）、fig04 面板 b 与 fig05 的 ICEWS 点须改截断口径（图件解冻后执行）。

## 第二批替换（补充扫描，2026-07-27 执行完毕）

- 触发：同类疏漏全面扫描（见 `审计报告补充_同类疏漏全扫描_202607.md`），发现 Phoenix 2019-04~12 填充窗同构污染。
- 追加 5 处替换：para 78 Phoenix M1 −1.98→−1.87；para 85 同方程 GDELT 进口 0.0127**/0.0212**→0.0108†/0.0162†（措辞降"边际显著"）、Phoenix 出口 −0.0080→−0.0055(p=0.010)、清华 p 范围 0.54~0.75→0.45~0.71；para 96 第五组证据 19.4%/33.5% 不可复现句 → 用户拍板改为可复现表述（3 库完全一致率：负面 50.0% vs 正面 34.3%，n=58/108，口径与定义已写入正文）。
- 执行：`tmp\make_v8_full.py` 从 v7 一键重新生成 v8（13/13 替换，旧数字零残留，日志 `tmp\make_v8_full_log.txt`）。
- 附录：`311工程论文_文稿合集\311工程论文_附录_v4.docx`（S3-1 改 fair 主表 12 行 + 新增 S3-1R 全期/公共窗口对照表 24 行，口径说明已补；验证闸门 full 24/24 复现 v3）。
