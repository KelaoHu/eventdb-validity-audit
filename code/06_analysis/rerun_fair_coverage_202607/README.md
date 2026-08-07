# 重跑_公平覆盖期_202607（canonical 双口径重跑工作区）

2026-07-28~29 公平覆盖期全量重跑的工作区，**正文 v8 全部 fair 口径数字的权威来源**。

## 结构
```
01_PPML套件\{full,fair}\        # PPML 套件镜像（仅改数据路径：full→原 data，fair→data_fair）
02_事件研究套件\{full,fair}\    # 事件研究 9 模块 + 05 robustness 镜像
03_修订检验\{full,fair}\        # 同方程/换届/命中率/M1/test1-3 镜像
r2_compare.py                   # R2 三口径对比器（archive vs full复现 vs fair）
r2_drift_summary.py             # G1 漂移量化（符号翻转/显著性跨界）
r2_key_numbers.py / r2_key2.py  # 正文引用数字三口径提取器
对比总账\                       # 全部对比产物（见下）
```

## 对比总账\（数字溯源第一站）
| 文件 | 内容 |
|---|---|
| `总账报告_R2_20260729.md` | **主报告**：G1 闸门总表、漂移归因、正文关键数字三列对照、R3 执行记录 |
| `compare_summary.csv` | 23 个结果文件的 G1 PASS/DIFF + fair 差异格数 |
| `G1DIFF_*.csv` | 10 个 DIFF 文件的逐格 archive-vs-full 差异明细 |
| `key_numbers_3way_v2.txt` | 正文引用数字的 archive/full/fair 三列提取 |
| `drift_summary.txt` | 漂移量化摘要 |

## G1 闸门结论（速查）
- **13 PASS**（full≡archive）：PPML 全部、命中率、同方程、M1、test1/2/3、合作冲突 → fair 差异=纯截断效应
- **10 DIFF**：事件研究 01–08 + REV_03 → 根因 = 2026-07-28 事件库 713→712 修订与 07-23 模块代码改版，**与截断无关**

## 使用纪律
1. 引用数字：fair 列为准；GDELT/清华 fair≡full
2. 重跑某模块：进对应 `{full,fair}` 镜像目录跑 R 脚本（数据路径已配好绝对路径）；
   跑完核对输出时间戳/行数，GDELT/清华 fair 与 full 应零差异
3. 本工作区脚本一律不动原套件（原套件在 `..\事件研究套件\` 等，保持原样）
