# Measurement validity in political event databases is audience-specific: evidence from China and its 25 trading partners

[![Python 3.12](https://img.shields.io/badge/Python-3.12-blue)](https://www.python.org/) [![R 4.6](https://img.shields.io/badge/R-4.6.1-276DC3)](https://www.r-project.org/) [![DOI](https://img.shields.io/badge/DOI-10.5281%2Fzenodo.21862534-blue)](https://doi.org/10.5281/zenodo.21862534) [![License: MIT + CC-BY](https://img.shields.io/badge/License-MIT%20%2B%20CC--BY-green)](LICENSE) [![Reproduction: verified](https://img.shields.io/badge/Reproduction-verified%20end--to--end-brightgreen)](docs/VERIFICATION.md)

---

# 🔍 The same 25 relationships. Four databases. Four different worlds.

## 9,659,113 events. 712 hand-verified truths. 25 partners. 23 years.

### The most comprehensive validity audit of political event databases to date.

---

### The assumption nobody checked

For two decades, every quantitative study of China's foreign relations has rested on a silent choice: pick GDELT, or ICEWS, or Phoenix, or the expert-coded Tsinghua index — and proceed as if the choice didn't matter. Event counts were quoted as ground truth; expert scores were cited by habit. **Nobody audited the instruments.** Nobody asked whether the China–Japan relationship measured by one database is the same relationship measured by another. And nobody asked what happens to published-style conclusions when you swap one for another.

Until now. As of August 2026, this repository presents, to our knowledge, **the first systematic cross-database validity audit of political-relations measurement** — four databases, one gold standard, and the consequences followed all the way down to substantive conclusions.

### The stage: 25 relationships that carried a rising power

On 11 December 2001, China joined the WTO. What followed was one of the fastest trade integrations in modern history — and it ran through exactly 25 relationships: **China's largest trading partners of 2002**, from Japan and the United States to Brazil and Iran. We tracked all 25 month by month for 23 years, through WTO accession, the 2008 financial crisis, the Belt and Road Initiative, the US–China trade war, and the pandemic — three machine-coded giants watching from the outside (GDELT, ICEWS, Phoenix), Tsinghua's experts scoring from the inside.

### What we built

- 🔢 **9,659,113 machine-coded events** — every relevant event GDELT, ICEWS and Phoenix recorded between China and its 25 partners, 2002–2025, filtered to strict dyads (GDELT 8,946,603 · ICEWS 613,599 · Phoenix 98,911)
- 🥇 **712 gold-standard events, each verified source-by-source** — to our knowledge **the first open, double-coded (κ = 0.866) ground truth** for China's bilateral relations, answering Schrodt's (2015) call for shared gold-standard infrastructure
- 📊 **Two purpose-built panels** — monthly trade (n = 6,685) and public opinion from six independent sources (Pew core: 17 countries × 13 waves, N = 170)
- 🧾 **A zero-trust replication package** — 1,064 files, every one md5-fingerprinted; end-to-end reproduction byte-identical; headline numbers recompute in 30 seconds (10/10 PASS)

### What we found

1. **Agreement is a coverage property, not a database property.** GDELT–ICEWS correlation ranges from ρ = 0.633 (China–Japan) to ρ = 0.031 (China–Brazil), n = 207 — the same pair of databases, two different worlds.
2. **Machines capture behavior; experts judge intensity.** The four databases are not noisy versions of each other — they are measuring different things.
3. **Your database choice *is* your result.** In **this literature's first same-specification, four-database horse race**, the Phoenix export coefficient flips sign (β = −0.0062, p = 0.005).
4. **There is no universally best database — only the best match to your audience.** Trade listens to GDELT. Public opinion listens to Phoenix.

### Which database should you cite?

| Your question | The evidence says |
|---|---|
| Trade, sanctions, economic statecraft | **GDELT** — the only database that co-moves with trade flows (β = 0.0127, p = 0.026) |
| Public opinion, soft power | **All four work — Phoenix wins the horse race** (β = 0.090, p = 0.002) |
| High-media-coverage partners (Japan, US, …) | Databases largely agree — any choice defensible |
| Low-coverage partners (Brazil, …) | Treat any single-database result with caution (ρ as low as 0.031) |

**Don't take our word for it — clone and run the 30-second check.**

## Key findings at a glance

Four findings — every one recomputes from this repository in seconds.

| Finding | Numbers | So what |
|---|---|---|
| Cross-database agreement collapses along media density | GDELT–ICEWS Spearman ρ: **0.633** (China–Japan) vs **0.031** (China–Brazil), n = 207 | Correlation is not a database property — it is a coverage property |
| Divergence is structural, not noise | Machines capture behavior; experts judge intensity (gold-standard hit rates by event type) | The four databases are not measuring the same thing |
| Measurement choice changes conclusions | Same PPML-HDFE spec: only GDELT co-moves with trade (β = 0.0127, p = 0.026); Phoenix exports turn **negative** (−0.0062, p = 0.005) in the four-database equation | Your database choice *is* your result |
| The best database switches with the audience | Trade: GDELT wins. Public opinion: all four significant, **Phoenix** survives the horse race (β = 0.090, p = 0.002) | Validity is audience-specific — match the database to the question |

**Evidence base**: 9.66 million machine-coded events + **712 hand-curated, source-verified gold-standard events** (inter-coder Cohen's κ = 0.866) + monthly panel of China × 25 trading partners, 2002–2025 (n = 6,685) + six independent polling sources (Pew core: 17 countries × 13 waves).

![Cross-country consistency gradient](figures/Figure1.png)

*Figure 1. GDELT–ICEWS monthly-index correlations across 25 bilateral relationships (heatmap, ranked) and the annual distribution of the 712 gold-standard events (bars).*

![Machines capture behavior, experts judge intensity](figures/Figure2.png)

*Figure 2. Gold-standard hit rates by event type (a) and event-window responses to negative vs positive events (b).*

## Why this repository is trustworthy

- ⚡ **30-second self-check**: clone and run `python verification/verify_headline_stats.py` — headline statistics recomputed independently, PASS/FAIL printed. No configuration needed.

Every number in the paper was re-derived from this repository before release (see [`docs/VERIFICATION.md`](docs/VERIFICATION.md)):

- ✅ **End-to-end Python reproduction**: the aggregation script re-run on the 2.36 GB raw retrieval CSV reproduces the released monthly scores **byte-identical** (md5-matched)
- ✅ **End-to-end R reproduction**: Figure 2 re-generated from package files alone, all built-in QA gates passed (hit rates 67.5 / 51.3 / 75.8; Phoenix IRF −1.87 / +0.43)
- ✅ **Headline statistics recomputed** from released scores: 0.633 / 0.031 (n = 207) reproduced exactly
- ✅ Full-file **md5 manifest** + row-count assertions (panel n = 6,685; events = 712; …)

## The audit in one paragraph

The machinery behind these claims: three layers, one question. *Consistency*: do the databases agree with each other (pairwise correlations, directional agreement, five aggregation algorithms)? *Validity*: do they capture what experts say happened (712-event gold standard, hit rates by type and window)? *Consequences*: does the choice change the answer (same-equation PPML-HDFE horse races on trade and public opinion, local projections h = 0–6, event studies with 1,000× permutation falsification)?

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
| `data/core/` | The release datasets (fair-coverage scores ×4 DBs, panel, 712 events + gold-standard, Pew panel, versions/leaders/auxiliary) |
| `data/appendix_tables/` | 33 CSVs backing every table in paper & SI |
| `figures/` | All manuscript figures (300 dpi) |

Raw event data (3.5 GB: GDELT/ICEWS retrievals, Phoenix source package) and the full unabridged package are archived separately on Zenodo: **[doi:10.5281/zenodo.21862534](https://doi.org/10.5281/zenodo.21862534)**. Source databases are public: GDELT Project, ICEWS (doi:10.7910/DVN/28075), Phoenix (doi:10.13012/B2IDB-0647142_V3).

## Reproduce

```bash
pip install -r requirements.txt        # Python deps; R deps in code/R_packages.txt
python verification/verify_headline_stats.py   # 30 秒自证：头条数字独立重算，打印 PASS/FAIL
Rscript code/07_figures/figures_R/fig02_v3.R   # 图 2 再生成（内置 QA 闸门）
```

Scripts carry the author's machine paths; redirect to this repo's folders as documented in `docs/PIPELINE.md`.

Full 3.5 GB archive (raw data included): Zenodo [doi:10.5281/zenodo.21862534](https://doi.org/10.5281/zenodo.21862534).

## Citation

See `CITATION.cff`. If you use the 712-event gold standard or the audit framework, please cite the manuscript (preprint available from the authors).

## License

Code: MIT (see [LICENSE](LICENSE)). Data (derived indices, gold-standard events, appendix tables): CC-BY 4.0 (see [LICENSE-DATA.md](LICENSE-DATA.md)). Source databases remain under their original publishers' terms.
