# E5: Descriptive Case Enumeration — Sparse Event Categories (N<20)

library(data.table)

DATA_DIR <- "C:/Users/胡克劳/Desktop/311工程数据/07_数据库与民调"
OUT_DIR  <- file.path(DATA_DIR, "02_分析结果")
EVENTS_FILE <- file.path(DATA_DIR, "..", "02_中间数据_分数与面板", "月度分数_公平覆盖期", "events_712.csv")

events <- fread(EVENTS_FILE, encoding = "UTF-8")
events[, year := as.integer(substr(event_date, 1, 4))]

paired <- fread(file.path(OUT_DIR, "paired_panel_events.csv"), encoding = "UTF-8")
pew17 <- sort(unique(paired$country))

# Filter to Pew17 × 2005-2019
events <- events[country_en %in% pew17 & year >= 2005 & year <= 2019]

cat("============================================================\n")
cat("E5: Descriptive Case Enumeration — Sparse Event Types (N<20)\n")
cat("============================================================\n\n")
cat("METHOD: For each event in N<20 categories, locate the country-year\n")
cat("  in the polling panel. Report polling_z_pew and its change from\n")
cat("  the previous available polling year.\n")
cat("DISCLAIMER: Descriptive only. No statistical inference is attempted.\n")
cat("  These patterns are presented as qualitative evidence of direction\n")
cat("  consistency. They do not support causal or generalizable claims.\n")
cat("  Per Nature-statistics: 'do not use significance language for\n")
cat("  descriptive patterns. State N, direction, and proportion.'\n\n")

# ---- Helper: get polling context for each event ----
get_polling_context <- function(event_country, event_year) {
  # Get polling for this year and previous available year
  this_yr <- paired[country == event_country & year == event_year,
                    .(polling_z_pew, favorable)]
  prev_yrs <- paired[country == event_country & year < event_year,
                     .(year, polling_z_pew, favorable)][order(-year)]
  
  list(
    pz_this = if (nrow(this_yr) > 0) round(this_yr$polling_z_pew[1], 3) else NA_real_,
    fav_this = if (nrow(this_yr) > 0) round(this_yr$favorable[1], 1) else NA_real_,
    pz_prev = if (nrow(prev_yrs) > 0) round(prev_yrs$polling_z_pew[1], 3) else NA_real_,
    fav_prev = if (nrow(prev_yrs) > 0) round(prev_yrs$favorable[1], 1) else NA_real_,
    prev_year = if (nrow(prev_yrs) > 0) prev_yrs$year[1] else NA_integer_
  )
}

# ---- Categories to enumerate ----
# Groups merged for presentation clarity
sparse_groups <- list(
  "制裁与科技管制 (Sanctions + Tech Control)" = c(
    "Economic sanction / tariff barrier", "Tech control / export restriction"),
  "外交抗议 (Diplomatic Protest)" = c("Diplomatic protest / friction"),
  "军事与安全 (Military/Security)" = c("Military / security cooperation", "Security threat"),
  "拘留与司法 (Detention/Judicial)" = c("Detention / judicial dispute"),
  "人文合作 (Cultural Cooperation)" = c("Cultural / people-to-people cooperation"),
  "国内政治变动 (Domestic Politics)" = c("Policy shift / domestic politics"),
  "负面战略定位 (Negative Strategic Positioning)" = c("Negative strategic positioning"),
  "疫情冲击 (Pandemic Shock)" = c("Pandemic / disaster shock")
)

cat("--- Enumeration by Event Category ---\n\n")

all_cases <- list()

