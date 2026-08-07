# Data Sources & Access（原始数据来源与获取）

本仓库（GitHub）存放派生数据（月度指数、面板、黄金标准事件、附录表）。**原始检索数据（3.5 GB）因体积与源站条款存于 Zenodo 归档**：

> **Zenodo archive**: [DOI 待回填 / to be assigned upon deposit]
> 内容：GDELT 中国×25 国原始双边事件（2.36 GB）、ICEWS 原始双边事件（210 MB）、Phoenix 发布包（894 MB）与整理版、清华指数原始 PDF 与提取校验全套。

## 上游公开数据源（请遵循原发布方条款）

| Source | Access | Identifier |
|---|---|---|
| GDELT 1.0 events | gdeltproject.org /events/ | — |
| ICEWS | Harvard Dataverse | doi:10.7910/DVN/28075 |
| Phoenix (Cline Center) | Cline Center / UIUC | doi:10.13012/B2IDB-0647142_V3 |
| 清华指数（中国与大国关系） | 公开出版物 | Yan & Zhou (2004), 中国社会科学 (6): 90–103 [In Chinese] |
| IMF DOTS / QNEA / IFS；BIS REER | IMF Data / BIS Data Portal | — |
| UN Comtrade；WTO RTA；CEPII BACI | 各自官网/API | — |
| Pew Global Attitudes | pewresearch.org | 2007 无波次、2015 波次未纳入（见文稿口径） |
| Gallup World Affairs / Lowy Poll / 日本内阁府世论调查 / SIFCCT / Afrobarometer R6–9 | 各自官网 | SIFCCT: Harvard Dataverse |

## 复现所需的最小数据

仅需 `data/` 目录即可重跑全部分析与图件（见 `docs/VERIFICATION.md` 的端到端复现记录）；原始层仅用于复现"检索→聚合"前两阶段。
