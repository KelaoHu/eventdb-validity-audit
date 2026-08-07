# 07_run_robustness_and_placebo.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
ROOT_DIR <- dirname(PPML_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/3] 读取事件面板...\n")
panel_ev <- fread(file.path(PPML_DIR, "00_事件面板构建", "中间数据", "event_panel_ready.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]

# ---- 辅助函数：跑基准模型并提取系数 ----
run_baseline <- function(dt, trade = "Trade_Total", controls = CONTROLS, cluster = ~ISO) {
  dt_fit <- dt[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  formula_str <- sprintf("%s ~ Event_Positive + Event_Negative + Event_Neutral + %s | ISO + YearMonth",
                         trade, paste(controls, collapse = " + "))
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = cluster, glm.iter = 100),
    error = function(e) NULL
  )
  if (is.null(fit)) return(NULL)
  ct <- coeftable(fit)
  data.table(
    variable = c("Event_Positive", "Event_Negative", "Event_Neutral"),
    estimate = as.numeric(ct[c("Event_Positive", "Event_Negative", "Event_Neutral"), "Estimate"]),
    se = as.numeric(ct[c("Event_Positive", "Event_Negative", "Event_Neutral"), "Std. Error"]),
    pval = as.numeric(ct[c("Event_Positive", "Event_Negative", "Event_Neutral"), "Pr(>|z|)"])
  )
}

# ---- 稳健性检验 ----
cat("[2/3] 跑稳健性检验...\n")
res_rob <- list()

# 1. 基准（总贸易）
b1 <- run_baseline(panel_ev, "Trade_Total", CONTROLS, ~ISO)
if (!is.null(b1)) {
  b1[, test := "基准"]
  res_rob[[length(res_rob) + 1]] <- b1
}

# 2. 加入 ln_GDP
b2 <- run_baseline(panel_ev, "Trade_Total", c(CONTROLS, "ln_GDP"), ~ISO)
if (!is.null(b2)) {
  b2[, test := "加入 ln_GDP"]
  res_rob[[length(res_rob) + 1]] <- b2
}

# 3. 排除美国
dt_no_us <- panel_ev[ISO != "US"]
b3 <- run_baseline(dt_no_us, "Trade_Total", CONTROLS, ~ISO)
if (!is.null(b3)) {
  b3[, test := "排除美国"]
  res_rob[[length(res_rob) + 1]] <- b3
}

# 4. 排除 2020-2022 疫情期
dt_no_covid <- panel_ev[YearMonth < as.Date("2020-01-01") | YearMonth > as.Date("2022-12-01")]
b4 <- run_baseline(dt_no_covid, "Trade_Total", CONTROLS, ~ISO)
if (!is.null(b4)) {
  b4[, test := "排除疫情期"]
  res_rob[[length(res_rob) + 1]] <- b4
}

# 5. 双向聚类
b5 <- run_baseline(panel_ev, "Trade_Total", CONTROLS, ~ISO + YearMonth)
if (!is.null(b5)) {
  b5[, test := "双向聚类"]
  res_rob[[length(res_rob) + 1]] <- b5
}

# 6. OLS 对比
b6 <- tryCatch(
  feols(Trade_Total ~ Event_Positive + Event_Negative + Event_Neutral + ln_GDP_product + ln_ER + FTA_Dummy | ISO + YearMonth,
        data = panel_ev, cluster = ~ISO),
  error = function(e) NULL
)
if (!is.null(b6)) {
  ct6 <- coeftable(b6)
  res_rob[[length(res_rob) + 1]] <- data.table(
    variable = c("Event_Positive", "Event_Negative", "Event_Neutral"),
    estimate = as.numeric(ct6[c("Event_Positive", "Event_Negative", "Event_Neutral"), "Estimate"]),
    se = as.numeric(ct6[c("Event_Positive", "Event_Negative", "Event_Neutral"), "Std. Error"]),
    pval = as.numeric(ct6[c("Event_Positive", "Event_Negative", "Event_Neutral"), "Pr(>|t|)"]),
    test = "OLS 对比"
  )
}

out_rob <- rbindlist(res_rob, use.names = TRUE)
if (nrow(out_rob) > 0) {
  out_rob[, sig := ifelse(pval < 0.01, "***", ifelse(pval < 0.05, "**", ifelse(pval < 0.10, "*", "")))]
}

# ---- 安慰剂检验 ----
cat("[3/3] 跑安慰剂检验...\n")
set.seed(20250717)
N_PERM <- 100

res_placebo <- list()

dt_base <- panel_ev[!is.na(Trade_Total) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]

# 真实系数
fit_real <- tryCatch(
  fepois(Trade_Total ~ Event_Positive + Event_Negative + Event_Neutral + ln_GDP_product + ln_ER + FTA_Dummy | ISO + YearMonth,
         data = dt_base, cluster = ~ISO, glm.iter = 100),
  error = function(e) NULL
)

if (!is.null(fit_real)) {
  ct_real <- coeftable(fit_real)
  real_coef <- as.numeric(ct_real[c("Event_Positive", "Event_Negative", "Event_Neutral"), "Estimate"])
  names(real_coef) <- c("Event_Positive", "Event_Negative", "Event_Neutral")
  
  # 随机置换事件日期
  for (v in c("Event_Positive", "Event_Negative", "Event_Neutral")) {
    placebo_dist <- numeric(N_PERM)
    event_rows <- which(dt_base[[v]] == 1)
    n_events <- length(event_rows)
    
    for (b in 1:N_PERM) {
      if (n_events == 0) {
        placebo_dist[b] <- 0
        next
      }
      # 在国家内随机抽取时间点
      dt_perm <- copy(dt_base)
      dt_perm[[v]] <- 0L
      for (iso in unique(dt_perm$ISO)) {
        n_iso_events <- sum(dt_base$ISO == iso & dt_base[[v]] == 1)
        if (n_iso_events == 0) next
        idx <- which(dt_perm$ISO == iso)
        chosen <- sample(idx, n_iso_events, replace = FALSE)
        dt_perm[[v]][chosen] <- 1L
      }
      
      fit_p <- tryCatch(
        fepois(as.formula(sprintf("Trade_Total ~ %s + %s | ISO + YearMonth", v, paste(CONTROLS, collapse = " + "))),
               data = dt_perm, cluster = ~ISO, glm.iter = 100),
        error = function(e) NULL
      )
      placebo_dist[b] <- if (!is.null(fit_p) && v %in% rownames(coeftable(fit_p))) {
        as.numeric(coeftable(fit_p)[v, "Estimate"])
      } else NA_real_
    }
    
    placebo_dist <- placebo_dist[!is.na(placebo_dist)]
    p_val <- mean(abs(placebo_dist) >= abs(real_coef[v]))
    
    res_placebo[[length(res_placebo) + 1]] <- data.table(
      variable = v,
      real_estimate = real_coef[v],
      placebo_mean = mean(placebo_dist),
      placebo_sd = sd(placebo_dist),
      placebo_pvalue = p_val
    )
  }
}

out_placebo <- rbindlist(res_placebo, use.names = TRUE)

fwrite(out_rob, file.path(OUT_DIR, "07_robustness.csv"))
fwrite(out_placebo, file.path(OUT_DIR, "07_placebo_tests.csv"))
cat(sprintf("✓ 07_robustness.csv 已保存 (%d 行)\n", nrow(out_rob)))
cat(sprintf("✓ 07_placebo_tests.csv 已保存 (%d 行)\n", nrow(out_placebo)))
print(out_rob)
print(out_placebo)
