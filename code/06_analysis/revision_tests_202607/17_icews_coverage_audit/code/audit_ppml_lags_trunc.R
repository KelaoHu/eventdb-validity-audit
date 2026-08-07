# audit_ppml_lags_trunc.R — para 97 check: ICEWS at ALL horizons h=0..6, full vs truncated

suppressMessages({library(fixest); library(data.table)})

AUDIT_DIR <- dirname(normalizePath(commandArgs(trailingOnly=FALSE)[grep("^--file=", commandArgs(trailingOnly=FALSE))][1], winslash="/"))
OUT_DIR <- file.path(dirname(AUDIT_DIR), "results")

PPML_DATA <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.3 政治经济组合分析PPMLHDFE/新PPMLHDFE/data"
SCORE_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data"
CUTOFF <- as.Date("2023-04-01")

panel <- fread(file.path(PPML_DATA, "panel_clean.csv"), encoding="UTF-8")
setnames(panel, sub("^\ufeff", "", names(panel)))
panel[, YearMonth := as.Date(month)]
dt <- fread(file.path(SCORE_DIR, "icews_scores.csv"), encoding="UTF-8")
setnames(dt, sub("^\ufeff", "", names(dt)))
dt[, YearMonth := as.Date(paste0(YearMonth, "-01"))]
dt <- dcast(dt, Partner + YearMonth ~ Index_Type, value.var="Index_Value")
setnames(dt, c("Aggregated","CHN->Partner","Partner->CHN"), c("Pol_Agg","Pol_CHN_Partner","Pol_Partner_CHN"), skip_absent=TRUE)
setnames(dt, "Partner", "Country")
pd <- merge(panel, dt, by=c("Country","YearMonth"), all.x=TRUE)
setorder(pd, ISO, YearMonth)

make_zscore <- function(x){ mu<-mean(x,na.rm=TRUE); sg<-sd(x,na.rm=TRUE); if(is.na(sg)||sg==0) rep(NA_real_,length(x)) else (x-mu)/sg }
extract_ar1_resid <- function(x){
  if(sum(!is.na(x))<12) return(rep(NA_real_,length(x)))
  fit<-tryCatch(arima(x,order=c(1,0,0),include.mean=TRUE),error=function(e) NULL)
  if(is.null(fit)) return(rep(NA_real_,length(x)))
  as.vector(residuals(fit))
}
pd[, u := extract_ar1_resid(make_zscore(Pol_Agg)), by=ISO]          # full-period z/AR1
pd[YearMonth<=CUTOFF, u_t := extract_ar1_resid(make_zscore(Pol_Agg)), by=ISO]  # truncated z/AR1

CONTROLS <- c("ln_GDP_product","ln_ER","FTA_Dummy")
run_lag <- function(data, xvar, h){
  d <- copy(data[!is.na(get(xvar))])
  setorder(d, ISO, YearMonth)
  if(h>0){ d[, x_lag := shift(get(xvar), h), by=ISO]; xv <- "x_lag" } else xv <- xvar
  d <- d[!is.na(Trade_Total) & !is.na(get(xv)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  f <- as.formula(sprintf("Trade_Total ~ %s + %s | ISO + YearMonth", xv, paste(CONTROLS, collapse="+")))
  fit <- fepois(f, data=d, cluster=~ISO, glm.iter=100)
  ct <- coeftable(fit)
  cat(sprintf("h=%d %-14s Est=% .5f  SE=%.5f  p=%.4f  n=%d\n", h, xvar, ct[xv,"Estimate"], ct[xv,"Std. Error"], ct[xv,"Pr(>|z|)"], nrow(d)))
  data.table(h=h, variant=xvar, Est=ct[xv,"Estimate"], SE=ct[xv,"Std. Error"], pv=ct[xv,"Pr(>|z|)"], n=nrow(d))
}
res <- list()
for(h in 0:6){
  res[[length(res)+1]] <- run_lag(pd,                    "u",   h)
  res[[length(res)+1]] <- run_lag(pd[YearMonth<=CUTOFF], "u_t", h)
}
out <- rbindlist(res)
fwrite(out, file.path(OUT_DIR, "ppml_icews_lags_full_vs_trunc.csv"))
cat("saved: ppml_icews_lags_full_vs_trunc.csv\n")
