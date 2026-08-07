# 10c_country_label_placebo.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
ROOT_DIR <- dirname(PPML_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
FIG_DIR <- file.path(TEST_DIR, "图片")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

N_PERM <- 500L
TRADE_TARGET <- "Trade_Total"

cat("[1/3] 读取数据并构造国家特征...\n")
panel_ev <- fread(file.path(PPML_DIR, "00_事件面板构建", "中间数据", "event_panel_ready.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]

developed_list <- c("US", "JP", "DE", "GB", "FR", "IT", "CA", "AU", "ES", "NL", "BE", "KR", "SG")

avg_trade <- panel_ev[, .(avg_trade = mean(Trade_Total, na.rm = TRUE)), by = ISO]
avg_trade[, z_trade_dep := scale(avg_trade)[, 1]]

chars <- panel_ev[, .(
  FTA = mean(FTA_Dummy, na.rm = TRUE),
  developed = as.integer(ISO[1] %in% developed_list)
), by = ISO]
chars <- merge(chars, avg_trade[, .(ISO, z_trade_dep)], by = "ISO", all.x = TRUE)
chars[, region := fcase(
  ISO %in% c("JP", "KR", "IN", "ID", "TH", "MY", "PH", "VN", "SG", "AE", "SA"), "Asia_MiddleEast",
  ISO %in% c("DE", "GB", "FR", "IT", "ES", "NL", "BE", "RU"), "Europe",
  ISO %in% c("US", "CA", "MX", "BR"), "Americas",
  default = "Other"
)]

# 目标交互项
target_terms <- c("Event_Positive_x_z_trade_dep", "Event_Negative_x_z_trade_dep",
                  "Event_Positive_x_FTA", "Event_Negative_x_FTA",
                  "Event_Positive_x_developed", "Event_Negative_x_developed")

# ----------------------------------------------------------------------------
# 2) 真实模型系数
# ----------------------------------------------------------------------------
cat("[2/3] 估计真实模型系数...\n")

run_model <- function(dt) {
  dt_fit <- dt[!is.na(get(TRADE_TARGET)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  rhs <- c("Event_Positive", "Event_Negative", "Event_Neutral",
           "Event_Positive_x_z_trade_dep", "Event_Negative_x_z_trade_dep",
           "Event_Positive_x_FTA", "Event_Negative_x_FTA",
           "Event_Positive_x_developed", "Event_Negative_x_developed",
           CONTROLS)
  formula_str <- sprintf("%s ~ %s | ISO + YearMonth", TRADE_TARGET, paste(rhs, collapse = " + "))
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  return(fit)
}

# 构建真实面板
dt_real <- merge(panel_ev, chars[, .(ISO, z_trade_dep, FTA, developed)], by = "ISO", all.x = TRUE)
for (ev in c("Event_Positive", "Event_Negative", "Event_Neutral")) {
  dt_real[, (paste0(ev, "_x_z_trade_dep")) := get(ev) * z_trade_dep]
  dt_real[, (paste0(ev, "_x_FTA")) := get(ev) * FTA]
  dt_real[, (paste0(ev, "_x_developed")) := get(ev) * developed]
}

fit_real <- run_model(dt_real)
real_coefs <- sapply(target_terms, function(t) {
  ct <- coeftable(fit_real)
  if (t %in% rownames(ct)) as.numeric(ct[t, "Estimate"]) else NA_real_
})

# ----------------------------------------------------------------------------
# 3) 置换国家标签
# ----------------------------------------------------------------------------
cat("[3/3] 国家标签置换安慰剂（", N_PERM, " 次）...\n", sep = "")

set.seed(20250720)
null_dist <- matrix(NA_real_, nrow = N_PERM, ncol = length(target_terms))
colnames(null_dist) <- target_terms

pb <- txtProgressBar(min = 0, max = N_PERM, style = 3)
for (i in seq_len(N_PERM)) {
  chars_perm <- copy(chars)
  # 在同区域内随机打乱标签，保留区域结构
  chars_perm[, perm_idx := sample(.I), by = region]
  chars_perm <- chars_perm[, .(ISO, region, z_trade_dep = chars$z_trade_dep[perm_idx],
                               FTA = chars$FTA[perm_idx], developed = chars$developed[perm_idx])]
  
  dt_perm <- merge(panel_ev, chars_perm[, .(ISO, z_trade_dep, FTA, developed)], by = "ISO", all.x = TRUE)
  for (ev in c("Event_Positive", "Event_Negative", "Event_Neutral")) {
    dt_perm[, (paste0(ev, "_x_z_trade_dep")) := get(ev) * z_trade_dep]
    dt_perm[, (paste0(ev, "_x_FTA")) := get(ev) * FTA]
    dt_perm[, (paste0(ev, "_x_developed")) := get(ev) * developed]
  }
  
  fit_p <- run_model(dt_perm)
  if (!is.null(fit_p)) {
    ct_p <- coeftable(fit_p)
    for (t in target_terms) {
      null_dist[i, t] <- if (t %in% rownames(ct_p)) as.numeric(ct_p[t, "Estimate"]) else NA_real_
    }
  }
  setTxtProgressBar(pb, i)
}
close(pb)

# ----------------------------------------------------------------------------
# 4) 汇总与保存
# ----------------------------------------------------------------------------
draws_dt <- as.data.table(null_dist)
draws_dt[, iter := .I]
draws_dt <- melt(draws_dt, id.vars = "iter", variable.name = "term", value.name = "placebo_coef")

summary_dt <- data.table(
  term = target_terms,
  actual_coef = real_coefs[target_terms],
  placebo_mean = colMeans(null_dist, na.rm = TRUE),
  placebo_sd = apply(null_dist, 2, sd, na.rm = TRUE),
  placebo_pvalue = sapply(target_terms, function(t) mean(abs(null_dist[, t]) >= abs(real_coefs[t]), na.rm = TRUE)),
  n_perm = colSums(!is.na(null_dist))
)

fwrite(draws_dt, file.path(OUT_DIR, "10c_label_placebo_draws.csv"))
fwrite(summary_dt, file.path(OUT_DIR, "10c_label_placebo_summary.csv"))
cat(sprintf("✓ 10c_label_placebo_draws.csv 已保存 (%d 行)\n", nrow(draws_dt)))
cat(sprintf("✓ 10c_label_placebo_summary.csv 已保存 (%d 行)\n", nrow(summary_dt)))
print(summary_dt)

# ----------------------------------------------------------------------------
# 5) 绘图
# ----------------------------------------------------------------------------
p <- ggplot(draws_dt[!is.na(placebo_coef)], aes(x = placebo_coef)) +
  geom_histogram(aes(y = after_stat(density)), bins = 40, fill = "steelblue", color = "white", alpha = 0.7) +
  geom_density(color = "darkblue", linewidth = 0.8) +
  geom_vline(data = summary_dt, aes(xintercept = actual_coef), color = "firebrick", linetype = "dashed", linewidth = 1) +
  geom_text(data = summary_dt,
            aes(x = actual_coef, y = Inf,
                label = sprintf("实际 = %.3f\np = %.3f", actual_coef, placebo_pvalue)),
            hjust = 1.1, vjust = 1.5, color = "firebrick", size = 2.8, inherit.aes = FALSE) +
  facet_wrap(~term, scales = "free") +
  labs(
    title = "国家标签置换安慰剂检验",
    subtitle = "在同区域内随机打乱国家特征标签",
    x = "安慰剂系数",
    y = "密度"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "none",
        strip.text = element_text(face = "bold", size = 9))

ggsave(file.path(FIG_DIR, "10c_label_placebo.png"), p, width = 12, height = 8, dpi = 300)
cat("✓ 已保存 10c_label_placebo.png\n")
