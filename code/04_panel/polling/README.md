# polling — Public-Opinion Data Chain (Case 2)

Cleaning and analysis chain for the six independent polling sources used in the public-opinion case (paper §3.4; SI S4).

## Pipeline

`phase0_clean.py` → `01_cleaned/paired_panel_annual.csv` → `E0_events_merge.R` → `02_results/paired_panel_events.csv` (Pew 17 countries × 13 waves, N = 170) → `E1–E5` analyses → `robustness.R`

| Item | Role |
|---|---|
| `phase0_clean.py` | Six-source polling data cleaning and country-year pairing |
| `analysis.R` / `robustness.R` | Main regressions and robustness checks |
| `E0_events_merge.R` | Merge 712 gold-standard events (annual aggregation) into the opinion panel |
| `E1_event_presence.R` | Negative-event years → opinion (β = −0.190, p = 0.016) |
| `E2_signal_gradient.R` | Visit-level gradient (gov-head 0.277 > state-head 0.157) |
| `E3_negative_events.R` | Negative-event analyses |
| `E4_moderation.R` | Interaction/moderation tests |
| `E5_case_enumeration.R` | Case enumeration (19 matched cases, 78.9% directional) |
| `vif_reproduce.py` | VIF reproduction check |
| `01_cleaned/` | Cleaned annual panel (input) |
| `02_results/` | Result CSVs (E1a–E5, T1.1–T1.4, robustness, BH correction) |
| `favorability_by_year.csv` | Favorability toward China by country-year (source layer) |
| `favorability_provenance.md` | Provenance notes for the six sources |
| `polling_sources_and_citations.md` | Full source & citation documentation |
