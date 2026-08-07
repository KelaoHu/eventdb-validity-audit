# 检验结果CSV

干净面板 PPML：基于清洗后面板的联合分布滞后回归。

## 现有文件

- `ppml_final.csv`：由 `../R语言工程文件/03_run_clean_panel_ppml_v2.R` 生成
- 列说明：`label`（规格标签）、`n`（样本量）、`cum`（h=0..6 累计系数）、`cum_se`（累计系数标准误，v2 新增）、`h0`（当期系数）、`h0p`（当期 p 值）
- `ppml_final_before_cumse_20260729.csv`：v2 之前版本（无 `cum_se`）
