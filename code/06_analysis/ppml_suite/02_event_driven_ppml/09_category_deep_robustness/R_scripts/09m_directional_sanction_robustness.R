# 09m_directional_sanction_robustness.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
ROOT_DIR <- dirname(PPML_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/3] 读取带方向化制裁变量的事件面板...\n")
panel_ev <- fread(file.path(PPML_DIR, "00_事件面板构建", "中间数据", "event_panel_with_directional_sanctions.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]

# 17 类控制变量（保留不含方向化的原始 17 类）
cat_cols <- grep("^Cat_", names(panel_ev), value = TRUE)
cat_cols <- cat_cols[!grepl("_L[0-9]+$|_F[0-9]+$", cat_cols)]
cat_cols <- setdiff(cat_cols, c("Cat_科技管制/出口限制", "Cat_经贸制裁/关税壁垒"))

# 方向化变量（原始）
tech_cn <- "Cat_科技管制_对华"
sanc_cn <- "Cat_经贸制裁_对华"
sanc_partner <- "Cat_经贸制裁_对伙伴"
sanc_multi <- "Cat_经贸制裁_多边"
sanc_ambig <- "Cat_经贸制裁_模糊"

# 构建“包含模糊”的替代变量
panel_ev[, Cat_经贸制裁_对华_含模糊 := as.integer(Cat_经贸制裁_对华 + Cat_经贸制裁_模糊 > 0)]

# 辅助：确保目标列存在
ensure_cols <- function(dt, cols) {
  for (col in cols) if (!(col %in% names(dt))) dt[, (col) := 0L]
  dt
}
panel_ev <- ensure_cols(panel_ev, c(tech_cn, sanc_cn, sanc_partner, sanc_multi, sanc_ambig))

# 安慰剂样本数
N_PLACEBO <- 1000L

results <- list()

# ----------------------------------------------------------------------------
# 通用回归函数
# ----------------------------------------------------------------------------
run_spec <- function(dt, trade, dir_use, extra_terms = NULL, cluster = "~ISO", label = "基准",
                     include_other_dir = TRUE, keep_real_names = TRUE) {
  dt_fit <- dt[!is.na(get(trade))]
  for (c in CONTROLS) dt_fit <- dt_fit[!is.na(get(c))]
  
  # 构造 RHS
  other_dir <- character(0)
  if (include_other_dir) {
    # 保留原始其他方向变量（如 对伙伴/多边/模糊），但剔除当前关注的变量避免重复
    all_dir <- c(tech_cn, sanc_cn, sanc_partner, sanc_multi, sanc_ambig)
    other_dir <- setdiff(all_dir, dir_use)
  }
  rhs <- c(sprintf("`%s`", dir_use), sprintf("`%s`", other_dir),
           sprintf("`%s`", cat_cols), CONTROLS)
  if (!is.null(extra_terms)) rhs <- c(rhs, extra_terms)
  
  formula_str <- sprintf("%s ~ %s | ISO + YearMonth", trade, paste(rhs, collapse = " + "))
  
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = as.formula(cluster), glm.iter = 100),
    error = function(e) NULL
  )
  
  if (is.null(fit)) return(NULL)
  ct <- coeftable(fit)
  
  res <- list()
  for (v in dir_use) {
    # coeftable 行名可能去掉反引号
    row_name <- v
    if (!(row_name %in% rownames(ct))) row_name <- gsub("`", "", row_name)
    if (row_name %in% rownames(ct)) {
      nm <- if (keep_real_names) v else row_name
      res[[length(res) + 1]] <- data.table(
        test = label,
        trade = trade,
        variable = nm,
        estimate = as.numeric(ct[row_name, "Estimate"]),
        se = as.numeric(ct[row_name, "Std. Error"]),
        pvalue = as.numeric(ct[row_name, "Pr(>|z|)"]),
        n = nrow(dt_fit)
      )
    }
  }
  rbindlist(res, use.names = TRUE)
}

# ----------------------------------------------------------------------------
# 2) 主要稳健性设定
# ----------------------------------------------------------------------------
cat("[2/3] 主要稳健性设定...\n")

