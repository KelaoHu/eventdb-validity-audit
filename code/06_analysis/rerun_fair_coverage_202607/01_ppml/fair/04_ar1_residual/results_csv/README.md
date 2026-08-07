# 检验结果CSV

AR(1) 残差回归：对政治分数提取 AR(1) 冲击后的稳健性检验。

## 现有文件

- `A_AR1.csv`：由 `../R语言工程文件/04_run_ar1_residual_ppml_v2.R` 生成
- 列说明：`db`（数据库）、`label`（规格标签）、`n`（样本量）、`cum`（h=0..6 累计系数）、`cum_se`（累计系数标准误，v2 新增）、`h0`（当期系数）、`h0p`（当期 p 值）
- `A_AR1_before_cumse_20260729.csv`：v2 之前版本（无 `cum_se`）