for (group_name in names(sparse_groups)) {
  cats <- sparse_groups[[group_name]]
  group_events <- events[event_category_en %in% cats]
  n_events <- nrow(group_events)
  
  cat(sprintf("## %s  (N=%d)\n\n", group_name, n_events))
  
  if (n_events == 0) {
    cat("  No events in Pew17×2005-2019 window.\n\n")
    next
  }
  
  # Determine expected direction
  negative_cats <- c("Economic sanction / tariff barrier", "Tech control / export restriction",
                     "Diplomatic protest / friction", "Security threat",
                     "Detention / judicial dispute", "Negative strategic positioning",
                     "Pandemic / disaster shock")
  is_negative <- any(cats %in% negative_cats)
  
  expected_label <- if (is_negative) "↓ (预期民意下行)" else "unspecified"
  
  directions <- c()
  
  for (i in seq_len(nrow(group_events))) {
    ev <- group_events[i]
    ctx <- get_polling_context(ev$country_en, ev$year)
    
    # Determine direction of polling change
    if (!is.na(ctx$pz_this) && !is.na(ctx$pz_prev)) {
      delta <- ctx$pz_this - ctx$pz_prev
      dir_symbol <- if (delta < -0.05) "↓" else if (delta > 0.05) "↑" else "→"
      directions <- c(directions, dir_symbol)
      delta_str <- sprintf("%+.3f", delta)
    } else {
      dir_symbol <- "?"
      delta_str <- "N/A"
      directions <- c(directions, dir_symbol)
    }
    
    cat(sprintf("  %d. %s | %s | %d-%02d | %s\n",
        i, ev$country_en, ev$year, ev$year,
        if (!is.na(as.integer(substr(ev$event_date, 6, 7)))) as.integer(substr(ev$event_date, 6, 7)) else 0,
        ev$event_name))
    cat(sprintf("     poll_z: this=%-6s prev(yr %s)=%-6s  Δ=%s %s\n",
        if (is.na(ctx$pz_this)) "N/A" else sprintf("%+.3f", ctx$pz_this),
        if (is.na(ctx$prev_year)) "N/A" else as.character(ctx$prev_year),
        if (is.na(ctx$pz_prev)) "N/A" else sprintf("%+.3f", ctx$pz_prev),
        delta_str, dir_symbol))
    
    all_cases[[length(all_cases) + 1]] <- data.table(
      group = group_name,
      country = ev$country_en,
      year = ev$year,
      event_name = ev$event_name,
      event_category = ev$event_category_en,
      impact = ev$impact,
      pz_this = ctx$pz_this,
      pz_prev = ctx$pz_prev,
      prev_year = ctx$prev_year,
      delta_pz = if (!is.na(ctx$pz_this) && !is.na(ctx$pz_prev))
        round(ctx$pz_this - ctx$pz_prev, 3) else NA_real_,
      direction = dir_symbol
    )
  }
  
  # Summary for this group
  n_with_data <- sum(directions != "?")
  if (n_with_data > 0 && is_negative) {
    n_expected <- sum(directions == "↓")
    cat(sprintf("\n  Summary: %d/%d cases (%d%%) show %s polling after event\n",
        n_expected, n_with_data,
        round(100 * n_expected / n_with_data),
        expected_label))
  } else if (n_with_data > 0) {
    n_up <- sum(directions == "↑")
    n_down <- sum(directions == "↓")
    n_flat <- sum(directions == "→")
    cat(sprintf("\n  Direction: %d↑ %d↓ %d→ (N=%d with polling data)\n",
        n_up, n_down, n_flat, n_with_data))
  }
  cat("\n")
}

# ---- Overall Summary ----
cat("============================================================\n")
cat("E5: OVERALL SUMMARY\n")
cat("============================================================\n\n")

# Count by expected direction
all_df <- rbindlist(all_cases)
all_df <- all_df[!is.na(direction) & direction != "?"]

negative_groups <- names(sparse_groups)[c(1, 2, 4, 7, 8)]  # 制裁, 抗议, 拘留, 负面定位, 疫情
neg_cases <- all_df[group %in% negative_groups]

if (nrow(neg_cases) > 0) {
  n_neg_expected <- sum(neg_cases$direction == "↓")
  cat(sprintf("Negative-impact events (expected ↓):\n"))
  cat(sprintf("  %d/%d cases (%d%%) show polling decrease\n\n",
      n_neg_expected, nrow(neg_cases),
      round(100 * n_neg_expected / nrow(neg_cases))))
}

other_cases <- all_df[!group %in% negative_groups]
if (nrow(other_cases) > 0) {
  cat(sprintf("Non-negative events (no directional expectation):\n"))
  cat(sprintf("  %d cases: %d↑ %d↓ %d→\n\n",
      nrow(other_cases),
      sum(other_cases$direction == "↑"),
      sum(other_cases$direction == "↓"),
      sum(other_cases$direction == "→")))
}

cat(sprintf("TOTAL cases enumerated: %d across %d categories\n",
    nrow(all_df), uniqueN(all_df$group)))

# ---- SAVE ----
fwrite(all_df, file.path(OUT_DIR, "E5_case_enumeration.csv"))

cat("\n============================================================\n")
cat("E5 COMPLETE\n")
cat("============================================================\n")
cat("NATURE-STATISTICS COMPLIANCE CHECKLIST:\n")
cat("  [x] No p-values reported for individual cases\n")
cat("  [x] No regression models fitted on N<20 categories\n")
cat("  [x] N, direction proportion, and context stated for each group\n")
cat("  [x] 'Descriptive only, not generalizable' disclaimer\n")
cat("  [x] Expected direction declared before enumeration\n")
cat("  [x] Missing data ('N/A') explicitly flagged\n")