specs <- list(
  # 1. 仅控制 17 类（复现 09j 左栏）
  list(dt = panel_ev, trade = "Trade_Imports", dir = c(tech_cn, sanc_cn),
       extra = NULL, cluster = "~ISO", label = "基准 PPML（仅17类）"),
  list(dt = panel_ev, trade = "Trade_Exports", dir = c(tech_cn, sanc_cn),
       extra = NULL, cluster = "~ISO", label = "基准 PPML（仅17类）"),
  list(dt = panel_ev, trade = "Trade_Total", dir = c(tech_cn, sanc_cn),
       extra = NULL, cluster = "~ISO", label = "基准 PPML（仅17类）"),
  
  # 2. 加入 Event_Negative（复现 09j 右栏核心结果）
  list(dt = panel_ev, trade = "Trade_Imports", dir = c(tech_cn, sanc_cn),
       extra = "Event_Negative", cluster = "~ISO", label = "加入 Event_Negative"),
  list(dt = panel_ev, trade = "Trade_Exports", dir = c(tech_cn, sanc_cn),
       extra = "Event_Negative", cluster = "~ISO", label = "加入 Event_Negative"),
  list(dt = panel_ev, trade = "Trade_Total", dir = c(tech_cn, sanc_cn),
       extra = "Event_Negative", cluster = "~ISO", label = "加入 Event_Negative"),
  
  # 3. 排除多边与对伙伴方向变量
  list(dt = panel_ev, trade = "Trade_Imports", dir = c(tech_cn, sanc_cn),
       extra = "Event_Negative", cluster = "~ISO", label = "排除多边/对伙伴变量",
       include_other_dir = FALSE),
  list(dt = panel_ev, trade = "Trade_Exports", dir = c(tech_cn, sanc_cn),
       extra = "Event_Negative", cluster = "~ISO", label = "排除多边/对伙伴变量",
       include_other_dir = FALSE),
  
  # 4. 排除出现对伙伴事件的国家-月份
  list(dt = panel_ev[Cat_经贸制裁_对伙伴 == 0], trade = "Trade_Imports", dir = c(tech_cn, sanc_cn),
       extra = "Event_Negative", cluster = "~ISO", label = "排除对伙伴事件期"),
  list(dt = panel_ev[Cat_经贸制裁_对伙伴 == 0], trade = "Trade_Exports", dir = c(tech_cn, sanc_cn),
       extra = "Event_Negative", cluster = "~ISO", label = "排除对伙伴事件期"),
  
  # 5. 严格关键词：仅保留明确的 partner_to_china 事件（经贸制裁模糊事件不计入）
  list(dt = panel_ev, trade = "Trade_Imports",
       dir = c(tech_cn, sanc_cn), extra = "Event_Negative", cluster = "~ISO",
       label = "严格关键词（仅对华）", include_other_dir = FALSE),
  list(dt = panel_ev, trade = "Trade_Exports",
       dir = c(tech_cn, sanc_cn), extra = "Event_Negative", cluster = "~ISO",
       label = "严格关键词（仅对华）", include_other_dir = FALSE),
  
  # 6. 包含模糊事件：将 ambiguous 经贸制裁并入对华
  list(dt = panel_ev, trade = "Trade_Imports",
       dir = c(tech_cn, "Cat_经贸制裁_对华_含模糊"), extra = "Event_Negative", cluster = "~ISO",
       label = "包含模糊事件", include_other_dir = FALSE),
  list(dt = panel_ev, trade = "Trade_Exports",
       dir = c(tech_cn, "Cat_经贸制裁_对华_含模糊"), extra = "Event_Negative", cluster = "~ISO",
       label = "包含模糊事件", include_other_dir = FALSE),
  
  # 7. 排除疫情期
  list(dt = panel_ev[YearMonth < as.Date("2020-01-01") | YearMonth > as.Date("2022-12-01")],
       trade = "Trade_Imports", dir = c(tech_cn, sanc_cn),
       extra = "Event_Negative", cluster = "~ISO", label = "排除疫情期"),
  list(dt = panel_ev[YearMonth < as.Date("2020-01-01") | YearMonth > as.Date("2022-12-01")],
       trade = "Trade_Exports", dir = c(tech_cn, sanc_cn),
       extra = "Event_Negative", cluster = "~ISO", label = "排除疫情期"),
  
  # 8. 排除美国
  list(dt = panel_ev[ISO != "US"], trade = "Trade_Imports", dir = c(tech_cn, sanc_cn),
       extra = "Event_Negative", cluster = "~ISO", label = "排除美国"),
  list(dt = panel_ev[ISO != "US"], trade = "Trade_Exports", dir = c(tech_cn, sanc_cn),
       extra = "Event_Negative", cluster = "~ISO", label = "排除美国"),
  
  # 9. 排除伊朗
  list(dt = panel_ev[ISO != "IR"], trade = "Trade_Imports", dir = c(tech_cn, sanc_cn),
       extra = "Event_Negative", cluster = "~ISO", label = "排除伊朗"),
  list(dt = panel_ev[ISO != "IR"], trade = "Trade_Exports", dir = c(tech_cn, sanc_cn),
       extra = "Event_Negative", cluster = "~ISO", label = "排除伊朗"),
  
  # 10. 双向聚类
  list(dt = panel_ev, trade = "Trade_Imports", dir = c(tech_cn, sanc_cn),
       extra = "Event_Negative", cluster = "~ISO + YearMonth", label = "双向聚类"),
  list(dt = panel_ev, trade = "Trade_Exports", dir = c(tech_cn, sanc_cn),
       extra = "Event_Negative", cluster = "~ISO + YearMonth", label = "双向聚类")
)

