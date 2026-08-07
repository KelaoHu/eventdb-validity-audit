# 02_run_valence_and_visits.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
ROOT_DIR <- dirname(PPML_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/2] 读取事件面板...\n")
panel_ev <- fread(file.path(PPML_DIR, "00_事件面板构建", "中间数据", "event_panel_ready.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]

# ---- 正负向非对称检验 ----
cat("[2/2] 跑 PPML...\n")
res_valence <- list()
res_visits <- list()

for (trade in TRADE_VARS) {
  dt_fit <- panel_ev[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  
  # 模型 1：正/负事件同时进入
  f1 <- tryCatch(
    fepois(as.formula(sprintf("%s ~ Event_Positive + Event_Negative + %s | ISO + YearMonth",
                              trade, paste(CONTROLS, collapse = " + "))),
           data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  
  if (!is.null(f1)) {
    ct <- coeftable(f1)
    for (v in c("Event_Positive", "Event_Negative")) {
      if (v %in% rownames(ct)) {
        res_valence[[length(res_valence) + 1]] <- data.table(
          trade = trade, variable = v,
          estimate = ct[v, "Estimate"], se = ct[v, "Std. Error"],
          z = ct[v, "z value"], pvalue = ct[v, "Pr(>|z|)"]
        )
      }
    }
    # Wald 检验 H0: beta_pos + beta_neg = 0（手动计算，避免 fixest wald 语法版本差异）
    v <- vcov(f1)
    if (all(c("Event_Positive", "Event_Negative") %in% rownames(v))) {
      b_pos <- coef(f1)["Event_Positive"]
      b_neg <- coef(f1)["Event_Negative"]
      diff <- b_pos + b_neg
      var_sum <- v["Event_Positive", "Event_Positive"] + v["Event_Negative", "Event_Negative"] +
                 2 * v["Event_Positive", "Event_Negative"]
      if (var_sum > 0) {
        chi2 <- diff^2 / var_sum
        pval <- 1 - pchisq(chi2, df = 1)
        res_valence[[length(res_valence) + 1]] <- data.table(
          trade = trade, variable = "Wald_Pos_Equals_Neg",
          estimate = diff, se = sqrt(var_sum),
          z = sqrt(chi2), pvalue = pval
        )
      }
    }
  }
  
  # 模型 2：4 类访问效应（以 Third-party meeting 为参照）
  visit_formula <- sprintf("%s ~ V_RemoteTalk + V_China_Outbound + V_Partner_Inbound + %s | ISO + YearMonth",
                           trade, paste(CONTROLS, collapse = " + "))
  f2 <- tryCatch(
    fepois(as.formula(visit_formula), data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  
  if (!is.null(f2)) {
    ct2 <- coeftable(f2)
    for (v in VISIT_VARS[VISIT_VARS != "V_ThirdParty"]) {
      if (v %in% rownames(ct2)) {
        res_visits[[length(res_visits) + 1]] <- data.table(
          trade = trade, variable = v,
          estimate = ct2[v, "Estimate"], se = ct2[v, "Std. Error"],
          z = ct2[v, "z value"], pvalue = ct2[v, "Pr(>|z|)"]
        )
      }
    }
  }
}

out_valence <- rbindlist(res_valence, use.names = TRUE)
out_valence[, sig := ifelse(pvalue < 0.01, "***", ifelse(pvalue < 0.05, "**", ifelse(pvalue < 0.10, "*", "")))]
out_valence[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

out_visits <- rbindlist(res_visits, use.names = TRUE)
out_visits[, sig := ifelse(pvalue < 0.01, "***", ifelse(pvalue < 0.05, "**", ifelse(pvalue < 0.10, "*", "")))]
out_visits[, variable := factor(variable, levels = VISIT_VARS,
                                labels = c("远程通话", "中方领导人出访", "外方领导人来访",
                                           "第三方会晤"))]
out_visits[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

fwrite(out_valence, file.path(OUT_DIR, "02_valence_asymmetry.csv"))
fwrite(out_visits, file.path(OUT_DIR, "02_four_visit_effects.csv"))

cat(sprintf("✓ 02_valence_asymmetry.csv 已保存 (%d 行)\n", nrow(out_valence)))
cat(sprintf("✓ 02_four_visit_effects.csv 已保存 (%d 行)\n", nrow(out_visits)))
print(out_valence)
print(out_visits)
