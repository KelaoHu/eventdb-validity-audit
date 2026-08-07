# Robustness Checks — All Tier 1 + Event tests under exclusion conditions

library(data.table)
library(fixest)

DATA_DIR <- "C:/Users/胡克劳/Desktop/311工程数据/07_数据库与民调"
OUT_DIR  <- file.path(DATA_DIR, "02_分析结果")

paired <- fread(file.path(OUT_DIR, "paired_panel_events.csv"), encoding = "UTF-8")
DBS <- c("gdelt", "icews", "phoenix")
DB_LABELS <- c(gdelt = "GDELT", icews = "ICEWS", phoenix = "Phoenix")

# ===========================================================================
# Define all robustness conditions
# ===========================================================================
robustness_conditions <- list(
  R1_exclude_US = list(
    label = "Exclude United States",
    filter = function(d) d[country != "United States"],
    note = "US has 34 events (most), 13 polling obs"
  ),
  R2_exclude_JP = list(
    label = "Exclude Japan",
    filter = function(d) d[country != "Japan"],
    note = "Japan has 49 events (most), 12 polling obs"
  ),
  R3_exclude_US_JP = list(
    label = "Exclude US + Japan",
    filter = function(d) d[!country %in% c("United States", "Japan")],
    note = "Removes 2 largest event contributors (34+49=83 events)"
  ),
  R4_exclude_2019 = list(
    label = "Exclude 2019",
    filter = function(d) d[year != 2019],
    note = "Phoenix 2019 only 3 months; removes partial-year bias"
  ),
  R5_2008_2019 = list(
    label = "Only 2008-2019",
    filter = function(d) d[year >= 2008],
    note = "Exclude 2005-2007 (sparse events, early Pew waves)"
  )
)

# ===========================================================================
# Run each robustness check
# ===========================================================================
cat("============================================================\n")
cat("ROBUSTNESS CHECKS\n")
cat("============================================================\n\n")

all_robust <- list()

for (rc_name in names(robustness_conditions)) {
  rc <- robustness_conditions[[rc_name]]
  d <- rc$filter(paired)
  
  cat(sprintf("--- %s: %s ---\n", rc_name, rc$label))
  cat(sprintf("  N=%d, %d countries. %s\n\n", nrow(d), uniqueN(d$country), rc$note))
  
  # ---- T1.1: Within-country mean ρ ----
  for (db in DBS) {
    score_col <- paste0(db, "_mean")
    sub <- na.omit(d[, .(country, year, score = get(score_col), polling_z_pew)])
    if (nrow(sub) < 30) next
    within_rs <- sapply(unique(sub$country), function(cty) {
      s <- sub[country == cty]
      if (nrow(s) >= 5) cor(s$score, s$polling_z_pew, method = "spearman") else NA
    })
    within_rs <- within_rs[!is.na(within_rs)]
    rw <- mean(within_rs)
    
    all_robust[[length(all_robust) + 1]] <- data.table(
      condition = rc_name, test = "T1.1_within", db = DB_LABELS[db],
      value = round(rw, 3), metric = "mean_rho",
      n = nrow(sub), n_countries = length(within_rs)
    )
  }
  
  # ---- T1.3: Asymmetry ----
  for (db in DBS) {
    score_col <- paste0(db, "_mean")
    sub <- na.omit(d[, .(country, year, score = get(score_col), polling_z_pew)])
    if (nrow(sub) < 30) next
    setorder(sub, country, year)
    sub[, `:=`(score_delta = score - shift(score),
               poll_delta = polling_z_pew - shift(polling_z_pew)), by = country]
    delta <- na.omit(sub[, .(country, year, score_delta, poll_delta)])
    country_diff <- delta[, .(
      neg_mean = mean(poll_delta[score_delta < 0], na.rm = TRUE),
      pos_mean = mean(poll_delta[score_delta > 0], na.rm = TRUE),
      n_neg = sum(score_delta < 0, na.rm = TRUE),
      n_pos = sum(score_delta > 0, na.rm = TRUE)
    ), by = country]
    country_diff[, diff := neg_mean - pos_mean]
    country_diff <- na.omit(country_diff[n_neg >= 2 & n_pos >= 2])
    
    if (nrow(country_diff) >= 5) {
      ct <- t.test(country_diff$diff)
      d_val <- mean(country_diff$diff) / sd(country_diff$diff)
      
      all_robust[[length(all_robust) + 1]] <- data.table(
        condition = rc_name, test = "T1.3_asym", db = DB_LABELS[db],
        value = round(ct$p.value, 4), metric = "p_value",
        n = nrow(sub), n_countries = nrow(country_diff),
        d = round(d_val, 3)
      )
    }
  }
  
  # ---- T1.4: FE Panel ----
  for (db in DBS) {
    score_col <- paste0(db, "_mean")
    sub <- na.omit(d[, .(country, year, score = get(score_col), polling_z_pew)])
    if (nrow(sub) < 30 || uniqueN(sub$country) < 5) next
    sub[, `:=`(country = as.factor(country), year = as.factor(year))]
    
    m <- tryCatch({
      feols(polling_z_pew ~ score | country + year, data = sub, cluster = ~country)
    }, error = function(e) NULL)
    
    if (!is.null(m)) {
      all_robust[[length(all_robust) + 1]] <- data.table(
        condition = rc_name, test = "T1.4_FE", db = DB_LABELS[db],
        value = round(pvalue(m)["score"], 4), metric = "p_value",
        beta = round(coef(m)["score"], 4),
        n = nobs(m), n_countries = uniqueN(sub$country),
        r2 = round(r2(m, type = "wr2"), 3)
      )
    }
  }
  
  # ---- E3: Negative events ----
  sub <- na.omit(d[, .(country, year, polling_z_pew, has_negative)])
  n_neg <- sum(sub$has_negative)
  if (n_neg >= 10 && uniqueN(sub$country) >= 5) {
    sub[, `:=`(country = as.factor(country), year = as.factor(year))]
    m <- tryCatch({
      feols(polling_z_pew ~ has_negative | country + year, data = sub, cluster = ~country)
    }, error = function(e) NULL)
    
    if (!is.null(m)) {
      all_robust[[length(all_robust) + 1]] <- data.table(
        condition = rc_name, test = "E3_neg_event", db = "ALL",
        value = round(pvalue(m)["has_negative"], 4), metric = "p_value",
        beta = round(coef(m)["has_negative"], 4),
        n = nobs(m), n_countries = uniqueN(sub$country),
        r2 = round(r2(m, type = "wr2"), 3)
      )
    }
  }
  
  cat(sprintf("  Completed %s\n\n", rc_name))
}

