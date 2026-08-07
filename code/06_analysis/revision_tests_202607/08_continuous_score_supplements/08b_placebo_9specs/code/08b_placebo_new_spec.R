# 08b_placebo_new_spec.R

rm(list = ls())
library(fixest); library(data.table); library(parallel)

PPML_ROOT <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.3 政治经济组合分析PPMLHDFE/新PPMLHDFE"
SCORE_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data"
OUT_DIR   <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/修订补充检验_202607/08_连续分数补充检验包/08b_新版安慰剂9组合/results"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

N_PERM <- 200L
BLOCK_SIZE <- 12L
SEED <- 20260726L
N_CORES <- max(1L, detectCores() - 1L)

TRADE_VARS <- c("Trade_Total", "Trade_Exports", "Trade_Imports")
CONTROLS   <- c("ln_GDP_product", "ln_ER", "FTA_Dummy")
HORIZONS   <- 0:6
PERM_TYPES <- c("Country_Label_Permutation", "Random_Shock", "Time_Block_Permutation")

# ---- 数据：与 01_run_irf.R / 08a 完全一致的 GDELT 冲击构造 ----
panel <- fread(file.path(PPML_ROOT, "data/panel_clean.csv"), encoding = "UTF-8")
setnames(panel, sub("^\ufeff", "", names(panel)))
panel[, YearMonth := as.Date(month)]
panel[, Country := as.character(Country)]
panel[, ISO := as.character(ISO)]

gd <- fread(file.path(SCORE_DIR, "gdelt_scores.csv"), encoding = "UTF-8")
setnames(gd, sub("^\ufeff", "", names(gd)))
gd[, YearMonth := as.Date(paste0(YearMonth, "-01"))]
gd <- dcast(gd, Partner + YearMonth ~ Index_Type, value.var = "Index_Value")
setnames(gd, "Aggregated", "Pol_Agg", skip_absent = TRUE)
gd[, Country := Partner][, Partner := NULL]

dt <- merge(panel, gd[, .(Country, YearMonth, Pol_Agg)],
            by = c("Country", "YearMonth"), all.x = TRUE)
setorder(dt, ISO, YearMonth)

make_zscore <- function(x) {
  mu <- mean(x, na.rm = TRUE); sg <- sd(x, na.rm = TRUE)
  if (is.na(sg) || sg == 0) rep(NA_real_, length(x)) else (x - mu) / sg
}
dt[, PolZ_Agg := make_zscore(Pol_Agg), by = ISO]

extract_ar1_resid <- function(x) {
  if (sum(!is.na(x)) < 12) return(rep(NA_real_, length(x)))
  fit <- tryCatch(arima(x, order = c(1, 0, 0), include.mean = TRUE), error = function(e) NULL)
  if (is.null(fit)) return(rep(NA_real_, length(x)))
  as.vector(residuals(fit))
}
dt[, u_Agg := extract_ar1_resid(PolZ_Agg), by = ISO]
for (h in 1:6) dt[, (paste0("u_Agg_L", h)) := shift(u_Agg, n = h, type = "lag"), by = ISO]
dt[, has_GDELT := !is.na(u_Agg)]

cat("面板:", nrow(dt), "行, 支持域:", sum(dt$has_GDELT), "\n")

