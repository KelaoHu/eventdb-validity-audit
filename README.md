# Choosing the Right Ruler: An Audience-Specific Audit of Political Event Databases

> **事件数据库没有绝对最优，只有与受众最匹配。** 同一段中国与 25 个贸易伙伴的双边关系，用 GDELT、ICEWS、Phoenix 与清华指数四把"尺子"量出来，是四个不同的世界——本文用三层审计证明这一点，并解释为什么。

> 🎓 **For prospective advisors / 给未来的导师**：一页项目陈述见 [`docs/PROJECT_OVERVIEW.md`](docs/PROJECT_OVERVIEW.md)；30 秒独立重算头条数字请直接运行 `python examples/verify_headline_stats.py`（克隆后无需任何配置）。

[![Python 3.12](https://img.shields.io/badge/Python-3.12-blue)](https://www.python.org/) [![R 4.6](https://img.shields.io/badge/R-4.6.1-276DC3)](https://www.r-project.org/) [![License: MIT + CC-BY](https://img.shields.io/badge/License-MIT%20%2B%20CC--BY-green)](LICENSE) [![Reproduction: verified](https://img.shields.io/badge/Reproduction-verified%20end--to--end-brightgreen)](docs/VERIFICATION.md)

## Key findings at a glance

| Finding | Numbers |
|---|---|
| Cross-database agreement collapses along media density | GDELT–ICEWS Spearman ρ: **0.633** (China–Japan) vs **0.031** (China–Brazil), n = 207 |
| Divergence is structural, not noise | Machines capture behavior; experts judge intensity (gold-standard hit rates by event type) |
| Measurement choice changes conclusions | Same PPML-HDFE spec: only GDELT co-moves with trade (β = 0.0127, p = 0.026); Phoenix exports turn **negative** (−0.0062, p = 0.005) in the four-database equation |
| The best database switches with the audience | Trade: GDELT wins. Public opinion: all four significant, **Phoenix** survives the horse race (β = 0.090, p = 0.002) |

**Evidence base**: 9.66 million machine-coded events + **712 hand-curated, source-verified gold-standard events** (inter-coder Cohen's κ = 0.866) + monthly panel of China × 25 trading partners, 2002–2025 (n = 6,685) + six independent polling sources (Pew core: 17 countries × 13 waves).

![Cross-country consistency gradient](figures/Figure1.png)

*Figure 1. GDELT–ICEWS monthly-index correlations across 25 bilateral relationships (heatmap, ranked) and the annual distribution of the 712 gold-standard events (bars).*

![Machines capture behavior, experts judge intensity](figures/Figure2.png)

*Figure 2. Gold-standard hit rates by event type (a) and event-window responses to negative vs positive events (b).*

## Why this repository is trustworthy

Every number in the paper was re-derived from this repository before release (see [`docs/VERIFICATION.md`](docs/VERIFICATION.md)):

- ✅ **End-to-end Python reproduction**: the aggregation script re-run on the 2.36 GB raw retrieval CSV reproduces the released monthly scores **byte-identical** (md5-matched)
- ✅ **End-to-end R reproduction**: Figure 2 re-generated from package files alone, all built-in QA gates passed (hit rates 67.5 / 51.3 / 75.8; Phoenix IRF −1.87 / +0.43)
- ✅ **Headline statistics recomputed** from released scores: 0.633 / 0.031 (n = 207) reproduced exactly
- ✅ Full-file **md5 manifest** + row-count assertions (panel n = 6,685; events = 712; …)

## Pipeline

```
Raw acquisition (GDELT zips / ICEWS Dataverse / Phoenix package / Tsinghua PDF / IMF / WTO / 6 polling sources)
  → dyad retrieval (China × 25 partners, strict actor-country matching)
  → day-to-month aggregation (geometric mean in log space, +11 shift, two-stage)
  → panel assembly (trade + scores + GDP + FX + FTA)
  → estimation (PPML-HDFE, Local Projections h=0–6, event studies, 1,000× permutation falsification)
  → audit reporting (three layers: consistency, validity, causal inference)
```

See [`docs/PIPELINE.md`](docs/PIPELINE.md) for the full lineage map and [`docs/SCRIPT_LINEAGE.md`](docs/SCRIPT_LINEAGE.md) for the versioned script inventory.

## Repository map

| Path | Contents |
|---|---|
| `code/01_acquisition/` | GDELT/ICEWS download & dyad-retrieval scripts (final versions) |
| `code/02_aggregation/` | Day-to-month aggregation lab (geometric-mean baseline + 4 alternatives) |
| `code/03_economic_data/` | IMF DOTS/QNEA/REER, Comtrade, WTO RTA, CEPII BACI scripts |
| `code/04_panel/` | Panel assembly + polling-data cleaning chain (Python + R) |
| `code/05_event_curation/` | Gold-standard event curation & source-verification scripts |
| `code/06_analysis/` | PPML suite, event-study suite (9 modules), 17 revision tests, fair-coverage rerun with comparison ledger |
| `code/07_figures/` | All figure scripts (R, ggplot2) |
| `data/core/` | The 8 release datasets (fair-coverage scores, panel, 712 events, Pew panel) |
| `data/appendix_tables/` | 27 CSVs backing every table in paper & SI |
| `figures/` | All manuscript figures (300 dpi) |

Raw event data (3.5 GB: GDELT/ICEWS retrievals, Phoenix source package) and the full unabridged package are archived separately on Zenodo: **[DOI placeholder — see `docs/DATA_SOURCES.md`]**. Source databases are public: GDELT Project, ICEWS (doi:10.7910/DVN/28075), Phoenix (doi:10.13012/B2IDB-0647142_V3).

## Reproduce

```bash
pip install -r requirements.txt        # Python deps; R deps in code/R_packages.txt
python examples/verify_headline_stats.py   # 30 秒自证：头条数字独立重算，打印 PASS/FAIL
Rscript code/07_figures/figures_R/fig02_v3.R   # 图 2 再生成（内置 QA 闸门）
```

Scripts carry the author's machine paths; redirect to this repo's folders as documented in `docs/PIPELINE.md`.

## Citation

See `CITATION.cff`. If you use the 712-event gold standard or the audit framework, please cite the manuscript (preprint available from the authors).

## License

Code: MIT (see [LICENSE](LICENSE)). Data (derived indices, gold-standard events, appendix tables): CC-BY 4.0 (see [LICENSE-DATA.md](LICENSE-DATA.md)). Source databases remain under their original publishers' terms.

---

## 中文简介

本仓库是一篇论文的完整复现包：对 GDELT、ICEWS、Phoenix 与清华指数四个政治事件数据库做"一致性—效度—因果推断"三层审计，证据基础为 966 万条机器编码事件与 712 条人工核查的黄金标准事件（中国与 25 个贸易伙伴，2002–2025 月度面板）。核心命题：**数据库的预测力取决于其信源结构与受众信息环境的重合度**——贸易跟随 GDELT 所呈现的政治，民意跟随 Phoenix 所呈现的政治。全部数字经端到端复现验证（见 docs/VERIFICATION.md）。
