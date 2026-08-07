# 05a_phone_confound_ppml.R

rm(list = ls())
library(fixest); library(data.table)

PPML_ROOT  <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.3 政治经济组合分析PPMLHDFE/新PPMLHDFE"
EVENTS_CSV <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data/events_713.csv"
OUT_DIR    <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/修订补充检验_202607/05_远程通话混淆控制/results"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

CONTROLS   <- c("ln_GDP_product", "ln_ER", "FTA_Dummy")
TRADE_VARS <- c("Trade_Total", "Trade_Exports", "Trade_Imports")

# ---- 事件面板 ----
panel_ev <- fread(file.path(PPML_ROOT, "02_事件驱动PPMLHDFE/00_事件面板构建/中间数据/event_panel_ready.csv"),
                  encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]

# ---- 模块7负面事件集：非访问 & impact=="negative" ----
ev <- fread(EVENTS_CSV, encoding = "UTF-8")
setnames(ev, sub("^\ufeff", "", names(ev)))
ev[, impact := tolower(impact)]
neg <- ev[event_type_original != "leader_visit" & impact == "negative",
          .(Country = country_en, neg_ym = as.Date(paste0(event_date, "-01")))]
cat("负面事件集（模块7口径）: n =", nrow(neg), "\n")

# 国家名 -> ISO 映射
iso_map <- unique(panel_ev[, .(ISO, Country)])
neg <- merge(neg, iso_map, by = "Country", all.x = TRUE)
stopifnot(!any(is.na(neg$ISO)))

# 口径1：同月
neg_same <- unique(neg[, .(ISO, YearMonth = neg_ym)])[, Neg_Same := 1L]
# 口径2：±1月（t-1, t, t+1 任一存在负面事件）
shift_month <- function(d, k) {
  # 月份平移 k 个月（d 均为月初）
  y <- as.integer(format(d, "%Y")); m <- as.integer(format(d, "%m"))
  m2 <- m + k
  y2 <- y + (m2 - 1L) %/% 12L
  m3 <- (m2 - 1L) %% 12L + 1L
  as.Date(sprintf("%04d-%02d-01", y2, m3))
}
neg_pm1 <- rbindlist(list(
  neg[, .(ISO, YearMonth = neg_ym)],
  neg[, .(ISO, YearMonth = shift_month(neg_ym,  1L))],
  neg[, .(ISO, YearMonth = shift_month(neg_ym, -1L))]
)) |> unique()
neg_pm1[, Neg_PM1 := 1L]

panel_ev <- merge(panel_ev, neg_same, by = c("ISO", "YearMonth"), all.x = TRUE)
panel_ev <- merge(panel_ev, neg_pm1,  by = c("ISO", "YearMonth"), all.x = TRUE)
panel_ev[is.na(Neg_Same), Neg_Same := 0L]
panel_ev[is.na(Neg_PM1),  Neg_PM1 := 0L]

# ---- 混淆结构诊断 ----
cat("\n[诊断] V_RemoteTalk==1 的", sum(panel_ev$V_RemoteTalk), "个国家-月份单元中:\n")
cat("  与 Neg_Same 重叠:", sum(panel_ev$V_RemoteTalk == 1 & panel_ev$Neg_Same == 1), "\n")
cat("  与 Neg_PM1  重叠:", sum(panel_ev$V_RemoteTalk == 1 & panel_ev$Neg_PM1 == 1), "\n")

# ---- 跑 PPML ----
run_one <- function(dt, trade, neg_var) {
  rhs <- c("V_RemoteTalk", "V_China_Outbound", "V_Partner_Inbound")
  if (!is.null(neg_var)) rhs <- c(rhs, neg_var)
  fml <- as.formula(sprintf("%s ~ %s + %s | ISO + YearMonth",
                            trade, paste(rhs, collapse = " + "),
                            paste(CONTROLS, collapse = " + ")))
  dt_fit <- dt[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  fit <- tryCatch(fepois(fml, data = dt_fit, cluster = ~ISO, glm.iter = 100),
                  error = function(e) NULL)
  if (is.null(fit)) return(NULL)
  ct <- coeftable(fit)
  keep <- intersect(rhs, rownames(ct))
  rbindlist(lapply(keep, function(v) data.table(
    trade = trade, spec = ifelse(is.null(neg_var), "baseline_no_neg_control",
                                 ifelse(neg_var == "Neg_Same", "control_neg_same_month",
                                        "control_neg_pm1_month")),
    variable = v, estimate = ct[v, "Estimate"], se = ct[v, "Std. Error"],
    z = ct[v, "z value"], pvalue = ct[v, "Pr(>|z|)"], n_obs = nrow(dt_fit)
  )))
}

res <- list()
for (trade in TRADE_VARS) {
  res[[length(res) + 1]] <- run_one(panel_ev, trade, NULL)
  res[[length(res) + 1]] <- run_one(panel_ev, trade, "Neg_Same")
  res[[length(res) + 1]] <- run_one(panel_ev, trade, "Neg_PM1")
}
out <- rbindlist(res)
out[, sig := fcase(pvalue < 0.01, "***", pvalue < 0.05, "**", pvalue < 0.10, "*", default = "")]

# 附加诊断行：重叠单元数
diag <- data.table(
  trade = NA_character_, spec = "diagnostic",
  variable = c("n_neg_events_module7", "n_remote_talk_cells",
               "overlap_remote_x_neg_same", "overlap_remote_x_neg_pm1",
               "n_neg_same_cells", "n_neg_pm1_cells"),
  estimate = c(nrow(neg), sum(panel_ev$V_RemoteTalk),
               sum(panel_ev$V_RemoteTalk == 1 & panel_ev$Neg_Same == 1),
               sum(panel_ev$V_RemoteTalk == 1 & panel_ev$Neg_PM1 == 1),
               sum(panel_ev$Neg_Same), sum(panel_ev$Neg_PM1)),
  se = NA_real_, z = NA_real_, pvalue = NA_real_, n_obs = NA_integer_, sig = ""
)
out <- rbind(out, diag, fill = TRUE)

fwrite(out, file.path(OUT_DIR, "phone_call_confound.csv"))
cat("\n✓ phone_call_confound.csv 已保存 (", nrow(out), " 行)\n", sep = "")
print(out[variable %in% c("V_RemoteTalk", "Neg_Same", "Neg_PM1") | spec == "diagnostic"])
