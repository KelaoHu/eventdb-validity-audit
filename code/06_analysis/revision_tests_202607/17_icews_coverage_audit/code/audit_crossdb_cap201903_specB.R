# audit_crossdb_cap201903_specB.R — B2b: same-equation spec (b) 4-DB 11-country, cap 2019-03

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
tsinghua <- fread(file.path(SCORE_DIR, "tsinghua_scores.csv"), encoding="UTF-8")
setnames(tsinghua, sub("^\ufeff", "", names(tsinghua)))
tsinghua[, YearMonth := as.Date(paste0(YearMonth, "-01"))]
setnames(tsinghua, c("Country","YearMonth","Score"), c("Country","YearMonth","Pol_Agg"))
tsinghua[, db := "Tsinghua"]

scores <- rbindlist(list(
  read_score_long(file.path(SCORE_DIR,"gdelt_scores.csv"),"GDELT"),
  read_score_long(file.path(SCORE_DIR,"icews_scores.csv"),"ICEWS"),
  read_score_long(file.path(SCORE_DIR,"phoenix_scores.csv"),"Phoenix"),
  tsinghua), fill=TRUE)

panel_db <- merge(panel, scores, by=c("Country","YearMonth"), all.x=TRUE)
setorder(panel_db, db, ISO, YearMonth)

make_zscore <- function(x){ mu<-mean(x,na.rm=TRUE); sg<-sd(x,na.rm=TRUE); if(is.na(sg)||sg==0) rep(NA_real_,length(x)) else (x-mu)/sg }
extract_ar1_resid <- function(x){
  if(sum(!is.na(x))<12) return(rep(NA_real_,length(x)))
  fit<-tryCatch(arima(x,order=c(1,0,0),include.mean=TRUE),error=function(e) NULL)
  if(is.null(fit)) return(rep(NA_real_,length(x)))
  as.vector(residuals(fit))
}
# archive pipeline: Tsinghua = z-score of first diff (full period); others = AR1 resid of z (full period)
panel_db[, PolZ := make_zscore(Pol_Agg), by=.(db,ISO)]
panel_db[, dPol := Pol_Agg - shift(Pol_Agg,1,type="lag"), by=.(db,ISO)]
panel_db[db=="Tsinghua", PolZ := make_zscore(dPol), by=ISO]
panel_db[, u_full := extract_ar1_resid(PolZ), by=.(db,ISO)]
panel_db[db=="Tsinghua", u_full := PolZ]
# truncated variant: same construction within <=2019-03
panel_db[YearMonth<=CUTOFF, PolZt := make_zscore(Pol_Agg), by=.(db,ISO)]
panel_db[YearMonth<=CUTOFF, dPolt := Pol_Agg - shift(Pol_Agg,1,type="lag"), by=.(db,ISO)]
panel_db[db=="Tsinghua" & YearMonth<=CUTOFF, PolZt := make_zscore(dPolt), by=ISO]
panel_db[YearMonth<=CUTOFF, u_tr := extract_ar1_resid(PolZt), by=.(db,ISO)]
panel_db[db=="Tsinghua" & YearMonth<=CUTOFF, u_tr := PolZt]

ts_iso <- unique(panel[Country %in% intersect(unique(tsinghua$Country), unique(panel$Country)), ISO])
cat("Tsinghua-panel countries:", length(ts_iso), "\n")

mk_base <- function(ucol) {
  w <- dcast(panel_db[, .(ISO, Country, YearMonth, db, u=get(ucol))], ISO+Country+YearMonth~db, value.var="u")
  m <- merge(panel[, .(ISO, Country, YearMonth, Trade_Total, Trade_Exports, Trade_Imports, ln_GDP_product, ln_ER, FTA_Dummy)],
        w[, .(ISO, YearMonth, GDELT, ICEWS, Phoenix, Tsinghua)], by=c("ISO","YearMonth"), all.x=TRUE)
  m[ISO %in% ts_iso]
}
base_full <- mk_base("u_full")
base_tr   <- mk_base("u_tr")[YearMonth<=CUTOFF]

run_spec <- function(dt, trade, label) {
  shk <- c("GDELT","ICEWS","Phoenix","Tsinghua")
  need <- c(trade, shk, CONTROLS)
  d <- dt[complete.cases(dt[, ..need])]
  f <- as.formula(sprintf("%s ~ %s + %s | ISO + YearMonth", trade, paste(shk, collapse="+"), paste(CONTROLS, collapse="+")))
  fit <- fepois(f, data=d, cluster=~ISO+YearMonth, glm.iter=100)
  ct <- coeftable(fit)
  for (v in shk)
    cat(sprintf("%-28s %-14s %-9s Est=% .5f SE=%.5f p=%.4f n=%d\n", label, trade, v, ct[v,"Estimate"], ct[v,"Std. Error"], ct[v,"Pr(>|z|)"], nrow(d)))
  rbindlist(lapply(shk, function(v)
    data.table(variant=label, trade=trade, db=v, Est=ct[v,"Estimate"], SE=ct[v,"Std. Error"], pv=ct[v,"Pr(>|z|)"], n=nrow(d))))
}
res <- list()
for (tr in c("Trade_Total","Trade_Exports","Trade_Imports")) {
  res[[length(res)+1]] <- run_spec(base_full, tr, "A_archive_cap201912")
  res[[length(res)+1]] <- run_spec(base_tr,   tr, "B_cap201903_truncZ")
}
out <- rbindlist(res)
fwrite(out, file.path(OUT_DIR, "cross_db_specB_cap201903_full_vs_trunc.csv"))
cat("saved cross_db_specB_cap201903_full_vs_trunc.csv\n")
