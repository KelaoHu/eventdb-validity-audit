# E4: Score-Polling Moderation by Event Type

library(data.table)
library(fixest)

DATA_DIR <- "C:/Users/胡克劳/Desktop/311工程数据/07_数据库与民调"
OUT_DIR  <- file.path(DATA_DIR, "02_分析结果")

paired <- fread(file.path(OUT_DIR, "paired_panel_events.csv"), encoding = "UTF-8")
DBS <- c("gdelt", "icews", "phoenix")
DB_LABELS <- c(gdelt = "GDELT", icews = "ICEWS", phoenix = "Phoenix")

cat("============================================================\n")
cat("E4: Event-Type Moderation of Score-Polling Association\n")
cat("============================================================\n\n")
cat("PRIMARY QUESTION: Does the strength of the score-polling association\n")
cat("  differ between years with cooperative vs conflict events?\n")
cat("RATIONALE: §4.2 shows DBs specialize — machine gets cooperation,\n")
cat("  expert gets conflict. If true, cooperative-event years should\n")
cat("  amplify GDELT's polling association, conflict years should\n")
cat("  amplify Tsinghua's (but Tsinghua excluded — only 10 countries).\n\n")
cat("UNIT: country-year (N=170, 17 countries)\n")
cat("MODEL: polling_z = b1*score + b2*score*moderator + b3*moderator + FE\n\n")
cat("E3c already tested score×has_negative (all n.s.).\n")
cat("E4 extends to score×has_positive and score×has_conflict.\n\n")

# ---- Prevalence check ----
cat("Moderator variable prevalence:\n")
for (v in c("has_positive", "has_negative", "has_conflict", "has_any_event")) {
  cat(sprintf("  %-20s = 1 in %d/170 (%.0f%%)\n",
      v, sum(paired[[v]]), 100*sum(paired[[v]])/170))
}
cat("\n")

# ---- E4a: has_positive as moderator ----
cat("--- E4a: Positive events moderate score-polling? ---\n")
cat("H0: b(score×has_positive) = 0\n\n")

e4a_pvals <- c()
for (db in DBS) {
  score_col <- paste0(db, "_mean")
  sub <- na.omit(paired[, .(country, year, polling_z_pew, score = get(score_col),
                              has_positive)])
  sub[, `:=`(country = as.factor(country), year = as.factor(year),
             score_x_pos = score * has_positive)]
  
  m <- feols(polling_z_pew ~ score + score_x_pos + has_positive | country + year,
             data = sub, cluster = ~country)
  
  b2 <- coef(m)["score_x_pos"]
  cat(sprintf("  %-10s score×has_positive  beta=%+.4f  SE=%.4f  p=%.4f\n",
      DB_LABELS[db], b2, se(m)["score_x_pos"], pvalue(m)["score_x_pos"]))
  cat(sprintf("            score              beta=%+.4f  SE=%.4f  p=%.4f\n",
      coef(m)["score"], se(m)["score"], pvalue(m)["score"]))
  cat(sprintf("            R²=%.3f  N=%d\n\n", r2(m, type = "wr2"), nobs(m)))
  e4a_pvals <- c(e4a_pvals, pvalue(m)["score_x_pos"])
}

# ---- E4b: has_conflict as moderator ----
cat("--- E4b: Conflict events moderate score-polling? ---\n")
cat("Note: has_conflict = 1 in only 26/170 (15%). Power very limited.\n")
cat("H0: b(score×has_conflict) = 0\n\n")

e4b_pvals <- c()
for (db in DBS) {
  score_col <- paste0(db, "_mean")
  sub <- na.omit(paired[, .(country, year, polling_z_pew, score = get(score_col),
                              has_conflict)])
  sub[, `:=`(country = as.factor(country), year = as.factor(year),
             score_x_confl = score * has_conflict)]
  
  m <- feols(polling_z_pew ~ score + score_x_confl + has_conflict | country + year,
             data = sub, cluster = ~country)
  
  b2 <- coef(m)["score_x_confl"]
  cat(sprintf("  %-10s score×has_conflict  beta=%+.4f  SE=%.4f  p=%.4f\n",
      DB_LABELS[db], b2, se(m)["score_x_confl"], pvalue(m)["score_x_confl"]))
  cat(sprintf("            score              beta=%+.4f  SE=%.4f  p=%.4f\n",
      coef(m)["score"], se(m)["score"], pvalue(m)["score"]))
  cat(sprintf("            R²=%.3f  N=%d\n\n", r2(m, type = "wr2"), nobs(m)))
  e4b_pvals <- c(e4b_pvals, pvalue(m)["score_x_confl"])
}

