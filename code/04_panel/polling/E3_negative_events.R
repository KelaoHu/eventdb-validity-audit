# E3: Negative Events and Public Opinion

library(data.table)
library(fixest)

DATA_DIR <- "C:/Users/胡克劳/Desktop/311工程数据/07_数据库与民调"
OUT_DIR  <- file.path(DATA_DIR, "02_分析结果")

paired <- fread(file.path(OUT_DIR, "paired_panel_events.csv"), encoding = "UTF-8")

cat("============================================================\n")
cat("E3: Negative Events and Public Opinion\n")
cat("============================================================\n")
cat("RESEARCH QUESTION: Do country-years with negative events show\n")
cat("  systematically lower public opinion toward China?\n")
cat("UNIT: country-year (N=170, 17 countries)\n")
cat("TREATMENT: has_negative = 1 in 30/170 (18%) country-years\n")
cat("MODEL: polling_z_pew = b*has_negative + country_FE + year_FE\n")
cat("  SE clustered by country\n")
cat("CAVEAT: 18% prevalence limits statistical power. The analysis\n")
cat("  identifies annual co-occurrence, not causal effect of events.\n\n")

# ---- E3a: Main — any negative event ----
cat("--- E3a: Any negative event (has_negative) ---\n\n")

sub <- na.omit(paired[, .(country, year, polling_z_pew, has_negative)])
sub[, country := as.factor(country)]
sub[, year := as.factor(year)]

# Check: how many countries have variation in has_negative?
var_check <- sub[, .(var_neg = var(has_negative)), by = country]
n_with_variation <- sum(var_check$var_neg > 0)
cat(sprintf("Countries with variation in has_negative: %d/17 (those without\n", n_with_variation))
cat("  variation cannot contribute to FE identification)\n\n")

m_main <- feols(polling_z_pew ~ has_negative | country + year,
                data = sub, cluster = ~country)

b  <- coef(m_main)["has_negative"]
se_val <- se(m_main)["has_negative"]
p_val <- pvalue(m_main)["has_negative"]
t_val <- b / se_val
ci_lo <- b - 1.96 * se_val
ci_hi <- b + 1.96 * se_val
r2 <- r2(m_main, type = "wr2")
n  <- nobs(m_main)

cat(sprintf("  has_negative  beta=%+.4f  SE=%.4f  t=%.2f  p=%.4f\n", b, se_val, t_val, p_val))
cat(sprintf("  95%% CI: [%+.4f, %+.4f]\n", ci_lo, ci_hi))
cat(sprintf("  R²=%.3f  N=%d  clusters=%d\n\n", r2, n, uniqueN(sub$country)))

# ---- E3b: Negative event types with N>=20 ----
cat("--- E3b: Sovereignty dispute (has_sovereignty_dispute, N=20) ---\n\n")

# Create sovereignty dispute dummy
paired[, has_sov := as.integer(n_sovereignty_dispute > 0)]
cat(sprintf("has_sov = 1 in %d/170 country-years\n\n", sum(paired$has_sov)))

sub_sov <- na.omit(paired[, .(country, year, polling_z_pew, has_sov,
                                has_other_neg = as.integer(has_negative == 1 & has_sov == 0))])
sub_sov[, country := as.factor(country)]
sub_sov[, year := as.factor(year)]

m_sov <- feols(polling_z_pew ~ has_sov + has_other_neg | country + year,
               data = sub_sov, cluster = ~country)

cat(sprintf("  has_sov            beta=%+.4f  SE=%.4f  p=%.4f\n",
    coef(m_sov)["has_sov"], se(m_sov)["has_sov"], pvalue(m_sov)["has_sov"]))
cat(sprintf("  has_other_neg      beta=%+.4f  SE=%.4f  p=%.4f\n",
    coef(m_sov)["has_other_neg"], se(m_sov)["has_other_neg"], pvalue(m_sov)["has_other_neg"]))
cat(sprintf("  R²=%.3f  N=%d\n\n", r2(m_sov, type = "wr2"), nobs(m_sov)))

# ---- E3c: Has_negative × score interaction (does negativity moderate score-polling?) ----
cat("--- E3c: Score × Negative Event Interaction ---\n")
cat("Question: In years with negative events, is the score-polling association different?\n\n")

DBS <- c("gdelt", "icews", "phoenix")
DB_LABELS <- c(gdelt = "GDELT", icews = "ICEWS", phoenix = "Phoenix")

