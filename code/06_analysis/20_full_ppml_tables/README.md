# 20_完整PPML回归表

## 目的
为论文附录 S4 提供完整、可复现的 PPML 回归结果表，包括基线模型完整系数、局部投影估计汇总、稳健性检验与安慰剂检验。

## 路径
- R 脚本：`01_R脚本/01_run_full_ppml_tables.R`
- 输出表格：`02_输出表格/`
- 文档化表格：`05_文档/311工程论文_附录_v6.docx`（表 S4-1 至 S4-4）

## 输出文件说明
| 文件 | 内容 |
|------|------|
| `S4_01_baseline_full_coeftable.csv` | 基线模型完整系数（GDELT，总贸易，h=0） |
| `S4_01_baseline_fitstats.csv` | 基线模型拟合统计量（N、Pseudo R²、对数似然、偏差） |
| `S4_02_lp_estimates.csv` | 全部 LP 估计长表（4 库 × 3 流向 × 7 期） |
| `S4_02_lp_estimates_wide.csv` | 便于阅读的宽表 |
| `S4_03_robustness_checks.csv` | 稳健性检验结果 |
| `S4_04_placebo_tests.csv` | 安慰剂检验结果 |

## 模型设定
- 估计方法：PPML（泊松伪最大似然估计，`fixest::fepois`）
- 固定效应：国家（ISO）+ 年月（YearMonth）
- 聚类：国家层面
- 控制变量：ln(GDP_i×GDP_j)、ln(汇率)、FTA 虚拟变量
- 政治冲击：各国各数据库政治分数经 z-score 标准化后的 AR(1) 残差；Tsinghua 使用差分后的 z-score

## 附录中对应的表格
- 表 S4-1：基线模型完整系数表
- 表 S4-2a–S4-2d：GDELT / ICEWS / Phoenix / Tsinghua 局部投影估计
- 表 S4-3：稳健性检验
- 表 S4-4：安慰剂检验

## 运行方式
```r
Rscript "01_R脚本/01_run_full_ppml_tables.R"
```

## 注意事项
- 脚本依赖数据路径中的面板与政治分数，请勿移动或重命名 `311工程/3 实证结果/...` 目录
- 频率扫描与前向效应计算会生成新的列，重新运行前建议清空环境或重读数据
