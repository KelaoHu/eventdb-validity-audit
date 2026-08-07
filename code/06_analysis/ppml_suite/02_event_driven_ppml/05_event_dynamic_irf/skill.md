# 05_事件动态 IRF Skill

## 适用场景

当你想刻画事件发生后贸易随时间的动态变化路径（即时效应 vs 滞后效应、持续期）时，使用本 Skill。

## 科学问题

事件效应是立即出现还是滞后？持续多久？正事件是否存在“蜜月期”后衰减？负事件是否存在持续抑制或反转？

## 输入数据

- `00_事件面板构建/中间数据/event_panel_ready.csv`
- 已预生成滞后变量：`Event_Positive_L1/L3/L6/L12`、`Event_Negative_L*`、4 类访问滞后、17 类滞后

## 核心模型

局部投影法（LP-IRF），每期单独回归：

```
fepois(Trade_t ~ Event_Positive_Lh + Event_Negative_Lh + Event_Neutral_Lh + Controls | ISO + YearMonth,
       cluster = ~ISO)
```

`h = 0, 1, 3, 6, 12`。

## 输出文件

- `检验结果CSV/05_event_irf.csv`
- `图片/fig05_irf_positive_negative.png`
- `图片/fig05_irf_four_visits.png`

## 结果解读

- h=0 系数：事件当月效应。
- h=12 系数：事件一年后效应。
- 若多数 h 系数同号且部分显著：效应持久。
- 若系数符号反转：可能存在过度反应后的修正。

## 常见陷阱

1. **滞后项处理**：本脚本使用面板中预生成的滞后项，等价于 `Trade_{t+h} ~ Event_t`。
2. **置信带膨胀**：多期 IRF 增加族错误率，可将结果视为描述性而非严格多重检验。