for (sp in specs) {
  res <- run_spec(
    dt = sp$dt,
    trade = sp$trade,
    dir_use = sp$dir,
    extra_terms = sp$extra,
    cluster = sp$cluster,
    label = sp$label,
    include_other_dir = if (is.null(sp$include_other_dir)) TRUE else sp$include_other_dir
  )
  if (!is.null(res)) results[[length(results) + 1]] <- res
}

out <- rbindlist(results, use.names = TRUE)
out[, sig := ifelse(pvalue < 0.01, "***", ifelse(pvalue < 0.05, "**", ifelse(pvalue < 0.10, "*", "")))]
out[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

fwrite(out, file.path(OUT_DIR, "09m_directional_sanction_robustness.csv"))
cat(sprintf("✓ 09m_directional_sanction_robustness.csv 已保存 (%d 行)\n", nrow(out)))
print(out[variable %in% c(tech_cn, sanc_cn, "Cat_经贸制裁_对华_含模糊")][order(variable, trade, test)])

# ----------------------------------------------------------------------------
# 3) 安慰剂检验（以“加入 Event_Negative”的进口方程为基准）
# ----------------------------------------------------------------------------
cat("[3/3] 安慰剂检验（", N_PLACEBO, " 次 / 变量）...\n", sep = "")

dt_base <- panel_ev[!is.na(Trade_Imports)]
for (c in CONTROLS) dt_base <- dt_base[!is.na(get(c))]

other_dir <- c(sanc_partner, sanc_multi, sanc_ambig)
rhs_base <- c(sprintf("`%s`", other_dir), sprintf("`%s`", cat_cols), CONTROLS, "Event_Negative")
formula_base <- sprintf("Trade_Imports ~ %s | ISO + YearMonth", paste(rhs_base, collapse = " + "))

placebo_one <- function(target_var) {
  actual_fit <- fepois(as.formula(sprintf("Trade_Imports ~ `%s` + %s | ISO + YearMonth",
                                          target_var, paste(rhs_base, collapse = " + "))),
                       data = dt_base, cluster = ~ISO, glm.iter = 100)
  actual_coef <- coef(actual_fit)[[target_var]]
  
  set.seed(2025)
  null_coefs <- numeric(N_PLACEBO)
  pb <- txtProgressBar(min = 0, max = N_PLACEBO, style = 3)
  for (i in seq_len(N_PLACEBO)) {
    dt_i <- copy(dt_base)
    # 在同一个月内随机打乱目标变量，保留事件时间分布
    dt_i[, placebo := sample(get(target_var)), by = YearMonth]
    fit_i <- tryCatch(
      fepois(as.formula(sprintf("Trade_Imports ~ placebo + %s | ISO + YearMonth",
                                paste(rhs_base, collapse = " + "))),
             data = dt_i, glm.iter = 50, warn = FALSE),
      error = function(e) NULL
    )
    if (!is.null(fit_i) && "placebo" %in% names(coef(fit_i))) {
      null_coefs[i] <- as.numeric(coef(fit_i)[["placebo"]])
    } else {
      null_coefs[i] <- NA_real_
    }
    setTxtProgressBar(pb, i)
  }
  close(pb)
  
  pvalue <- mean(null_coefs >= actual_coef, na.rm = TRUE)
  summary_dt <- data.table(
    variable = target_var,
    actual_coef = actual_coef,
    placebo_mean = mean(null_coefs, na.rm = TRUE),
    placebo_sd = sd(null_coefs, na.rm = TRUE),
    placebo_pvalue = pvalue,
    n_placebo = sum(!is.na(null_coefs))
  )
  draws_dt <- data.table(
    variable = target_var,
    iter = seq_len(N_PLACEBO),
    placebo_coef = null_coefs
  )
  list(summary = summary_dt, draws = draws_dt)
}

placebo_tech <- placebo_one(tech_cn)
placebo_sanc <- placebo_one(sanc_cn)

placebo_res <- rbindlist(list(placebo_tech$summary, placebo_sanc$summary), use.names = TRUE)
placebo_draws <- rbindlist(list(placebo_tech$draws, placebo_sanc$draws), use.names = TRUE)

fwrite(placebo_res, file.path(OUT_DIR, "09m_directional_sanction_placebo_summary.csv"))
fwrite(placebo_draws, file.path(OUT_DIR, "09m_directional_sanction_placebo_draws.csv"))
cat(sprintf("✓ 09m_directional_sanction_placebo_summary.csv 已保存 (%d 行)\n", nrow(placebo_res)))
cat(sprintf("✓ 09m_directional_sanction_placebo_draws.csv 已保存 (%d 行)\n", nrow(placebo_draws)))
print(placebo_res)
