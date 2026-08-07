# 01_事件基准效应 Skill

## 适用场景

当你想估计政治事件（正向/负向/中性）对双边贸易的平均因果效应时，使用本 Skill。

## 科学问题

正向事件是否促进贸易？负向事件是否抑制贸易？中性事件是否无显著影响？

## 输入数据

- `00_事件面板构建/中间数据/event_panel_ready.csv`
- 必需列：`Trade_Total/Exports/Imports`、`Event_Positive/Negative/Neutral`、`ln_GDP_product`、`ln_ER`、`FTA_Dummy`、`ISO`、`YearMonth`

## 核心模型

```
fepois(Trade ~ Event_Positive + Event_Negative + Event_Neutral + ln_GDP_product + ln_ER + FTA_Dummy | ISO + YearMonth,
       data = dt, cluster = ~ISO)
```

- 被解释变量：`Trade_Total`、`Trade_Exports`、`Trade_Imports`
- 固定效应：国家 + 时间
- 聚类：国家

## 输出文件

- `检验结果CSV/01_baseline_event_effects.csv`
- `图片/fig01_baseline_event_effects.png`

## 结果解读

- 系数 > 0：该类事件促进贸易。
- 系数 < 0：该类事件抑制贸易。
- 由于事件稀疏且 FE 消耗自由度，很多系数可能不显著，需结合 05 IRF 与 06 强度综合判断。

## 常见陷阱

1. **事件稀疏**：719 事件分布在 6685 观测中，约 10% 处理密度，统计功效有限。
2. **多重共线性**：正/负/中性事件很少同时发生，但三者同时进入模型会以中性为某种参照，注意解释。
