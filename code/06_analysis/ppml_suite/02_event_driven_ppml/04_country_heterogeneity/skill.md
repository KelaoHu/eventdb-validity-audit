# 04_国家异质性 Skill

## 适用场景

当你想识别不同国家对政治事件的贸易反应差异，并计算国家层面的事件敏感度排名时，使用本 Skill。

## 科学问题

哪些国家对政治事件最敏感？哪些国家贸易对政治冲击最具韧性？美国盟友是否反应更负面？

## 输入数据

- `00_事件面板构建/中间数据/event_panel_ready.csv`
- 必需列：`ISO`、`Country`、`Trade_Total`、`Event_Positive`、`Event_Negative`、控制变量

## 核心模型

通过 ISO × 事件交互项实现分国家系数估计：

```
fepois(Trade_Total ~ Pos_ISO + Neg_ISO + ... + Controls | ISO + YearMonth, cluster = ~ISO)
```

其中 `Pos_ISO` = `I(ISO==c) * Event_Positive`，`Neg_ISO` 类似。以第一个国家为参照组。

## 输出文件

- `检验结果CSV/04_country_heterogeneity.csv`
- `图片/fig04_country_sensitivity_ranking.png`
- `图片/fig04_country_pos_neg_scatter.png`

## 结果解读

- 国家敏感度指数：`sensitivity = beta_Negative - beta_Positive`
- 指数越高，说明负向事件抑制越强 / 正向事件促进越弱，国家越敏感。

## 常见陷阱

1. **参照国选择**：默认按 ISO 字母顺序第一个国家为参照，改变参照国不影响相对排名但改变交互项系数。
2. **事件稀疏国家**：部分国家事件过少，其交互项可能被共线剔除。
3. **解释维度**：敏感度指数综合了正负双向反应，也可分别报告正负系数。
