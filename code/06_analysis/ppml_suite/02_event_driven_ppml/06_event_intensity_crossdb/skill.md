# 06_事件强度与四库验证 Skill

## 适用场景

当你想用 GDELT、ICEWS、Phoenix、Tsinghua 四个数据库的政治分数变化来验证事件效应稳健性，并检验剂量反应时，使用本 Skill。

## 科学问题

四库对同一事件的强度测度是否一致？事件强度越大，贸易效应是否越强？

## 输入数据

- `00_事件面板构建/中间数据/event_panel_ready.csv`
- 连续强度变量：`Delta_GDELT`、`Delta_ICEWS`、`Delta_Phoenix`、`Delta_Tsinghua`

## 核心模型

### 连续强度

```
fepois(Trade ~ Delta_db + Controls | ISO + YearMonth, cluster = ~ISO)
```

分别对每个数据库跑回归。

### 剂量反应

仅使用事件月，按 `|Delta_db|` 三分位分组：

```
fepois(Trade ~ dose_medium + dose_high + Controls | ISO + YearMonth, cluster = ~ISO)
```

## 输出文件

- `检验结果CSV/06_cross_db_validation.csv`
- `检验结果CSV/06_dose_response.csv`
- `图片/fig06_cross_db_comparison.png`
- `图片/fig06_dose_response.png`

## 结果解读

- 连续强度系数显著为负：政治关系恶化（负 Delta）伴随贸易下降，改善（正 Delta）伴随贸易上升。
- 四库方向一致：事件效应跨库稳健。
- 剂量反应递增：高强度事件效应 > 中强度 > 低强度。

## 常见陷阱

1. **Delta 计算窗口**：默认事件前后各 3 个月（t−3 到 t+0），改变窗口会改变结果。
2. **Tsinghua 差分**：Tsinghua 原始序列为单位根，Delta 基于差分后 z-score，系数幅度可能更大。
3. **非事件月 Delta=0**：回归中大量 0 值可能降低功效，可考虑仅事件月回归作为稳健性。
