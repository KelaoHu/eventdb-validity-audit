# 00_utils.R

# ---- 包加载 ----
pkgs <- c("fixest", "data.table", "dplyr", "readr", "tidyr", "ggplot2", "stringr")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org/")
    library(p, character.only = TRUE)
  }
}

# ---- 路径解析（兼容 source/chdir 和直接 Rscript 运行） ----
get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  f <- grep("^--file=", args, value = TRUE)
  if (length(f) > 0) {
    path <- sub("^--file=", "", f[1])
    path <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (file.exists(path)) return(dirname(path))
  }
  return(getwd())
}

# ---- 读取面板 ----
load_panel <- function(root_dir) {
  data_dir <- file.path(root_dir, "data")
  panel <- fread(file = file.path(data_dir, "panel_clean.csv"), encoding = "UTF-8")
  setnames(panel, sub("^\ufeff", "", names(panel)))
  panel[, month := as.Date(month)]
  panel[, YearMonth := month]
  panel[, Country := as.character(Country)]
  panel[, ISO := as.character(ISO)]
  return(panel)
}

# ---- 读取并整理政治分数 ----
load_scores <- function(root_dir) {
  score_dir <- file.path(root_dir, "..", "..", "3.2 双边关系分析基于月度政治分数", "全新事件研究法", "data")
  score_dir <- normalizePath(score_dir, winslash = "/")
  
  read_score_long <- function(csv, db_name) {
    dt <- fread(file = csv, encoding = "UTF-8")
    setnames(dt, sub("^\ufeff", "", names(dt)))
    dt[, YearMonth := as.Date(paste0(YearMonth, "-01"))]
    dt <- dcast(dt, Partner + YearMonth ~ Index_Type, value.var = "Index_Value")
    setnames(dt, c("Aggregated", "CHN->Partner", "Partner->CHN"),
             c("Pol_Agg", "Pol_CHN_Partner", "Pol_Partner_CHN"), skip_absent = TRUE)
    dt[, db := db_name]
    dt[, Country := Partner]
    return(dt[, !"Partner"])
  }
  
  gdelt <- read_score_long(file.path(score_dir, "gdelt_scores.csv"), "GDELT")
  icews <- read_score_long(file.path(score_dir, "icews_scores.csv"), "ICEWS")
  phoenix <- read_score_long(file.path(score_dir, "phoenix_scores.csv"), "Phoenix")
  
  tsinghua <- fread(file = file.path(score_dir, "tsinghua_scores.csv"), encoding = "UTF-8")
  setnames(tsinghua, sub("^\ufeff", "", names(tsinghua)))
  tsinghua[, YearMonth := as.Date(paste0(YearMonth, "-01"))]
  setnames(tsinghua, c("Country", "YearMonth", "Score"), c("Country", "YearMonth", "Pol_Agg"))
  tsinghua[, db := "Tsinghua"]
  
  scores <- rbindlist(list(gdelt, icews, phoenix, tsinghua), fill = TRUE, use.names = TRUE)
  return(scores)
}

# ---- 合并面板与分数，并生成标准化分数 / AR(1) 冲击 ----
prepare_panel_db <- function(panel, scores) {
  panel_db <- merge(panel, scores, by = c("Country", "YearMonth"), all.x = TRUE)
  setorder(panel_db, db, ISO, YearMonth)
  
  make_zscore <- function(x) {
    mu <- mean(x, na.rm = TRUE)
    sg <- sd(x, na.rm = TRUE)
    if (is.na(sg) || sg == 0) rep(NA_real_, length(x)) else (x - mu) / sg
  }
  
  panel_db[, PolZ_Agg := make_zscore(Pol_Agg), by = .(db, ISO)]
  panel_db[, PolZ_CHN_Partner := make_zscore(Pol_CHN_Partner), by = .(db, ISO)]
  panel_db[, PolZ_Partner_CHN := make_zscore(Pol_Partner_CHN), by = .(db, ISO)]
  
  # Tsinghua 为单位根过程，使用一阶差分
  panel_db[, dPol_Agg := get("Pol_Agg") - shift(get("Pol_Agg"), 1, type = "lag"), by = .(db, ISO)]
  panel_db[db == "Tsinghua", PolZ_Agg := make_zscore(dPol_Agg), by = ISO]
  panel_db[db == "Tsinghua", PolZ_CHN_Partner := NA_real_]
  panel_db[db == "Tsinghua", PolZ_Partner_CHN := NA_real_]
  
  # AR(1) 残差
  extract_ar1_resid <- function(x) {
    if (sum(!is.na(x)) < 12) return(rep(NA_real_, length(x)))
    fit <- tryCatch(arima(x, order = c(1, 0, 0), include.mean = TRUE), error = function(e) NULL)
    if (is.null(fit)) return(rep(NA_real_, length(x)))
    as.vector(residuals(fit))
  }
  
  panel_db[, u_Agg := extract_ar1_resid(PolZ_Agg), by = .(db, ISO)]
  panel_db[, u_CHN_Partner := extract_ar1_resid(PolZ_CHN_Partner), by = .(db, ISO)]
  panel_db[, u_Partner_CHN := extract_ar1_resid(PolZ_Partner_CHN), by = .(db, ISO)]
  panel_db[db == "Tsinghua", u_Agg := PolZ_Agg]
  
  # 生成滞后变量 h = 1:6
  for (v in c("u_Agg", "u_CHN_Partner", "u_Partner_CHN")) {
    for (h in 1:6) {
      panel_db[, (paste0(v, "_L", h)) := shift(get(v), n = h, type = "lag"), by = .(db, ISO)]
    }
  }
  
  return(panel_db)
}

# ---- 计算 AR(1) rho（用于 scaling） ----
calc_rho_summary <- function(panel_db) {
  rho_df <- panel_db[, {
    x <- PolZ_Agg[!is.na(PolZ_Agg)]
    if (length(x) > 12) {
      fit <- tryCatch(arima(x, order = c(1, 0, 0)), error = function(e) NULL)
      rho <- if (!is.null(fit)) fit$coef["ar1"] else NA_real_
    } else {
      rho <- NA_real_
    }
    .(rho = rho, n = length(x))
  }, by = .(db, ISO)]
  
  diff_rho_df <- panel_db[db == "Tsinghua", {
    dx <- dPol_Agg[!is.na(dPol_Agg)]
    if (length(dx) > 12) {
      fit <- tryCatch(arima(dx, order = c(1, 0, 0)), error = function(e) NULL)
      rho <- if (!is.null(fit)) fit$coef["ar1"] else NA_real_
    } else {
      rho <- NA_real_
    }
    .(rho = rho, n = length(dx))
  }, by = .(db, ISO)]
  
  scaling_summary <- rho_df[, .(
    rho = mean(rho, na.rm = TRUE),
    n_country = uniqueN(ISO),
    n_obs = sum(n, na.rm = TRUE)
  ), by = db]
  scaling_summary[db == "Tsinghua", rho := diff_rho_df[, mean(rho, na.rm = TRUE)]]
  
  return(scaling_summary)
}

# ---- 标准控制变量 ----
CONTROLS <- c("ln_GDP_product", "ln_ER", "FTA_Dummy")
DBS <- c("GDELT", "ICEWS", "Phoenix", "Tsinghua")
TRADE_VARS <- c("Trade_Total", "Trade_Exports", "Trade_Imports")
