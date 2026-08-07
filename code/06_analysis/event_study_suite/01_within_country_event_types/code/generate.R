# 01_单个国家内不同类型事件的反映

library(tidyverse); library(lubridate); library(zoo)
SD <- "../../data"
dir.create("results", showWarnings=F, recursive=T)

events <- read_csv(file.path(SD, "events_712.csv"), show_col_types=F, locale=locale(encoding="UTF-8")) %>%
  mutate(event_date_ym = ymd(paste0(event_date, "-01")))

versions <- list(
  v1=list(label="4DB_2019", file="scores_v1_4DB_2019.csv", dbs=c("GDELT","ICEWS","Phoenix","Tsinghua")),
  v2=list(label="3DB_2025", file="scores_v2_3DB_2025.csv", dbs=c("GDELT","ICEWS","Tsinghua")),
  v3=list(label="GDELT_ICEWS", file="scores_v3_GDELT_ICEWS_2025.csv", dbs=c("GDELT","ICEWS"))
)

cat("Module 1: Event Types within Countries\n")
all_res <- list()
for (v in names(versions)) {
  sc <- read_csv(file.path(SD, versions[[v]]$file), show_col_types=F, locale=locale(encoding="UTF-8"))
  non_leader <- events %>% filter(event_type_original != "leader_visit")
  res <- list()
  for (db in versions[[v]]$dbs) {
    db_sc <- sc %>% filter(db == !!db)
    for (cty in unique(non_leader$country_en)) {
      cty_ev <- non_leader %>% filter(country_en == cty)
      cty_sc <- db_sc %>% filter(country == cty)
      if (nrow(cty_ev)==0 || nrow(cty_sc)==0) next
      for (i in 1:nrow(cty_ev)) {
        edate <- cty_ev$event_date_ym[i]
        pre <- cty_sc %>% filter(month >= edate %m-% months(3), month < edate)
        bl <- mean(pre$value, na.rm=T); if (is.na(bl)) next
        for (pm in c(0,1,3,6,12)) {
          post <- cty_sc %>% filter(month == edate %m+% months(pm))
          if (nrow(post)>0 && !is.na(post$value[1])) {
            res[[length(res)+1]] <- tibble(version=v, db=db, country=cty,
              event_date=edate, event_name=cty_ev$event_name[i],
              category=cty_ev$event_category_en[i], impact=cty_ev$impact[i],
              baseline=bl, post_month=pm, shock=post$value[1]-bl)
          }
        }
      }
    }
  }
  all_res[[v]] <- bind_rows(res)
  cat(sprintf("  %s: %d obs\n", versions[[v]]$label, nrow(all_res[[v]])))
}
out <- bind_rows(all_res, .id="version")
write_csv(out, "results/event_study_metrics.csv")
cat(sprintf("Done: %d rows saved\n", nrow(out)))
