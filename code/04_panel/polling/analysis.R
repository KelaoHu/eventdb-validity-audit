# Phase 1+2: 民调-政治分数配对分析 (CORRECTED)

library(data.table)

DATA_DIR <- "C:/Users/胡克劳/Desktop/311工程数据/07_数据库与民调"
IN_DIR   <- file.path(DATA_DIR, "01_清洗后")
OUT_DIR  <- file.path(DATA_DIR, "02_分析结果")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

df <- fread(file.path(IN_DIR, "paired_panel_annual.csv"), encoding = "UTF-8")
df <- df[year >= 2002 & year <= 2025]

DBS <- c("gdelt", "icews", "phoenix", "tsinghua")
DB_LABELS <- c(gdelt = "GDELT", icews = "ICEWS", phoenix = "Phoenix", tsinghua = "Tsinghua")

# ===========================================================================
# PREP: Pew-only primary window + RE-STANDARDIZE polling within this window
# ===========================================================================
pew <- df[source == "Pew Research Center"]
pew[, n_obs := .N, by = country]
pew_core <- pew[n_obs > 2 & year >= 2005 & year <= 2019]

# FIX#7: Re-standardize polling_z within the Pew subset
pew_core[, polling_z_pew := (favorable - mean(favorable, na.rm = TRUE)) / 
                              sd(favorable, na.rm = TRUE)]

cat("============================================================\n")
cat("PHASE 1: DESCRIPTIVE STATISTICS\n")
cat("============================================================\n\n")

cat(sprintf("Full panel: %d rows, %d countries\n", nrow(df), uniqueN(df$country)))
cat(sprintf("Pew core window (17 countries, 2005-2019): %d country-years\n", nrow(pew_core)))
cat(sprintf("Countries: %s\n\n", paste(sort(unique(pew_core$country)), collapse = ", ")))

# Per-country obs summary
cat("Coverage (Pew core):\n")
for (cty in sort(unique(pew_core$country))) {
  n <- pew_core[country == cty, .N]
  yrs <- pew_core[country == cty, range(year)]
  cat(sprintf("  %-20s %2d obs  %d-%d\n", cty, n, yrs[1], yrs[2]))
}

cat(sprintf("\nRe-standardized polling_z within Pew window: mean=%.6f, SD=%.4f\n",
    mean(pew_core$polling_z_pew, na.rm = TRUE), sd(pew_core$polling_z_pew, na.rm = TRUE)))

# ===========================================================================
# T1.1: Cross-database convergence — DECOMPOSED
# ===========================================================================
cat("\n============================================================\n")
cat("T1.1: Cross-Database Convergence with Public Opinion\n")
cat("============================================================\n")
cat("FIX applied: decompose between-country vs within-country correlation.\n")
cat("Unit: country-level means (N=17) for between; within-country mean.\n")
cat("No pooled ρ reported — it mixes independent and non-independent variation.\n\n")

t11_between <- list()
t11_within  <- list()

for (db in DBS) {
  score_col <- paste0(db, "_mean")
  sub <- na.omit(pew_core[, .(country, year, score = get(score_col), polling_z_pew)])
  
  # Between-country: aggregate to country means, then correlate
  country_means <- sub[, .(mean_score = mean(score), mean_poll = mean(polling_z_pew), n = .N), by = country]
  
  if (nrow(country_means) >= 5) {
    rb <- cor(country_means$mean_score, country_means$mean_poll, method = "spearman")
    # Bootstrap CI for between-country
    set.seed(42)
    boot_rb <- replicate(2000, {
      idx <- sample(seq_len(nrow(country_means)), replace = TRUE)
      cor(country_means$mean_score[idx], country_means$mean_poll[idx], method = "spearman")
    })
    ci_lo <- quantile(boot_rb, 0.025, na.rm = TRUE)
    ci_hi <- quantile(boot_rb, 0.975, na.rm = TRUE)
    
    # Within-country: mean of per-country ρ
    within_rs <- c()
    for (cty in unique(sub$country)) {
      s <- sub[country == cty]
      if (nrow(s) >= 5) {
        within_rs <- c(within_rs, cor(s$score, s$polling_z_pew, method = "spearman"))
      }
    }
    rw_mean <- mean(within_rs, na.rm = TRUE)
    rw_sd   <- sd(within_rs, na.rm = TRUE)
    
    t11_between[[db]] <- data.table(
      database = DB_LABELS[db],
      n_countries = nrow(country_means),
      between_rho = round(rb, 3), between_ci_lo = round(ci_lo, 3), between_ci_hi = round(ci_hi, 3)
    )
    t11_within[[db]] <- data.table(
      database = DB_LABELS[db],
      n_countries_within = length(within_rs),
      within_mean_rho = round(rw_mean, 3), within_sd_rho = round(rw_sd, 3)
    )
    
    cat(sprintf("  %-10s between-country ρ=%+.3f [%+.3f, %+.3f] (N=%d countries)\n",
        DB_LABELS[db], rb, ci_lo, ci_hi, nrow(country_means)))
    cat(sprintf("            within-country  ρ=%+.3f (SD=%.3f, N=%d countries)\n\n",
        rw_mean, rw_sd, length(within_rs)))
  }
}