# ===========================================================================
# SUMMARY TABLE
# ===========================================================================
robust_df <- rbindlist(all_robust, fill = TRUE)

# Baseline values from main analysis for comparison
baseline <- data.table(
  condition = "BASELINE",
  test = c(rep("T1.1_within", 3), rep("T1.3_asym", 3), rep("T1.4_FE", 3), "E3_neg_event"),
  db = c("GDELT","ICEWS","Phoenix","GDELT","ICEWS","Phoenix","GDELT","ICEWS","Phoenix","ALL"),
  value = c(0.402, 0.347, 0.349, 0.0116, 0.0396, 0.1835, 0.0022, 0.0015, 0.0002, 0.0155),
  metric = c(rep("mean_rho", 3), rep("p_value", 7))
)

cat("============================================================\n")
cat("ROBUSTNESS SUMMARY\n")
cat("============================================================\n\n")
cat("BASELINE (Pew 17-country, 2005-2019, N=170):\n")
for (i in seq_len(nrow(baseline))) {
  cat(sprintf("  %-15s %-6s %s=%-10s\n",
      baseline$test[i], baseline$db[i], baseline$metric[i],
      if (baseline$metric[i] == "p_value") sprintf("%.4f", baseline$value[i])
      else sprintf("%.3f", baseline$value[i])))
}

cat("\nROBUSTNESS:\n")
cat(sprintf("%-20s %-12s %-6s %-12s %s\n", "Condition", "Test", "DB", "Value", "vs Baseline"))
cat(paste(rep("-", 70), collapse = ""), "\n")

for (rc_name in names(robustness_conditions)) {
  rc <- robustness_conditions[[rc_name]]
  sub <- robust_df[condition == rc_name]
  if (nrow(sub) == 0) next
  
  for (i in seq_len(nrow(sub))) {
    row <- sub[i]
    # Find baseline match
    bl <- baseline[test == row$test & db == row$db]
    if (nrow(bl) == 0) next
    
    if (row$metric == "p_value") {
      bl_sig <- bl$value < 0.05
      ro_sig <- row$value < 0.05
      if (bl_sig && ro_sig) flag <- "[stable]"
      else if (!bl_sig && !ro_sig) flag <- "[stable n.s.]"
      else if (bl_sig && !ro_sig) flag <- "[LOST significance]"
      else flag <- "[GAINED significance]"
      
      cat(sprintf("  %-20s %-12s %-6s p=%-12s %s\n",
          rc$label, row$test, row$db,
          sprintf("%.4f", row$value), flag))
    } else {
      diff_val <- row$value - bl$value
      flag <- if (abs(diff_val) < 0.05) "[stable]" else sprintf("[Δ=%+.3f]", diff_val)
      cat(sprintf("  %-20s %-12s %-6s ρ=%-12s %s\n",
          rc$label, row$test, row$db,
          sprintf("%.3f", row$value), flag))
    }
  }
}

# ===========================================================================
# Final stability count
# ===========================================================================
cat("\n============================================================\n")
cat("STABILITY ASSESSMENT\n")
cat("============================================================\n\n")

pval_rows <- robust_df[metric == "p_value"]
pval_rows[, bl_val := baseline$value[match(paste(test, db), paste(baseline$test, baseline$db))]]
pval_rows[, bl_sig := bl_val < 0.05]
pval_rows[, ro_sig := value < 0.05]
pval_rows[, stable := (bl_sig == ro_sig)]

n_total <- nrow(pval_rows)
n_stable <- sum(pval_rows$stable)
n_lost <- sum(pval_rows$bl_sig & !pval_rows$ro_sig)
n_gained <- sum(!pval_rows$bl_sig & pval_rows$ro_sig)

cat(sprintf("Significance stability across %d robustness checks:\n", n_total))
cat(sprintf("  %d/%d (%.0f%%) stable (both sig or both n.s.)\n",
    n_stable, n_total, 100*n_stable/n_total))
cat(sprintf("  %d lost significance\n", n_lost))
cat(sprintf("  %d gained significance\n", n_gained))

if (n_lost > 0) {
  cat("\n  Tests that lost significance:\n")
  lost_rows <- pval_rows[bl_sig & !ro_sig]
  for (i in seq_len(nrow(lost_rows))) {
    cat(sprintf("    %s | %s | %s: baseline p=%.4f → robust p=%.4f\n",
        lost_rows$condition[i], lost_rows$test[i], lost_rows$db[i],
        lost_rows$bl_val[i], lost_rows$value[i]))
  }
}

# SAVE
fwrite(robust_df, file.path(OUT_DIR, "robustness_checks.csv"))

cat("\n============================================================\n")
cat("ROBUSTNESS COMPLETE\n")
cat("============================================================\n")
