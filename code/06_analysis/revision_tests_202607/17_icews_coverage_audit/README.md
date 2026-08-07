# 17_ICEWS覆盖期审计

发现并量化"ICEWS 2023-04 后前向填充、Phoenix 2019-03 后填充"对全部检验影响的专项审计（2026-07），
是 fair 口径改革与 v8 修订的起点。

## 文件清单
| 文件/目录 | 内容 |
|---|---|
| `审计报告_ICEWS覆盖期_202607.md` | 主审计报告：四库填充画像、命中率/PPML/M5/M7/test 系列影响量化 |
| `审计报告补充_同类疏漏全扫描_202607.md` | B1–B6 同类疏漏扫描（Phoenix 填充窗、同方程灵敏度、B4 无源数字等） |
| `v8数字替换包_命中率与ICEWS口径_202607.md` | 当时的 v8 数字替换方案（审计期口径，部分已被 canonical fair 取代） |
| `code\` | 10+ 审计脚本（audit_hitrates、audit_ppml_lags_trunc、audit_m1/m5/m5678、dir_consistency 等） |
| `results\` | 审计产物（hitrate_fair_era.csv、ppml 三口径、m5/m7/test 两口径、s3_1 表、dir_consistency_final.csv 等） |

## 历史定位与使用注意
- 本模块结论已全部被 `..\..\重跑_公平覆盖期_202607\` 的 canonical 重跑**复核或取代**：
  - 仍有效：命中率 fair 口径（与重跑一致）、M7 fair 值、B4 方向一致性口径
  - **已被取代**：同方程审计期快算值（"边际显著"）、test2 置换 p=0.40（canonical 为 0.37）——
    详见根 `项目状态与交接.md` 教训 3/4
- 引用本目录数字前，一律先与 `对比总账` 核对
