# Project Overview — For Prospective Advisors

**One sentence**: I built a complete empirical pipeline that audits four political event databases (GDELT, ICEWS, Phoenix, Tsinghua index) against a hand-curated gold standard, and shows that *no database is universally best — validity is audience-specific*.

## The research question

Two generations of scholars estimated the politics–trade relationship with a single political-relations measure and never tested whether conclusions survive a change of database. I asked: How much do four major event databases disagree (RQ1)? Why (RQ2)? Does database choice change substantive conclusions (RQ3)? Does the best database switch with the audience (RQ4)?

## What I built (data engineering)

| Stage | Scale / method |
|---|---|
| Event retrieval | **9.66 million** machine-coded events filtered to China × 25 trading-partner dyads (strict actor-country matching, multiprocess Python; GDELT zips + ICEWS Dataverse + Phoenix package) |
| Gold standard | **712 hand-curated major bilateral events** (2002–2025), multi-source verified; independent second coder, **Cohen's κ = 0.866** |
| Monthly indices | Two-stage day→month aggregation (geometric mean in log space, +11 shift); full and fair-coverage calibers |
| Panels | Monthly trade panel (n = 6,685: IMF DOTS + scores + GDP + REER + FTA) and Pew opinion panel (17 × 13, N = 170, six polling sources) |
| Tsinghua index digitization | Dual-channel PDF extraction (PyMuPDF vs text) with cross-channel validation |

## Methods

PPML-HDFE gravity estimation with two-way fixed effects; Local Projections (h = 0–6); event-study designs with **1,000× permutation falsification** (plus 500× label permutation and 200× × 3-class continuous-score placebos); Bai–Perron structural-break tests; BH-FDR multiple-testing control; Spearman/directional consistency suites; same-equation horse races across databases.

## Verification culture

Every number was re-derived before release (see `docs/VERIFICATION.md`): md5 lineage checks, row-count assertions, statistic recomputation, and **end-to-end re-execution** — the aggregation script re-run on 2.36 GB of raw events reproduces the released scores byte-identically, and figure scripts carry built-in QA gates that print PASS/FAIL. Anyone can spot-check the headline numbers in 30 seconds: `python examples/verify_headline_stats.py`.

## Skill matrix

- **Python**: multiprocess large-scale retrieval (9.66M events), pandas pipelines, SDMX/Dataverse/Comtrade APIs, OCR digitization
- **R**: fixest (PPML-HDFE), Local Projections, bootstrap/permutation inference, ggplot2 figure production (300 dpi, QA-gated)
- **Research engineering**: versioned pipeline with lineage manifests, fair/full double-run comparison ledger, dual-language documentation

## Status

Manuscript under review at *Scientific Reports* (submission-ready; preprint available on request).

---

## 中文摘要

本项目是我独立完成的一项实证工程：对四个政治事件数据库做"一致性—效度—因果推断"三层审计。数据侧完成 966 万条机器编码事件的中国×25 国检索、712 条人工核查黄金标准事件库（κ=0.866）、月度指数聚合与两套面板构建；方法侧用 PPML-HDFE、Local Projections、事件研究与置换检验完成估计；工程侧建立全链路血缘清单与端到端复现验证（头条数字 30 秒可独立重算）。论文已在投稿流程中。
