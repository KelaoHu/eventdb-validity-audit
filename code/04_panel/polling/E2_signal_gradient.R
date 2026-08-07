# E2: Signal Cost Gradient — state_head > gov_head > third_party?

library(data.table)
library(fixest)

DATA_DIR <- "C:/Users/胡克劳/Desktop/311工程数据/07_数据库与民调"
OUT_DIR  <- file.path(DATA_DIR, "02_分析结果")

paired <- fread(file.path(OUT_DIR, "paired_panel_events.csv"), encoding = "UTF-8")

DBS <- c("gdelt", "icews", "phoenix")
DB_LABELS <- c(gdelt = "GDELT", icews = "ICEWS", phoenix = "Phoenix")

cat("============================================================\n")
cat("E2: Signal Cost Gradient in Public Opinion\n")
cat("============================================================\n\n")
cat("MODEL: polling_z_pew = b1*n_state_head + b2*n_gov_head + b3*n_third_party\n")
cat("                     + country_FE + year_FE, cluster by country\n")
cat("H1: b1 > b2 > b3 (信号成本梯度: 元首>首脑>会晤)\n")
cat("F-test H0: b1=b2 (state vs gov), H0: b2=b3 (gov vs third)\n\n")

cat("Variable non-zero prevalence:\n")
for (v in c("n_visit_state_head", "n_visit_gov_head", "n_visit_third_party")) {
  cat(sprintf("  %-30s nonzero=%d/170 (%.0f%%), max=%d\n",
      v, sum(paired[[v]] > 0), 100*sum(paired[[v]] > 0)/nrow(paired), max(paired[[v]])))
}
cat("\n")

cat("\n")
cat("NOTE: E2a/E2b use EVENT COUNTS as predictors (not political scores).\n")
cat("Results are database-independent — identical across GDELT/ICEWS/Phoenix.\n")
cat("Running once with the full panel.\n\n")

sub <- na.omit(paired[, .(country, year, polling_z_pew,
    n_state = n_visit_state_head, n_gov = n_visit_gov_head,
    n_third = n_visit_third_party)])
sub[, country := as.factor(country)]
sub[, year := as.factor(year)]

m <- feols(polling_z_pew ~ n_state + n_gov + n_third | country + year,
           data = sub, cluster = ~country)

b1 <- coef(m)["n_state"]
b2 <- coef(m)["n_gov"]
b3 <- coef(m)["n_third"]

cat(sprintf("  n_state_head    beta=%+.4f  SE=%.4f  p=%.4f\n",
    b1, se(m)["n_state"], pvalue(m)["n_state"]))
cat(sprintf("  n_gov_head      beta=%+.4f  SE=%.4f  p=%.4f\n",
    b2, se(m)["n_gov"], pvalue(m)["n_gov"]))
cat(sprintf("  n_third_party   beta=%+.4f  SE=%.4f  p=%.4f\n",
    b3, se(m)["n_third"], pvalue(m)["n_third"]))
cat(sprintf("  R²=%.3f  N=%d\n", r2(m, type = "wr2"), nobs(m)))

# F-test: b1 = b2
f12_p <- tryCatch({
  wt <- wald(m, "n_state - n_gov = 0")
  if (is.list(wt)) wt$p else NA
}, error = function(e) NA)
cat(sprintf("  F-test H0: state=gov:      p=%.4f\n", f12_p))

# F-test: b2 = b3
f23_p <- tryCatch({
  wt <- wald(m, "n_gov - n_third = 0")
  if (is.list(wt)) wt$p else NA
}, error = function(e) NA)
cat(sprintf("  F-test H0: gov=third:      p=%.4f\n\n", f23_p))

e2a_results <- data.table(
  term = c("n_state_head", "n_gov_head", "n_third_party",
           "F_state_eq_gov", "F_gov_eq_third"),
  beta = round(c(b1, b2, b3, NA, NA), 4),
  se = round(c(se(m)["n_state"], se(m)["n_gov"], se(m)["n_third"], NA, NA), 4),
  p_raw = round(c(pvalue(m)["n_state"], pvalue(m)["n_gov"], pvalue(m)["n_third"],
                  f12_p, f23_p), 4),
  n = nobs(m), n_countries = uniqueN(sub$country),
  r2 = round(r2(m, type = "wr2"), 3)
)
fwrite(e2a_results, file.path(OUT_DIR, "E2a_signal_gradient_3level.csv"))

# ---- E2b: Direction-specific (china→partner vs partner→china) ----
cat("--- E2b: Direction-specific (outbound vs inbound) ---\n")
cat("NOTE: Also database-independent (event counts only).\n\n")

sub2 <- na.omit(paired[, .(country, year, polling_z_pew,
    n_out = n_visit_china_to_partner, n_in = n_visit_partner_to_china)])
sub2[, country := as.factor(country)]
sub2[, year := as.factor(year)]

cat(sprintf("  Non-zero: out=%d, in=%d\n", sum(sub2$n_out > 0), sum(sub2$n_in > 0)))

m2 <- feols(polling_z_pew ~ n_out + n_in | country + year,
           data = sub2, cluster = ~country)

cat(sprintf("  outbound (china→partner)  beta=%+.4f  SE=%.4f  p=%.4f\n",
    coef(m2)["n_out"], se(m2)["n_out"], pvalue(m2)["n_out"]))
cat(sprintf("  inbound (partner→china)   beta=%+.4f  SE=%.4f  p=%.4f\n",
    coef(m2)["n_in"], se(m2)["n_in"], pvalue(m2)["n_in"]))

fp <- tryCatch({
  wt <- wald(m2, "n_out - n_in = 0")
  if (is.list(wt)) wt$p else NA
}, error = function(e) NA)
cat(sprintf("  F-test out=in: p=%.4f\n", fp))
cat(sprintf("  R²=%.3f  N=%d\n\n", r2(m2, type = "wr2"), nobs(m2)))

# ---- E2c: Descriptive gradient check — mean polling_z by visit intensity ----
cat("--- E2c: Descriptive — mean polling_z by number of state_head visits ---\n\n")

paired[, state_cat := cut(n_visit_state_head, breaks = c(-1, 0, 1, 10),
    labels = c("0", "1", "2+"))]
for (db in DBS) {
  cat(sprintf("  %s:\n", DB_LABELS[db]))
  cat(sprintf("    0 visits:   polling_z mean=%+.3f (N=%d)\n",
      mean(paired[state_cat == "0"]$polling_z_pew, na.rm = TRUE),
      sum(paired$state_cat == "0", na.rm = TRUE)))
  cat(sprintf("    1 visit:    polling_z mean=%+.3f (N=%d)\n",
      mean(paired[state_cat == "1"]$polling_z_pew, na.rm = TRUE),
      sum(paired$state_cat == "1", na.rm = TRUE)))
  cat(sprintf("    2+ visits:  polling_z mean=%+.3f (N=%d)\n\n",
      mean(paired[state_cat == "2+"]$polling_z_pew, na.rm = TRUE),
      sum(paired$state_cat == "2+", na.rm = TRUE)))
}

cat("============================================================\n")
cat("E2 COMPLETE\n")
cat("============================================================\n")
