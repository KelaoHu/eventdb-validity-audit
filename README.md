# Choosing the Ruler: An Audience-Specific Audit of Measurement Validity in Political Event Databases — Evidence from Trade and Public Opinion between China and Its 25 Trading Partners

[![Python 3.12](https://img.shields.io/badge/Python-3.12-blue)](https://www.python.org/) [![R 4.6](https://img.shields.io/badge/R-4.6.1-276DC3)](https://www.r-project.org/) [![DOI](https://img.shields.io/badge/DOI-10.5281%2Fzenodo.21862534-blue)](https://doi.org/10.5281/zenodo.21862534) [![License: MIT + CC-BY](https://img.shields.io/badge/License-MIT%20%2B%20CC--BY-green)](LICENSE) [![Reproduction: verified](https://img.shields.io/badge/Reproduction-verified%20end--to--end-brightgreen)](docs/VERIFICATION.md)

> *Four databases watch the same 25 relationships between China and its trading partners — and tell four different stories. This repository shows which story holds up, for which audience.*

| **9,659,113** events | **712** verified events | **25** partners, 2002–2025 | **κ = 0.866** |
|---|---|---|---|
| GDELT · ICEWS · Phoenix | double-coded gold standard | monthly panel, n = 6,685 | inter-coder reliability |

![Cross-country consistency gradient](figures/Figure1.png)

*Figure 1. GDELT–ICEWS monthly-index correlations across 25 bilateral relationships (heatmap, ranked) and the annual distribution of the 712 gold-standard events (bars).*

## About this repository

This repository contains the data and code for the paper "Choosing the Ruler: An Audience-Specific Audit of Measurement Validity in Political Event Databases." The study audits four widely used measures of bilateral political relations — GDELT, ICEWS, Phoenix, and the expert-coded Tsinghua index — against a hand-verified record of 712 events between China and its 25 largest trading partners, tracked month by month from 2002 to 2025. The underlying corpus covers 9,659,113 machine-coded events (GDELT 8,946,603 · ICEWS 613,599 · Phoenix 98,911), a monthly trade panel (n = 6,685), and public-opinion measures from six independent sources (Pew core: 17 countries × 13 waves, N = 170). To our knowledge, this is the first systematic cross-database validity audit of political event databases.

## Why this matters

Quantitative studies of international relations routinely pick one event database and proceed as if the choice were neutral. Whether that choice affects substantive conclusions had not been systematically checked — neither whether two databases describe the same relationship in the same way, nor what happens to published-style findings when one instrument is swapped for another.

The setting is the trade integration that followed China's WTO accession in December 2001. We track China's 25 largest trading partners of 2002 — from Japan and the United States to Brazil and Iran — through the 2008 financial crisis, the Belt and Road Initiative, the US–China trade war, and the pandemic, with three machine-coded databases (GDELT, ICEWS, Phoenix) and one expert-coded index (Tsinghua) measured side by side.

## What the audit found

1. **Agreement is a coverage property, not a database property.** The same two databases correlate at ρ = **0.633** for China–Japan and ρ = **0.031** for China–Brazil (n = 207).
2. **Machines capture behavior; experts judge intensity.** The four databases are not noisy versions of one another — they measure different things.
3. **The choice of database can flip a conclusion.** In a same-specification, four-database horse race, the Phoenix export coefficient turns negative (β = **−0.0062**, p = 0.005).
4. **The best instrument depends on the audience.** Trade co-moves with GDELT (β = **0.0127**, p = 0.026); public opinion is best matched by Phoenix (β = **0.090**, p = 0.002).

## Which database should you use?

A practical summary for readers who just need a defensible choice:

| Research question | What the data show |
|---|---|
| Trade, sanctions, economic statecraft | **GDELT** — the only database that co-moves with trade flows (β = 0.0127, p = 0.026) |
| Public opinion, soft power | All four work; **Phoenix** wins the horse race (β = 0.090, p = 0.002) |
| High-media-coverage partners (Japan, US, …) | Databases largely agree — any choice defensible |
| Low-coverage partners (Brazil, …) | Treat any single-database result with caution (ρ as low as 0.031) |

![Machines capture behavior, experts judge intensity](figures/Figure2.png)

*Figure 2. Gold-standard hit rates by event type (a) and event-window responses to negative vs positive events (b).*

## What this makes possible

Beyond the findings themselves, this repository is meant to be infrastructure for other people's work. The 712-event gold standard is an open, double-coded benchmark for China's bilateral relations: any new database, coding model, or LLM-based event extractor can now be validated against a shared ground truth instead of an ad hoc sample. The three-layer audit design — consistency, validity, consequences — is portable: it can be applied to other country pairs, other regions, and other event-data ecosystems with minimal modification. The monthly panel (China × 25 partners, 2002–2025) and the six-source opinion series are reusable inputs for research on trade politics, economic statecraft, and public diplomacy. And because every number recomputes in seconds, the repository can serve as a teaching example of end-to-end reproducible research in political methodology.

## Reproduce in 30 seconds

```bash
pip install -r requirements.txt                       # Python deps; R deps in code/R_packages.txt
python verification/verify_headline_stats.py          # headline numbers recomputed independently, PASS/FAIL printed
Rscript code/07_figures/figures_R/fig02_v3.R          # Figure 2 regenerated with built-in QA gates
```

Scripts carry the author's machine paths; redirect to this repo's folders as documented in [`docs/PIPELINE.md`](docs/PIPELINE.md).

## Verification

Every number in the paper was re-derived from this repository before release (details in [`docs/VERIFICATION.md`](docs/VERIFICATION.md)):

- **End-to-end Python reproduction**: the aggregation script re-run on the 2.36 GB raw retrieval CSV reproduces the released monthly scores byte-identical (md5-matched).
- **End-to-end R reproduction**: Figure 2 regenerated from package files alone; all built-in QA gates passed (hit rates 67.5 / 51.3 / 75.8; Phoenix IRF −1.87 / +0.43).
- **Headline statistics recomputed** from released scores: 0.633 / 0.031 (n = 207) reproduced exactly.
- Full-file **md5 manifest** (1,064 files) plus row-count assertions (panel n = 6,685; events = 712; …).

## Design of the audit

Three layers, one question. *Consistency*: do the databases agree with each other (pairwise correlations, directional agreement, five aggregation algorithms)? *Validity*: do they capture what experts say happened (712-event gold standard, hit rates by type and window)? *Consequences*: does the choice change the answer (same-equation PPML-HDFE horse races on trade and public opinion, local projections h = 0–6, event studies with 1,000× permutation falsification)?

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

## Data availability

Raw event data (3.5 GB: GDELT/ICEWS retrievals, Phoenix source package) and the full unabridged package are archived on Zenodo: **[doi:10.5281/zenodo.21862534](https://doi.org/10.5281/zenodo.21862534)**. Source databases are public: GDELT Project, ICEWS ([doi:10.7910/DVN/28075](https://doi.org/10.7910/DVN/28075)), Phoenix ([doi:10.13012/B2IDB-0647142_V3](https://doi.org/10.13012/B2IDB-0647142_V3)).

## Citation

See `CITATION.cff`. If you use the 712-event gold standard or the audit framework, please cite the manuscript (preprint available from the authors).

## License

Code: MIT (see [LICENSE](LICENSE)). Data (derived indices, gold-standard events, appendix tables): CC-BY 4.0 (see [LICENSE-DATA.md](LICENSE-DATA.md)). Source databases remain under their original publishers' terms.

---

*This project is a small contribution to a shared problem. We hope the gold standard, the panel, and the audit design save others some of the trial and error we went through — and we would be glad to hear where they fall short.*
