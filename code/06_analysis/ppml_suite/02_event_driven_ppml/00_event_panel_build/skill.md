# 00_事件面板构建 Skill

## 适用场景

当你需要用 713 条人工标注事件作为核心解释变量，并与经济面板、四库政治分数合并成一个可用于回归分析的事件-面板数据集时，使用本 Skill。

## 科学问题

如何把结构化的离散事件（日期、国家、类别、impact）转换为回归可用的月度国家-面板虚拟变量与连续强度变量？

## 输入数据

1. `3.2 双边关系分析基于月度政治分数/自建事件库_25国_17类_713条事件.csv`
   - 必需列：`country_en`、`event_date`、`event_type_original`、`event_category`、`impact`、`visit_level`、`visit_direction`
2. `新PPMLHDFE/data/panel_clean.csv`
   - 必需列：`ISO`、`Country`、`month`、`Trade_Total/Exports/Imports`、`ln_GDP_product`、`ln_ER`、`FTA_Dummy`
3. `3.2 双边关系分析基于月度政治分数/全新事件研究法/data/{gdelt_scores.csv, icews_scores.csv, phoenix_scores.csv, tsinghua_scores.csv}`

## 核心操作

1. 解析 `event_date` 为 `YearMonth`。
2. 清洗 `event_category` 脏值，映射回标准 17 类中文。
3. 生成三类变量：
   - **impact 虚拟变量**：`Event_Positive`、`Event_Negative`、`Event_Neutral`
   - **4 类访问变量**：基于 `event_category_en` + `visit_direction`，合并 state_head / government_head，严格 Remote talk 口径
   - **17 类事件变量**：`Cat_*`
4. 同国家-月份多事件取并集（max 聚合）。
5. 计算每个事件前后四库 `zscore` 变化 `Delta_*`，聚合到国家-月份。
6. 生成滞后项 `*_L1/L3/L6/L12` 供 IRF 使用。

## 输出文件

- `中间数据/event_panel_ready.csv`：主数据集
- `中间数据/event_summary_by_category.csv`：事件频数摘要

## 常见陷阱

1. **国家名匹配**：事件库用 `country_en`（如 "Australia"），面板用 `ISO` + `Country`，需通过 `ISO-Country-country_en` 映射合并。
2. **脏类别**：`event_category` 列可能混入 `leader_visit`、`economic` 等英文，需映射回中文。
3. **Delta 计算**：`scores$Country` 为全名而非 ISO，比较时需使用 `country_en`。
4. **多事件合并**：同一国家-月份多个事件需用 max 聚合，避免重复计数。
