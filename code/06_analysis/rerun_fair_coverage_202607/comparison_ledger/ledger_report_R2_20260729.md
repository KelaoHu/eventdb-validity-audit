# R2 对比总账报告（archive / full 复现 / fair 公平覆盖期）

生成时间：2026-07-29 ｜ 工作区：`311工程\3 实证结果\重跑_公平覆盖期_202607\`
口径定义：**archive**=模块现存结果 CSV；**full**=镜像脚本+原 data 复现；**fair**=镜像脚本+data_fair（ICEWS≤2023-04、Phoenix≤2019-03 截断，z-score 截断段内重算=口径 C）。
G1 闸门：full 与 archive 逐格一致（容差 1e-6）方可把 fair-full 差异归因于截断。

---

## 一、G1 闸门总表（23 个结果文件）

### PASS（13 个，full≡archive，fair 差异=纯截断效应）
| 模块 | 文件 | fair 差异格数 |
|---|---|---|
| PPML 01 基准传导 | irf_all.csv ×4 库 | ICEWS/Phoenix 全变，GDELT/清华 0 变 ✓ |
| PPML 02 方向分解 | directional_decomp.csv | 0（GDELT-only ✓） |
| PPML 03 干净面板 | ppml_final.csv | 144/240 |
| PPML 04 AR1 | A_AR1.csv | 24/40 |
| PPML 05 频率扫描 | B_freqscan.csv | 56/140 |
| PPML 06 前向效应 | D_forward.csv | 0（GDELT-only ✓） |
| ES 09 命中率 | hit_rate_main.csv | 24/48（ICEWS/Phoenix 变） |
| REV 01 同方程 | cross_db_same_equation.csv | 105/105 |
| REV 11 M1 | m1_irf_significance.csv | 21/64 |
| REV 16 test1 | lp_interaction + perm_summary | GDELT 行 0 变 ✓，ICEWS 行变 |
| REV 16 test2 | partA + partB + perm_summary | GDELT 行 0 变 ✓，ICEWS 行变 |
| REV 16 test3 | wald_symmetry + joint_pos | GDELT 行 0 变 ✓，ICEWS 行变 |
| REV 04 合作冲突 | hitrate_cooperation_vs_conflict.csv | 156/360 |

### DIFF（10 个，full≠archive → 版本漂移，与本次截断无关）
| 模块 | 漂移规模 | 归因 |
|---|---|---|
| ES 01 单国多类型 | 2681 格 | 事件库/代码 2026-07-28 修订（events_713→712） |
| ES 02 断点 | 93 格+行数 45→32 | 模块代码 07-23 晚于存档结果（代码已改版） |
| ES 03 联盟 M3 | 517 格 | 同上 07-28 修订 |
| ES 04 换届 corr | 2 格（ICEWS r 0.050→−0.111） | 同上 |
| ES 05 会晤 M5 | 40 格（如 GDELT outbound 0.335→0.399） | 同上；模块 07-22 已重构（6类→4类，旧结果在 archive/ 子目录） |
| ES 06 跨国同类 | 517 格 | 07-28 修订 |
| ES 07 信任 M7 | 4 格（均值第2位小数级） | 07-28 修订 |
| ES 08 第三方 M8 | 648 格（ICEWS shock 系统性约×2） | 08 代码 07-23 晚于存档结果 07-19 |
| REV 03 换届重估 | 4 格（ICEWS vol_range12m r −0.0016→0.0012，p .994→.995） | scores_v3 07-18 重生成尾差；结论不变 |

**漂移根因（已取证）**：① `events_712.csv` mtime=2026-07-28 18:21，晚于全部存档结果——07-28 事件库 curation（713→712）+ 01/05/07 模块代码同日修订；② 08/02 模块代码 mtime=07-23 晚于其存档结果（07-19）——存档由旧版代码产出；③ 分数数据文件（icews/gdelt/tsinghua_scores.csv、scores_v1/v2/v3）mtime 均早于存档结果且内容未变。**镜像代码与现行原始代码逐行一致（仅数据路径补丁）**。结论：G1 DIFF 全部是**先已存在的事件库/代码版本漂移**，与公平覆盖期截断无关；fair-vs-full 使用同代码同事件库，其差异可干净归因于截断。

---

## 二、正文关键数字三列对照（arc / full / fair）

### 1. 命中率 W_strict（v8 已采用 fair 口径 ✓ 与重跑一致）
| 库 | arc=full | fair |
|---|---|---|
| GDELT | 68.3% (190/275) | 68.3% 不变 |
| ICEWS | 56.5% (157/275) | **66.1%** (156/233) |
| Phoenix | 60.9% (109/176) | **65.1%** (108/163) |
| 清华 | 62.7% (89/142) | 62.7% 不变 |

### 2. PPML 基准传导 h=0（G1 PASS）
| 规格 | arc=full | fair | 备注 |
|---|---|---|---|
| ICEWS IW-Total 总额 | 0.00213 (p=.781, n=6683) | 0.00241 (p=.608, n=6005) | 与 v8 现值一致 ✓ |
| Phoenix PH-Total 总额 | −0.00196 (p=.553) | −0.00056 (p=.794, n=4767) | 与 v8 一致 ✓ |
| **ICEWS IW-Import 出口** | 0.00638 (p=.107) | **0.00737 (p=.020\*)** | ⚠️ fair 新浮现显著 |
| **Phoenix PH-Export 进口** | 0.00613 (p=.343) | **0.00926 (p=.047\*)** | ⚠️ fair 新浮现显著 |
| GDELT 全部规格 | 0.01274 (p=.026) 等 | 完全不变 ✓ | |

### 3. 同方程交叉验证（G1 PASS）⚠️ 与审计期快算值差异大
| 规格 | arc=full | fair 重跑 | v8 现引用（审计期快算） |
|---|---|---|---|
| A 总量 GDELT | 0.0061 (p=.059*) | 0.0048 (p=.110, n.s.) | — |
| A 进口 GDELT | 0.0127 (p=.012**) | **0.0113 (p=.014**)** | 0.0108 (p=.062†) |
| B 总量 GDELT | 0.0108 (p=.020**) | 0.0080 (p=.063*) | — |
| B 进口 GDELT | 0.0212 (p=.0036***) | **0.0174 (p=.008***)** | 0.0162 (p=.066†) |
| B 出口 Phoenix | −0.0080 (p=.004***) | −0.0062 (p=.005***) 保持 | −0.0055 (p=.010*) |
| A 出口 Phoenix | −0.0040 (p=.177) | **−0.0044 (p=.088*)** | ⚠️ 新浮现边际显著 |

差异原因：审计期快算=截断样本重估但沿用全样本 z-score；canonical fair=截断段内重算 z-score（口径 C）。**fair 重跑下 GDELT 进口系数显著性不降反稳（**/***）**，审计期"降为边际显著"的叙述需重写。

### 4. M1 显著性（G1 PASS）
| 项 | arc=full | fair |
|---|---|---|
| Phoenix neg h=0 | −1.979 (p_tt=7e-6, n=41) | **−1.870** (p_tt=4e-5, n=37) 与 v8 一致 ✓ |
| Phoenix neg h=6 | −0.553 (p_boot=.020) | −0.505 (p_boot=.056) ⚠️ 失去 boot 显著 |
| Phoenix pos h=0 | 0.305 (p_boot=.192) | **0.425 (p_boot=.036\*)** ⚠️ 新浮现显著 |
| GDELT/ICEWS/清华各行 | — | 基本不变（分母 58/41 不变） |

### 5. M7 信任非对称 + test3 Wald（G1 PASS）
| 项 | arc=full | fair | v8 现引用 |
|---|---|---|---|
| ICEWS change h=0 | pos .252 / neg −.710 / Wald p=.019 | pos **.309** / neg **−.812** / Wald p=**.025** | −0.812/+0.309/0.025 ✓ 一致 |
| ICEWS level h=0 | pos .418 / neg −1.036 / p=1.6e-4 | pos .461 / neg −1.137 / p=4.3e-5 | — |

### 6. test2 第三方溢出（G1 PASS）
| 项 | arc=full | fair |
|---|---|---|
| ICEWS partA diff_p | .119 | .157 |
| ICEWS perm p（1000 次） | .731 | .704 |
| GDELT 全部 | — | 不变 ✓ |

### 7. M5 会晤（G1 DIFF=版本漂移）
| 项 | archive | full 复现 | fair |
|---|---|---|---|
| GDELT outbound | 0.335 | 0.399 | 0.399 不变 |
| GDELT inbound | 0.307 | 0.369 | 0.369 不变 |
| ICEWS outbound | 0.286 | 0.415 | 0.502 (n=100) |
| ICEWS inbound | 0.258 | 0.375 | 0.459 (n=129) |
| ICEWS third-party | 0.155 | 0.187 | 0.233 (n=108) |
⚠️ v8 现引用值=archive 列（0.335 等），现行管线已不复现该值；fair 列与审计期快算（0.316）亦不同。

### 8. 换届波动率（REV_03，G1 微差但结论不变）
ICEWS vol_sd12m：r=+0.050 (p=.812) → fair r=+0.074 (p=.726)，原假设保持 ✓

### 9. ES_06 跨国同类（G1 DIFF）：full "80 rows, 2 significant" → fair "80 rows, 5 significant"（显著数变化，正文如引用需复核）

---

## 三、待用户拍板事项

- **D1 采信基线**：v8/附录数字统一改用 canonical 重跑值（full=原口径现行管线、fair=公平覆盖期），archive 列仅作漂移备查。G1-DIFF 模块（ES 01-08）的"原口径"基线用 full 复现值而非存档 CSV。
- **D2 同方程叙述重写**：fair 重跑下 GDELT 进口保持 ** 及以上显著（非审计期所说的降为边际）；A 总量失去边际显著、B 总量降为边际。正文相关句需按上表重写。
- **D3 新浮现显著的处理**：PPML fair 两个新显著规格（ICEWS 进口方-出口 p=.020、Phoenix 出口方-进口 p=.047）、M1 Phoenix pos h0（p_boot=.036）、同方程 A 出口 Phoenix（p=.088）、ES_06 显著数 2→5——写入正文/附录，还是仅在总账/附录稳健性中报告？
- **D4 M5 口径**：v8 现引用 archive 值（0.335 系列）现行管线不可复现，须改用 full/fair 值；同时"远程通话 n.s."等表述按 fair 重跑复核（ICEWS remote fair n=10，0.754，CI 跨 0，保持 n.s. ✓）。
- **D5 漂移披露**：07-28 事件库 curation 漂移为既成事实（先于本轮公平覆盖期工作），是否在附录/修订说明中加一句版本说明？

## 四、结论性复核（截断后核心结论保持情况）
- 只有 GDELT 信号进入贸易决策：保持 ✓（PPML GDELT 不变且唯一稳健显著；fair 下同方程 GDELT 进口仍 **/***）
- H1/H2/H3、坏消息支配性、信号成本梯度：保持 ✓（M1 neg 全库 h=0 保持高度显著；M7 ICEWS 非对称 Wald fair p=.025）
- 命中率排序变化（ICEWS/Phoenix 升至 66.1/65.1）：v8 已正确反映 ✓
- 需要改写的叙述：同方程"边际显著"句（D2）、M5 引用值（D4）、新增显著项取舍（D3）

---

## 五、R3 执行记录（2026-07-29，用户审定 D1/D3/D5 后）

**正文 v8（从 v7 重新生成，`tmp\make_v8_canonical.py`，15/15 替换成功，旧值零残留）**
- 保持（canonical 复核一致）：命中率排序句+公共窗口 65.1/65.1/65.1/64.5（已用 fair 事件级数据复算 108/166、60/93 逐值一致）、放宽窗 65.5/62.6/57.6、PPML ICEWS 0.0024(0.608,n=6005)、M7 −0.812/+0.309/Wald p=0.025、M1 Phoenix −1.87、B4 句
- **回滚**：test2 置换 p 恢复 v7 原句 "p=0.55/0.37"（canonical fair ICEWS oneside=0.3656；审计期 0.40 系快算误差）
- **改写**：同方程句→canonical fair（GDELT 进口 0.0113 p=0.014 / 0.0174 p=0.008；清华 p=0.45~0.65；Phoenix 出口 −0.0062 p=0.005 + 新增 25 国边际 −0.0044 p=0.088）
- **改写**：M5 会晤→现行管线值（GDELT +0.399 [0.249,0.549]/+0.369/+0.168；ICEWS fair +0.502/+0.459/+0.233）
- **改写**：M1 正面句→fair 下 Phoenix h=0 正向显著（0.43，boot p=0.036），其余三库全期不显著
- **新增**：效度地图追加 fair 两个方向化子规格显著（ICEWS 进口方→出口 0.0074 p=0.020；Phoenix 出口方→进口 0.0093 p=0.047）
- **撤销**：误改 67.5%→66.7% 已回滚（112/166=67.5% 为事件数口径，与附录 S3 一致；模块 hit_rate 列 0.6667 是记录层面口径，非文本口径）

**附录 v4**：S3-1 fair 主表与 S3-1R 对照表逐格核对 canonical fair 模块输出全部一致（合作/冲突/总体 × 四库 × 三窗口），其余 3 表（S1 聚合算法）与远程通话混淆段不受截断影响，v4 维持不变即为 canonical 版。

**未触动**：para 80 断点（GDELT-only，修订检验 02 模块存档值逐字一致：澳 2017-12 段均值 1.259→0.045、AR(1) 0.25→0.60；菲三断点）、para 93 test1（GDELT 行不受截断影响；ICEWS change 规格 h=1 交互 full p=0.363/fair p=0.410 均不显著，正文表述保持）、ES_02 套件版 G1 DIFF（正文未引用）、ES_06 显著数 2→5（正文未引用，留总账备查）。