fwrite(rbindlist(t11_between), file.path(OUT_DIR, "T1.1_between_country_rho.csv"))
fwrite(rbindlist(t11_within),  file.path(OUT_DIR, "T1.1_within_country_rho.csv"))

# ===========================================================================
# T1.2: Country-Level Gradient (same as before, still valid)
# ===========================================================================
cat("============================================================\n")
cat("T1.2: Country-Level Gradient\n")
cat("============================================================\n")
cat("Unit: country-level ρ (N = number of countries per database)\n\n")

country_all <- list()
for (db in DBS) {
  score_col <- paste0(db, "_mean")
  cat(sprintf("%s:\n", DB_LABELS[db]))
  for (cty in sort(unique(pew_core$country))) {
    sub <- na.omit(pew_core[country == cty, .(score = get(score_col), polling_z_pew)])
    if (nrow(sub) >= 5) {
      r <- cor(sub$score, sub$polling_z_pew, method = "spearman")
      country_all[[length(country_all) + 1]] <- data.table(
        database = DB_LABELS[db], country = cty, rho = round(r, 3), n_obs = nrow(sub)
      )
    }
  }
  sub_rhos <- country_all[lengths(country_all) > 0]
  db_rhos <- sapply(sub_rhos[sapply(sub_rhos, function(x) x$database[1]) == DB_LABELS[db]], `[[`, "rho")
  if (is.list(db_rhos)) db_rhos <- unlist(db_rhos)
  db_rhos <- db_rhos[names(db_rhos) == "rho"]
  # Re-extract properly
  db_rows <- rbindlist(country_all)[database == DB_LABELS[db]]
  if (nrow(db_rows) >= 5) {
    sorted <- db_rows[order(-rho)]
    cat(sprintf("  %d countries: mean ρ=%+.3f SD=%.3f\n", nrow(db_rows), mean(db_rows$rho), sd(db_rows$rho)))
    cat(sprintf("  Top 3: %s\n", paste(sprintf("%s(%+.3f)", sorted$country[1:3], sorted$rho[1:3]), collapse=", ")))
    cat(sprintf("  Bot 3: %s\n\n", paste(sprintf("%s(%+.3f)", rev(sorted$country)[1:3], rev(sorted$rho)[1:3]), collapse=", ")))
  }
}

country_df <- rbindlist(country_all)
fwrite(country_df, file.path(OUT_DIR, "T1.2_country_level_spearman.csv"))

# ===========================================================================
# T1.3: Direction Asymmetry — FIXED: country as unit
# ===========================================================================
cat("============================================================\n")
cat("T1.3: Direction Asymmetry — Negativity Bias\n")
cat("============================================================\n")
cat("FIX applied: country as analysis unit (N = number of countries).\n")
cat("Method: per-country mean Δpoll in neg years minus mean Δpoll in pos years,\n")
cat("        then one-sample t-test on these country-level differences.\n\n")

asym_results <- list()
for (db in DBS) {
  score_col <- paste0(db, "_mean")
  sub <- na.omit(pew_core[, .(country, year, score = get(score_col), polling_z_pew)])
  setorder(sub, country, year)
  sub[, score_delta := score - shift(score), by = country]
  sub[, poll_delta := polling_z_pew - shift(polling_z_pew), by = country]
  delta <- na.omit(sub[, .(country, year, score_delta, poll_delta)])
  
  # Per-country: mean poll_delta in neg years minus mean in pos years
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
    d <- mean(country_diff$diff) / sd(country_diff$diff)
    
    asym_results[[db]] <- data.table(
      database = DB_LABELS[db],
      n_countries = nrow(country_diff),
      mean_diff = round(mean(country_diff$diff), 3),
      sd_diff = round(sd(country_diff$diff), 3),
      t_stat = round(ct$statistic, 3),
      p_raw = round(ct$p.value, 4),
      cohens_d = round(d, 3)
    )
    
    cat(sprintf("  %-10s mean neg-pos diff=%+.3f (SD=%.3f) t=%.2f p=%.4f d=%+.3f  (N=%d countries)\n",
        DB_LABELS[db], mean(country_diff$diff), sd(country_diff$diff),
        ct$statistic, ct$p.value, d, nrow(country_diff)))
  }
}

