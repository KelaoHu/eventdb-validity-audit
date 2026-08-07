# 《中国与各国互相好感度_逐年.csv》来路说明

版本：2026-07-28 ｜ 编制：本机数据处理管线（skill: ir-data-pipeline）

---

## 一、文件概况

**文件**：`中国与各国互相好感度_逐年.csv`（621 行，111 个方向，UTF-8-SIG 编码，Excel 可直接打开）

**内容**：以"中国↔世界各国"为轴心的民众好感度逐年时间序列，双向：
- **各国 → 中国**（563 行）：他国民众如何评价中国
- **中国 → 各国**（58 行）：中国民众如何评价他国（Pew 中国样本，2005–2016）

**列定义**：

| 列 | 含义 |
|---|---|
| 方向 | 评价方→被评价方，如 `Japan→中国`、`中国→United States` |
| 评价方 / 被评价方 | 国家名（Pew/Gallup 原文为英文，其余按来源习惯） |
| 年份 / 月份 | 调查执行时间（月度数据仅 SIFCCT） |
| 指标类型 | 好感度%／温度计0-100°／亲近感%／影响力正面%（**四类不可直接互比，见第四节**） |
| 好感度数值 | 主指标（%或度） |
| 恶感度数值 | 对照指标（无则为空） |
| 有效样本量 | 该题有效回答人数（好感/恶感%的分母，不含"不知道/拒答"） |
| 数据来源机构 / 调查波次 | 溯源信息 |

---

## 二、各数据源详情（按可信度与透明度排序）

### 1. Pew Research Center – Global Attitudes & Trends（主体来源，480 行）

- **来源**：官方微观数据集（.sav），经第三方开放数据镜像 opendata.com.pk 获取
  （CKAN 平台，`/api/3/action/package_search?q="global attitudes"`），
  原始文件保存于 `Pew皮尤_镜像/解压/`，含官方问卷与 Topline 备查
- **波次**：2005, 2006, 2008, 2009春, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020夏
  （2002/2004/2009秋/2020秋 原问卷无对华好感度题；2021 年后镜像未收录）
- **题目原文**（以 2015 年 Q12B 为例）：
  *"Please tell me if you have a very favorable, somewhat favorable, somewhat unfavorable or very unfavorable opinion of China?"*
- **编码**：1=Very favorable, 2=Somewhat favorable → **好感度% = (1+2)/有效样本**；
  3/4=恶感；8=Don't know, 9=Refused, 99=未在该国询问 → 均剔除出分母
- **各年份题号对照**：2005=Q5c, 2006=Q2c_Fav_China, 2008=Q10c, 2009=Q11C,
  2010=Q7C, 2011=Q3C, 2012=Q8C, 2013=Q9C, 2014=Q15B, 2015=Q12B, 2016=Q10B,
  2017–2020=fav_China/FAV_CHINA（均由变量标签自动识别+人工复核）
- **中国→各国方向**：同一电池题（battery）在中国样本（N≈2200–3600/年）上的取值；
  对象国因年而异（美/日/俄/印/欧盟/伊朗/巴基斯坦等，见 CSV）
- **样本**：各国全国代表性样本，每国约 700–3600 人，面访为主
- **已知差异**：2015 年前多为面访；不同年份调查月份不同（多为春季）

### 2. Gallup – World Affairs Survey（美国→中国，1985–2025）

- **来源**：Gallup 官网图表底层数据（Datawrapper 公开接口 `datawrapper.dwcdn.net/{id}/dataset.csv`）
- **题目原文**：*"Please tell me if you have a very favorable, mostly favorable, mostly unfavorable, or very unfavorable opinion of China?"*
- **编码**：好感度% = Very favorable + Mostly favorable
- **样本**：每年 2 月，美国成年人电话调查，约 1000 人
- **说明**：年度频率完整覆盖 2001–2025，早年（1985–2000）为不规则时点

### 3. Lowy Institute Poll（澳大利亚→中国，2006–2026）

- **来源**：官网交互图表底层 JSON（SvelteKit `__data.json`）完整提取，
  并经官方新闻稿数字校验（2026 年 NZ 86°/Canada 79°/Japan 77°/UK 72°，完全一致）
