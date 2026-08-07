# 08_汇总报告与可视化 Skill

## 适用场景

当你需要整合 01–07 全部结果，生成可放入论文的图表和文字摘要时，使用本 Skill。

## 科学问题

如何将分散的 10 张 CSV、12 张 PNG 整合成一份连贯的汇总报告？

## 输入数据

- `01_事件基准效应/检验结果CSV/01_baseline_event_effects.csv`
- `02_正负向非对称与4类访问效应/检验结果CSV/02_four_visit_effects.csv`
- `03_17类事件异质性/检验结果CSV/03_seventeen_category_effects.csv`
- `04_国家异质性/检验结果CSV/04_country_heterogeneity.csv`
- `06_事件强度与四库验证/检验结果CSV/06_cross_db_validation.csv`
- `07_稳健性与安慰剂/检验结果CSV/07_placebo_tests.csv`

## 核心操作

1. 读取各模块 CSV。
2. 生成综合森林图（按模块分面）。
3. 提取关键显著结果写入 `report.md`。

## 输出文件

- `report.md`
- `图片/fig08_combined_forest.png`

## 结果解读

- 报告中的结论应与其他模块 CSV 一致。
- 综合森林图可直观比较不同模块的效应大小与置信区间。

## 常见陷阱

1. **模块依赖**：08 必须在 01–07 生成 CSV 后运行。
2. **路径硬编码**：脚本中使用相对路径 `../../` 引用其他模块，确保工作目录正确。