# ---- 真实 IRF（与基准对齐核验：Trade_Total h=0 应为 β≈0.01274, p≈0.0262）----
true_irf <- rbindlist(lapply(TRADE_VARS, function(trade) {
  rbindlist(lapply(HORIZONS, function(h) {
    x_var <- if (h == 0) "u_Agg" else paste0("u_Agg_L", h)
    dt_fit <- dt[!is.na(get(trade)) & !is.na(get(x_var)) &
                   !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
    fit <- fepois(as.formula(sprintf("%s ~ %s + %s | ISO + YearMonth",
                                     trade, x_var, paste(CONTROLS, collapse = " + "))),
                  data = dt_fit, cluster = ~ISO, glm.iter = 100, lean = TRUE)
    ct <- coeftable(fit)
    data.table(trade = trade, h = h, True_Est = ct[x_var, "Estimate"],
               True_p = ct[x_var, "Pr(>|z|)"], n = nrow(dt_fit))
  }))
}))
cat("\n[真实 IRF 核验]\n"); print(true_irf)

# ---- 单次置换任务 ----
run_one_perm <- function(task_id, dt, perm_type, rep_id, seed) {
  set.seed(seed + task_id)
  dt_perm <- copy(dt)

  if (perm_type == "Time_Block_Permutation") {
    dt_perm[, u_perm := {
      vals <- u_Agg; covered <- has_GDELT
      runs <- rle(as.vector(covered))
      ends <- cumsum(runs$lengths); starts <- ends - runs$lengths + 1
      for (k in seq_along(runs$values)) {
        if (runs$values[k]) {
          seg <- vals[starts[k]:ends[k]]; n_seg <- length(seg)
          if (n_seg >= BLOCK_SIZE) {
            blocks <- split(seg, ceiling(seq_len(n_seg) / BLOCK_SIZE))
            seg <- unlist(sample(blocks))[1:n_seg]
          } else if (n_seg > 1) seg <- sample(seg)
          vals[starts[k]:ends[k]] <- seg
        }
      }
      vals
    }, by = ISO]
  } else if (perm_type == "Country_Label_Permutation") {
    dt_perm[, u_perm := {
      vals <- u_Agg; idx <- which(has_GDELT)
      if (length(idx) > 1) vals[idx] <- sample(vals[idx])
      vals
    }, by = YearMonth]
  } else { # Random_Shock
    dt_perm[, u_perm := NA_real_]
    dt_perm[has_GDELT == TRUE, u_perm := rnorm(.N)]
  }
  for (h in 1:6) dt_perm[, (paste0("u_perm_L", h)) := shift(u_perm, n = h, type = "lag"), by = ISO]

  rbindlist(lapply(TRADE_VARS, function(trade) {
    rbindlist(lapply(HORIZONS, function(h) {
      x_var <- if (h == 0) "u_perm" else paste0("u_perm_L", h)
      dt_fit <- dt_perm[!is.na(get(trade)) & !is.na(get(x_var)) &
                          !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
      fit <- tryCatch(
        fepois(as.formula(sprintf("%s ~ %s + %s | ISO + YearMonth",
                                  trade, x_var, paste(CONTROLS, collapse = " + "))),
               data = dt_fit, glm.iter = 100, lean = TRUE),
        error = function(e) NULL)
      if (is.null(fit)) return(data.table(trade = trade, h = h, Est = NA_real_))
      data.table(trade = trade, h = h, Est = unname(coef(fit)[x_var]))
    }))
  }))[, `:=`(perm_type = perm_type, rep = rep_id)]
}

# ---- 任务网格与并行 ----
tasks <- CJ(type = PERM_TYPES, rep = seq_len(N_PERM))
tasks[, task_id := .I]
cat(sprintf("\n任务总数: %d (3类 × %d次), workers: %d\n", nrow(tasks), N_PERM, N_CORES))

# 精简传输列
keep_cols <- c("ISO", "YearMonth", TRADE_VARS, CONTROLS, "u_Agg", "has_GDELT")
dt_slim <- dt[, ..keep_cols]

t0 <- Sys.time()
cl <- makeCluster(N_CORES)
clusterExport(cl, c("run_one_perm", "TRADE_VARS", "CONTROLS", "HORIZONS",
                    "BLOCK_SIZE", "dt_slim", "SEED", "tasks"), envir = environment())
invisible(clusterEvalQ(cl, { library(fixest); library(data.table); NULL }))

draws_list <- parLapply(cl, seq_len(nrow(tasks)), function(i) {
  run_one_perm(task_id = tasks$task_id[i], dt = dt_slim,
               perm_type = tasks$type[i], rep_id = tasks$rep[i], seed = SEED)
})
stopCluster(cl)
cat(sprintf("置换耗时: %.1f 分钟\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))

draws <- rbindlist(draws_list)
draws[, `:=`(db = "GDELT", spec = "GD-Total")]
fwrite(draws[, .(db, spec, perm_type, rep, trade, h, Est)],
       file.path(OUT_DIR, "placebo_draws.csv"))

# ---- 安慰剂 p 值 ----
summ <- merge(draws, true_irf[, .(trade, h, True_Est, True_p)], by = c("trade", "h"))
summ <- summ[, .(True_Est = mean(True_Est), True_p = mean(True_p),
                 Perm_Mean = mean(Est, na.rm = TRUE),
                 Perm_SD = sd(Est, na.rm = TRUE),
                 Perm_q025 = quantile(Est, 0.025, na.rm = TRUE),
                 Perm_q975 = quantile(Est, 0.975, na.rm = TRUE),
                 p_placebo = mean(abs(Est) >= abs(True_Est), na.rm = TRUE),
                 n_perm = sum(!is.na(Est))),
             by = .(perm_type, trade, h)]
summ[, `:=`(db = "GDELT", spec = "GD-Total")]
setcolorder(summ, c("db", "spec", "perm_type", "trade", "h", "True_Est", "True_p",
                    "Perm_Mean", "Perm_SD", "Perm_q025", "Perm_q975", "p_placebo", "n_perm"))
setorder(summ, perm_type, trade, h)

fwrite(summ, file.path(OUT_DIR, "placebo_new_spec.csv"))
cat("\n✓ placebo_new_spec.csv 已保存 (", nrow(summ), " 行)\n", sep = "")
cat("✓ placebo_draws.csv 已保存 (", nrow(draws), " 行)\n", sep = "")

cat("\n[9组合汇总：h=0 的安慰剂 p]\n")
print(summ[h == 0, .(perm_type, trade, True_Est, True_p, p_placebo, n_perm)])
cat("\n[全 horizon 最大安慰剂 p]:\n")
print(summ[, .(max_p = max(p_placebo)), by = .(perm_type, trade)])