# ---- E4c: Joint model — has_positive + has_negative simultaneously ----
cat("--- E4c: Joint model — positive + negative events simultaneously ---\n")
cat("Test: do both types independently moderate the score-polling association?\n\n")

e4c_pvals <- c()
for (db in DBS) {
  score_col <- paste0(db, "_mean")
  sub <- na.omit(paired[, .(country, year, polling_z_pew, score = get(score_col),
                              has_positive, has_negative)])
  sub[, `:=`(country = as.factor(country), year = as.factor(year),
             score_x_pos = score * has_positive,
             score_x_neg = score * has_negative)]
  
  m <- feols(polling_z_pew ~ score + score_x_pos + has_positive +
                          score_x_neg + has_negative | country + year,
             data = sub, cluster = ~country)
  
  cat(sprintf("  %s:\n", DB_LABELS[db]))
  for (v in c("score", "score_x_pos", "score_x_neg")) {
    cat(sprintf("    %-18s beta=%+.4f  SE=%.4f  p=%.4f\n",
        v, coef(m)[v], se(m)[v], pvalue(m)[v]))
  }
  cat(sprintf("    R²=%.3f  N=%d\n\n", r2(m, type = "wr2"), nobs(m)))
  e4c_pvals <- c(e4c_pvals, pvalue(m)["score_x_pos"], pvalue(m)["score_x_neg"])
}

# ---- E4d: Descriptive — split-sample Spearman ρ by event type ----
cat("--- E4d: Descriptive — ρ in positive-only vs negative-only vs both vs none ---\n\n")

paired[, event_combo := fcase(
  has_positive == 1 & has_negative == 0, "positive_only",
  has_negative == 1 & has_positive == 0, "negative_only",
  has_positive == 1 & has_negative == 1, "both",
  has_any_event == 0, "none"
)]

for (db in DBS) {
  score_col <- paste0(db, "_mean")
  cat(sprintf("  %s:\n", DB_LABELS[db]))
  for (combo in c("positive_only", "negative_only", "both", "none")) {
    s <- na.omit(paired[event_combo == combo, .(score = get(score_col), polling_z_pew)])
    if (nrow(s) >= 10) {
      r <- cor(s$score, s$polling_z_pew, method = "spearman")
      cat(sprintf("    %-16s ρ=%+.3f (N=%d)\n", combo, r, nrow(s)))
    } else {
      cat(sprintf("    %-16s N=%d (too few)\n", combo, nrow(s)))
    }
  }
  cat("\n")
}

# ---- BH Correction ----
cat("--- BH Correction ---\n")
all_pvals <- c(e4a_pvals, e4b_pvals, e4c_pvals)
all_names <- c(paste0("E4a_", DBS), paste0("E4b_", DBS),
               paste0("E4c_pos_", DBS), paste0("E4c_neg_", DBS))
bh <- p.adjust(all_pvals, method = "BH")

cat(sprintf("Family: %d tests across E4a/E4b/E4c\n\n", length(all_pvals)))
cat(sprintf("%-20s %-10s %-10s %s\n", "Test", "Raw p", "BH p", "Status"))
cat(paste(rep("-", 50), collapse = ""), "\n")
for (i in seq_along(all_pvals)) {
  st <- if (bh[i] < 0.05) "PASS" else "n.s."
  cat(sprintf("%-20s %-10.4f %-10.4f %s\n", all_names[i], all_pvals[i], bh[i], st))
}

# ---- SAVE ----
e4_summary <- data.table(
  test = all_names,
  p_raw = round(all_pvals, 4),
  p_bh = round(bh, 4)
)
fwrite(e4_summary, file.path(OUT_DIR, "E4_moderation.csv"))

cat("\n============================================================\n")
cat("E4 COMPLETE\n")
cat("============================================================\n")
cat("INTERPRETATION LIMITS:\n")
cat("  - has_conflict only 15% prevalence → 26 positive cases in 170 obs.\n")
cat("    Minimum detectable interaction: ~0.5 SD. Actual effects below\n")
cat("    this threshold would not be detectable (Type II risk).\n")
cat("  - Splitting sample by event type (E4d) reduces per-cell N to <50.\n")
cat("    Correlations in small cells are unstable — use as qualitative\n")
cat("    pattern description only, not formal comparison.\n")
