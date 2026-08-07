# run_ppml_truncated.R — ICEWS 截断样本（≤2023-04）PPML 重算

suppressMessages({library(fixest); library(data.table)})

AUDIT_DIR <- dirname(normalizePath(commandArgs(trailingOnly=FALSE)[grep("^--file=", commandArgs(trailingOnly=FALSE))][1], winslash="/"))
OUT_DIR <- file.path(dirname(AUDIT_DIR), "results")
dir.create(OUT_DIR, recursive=TRUE, showWarnings=FALSE)

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

# 全期标准化（口径A/B 共用）
pd[, PolZ_Agg_full := make_zscore(Pol_Agg), by=ISO]
pd[, u_full := extract_ar1_resid(PolZ_Agg_full), by=ISO]
# 截断段内标准化（口径C）
pd[YearMonth<=CUTOFF, PolZ_Agg_tr := make_zscore(Pol_Agg), by=ISO]
pd[YearMonth<=CUTOFF, u_tr := extract_ar1_resid(PolZ_Agg_tr), by=ISO]

CONTROLS <- c("ln_GDP_product","ln_ER","FTA_Dummy")
run1 <- function(data, xvar, trade, label){
  d <- data[!is.na(get(trade)) & !is.na(get(xvar)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  f <- as.formula(sprintf("%s ~ %s + %s | ISO + YearMonth", trade, xvar, paste(CONTROLS, collapse="+")))
  fit <- fepois(f, data=d, cluster=~ISO, glm.iter=100)
  ct <- coeftable(fit)
  cat(sprintf("%-58s Est=% .5f  SE=%.5f  p=%.4f  n=%d\n", label, ct[xvar,"Estimate"], ct[xvar,"Std. Error"], ct[xvar,"Pr(>|z|)"], nrow(d)))
  data.table(variant=label, trade=trade, Est=ct[xvar,"Estimate"], SE=ct[xvar,"Std. Error"], pv=ct[xvar,"Pr(>|z|)"], n=nrow(d))
}

res <- list()
for (tr in c("Trade_Total","Trade_Exports","Trade_Imports")){
  res[[length(res)+1]] <- run1(pd,                    "u_full", tr, paste0("A_full_replicate        ", tr))
  res[[length(res)+1]] <- run1(pd[YearMonth<=CUTOFF], "u_full", tr, paste0("B_trunc_fullZ           ", tr))
  res[[length(res)+1]] <- run1(pd[YearMonth<=CUTOFF], "u_tr",   tr, paste0("C_trunc_truncZ          ", tr))
}
out <- rbindlist(res)
fwrite(out, file.path(OUT_DIR, "ppml_icews_truncation_variants.csv"))
cat("saved:", file.path(OUT_DIR, "ppml_icews_truncation_variants.csv"), "\n")
