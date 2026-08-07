# E1: Event Presence × Score-Polling Association

library(data.table)
library(fixest)

DATA_DIR <- "C:/Users/胡克劳/Desktop/311工程数据/07_数据库与民调"
OUT_DIR  <- file.path(DATA_DIR, "02_分析结果")

paired <- fread(file.path(OUT_DIR, "paired_panel_events.csv"), encoding = "UTF-8")

DBS <- c("gdelt", "icews", "phoenix")
DB_LABELS <- c(gdelt = "GDELT", icews = "ICEWS", phoenix = "Phoenix")

cat("============================================================\n")
cat("E1: Event Presence × Score-Polling Association\n")
cat("============================================================\n\n")
cat("MODEL: polling_z_pew = b1*score + b2*score*has_any_event + b3*has_any_event\n")
cat("                     + country_FE + year_FE, SE clustered by country\n")
cat("UNIT: country-year (N=170, 17 countries)\n")
cat("has_any_event=1: 122/170 (72%). Reference group: 48 no-event years.\n")
cat("H0: b2 = 0 (event presence does NOT moderate the score-polling association)\n")
cat("BH family: E1a(3) + E1b(3 if applicable) = max 6 tests\n\n")

# ---- E1a: Binary ----
cat("--- E1a: Binary has_any_event ---\n\n")

e1a_results <- list()
for (db in DBS) {
  score_col <- paste0(db, "_mean")
  sub <- na.omit(paired[, .(country, year, polling_z_pew, score = get(score_col),
                              has_any_event)])
  sub[, country := as.factor(country)]
  sub[, year := as.factor(year)]
  sub[, score_x_event := score * has_any_event]
  
  m <- feols(polling_z_pew ~ score + score_x_event + has_any_event | country + year,
             data = sub, cluster = ~country)
  
  b1 <- coef(m)["score"]
  b2 <- coef(m)["score_x_event"]
  b3 <- coef(m)["has_any_event"]
  
  cat(sprintf("  %s:\n", DB_LABELS[db]))
  cat(sprintf("    score               beta=%+.4f  SE=%.4f  p=%.4f\n",
      b1, se(m)["score"], pvalue(m)["score"]))
  cat(sprintf("    score×has_any_event beta=%+.4f  SE=%.4f  p=%.4f\n",
      b2, se(m)["score_x_event"], pvalue(m)["score_x_event"]))
  cat(sprintf("    has_any_event       beta=%+.4f  SE=%.4f  p=%.4f\n",
      b3, se(m)["has_any_event"], pvalue(m)["has_any_event"]))
  cat(sprintf("    N=%d, %d countries, R²=%.3f\n\n",
      nobs(m), uniqueN(sub$country), r2(m, type = "wr2")))
  
  e1a_results[[db]] <- data.table(
    database = DB_LABELS[db],
    term = c("score", "score_x_event", "has_any_event"),
    beta = round(c(b1, b2, b3), 4),
    se = round(c(se(m)["score"], se(m)["score_x_event"], se(m)["has_any_event"]), 4),
    p_raw = round(c(pvalue(m)["score"], pvalue(m)["score_x_event"], pvalue(m)["has_any_event"]), 4),
    n = nobs(m), n_countries = uniqueN(sub$country), r2 = round(r2(m, type = "wr2"), 3)
  )
}

e1a_df <- rbindlist(e1a_results)
fwrite(e1a_df, file.path(OUT_DIR, "E1a_event_presence.csv"))

# ---- E1b: Continuous n_events (only if any E1a b2 is significant) ----
cat("--- E1b: Continuous n_events_total (secondary, only if E1a significant) ---\n\n")

e1b_sig <- e1a_df[term == "score_x_event" & p_raw < 0.05]
if (nrow(e1b_sig) > 0) {
  cat(sprintf("E1a significant for: %s. Running E1b.\n\n",
      paste(e1b_sig$database, collapse = ", ")))
  
  e1b_results <- list()
  for (db in DBS) {
    score_col <- paste0(db, "_mean")
    sub <- na.omit(paired[, .(country, year, polling_z_pew, score = get(score_col),
                                n_events_total)])
    sub[, country := as.factor(country)]
    sub[, year := as.factor(year)]
    sub[, score_x_n := score * n_events_total]
    
    m <- feols(polling_z_pew ~ score + score_x_n + n_events_total | country + year,
               data = sub, cluster = ~country)
    
    cat(sprintf("  %s:\n", DB_LABELS[db]))
    cat(sprintf("    score×n_events beta=%+.4f  SE=%.4f  p=%.4f\n",
        coef(m)["score_x_n"], se(m)["score_x_n"], pvalue(m)["score_x_n"]))
    cat(sprintf("    score          beta=%+.4f  SE=%.4f  p=%.4f\n",
        coef(m)["score"], se(m)["score"], pvalue(m)["score"]))
    cat(sprintf("    n_events       beta=%+.4f  SE=%.4f  p=%.4f\n",
        coef(m)["n_events_total"], se(m)["n_events_total"], pvalue(m)["n_events_total"]))
    cat(sprintf("    N=%d, R²=%.3f\n\n", nobs(m), r2(m, type = "wr2")))
    
    e1b_results[[db]] <- data.table(
      database = DB_LABELS[db],
      term = "score_x_n_events",
      beta = round(coef(m)["score_x_n"], 4),
      se = round(se(m)["score_x_n"], 4),
      p_raw = round(pvalue(m)["score_x_n"], 4),
      n = nobs(m), n_countries = uniqueN(sub$country),
      r2 = round(r2(m, type = "wr2"), 3)
    )
  }
  e1b_df <- rbindlist(e1b_results)
  fwrite(e1b_df, file.path(OUT_DIR, "E1b_event_density.csv"))
} else {
  cat("E1a: NO database showed significant score×has_any_event interaction.\n")
  cat("E1b: SKIPPED (per pre-registration rule).\n")
}

# ---- E1c: Descriptive — mean polling_z in event vs no-event years ----
cat("\n--- E1c: Descriptive check — polling_z in event vs no-event years ---\n\n")

for (db in DBS) {
  score_col <- paste0(db, "_mean")
  sub <- na.omit(paired[, .(country, year, polling_z_pew, score = get(score_col),
                              has_any_event, n_events_total)])
  
  event_years <- sub[has_any_event == 1]
  no_event_years <- sub[has_any_event == 0]
  
  cat(sprintf("  %s:\n", DB_LABELS[db]))
  cat(sprintf("    Event years:     polling_z mean=%+.3f SD=%.3f N=%d\n",
      mean(event_years$polling_z_pew), sd(event_years$polling_z_pew), nrow(event_years)))
  cat(sprintf("    No-event years:  polling_z mean=%+.3f SD=%.3f N=%d\n",
      mean(no_event_years$polling_z_pew), sd(no_event_years$polling_z_pew), nrow(no_event_years)))
  
  # Simple correlation in each subgroup
  r_event <- cor(event_years$score, event_years$polling_z_pew, method = "spearman")
  r_noevent <- cor(no_event_years$score, no_event_years$polling_z_pew, method = "spearman")
  cat(sprintf("    Spearman ρ (event years):    %+.3f (N=%d)\n", r_event, nrow(event_years)))
  cat(sprintf("    Spearman ρ (no-event years): %+.3f (N=%d)\n\n", r_noevent, nrow(no_event_years)))
}

cat("============================================================\n")
cat("E1 COMPLETE\n")
cat("============================================================\n")
