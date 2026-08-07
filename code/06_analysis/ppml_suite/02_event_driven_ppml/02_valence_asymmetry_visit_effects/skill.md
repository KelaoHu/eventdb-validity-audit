# 02_正负向非对称与 4 类访问效应 Skill

## 适用场景

当你想检验：（1）正向与负向事件的贸易效应是否对称；（2）图例 4 类领导人访问/会晤事件对贸易的异质性影响时，使用本 Skill。

## 科学问题

1. 负面冲击是否比正面冲击更具破坏力（损失厌恶）？
2. 中方国事访问、外方国事访问、第三方会晤等哪类领导人互动对贸易拉动最强？

## 输入数据

- `00_事件面板构建/中间数据/event_panel_ready.csv`
- 4 类访问变量：`V_RemoteTalk`、`V_China_Outbound`、`V_Partner_Inbound`、`V_ThirdParty`

## 核心模型

### 正负非对称

```
fepois(Trade ~ Event_Positive + Event_Negative + Controls | ISO + YearMonth, cluster = ~ISO)
Wald H0: beta_Positive + beta_Negative = 0
```

### 4 类访问效应

```
fepois(Trade_Total ~ V_RemoteTalk + V_China_Outbound + V_Partner_Inbound + Controls | ISO + YearMonth,
       cluster = ~ISO)
```

以 `V_ThirdParty`（第三方会晤）为参照组。

## 输出文件

- `检验结果CSV/02_valence_asymmetry.csv`
- `检验结果CSV/02_four_visit_effects.csv`
- `图片/fig02_valence_asymmetry.png`
- `图片/fig02_four_visit_effects.png`

## 结果解读

- Wald p < 0.10：拒绝正负效应绝对值相等的原假设，存在非对称。
- 访问类系数 > 0 且显著：该类访问相对第三方会晤显著促进贸易。

## 常见陷阱

1. **出访与来访类别内部相关性**：两者可能高度相关，联合回归与单独回归结果需对照。
2. **第三方会晤作为参照组**：其样本量最大（约 150+ 事件），是较稳定的参照。