for (db in DBS) {
  score_col <- paste0(db, "_mean")
  sub_int <- na.omit(paired[, .(country, year, polling_z_pew, score = get(score_col),
                                  has_negative)])
  sub_int[, country := as.factor(country)]
  sub_int[, year := as.factor(year)]
  sub_int[, score_x_neg := score * has_negative]
  
  m_int <- feols(polling_z_pew ~ score + score_x_neg + has_negative | country + year,
                 data = sub_int, cluster = ~country)
  
  cat(sprintf("  %s:\n", DB_LABELS[db]))
  cat(sprintf("    score           beta=%+.4f  SE=%.4f  p=%.4f\n",
      coef(m_int)["score"], se(m_int)["score"], pvalue(m_int)["score"]))
  cat(sprintf("    score×has_neg   beta=%+.4f  SE=%.4f  p=%.4f\n",
      coef(m_int)["score_x_neg"], se(m_int)["score_x_neg"], pvalue(m_int)["score_x_neg"]))
  cat(sprintf("    has_negative    beta=%+.4f  SE=%.4f  p=%.4f\n",
      coef(m_int)["has_negative"], se(m_int)["has_negative"], pvalue(m_int)["has_negative"]))
  cat(sprintf("    R²=%.3f  N=%d\n\n", r2(m_int, type = "wr2"), nobs(m_int)))
}

# ---- E3d: Descriptive — polling_z in negative vs non-negative years ----
cat("--- E3d: Descriptive comparison ---\n\n")

neg_years <- paired[has_negative == 1]
noneg_years <- paired[has_negative == 0]

cat(sprintf("  Negative years:     polling_z mean=%+.3f  SD=%.3f  N=%d\n",
    mean(neg_years$polling_z_pew), sd(neg_years$polling_z_pew), nrow(neg_years)))
cat(sprintf("  Non-negative years: polling_z mean=%+.3f  SD=%.3f  N=%d\n",
    mean(noneg_years$polling_z_pew), sd(noneg_years$polling_z_pew), nrow(noneg_years)))

raw_diff <- mean(neg_years$polling_z_pew) - mean(noneg_years$polling_z_pew)
cat(sprintf("  Raw difference: %+.3f\n\n", raw_diff))

# Country-level: how many show the expected direction?
country_dir <- paired[, .(
  neg_mean = mean(polling_z_pew[has_negative == 1], na.rm = TRUE),
  noneg_mean = mean(polling_z_pew[has_negative == 0], na.rm = TRUE),
  n_neg = sum(has_negative)
), by = country]
country_dir <- na.omit(country_dir[n_neg >= 1])
country_dir[, neg_lower := neg_mean < noneg_mean]
n_lower <- sum(country_dir$neg_lower)
n_total <- nrow(country_dir)

cat(sprintf("  Countries where negative-year polling is lower: %d/%d (%.0f%%)\n",
    n_lower, n_total, 100*n_lower/n_total))

# ---- E3e: Robustness — exclude US (most events) ----
cat("\n--- E3e: Robustness — exclude US ---\n\n")

sub_nous <- sub[country != "United States"]
sub_nous[, country := as.factor(country)]
sub_nous[, year := as.factor(year)]

m_nous <- feols(polling_z_pew ~ has_negative | country + year,
                data = sub_nous, cluster = ~country)

cat(sprintf("  Excluding US: beta=%+.4f  SE=%.4f  p=%.4f  N=%d  R²=%.3f\n",
    coef(m_nous)["has_negative"], se(m_nous)["has_negative"],
    pvalue(m_nous)["has_negative"], nobs(m_nous), r2(m_nous, type = "wr2")))

# ---- SAVE ----
e3_summary <- data.table(
  test = c("E3a_main", "E3b_sov", "E3b_other_neg",
           paste0("E3c_", DBS), "E3e_robust"),
  beta = round(c(b, coef(m_sov)["has_sov"], coef(m_sov)["has_other_neg"],
                 sapply(DBS, function(db) {
                   score_col <- paste0(db, "_mean")
                   sub_int <- na.omit(paired[, .(country, year, polling_z_pew,
                     score = get(score_col), has_negative)])
                   sub_int[, `:=`(country = as.factor(country), year = as.factor(year),
                                  score_x_neg = score * has_negative)]
                   m_int <- feols(polling_z_pew ~ score + score_x_neg + has_negative |
                                  country + year, data = sub_int, cluster = ~country)
                   coef(m_int)["score_x_neg"]
                 }),
                 coef(m_nous)["has_negative"]), 4),
  se = round(c(se_val, se(m_sov)["has_sov"], se(m_sov)["has_other_neg"],
               rep(NA, 3),
               se(m_nous)["has_negative"]), 4),
  p_raw = round(c(p_val, pvalue(m_sov)["has_sov"], pvalue(m_sov)["has_other_neg"],
                  rep(NA, 3),
                  pvalue(m_nous)["has_negative"]), 4)
)
fwrite(e3_summary, file.path(OUT_DIR, "E3_negative_events.csv"))

cat("============================================================\n")
cat("E3 COMPLETE\n")
cat("============================================================\n")
cat("Statistical power note: 30/170 negative event years.\n")
cat("Minimum detectable effect (80% power, alpha=0.05, 17 clusters):\n")
cat("  Approximately d=0.6 SD units. Smaller effects would not be detectable.\n")
cat("  If the true effect of negative events on polling is smaller than 0.6 SD,\n")
cat("  this test would fail to detect it (Type II error).\n")
