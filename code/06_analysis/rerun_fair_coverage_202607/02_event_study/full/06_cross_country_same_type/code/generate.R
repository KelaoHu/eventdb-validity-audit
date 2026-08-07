# 06_相同类型的事件在不同国家的反应

library(tidyverse); library(lubridate); SD <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data"
dir.create("results", showWarnings=F, recursive=T)

events <- read_csv(file.path(SD,"events_712.csv"), show_col_types=F, locale=locale(encoding="UTF-8")) %>%
  mutate(event_date_ym=ymd(paste0(event_date,"-01")))
non_leader <- events %>% filter(event_type_original!="leader_visit")
sc <- read_csv(file.path(SD,"scores_v3_GDELT_ICEWS_2025.csv"), show_col_types=F, locale=locale(encoding="UTF-8"))
cat(sprintf("Events: %d | Scores: %d rows\n", nrow(non_leader), nrow(sc)))

# Event study engine
res <- list()
for(db in unique(sc$db)) {
  db_sc <- sc %>% filter(db==!!db)
  for(cty in unique(non_leader$country_en)) {
    cty_ev <- non_leader %>% filter(country_en==cty); cty_sc <- db_sc %>% filter(country==cty)
    if(nrow(cty_ev)==0||nrow(cty_sc)==0) next
    for(i in 1:nrow(cty_ev)) {
      ed <- cty_ev$event_date_ym[i]; pre <- cty_sc %>% filter(month>=ed%m-%months(3),month<ed)
      bl <- mean(pre$value,na.rm=T); if(is.na(bl)) next
      for(pm in c(0,1,3,6,12)) {
        post <- cty_sc %>% filter(month==ed%m+%months(pm))
        if(nrow(post)>0&&!is.na(post$value[1])) {
          res[[length(res)+1]] <- tibble(db=db,version="v3",country=cty,event_name=cty_ev$event_name[i],
            category=cty_ev$event_category_en[i],post_month=pm,shock=post$value[1]-bl)
        }
      }
    }
  }
}
es <- bind_rows(res)

# Cross-country comparison
x <- es %>% group_by(category, post_month) %>%
  summarise(mean_shock=mean(shock,na.rm=T), sd_shock=sd(shock,na.rm=T),
            n_countries=n_distinct(country), .groups="drop") %>%
  mutate(se=sd_shock/sqrt(n_countries), ci_l=mean_shock-1.96*se, ci_u=mean_shock+1.96*se,
         significant=ifelse(ci_l>0|ci_u<0,"*",""))
write_csv(x, "results/m6_forest.csv")
write_csv(es, "results/m6_detailed.csv")
cat(sprintf("Done: %d rows, %d significant\n", nrow(x), sum(x$significant=="*")))
