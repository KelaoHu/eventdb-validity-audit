# audit_crossdb_cap201903.R — B2: same-equation spec (a), sample capped at 2019-03 vs archive 2019-12

suppressMessages({library(fixest); library(data.table)})

ROOT_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.3 政治经济组合分析PPMLHDFE/新PPMLHDFE"
SCORE_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data"
OUT_DIR <- "../results"
CUTOFF <- as.Date("2019-03-01")
CONTROLS <- c("ln_GDP_product","ln_ER","FTA_Dummy")

panel <- fread(file.path(ROOT_DIR, "data/panel_clean.csv"), encoding="UTF-8")
setnames(panel, sub("^\ufeff", "", names(panel)))
panel[, YearMonth := as.Date(month)]

read_score_long <- function(csv, db_name) {
  dt <- fread(csv, encoding="UTF-8")
  setnames(dt, sub("^\ufeff", "", names(dt)))
  dt[, YearMonth := as.Date(paste0(YearMonth, "-01"))]
  dt <- dcast(dt, Partner + YearMonth ~ Index_Type, value.var = "Index_Value")
  setnames(dt, c("Aggregated","CHN->Partner","Partner->CHN"), c("Pol_Agg","Pol_CHN_Partner","Pol_Partner_CHN"), skip_absent=TRUE)
  dt[, db := db_name][, Country := Partner]
  dt[, !"Partner"]
}
scores <- rbindlist(list(
  read_score_long(file.path(SCORE_DIR,"gdelt_scores.csv"),"GDELT"),
  read_score_long(file.path(SCORE_DIR,"icews_scores.csv"),"ICEWS"),
  read_score_long(file.path(SCORE_DIR,"phoenix_scores.csv"),"Phoenix")), fill=TRUE)

panel_db <- merge(panel, scores, by=c("Country","YearMonth"), all.x=TRUE)
setorder(panel_db, db, ISO, YearMonth)

make_zscore <- function(x){ mu<-mean(x,na.rm=TRUE); sg<-sd(x,na.rm=TRUE); if(is.na(sg)||sg==0) rep(NA_real_,length(x)) else (x-mu)/sg }
extract_ar1_resid <- function(x){
  if(sum(!is.na(x))<12) return(rep(NA_real_,length(x)))
  fit<-tryCatch(arima(x,order=c(1,0,0),include.mean=TRUE),error=function(e) NULL)
  if(is.null(fit)) return(rep(NA_real_,length(x)))
  as.vector(residuals(fit))
}
# full-period shocks (archive replication)
panel_db[, u_full := extract_ar1_resid(make_zscore(Pol_Agg)), by=.(db,ISO)]
# truncated-period shocks (within <=2019-03)
panel_db[YearMonth<=CUTOFF, u_tr := extract_ar1_resid(make_zscore(Pol_Agg)), by=.(db,ISO)]

mk_base <- function(ucol) {
  w <- dcast(panel_db[, .(ISO, Country, YearMonth, db, u=get(ucol))], ISO+Country+YearMonth~db, value.var="u")
  merge(panel[, .(ISO, Country, YearMonth, Trade_Total, Trade_Exports, Trade_Imports, ln_GDP_product, ln_ER, FTA_Dummy)],
        w[, .(ISO, YearMonth, GDELT, ICEWS, Phoenix)], by=c("ISO","YearMonth"), all.x=TRUE)
}
base_full <- mk_base("u_full")
base_tr   <- mk_base("u_tr")[YearMonth<=CUTOFF]

run_spec <- function(dt, trade, label) {
  need <- c(trade, "GDELT","ICEWS","Phoenix", CONTROLS)
  d <- dt[complete.cases(dt[, ..need])]
  f <- as.formula(sprintf("%s ~ GDELT + ICEWS + Phoenix + %s | ISO + YearMonth", trade, paste(CONTROLS, collapse="+")))
  fit <- fepois(f, data=d, cluster=~ISO+YearMonth, glm.iter=100)
  ct <- coeftable(fit)
  for (v in c("GDELT","ICEWS","Phoenix"))
    cat(sprintf("%-28s %-14s %-8s Est=% .5f SE=%.5f p=%.4f n=%d\n", label, trade, v, ct[v,"Estimate"], ct[v,"Std. Error"], ct[v,"Pr(>|z|)"], nrow(d)))
  rbindlist(lapply(c("GDELT","ICEWS","Phoenix"), function(v)
    data.table(variant=label, trade=trade, db=v, Est=ct[v,"Estimate"], SE=ct[v,"Std. Error"], pv=ct[v,"Pr(>|z|)"], n=nrow(d))))
}
res <- list()
for (tr in c("Trade_Total","Trade_Exports","Trade_Imports")) {
  res[[length(res)+1]] <- run_spec(base_full, tr, "A_archive_cap201912")
  res[[length(res)+1]] <- run_spec(base_tr,   tr, "B_cap201903_truncZ")
}
out <- rbindlist(res)
fwrite(out, file.path(OUT_DIR, "cross_db_cap201903_full_vs_trunc.csv"))
cat("saved cross_db_cap201903_full_vs_trunc.csv\n")
