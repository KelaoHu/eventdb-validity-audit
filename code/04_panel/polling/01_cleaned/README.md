# 01_清洗后 — Phase 0 产出说明

## 文件

| 文件 | 说明 | 行数 |
|------|------|------|
| `paired_panel_annual.csv` | 民调-政治分数配对面板（主分析用） | 278行 |
| `polling_coverage_summary.csv` | 21国民调覆盖摘要 | 21行 |

---

## paired_panel_annual.csv — 列定义

### 民调变量

| 列 | 说明 | 示例值 |
|----|------|--------|
| `country` | 论文25国标准名（经名称映射） | United States |
| `year` | 调查年份（整数） | 2019 |
| `indicator_type` | 指标类型 | 好感度%（四级题，1-2档） |
| `favorable` | 原始好感度数值（%或度） | 48.4 |
| `unfavorable` | 原始恶感度数值 | 23.2 |
| `n_sample` | 有效样本量 | 741 |
| `source` | 数据来源机构 | Pew Research Center |
| `wave` | 调查波次 | Pew_2019_34国 |

### 政治分数变量（公平覆盖期口径，年度聚合）

| 列 | 说明 |
|----|------|
| `gdelt_mean` | GDELT几何平均指数的年度算术均值 |
| `gdelt_std` | GDELT该年各月分数的标准差 |
| `gdelt_n_months` | GDELT该年有效月数（通常12，边缘年份可能更少） |
| `icews_mean` / `icews_std` / `icews_n_months` | ICEWS年度统计（截断至2023-04） |
| `phoenix_mean` / `phoenix_std` / `phoenix_n_months` | Phoenix年度统计（截断至2019-03） |
| `tsinghua_mean` / `tsinghua_std` / `tsinghua_n_months` | Tsinghua年度统计（11国，含Pakistan但Pakistan不在25国面板） |

### 标准化变量

| 列 | 说明 |
|----|------|
| `polling_z` | 按indicator_type分组的z-score标准化民意分 |
| `polling_z_by_source` | 按source机构分组的z-score标准化民意分（替代方案） |
| `polling_z_pew` | **【主分析用】** Pew子集内重新z-score，mean=0, SD=1（在 analysis.R 中计算） |

---

## polling_coverage_summary.csv — 列定义

| 列 | 说明 |
|----|------|
| `country` | 国家名 |
| `n_obs` | 该国在2002-2025窗口内的民调观测数 |
| `year_min` | 最早调查年份 |
| `year_max` | 最晚调查年份 |
| `sources` | 数据来源机构（以逗号分隔） |

### 覆盖概况

| 类别 | 国家 | 观测数 |
|------|------|--------|
| **高覆盖（≥10 obs）** | United States(54), Japan(43), Australia(28), France(14), Spain(14), United Kingdom(14), Germany(14), India(12), Russia(12), Indonesia(11), Mexico(10), Brazil(10) | 12国 |
| **中等覆盖（5-9 obs）** | South Korea(9), Italy(8), Canada(8), Netherlands(6), Philippines(5) | 5国 |
| **稀疏（≤2 obs）** | Vietnam(2), Malaysia(2), Belgium(1), Thailand(1) | 4国（主分析排除） |
| **零数据** | Iran, Saudi Arabia, Singapore, UAE | 4国（无民调） |

---

## 处理记录

### 数据清洗步骤 (phase0_clean.py)

1. **国家名标准化**（13条映射）
   - Britain → United Kingdom
   - Great Britain → United Kingdom
   - US → United States
   - 美国 → United States
   - 澳大利亚 → Australia
   - 日本 → Japan
   - Côte d'Ivoire → Cote d'Ivoire（统一变音符）
   - Pakistan refield → Pakistan
   - Palestinian Territories → Palestinian territories（统一大小写）
   - São Tomé and Príncipe → Sao Tome and Principe
   - Cape Verde → Cabo Verde
   - Swaziland → Eswatini

2. **方向过滤**
   - 只保留"他国→中国"方向（563行）
   - 排除"中国→他国"方向（58行，止于2016年，不可用于面板分析）

3. **25国过滤**
   - 论文25个贸易伙伴国中21国有数据
   - Iran, Saudi Arabia, Singapore, UAE 四国无任何民调数据

4. **时间过滤**
   - 仅保留2002-2025年观测（政治分数覆盖期）
   - 实际最早民调为1985年(Gallup美国)，最早政治分数为2002年

5. **四库分数匹配**
   - 左连接(Left Join)：民调行保留，政治分数按country+year匹配
   - 匹配率：GDELT 93.9%, ICEWS 91.7%, Phoenix 83.1%, Tsinghua 70.5%
   - 未匹配行：1985-2001年的Gallup数据（政治分数未覆盖）、部分低覆盖率国家

6. **z-score标准化**
   - 按indicator_type分组分别标准化
   - 5个指标类型组：好感度%（四级题，1-2档）n=187, 好感度%（四级题）n=40, 亲近感% n=6, 温度计0-100° n=21, 温度计0-100°（月均）n=24

---

## 使用注意

- **主分析请使用 analysis.R**，该脚本自动处理Pew子集筛选和窗口内重新z-score
- polling_z 字段用全数据集的mean/SD标准化——Pew子集均值≈0.071, SD≈0.916（非精确(0,1)）。analysis.R 中已重新标准化为 polling_z_pew，严格满足mean=0, SD=1
- 政治分数使用公平覆盖期口径（ICEWS≤2023-04, Phoenix≤2019-03），与论文正文一致
- Phoenix 2019仅3个月有效数据，年度均值噪声较大——analysis.R 中已标注并在稳健性中排除
- Tsinghua 实际覆盖11国（12国含Pakistan，Pakistan不在25国面板）