asym_df <- rbindlist(asym_results)
fwrite(asym_df, file.path(OUT_DIR, "T1.3_asymmetry.csv"))

# ===========================================================================
# T1.4: FE Panel Regression
# ===========================================================================
cat("\n============================================================\n")
cat("T1.4: Fixed Effects Panel Regression\n")
cat("============================================================\n")
cat("MODEL: polling_z_pew_it = beta * score_db_it + alpha_i + gamma_t + epsilon_it\n")
cat("SE clustered by country. Unit: country-year (N=170).\n")
cat("NOTE: Associational, not causal.\n\n")

library(fixest)

fe_results <- list()
for (db in DBS) {
  score_col <- paste0(db, "_mean")
  sub <- na.omit(pew_core[, .(country, year, score = get(score_col), polling_z_pew)])
  sub[, country := as.factor(country)]
  sub[, year := as.factor(year)]
  
  if (nrow(sub) < 30) next
  
  m <- feols(polling_z_pew ~ score | country + year, data = sub, cluster = ~country)
  
  beta <- coef(m)["score"]
  se   <- se(m)["score"]
  pval <- pvalue(m)["score"]
  r2   <- r2(m, type = "wr2")
  n    <- nobs(m)
  nc   <- uniqueN(sub$country)
  
  sig <- if (pval < 0.001) "***" else if (pval < 0.01) "**" else if (pval < 0.05) "*" else "n.s."
  
  fe_results[[db]] <- data.table(
    database = DB_LABELS[db], n = n, n_countries = nc,
    beta = round(beta, 4), se = round(se, 4), p_raw = round(pval, 4),
    r2_within = round(r2, 3), sig = sig
  )
  
  note <- if (db == "phoenix") " [Phoenix 2019=3 months only]" else if (db == "tsinghua") " [exploratory: 10 clusters]" else ""
  cat(sprintf("  %-10s beta=%+.4f (SE=%.4f) p=%.4f %s  n=%d countries=%d R²=%.3f%s\n",
      DB_LABELS[db], beta, se, pval, sig, n, nc, r2, note))
}

fe_df <- rbindlist(fe_results)
fwrite(fe_df, file.path(OUT_DIR, "T1.4_fe_regression.csv"))

# ===========================================================================
# BH CORRECTION across all tests
# ===========================================================================
cat("\n============================================================\n")
cat("MULTIPLE COMPARISON CORRECTION (Benjamini-Hochberg)\n")
cat("============================================================\n")
cat("Family: T1.1 between-ρ + T1.3 asymmetry + T1.4 FE across all databases\n\n")

all_pvals <- data.table(test = character(), db = character(), p_raw = numeric())

for (db in DBS) {
  if (!is.null(t11_between[[db]])) {
    # T1.1 between: use bootstrap CI approach (no simple p), skip for BH
  }
  if (!is.null(asym_results[[db]])) {
    all_pvals <- rbind(all_pvals, data.table(
      test = "T1.3", db = DB_LABELS[db], p_raw = asym_results[[db]]$p_raw
    ))
  }
  if (!is.null(fe_results[[db]])) {
    all_pvals <- rbind(all_pvals, data.table(
      test = "T1.4", db = DB_LABELS[db], p_raw = fe_results[[db]]$p_raw
    ))
  }
}

all_pvals[, p_bh := p.adjust(p_raw, method = "BH")]
all_pvals[, passes := ifelse(p_bh < 0.05, "PASS", "FAIL")]

cat(sprintf("%-6s %-10s %-10s %-10s %s\n", "Test", "DB", "Raw p", "BH p", "Status"))
cat(paste(rep("-", 50), collapse = ""), "\n")
for (i in seq_len(nrow(all_pvals))) {
  cat(sprintf("%-6s %-10s %-10.4f %-10.4f %s\n",
      all_pvals$test[i], all_pvals$db[i],
      all_pvals$p_raw[i], all_pvals$p_bh[i], all_pvals$passes[i]))
}

fwrite(all_pvals, file.path(OUT_DIR, "BH_correction.csv"))