- **题目原文**：*"Please rate your feelings towards some countries and territories, with one hundred meaning a very warm, favourable feeling, zero meaning a very cold, unfavourable feeling..."*
- **指标**：0–100° 温度计（样本均值），与百分比题不同源，**不可与 Pew/Gallup 直接比数值**

### 4. 日本内阁府《外交に関する世論調査》（日本→中国，2020–2025）

- **来源**：内阁府官方逐题 CSV（`survey.gov-online.go.jp`，表7 中国に対する親近感・時系列）
- **题目原文**：「あなたは、中国に親しみを感じますか、それとも感じませんか。」
- **编码**：親しみを感じる（小計）=「感じる」+「どちらかというと感じる」
- **样本**：全国 18 岁以上，约 1700–1900 人/年，访问留置法
- **说明**：与 Pew 的"favorable"措辞不同（"亲近感"），数值系统性偏低属正常现象

### 5. SIFCCT（日本→中国，2011.10–2013.09 月度）

- **来源**：早稻田大学，Harvard Dataverse 公开复现数据（DOI: 10.7910/DVN/LTJEO9）
- **题目**：对 16 国好感度温度计（0–100°）；888=不知道、999=拒答（已剔除）
- **样本**：每月一波全国网络调查，约 3000–3500 人/波，共 24 波
- **价值**：唯一月度频率数据源，可捕捉 2012-09 钓鱼岛事件骤降（21.2°→14.3°）

### 6. Afrobarometer（非洲 45 国→中国，R6/R8/R9 三轮）

- **来源**：官网免费 .sav（R6=Q81B, R8=Q70E, R9=Q78A）
- **题目**：*"In your opinion, is China's influence on your country positive or negative?"*
  （注意：是"影响力评价"而非"好感度"，作近似使用，已在指标类型中标注）

---

## 三、加工与质控记录

1. **变量识别**：Pew 各年份题号不同，一律按变量标签正则匹配（`favorable` + `opinion of China`），
   并排除 `more favorable or less favorable`（事件归因题，编码不同）等干扰变量
2. **未询问处理**：中国样本中未询问的对象国题为全 NaN（如 2010 年 Q7L Germany），
   先行 dropna 再判定样本量 ≥50 才纳入，杜绝"0% 假象"
3. **去重**：同年同对象只保留电池题正式变量（n 最大）
4. **史实校验**（全部通过）：
   - 日本→中国 Pew 2013 = 5.7%（钓鱼岛危机后官方公布值 ✓）
   - 美国→中国 Gallup 2023 = 15%（官方发布 ✓）
   - 中国→日本 Pew 2013 = 5.0%、中国→美国 2005–2016 区间 42–58%（与 Pew 报告一致 ✓）
   - 内阁府对华亲近感 2023 = 12.7%（官方公报 ✓）

## 四、使用注意（重要）

1. **四类指标不可直接比数值**：好感度%（Pew/Gallup）、温度计°（Lowy/SIFCCT）、
   亲近感%（内阁府）、影响力正面%（Afrobarometer）——比较时请分开或标准化（z-score）
2. **年份缺口**：Pew 2007、2015 前部分国家不连续；中国→各国方向 2017 年后无数据
   （Pew 2017 年起未在中国实地调查）
3. **口径**：均为"对国家整体的好感"，不含对国民/政府的区分（个别年份 Pew 另有 Americans 题，未混入）
4. 中国样本为 Pew 委托中国本土机构执行的城市为主样本，城乡代表性有偏，引用时建议注明

## 五、文件血缘

```
Pew皮尤_镜像/解压/*.sav  ─┐
                          ├→ 09_Pew_各国对中国好感度_2005-2020.csv ─┐
                          └→ Pew_中国对各国好感度_2005-2016.csv  ─┤
预处理成品CSV/01–08       ────────────────────────────────────┴→ 中国与各国互相好感度_逐年.csv
```

加工脚本逻辑与全部数据源抓取方法见：`桌面\skills\ir-data-pipeline\SKILL.md`
