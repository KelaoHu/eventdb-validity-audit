library(data.table)

DATA_DIR <- "C:/Users/胡克劳/Desktop/311工程数据/07_数据库与民调"
IN_DIR   <- file.path(DATA_DIR, "01_清洗后")
OUT_DIR  <- file.path(DATA_DIR, "02_分析结果")

# ---- 1. Load events ----
events <- fread(file.path(DATA_DIR, "..", "02_中间数据_分数与面板", "月度分数_公平覆盖期", "events_712.csv"),
                encoding = "UTF-8")
events[, year := as.integer(substr(event_date, 1, 4))]

# ---- 2. Load polling panel and Pew17 country list ----
paired <- fread(file.path(IN_DIR, "paired_panel_annual.csv"), encoding = "UTF-8")
pew_core <- paired[source == "Pew Research Center"]
pew_core[, n_obs := .N, by = country]
pew_core <- pew_core[n_obs > 2 & year >= 2005 & year <= 2019]
pew_core[, polling_z_pew := (favorable - mean(favorable, na.rm = TRUE)) / 
                              sd(favorable, na.rm = TRUE)]

pew17_countries <- sort(unique(pew_core$country))

cat(sprintf("Pew17 countries: %d\n", length(pew17_countries)))
cat(sprintf("Polling panel (Pew core): %d rows, %d countries\n", nrow(pew_core), uniqueN(pew_core$country)))

# ---- 3. Filter events to Pew17 × 2005-2019 ----
events_pew <- events[country_en %in% pew17_countries & year >= 2005 & year <= 2019]
cat(sprintf("\nEvents in Pew17×2005-2019: %d\n", nrow(events_pew)))

# ---- 4. Aggregate to country-year ----
# 4a: Impact-based counts
event_counts_impact <- events_pew[, .(
  n_events_total  = .N,
  n_positive      = sum(impact == "positive"),
  n_negative      = sum(impact == "negative"),
  n_neutral       = sum(impact == "neutral")
), by = .(country = country_en, year)]
event_counts_impact[, has_negative := as.integer(n_negative > 0)]
event_counts_impact[, has_positive := as.integer(n_positive > 0)]
event_counts_impact[, has_any_event := as.integer(n_events_total > 0)]

# 4b: Visit-level counts (for signal gradient E2)
visit_counts <- events_pew[!is.na(visit_level), .(
  n_visit_total          = .N,
  n_visit_state_head     = sum(visit_level == "state_head"),
  n_visit_gov_head       = sum(visit_level == "government_head"),
  n_visit_china_to_partner = sum(visit_direction == "china_to_partner"),
  n_visit_partner_to_china = sum(visit_direction == "partner_to_china"),
  n_visit_third_party      = sum(visit_direction == "third_party_meeting")
), by = .(country = country_en, year)]

# 4c: Category-based counts (for E4)
# Conflict categories
conflict_cats <- c("Negative strategic positioning", "Sovereignty dispute",
                   "Diplomatic protest / friction", "Economic sanction / tariff barrier",
                   "Tech control / export restriction", "Security threat",
                   "Detention / judicial dispute")
# Cooperative categories
coop_cats <- c("Economic win-win cooperation", "Strategic partnership upgrade",
               "Cultural / people-to-people cooperation", "Military / security cooperation")

event_counts_cat <- events_pew[, .(
  n_conflict    = sum(event_category_en %in% conflict_cats),
  n_cooperative = sum(event_category_en %in% coop_cats)
), by = .(country = country_en, year)]
event_counts_cat[, has_conflict := as.integer(n_conflict > 0)]

# 4d: Specific category dummies (for E3 supplementary, only if N>=20)
for (cat_name in unique(events_pew$event_category_en)) {
  cat_n <- events_pew[event_category_en == cat_name, .N]
  if (cat_n >= 20) {
    cat_safe <- gsub("[ /-]", "_", tolower(cat_name))
    cat_counts <- events_pew[event_category_en == cat_name, .(
      n = .N
    ), by = .(country = country_en, year)]
    setnames(cat_counts, "n", paste0("n_", cat_safe))
    event_counts_cat <- merge(event_counts_cat, cat_counts,
                              by = c("country", "year"), all = TRUE)
  }
}

# ---- 5. Merge all event counts ----
event_annual <- merge(event_counts_impact, visit_counts,
                      by = c("country", "year"), all = TRUE)
event_annual <- merge(event_annual, event_counts_cat,
                      by = c("country", "year"), all = TRUE)

# Fill NA with 0 for counts, 0 for binaries
count_cols <- grep("^n_", names(event_annual), value = TRUE)
binary_cols <- grep("^has_", names(event_annual), value = TRUE)
event_annual[, (count_cols) := lapply(.SD, function(x) fifelse(is.na(x), 0, x)), .SDcols = count_cols]
event_annual[, (binary_cols) := lapply(.SD, function(x) fifelse(is.na(x), 0, x)), .SDcols = binary_cols]

# ---- 6. Merge with polling panel ----
paired_events <- merge(pew_core, event_annual,
                       by = c("country", "year"), all.x = TRUE)

# Fill missing event variables for country-years with 0 events
paired_events[, (count_cols) := lapply(.SD, function(x) fifelse(is.na(x), 0, x)), .SDcols = count_cols]
paired_events[, (binary_cols) := lapply(.SD, function(x) fifelse(is.na(x), 0, x)), .SDcols = binary_cols]

# ---- 7. Reports ----
cat(sprintf("\nMerged panel: %d rows, %d countries\n", nrow(paired_events), uniqueN(paired_events$country)))
cat(sprintf("Country-years with >=1 event: %d/%d (%.0f%%)\n",
    sum(paired_events$n_events_total > 0), nrow(paired_events),
    100 * sum(paired_events$n_events_total > 0) / nrow(paired_events)))
cat(sprintf("Country-years with negative event: %d (%.0f%%)\n",
    sum(paired_events$has_negative), 100 * sum(paired_events$has_negative) / nrow(paired_events)))

cat("\nEvent variable summary:\n")
for (v in c(count_cols, binary_cols)) {
  vals <- paired_events[[v]]
  cat(sprintf("  %-35s mean=%.2f  sd=%.2f  max=%.0f  nonzero=%d\n",
      v, mean(vals), sd(vals), max(vals), sum(vals > 0)))
}

# ---- 8. Save ----
fwrite(paired_events, file.path(OUT_DIR, "paired_panel_events.csv"))
cat(sprintf("\nSaved: %s/paired_panel_events.csv\n", OUT_DIR))

# ---- 9. Category N report (for plan validation) ----
cat("\nEvent category sizes in Pew17×2005-2019 (for E3/E4 feasibility):\n")
cat_sizes <- events_pew[, .N, by = event_category_en][order(-N)]
for (i in seq_len(nrow(cat_sizes))) {
  flag <- if (cat_sizes$N[i] < 20) " [TOO SPARSE]" else if (cat_sizes$N[i] < 30) " [MARGINAL]" else ""
  cat(sprintf("  %-45s N=%3d%s\n", cat_sizes$event_category_en[i], cat_sizes$N[i], flag))
}