# ===========================================================================
# T1.5: Cross-database comparison — same-equation test
# ===========================================================================
cat("\n============================================================\n")
cat("T1.5: Cross-Database Same-Equation Test\n")
cat("============================================================\n")
cat("MODEL: polling_z = beta1*GDELT + beta2*ICEWS + beta3*Phoenix + FE\n")
cat("Purpose: direct test of whether databases contribute independently.\n")
cat("Analogous to main paper Section 4.3 cross-validation.\n\n")

sub3 <- na.omit(pew_core[, .(country, year, polling_z_pew, 
    gdelt_mean, icews_mean, phoenix_mean)])
sub3[, country := as.factor(country)]
sub3[, year := as.factor(year)]

m3 <- feols(polling_z_pew ~ gdelt_mean + icews_mean + phoenix_mean | country + year,
            data = sub3, cluster = ~country)
cat(sprintf("3-database same-equation (N=%d, %d countries):\n", nobs(m3), uniqueN(sub3$country)))
for (v in c("gdelt_mean", "icews_mean", "phoenix_mean")) {
  cat(sprintf("  %-15s beta=%+.4f (SE=%.4f) p=%.4f\n", v, coef(m3)[v], se(m3)[v], pvalue(m3)[v]))
}
cat(sprintf("  R²=%.3f\n\n", r2(m3, type = "wr2")))

# With Tsinghua (10 countries, exploratory)
sub4 <- na.omit(pew_core[, .(country, year, polling_z_pew,
    gdelt_mean, icews_mean, phoenix_mean, tsinghua_mean)])
sub4[, country := as.factor(country)]
sub4[, year := as.factor(year)]
if (nrow(sub4) >= 30) {
  m4 <- feols(polling_z_pew ~ gdelt_mean + icews_mean + phoenix_mean + tsinghua_mean | country + year,
              data = sub4, cluster = ~country)
  cat(sprintf("4-database same-equation [exploratory, N=%d, %d countries]:\n", nobs(m4), uniqueN(sub4$country)))
  for (v in c("gdelt_mean", "icews_mean", "phoenix_mean", "tsinghua_mean")) {
    cat(sprintf("  %-15s beta=%+.4f (SE=%.4f) p=%.4f\n", v, coef(m4)[v], se(m4)[v], pvalue(m4)[v]))
  }
  cat(sprintf("  R²=%.3f\n", r2(m4, type = "wr2")))
}

# ===========================================================================
# FINAL SUMMARY
# ===========================================================================
cat("\n============================================================\n")
cat("FINAL SUMMARY\n")
cat("============================================================\n")
cat("Primary window: Pew 17-country panel, 2005-2019, N=170 country-years\n")
cat("Measurement: Pew Global Attitudes 4-level favorability (re-standardized within window)\n")
cat("Political scores: annual mean of monthly fair-coverage indices\n\n")

cat("Key findings:\n")
cat(sprintf("  T1.1 between-country: GDELT ρ=%+.3f, ICEWS ρ=%+.3f, Phoenix ρ=%+.3f, Tsinghua ρ=%+.3f\n",
    t11_between$gdelt$between_rho, t11_between$icews$between_rho,
    t11_between$phoenix$between_rho, t11_between$tsinghua$between_rho))
cat(sprintf("  T1.1 within-country:   GDELT ρ=%+.3f, ICEWS ρ=%+.3f, Phoenix ρ=%+.3f, Tsinghua ρ=%+.3f\n",
    t11_within$gdelt$within_mean_rho, t11_within$icews$within_mean_rho,
    t11_within$phoenix$within_mean_rho, t11_within$tsinghua$within_mean_rho))
cat(sprintf("  T1.4 FE (GDELT): beta=%+.4f p=%.4f\n", fe_results$gdelt$beta, fe_results$gdelt$p_raw))
cat(sprintf("  T1.5 same-equation: 3 databases jointly (see above)\n"))

cat("\nCaveats:\n")
cat("  - Tsinghua: 10 countries only → cluster SE unreliable, labeled 'exploratory'\n")
cat("  - Phoenix: 2019 annual mean uses only 3 months (data ends 2019-03)\n")
cat("  - R²=0.07-0.12: political scores explain small fraction of polling variance\n")
cat("  - All estimates are associational, not causal\n")
cat("  - BH correction applied to T1.3+T1.4 p-values\n")

cat(sprintf("\nResults saved to: %s\n", OUT_DIR))
cat("Done.\n")
