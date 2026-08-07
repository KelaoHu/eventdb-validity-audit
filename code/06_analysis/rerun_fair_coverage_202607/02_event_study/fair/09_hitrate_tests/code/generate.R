# 09_四库事件命中率测试

library(tidyverse); library(lubridate)
SD <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data_fair"
dir.create("results", showWarnings=F, recursive=T); dir.create("figures", showWarnings=F, recursive=T)

events <- read_csv(file.path(SD,"events_712.csv"), show_col_types=F, locale=locale(encoding="UTF-8"))
events_test <- events %>% filter(event_type_original!="leader_visit", impact%in%c("positive","negative")) %>%
  mutate(event_date_ym=ymd(paste0(event_date,"-01")), event_sign=ifelse(impact=="positive",1,-1))
cat(sprintf("Test events: %d\n", nrow(events_test)))

# Load all 4 databases
load_scores <- function(file, db_name, partner_col="Partner") {
  df <- read_csv(file.path(SD,file), show_col_types=F, locale=locale(encoding="UTF-8"))
  if(db_name!="Tsinghua") df <- df %>% filter(Index_Type=="Aggregated")
  df <- df %>% mutate(month=ymd(paste0(YearMonth,"-01")))
  if(db_name=="Tsinghua") { df$sc<-df$Score*10/9; df$ct<-df$Country } else { df$sc<-df$Index_Value; df$ct<-df[[partner_col]] }
  df %>% select(country=ct, month, score=sc) %>% filter(month>=as.Date("2002-01-01")) %>% arrange(country,month)
}
scores <- list(
  GDELT=load_scores("gdelt_scores.csv","GDELT"), ICEWS=load_scores("icews_scores.csv","ICEWS"),
  Phoenix=load_scores("phoenix_scores.csv","Phoenix"), Tsinghua=load_scores("tsinghua_scores.csv","Tsinghua")
)

# Compute hit rates
windows <- list(W_strict=list(pre=c(-3,-1),post=c(0,0)), W_1m=list(pre=c(-3,-1),post=c(0,1)),
                W_2m=list(pre=c(-3,-1),post=c(0,2)), W_best=list(pre=c(-3,-1),post=NA))

all_hits <- list()
for(db in names(scores)) {
  sc <- scores[[db]]
  for(i in 1:nrow(events_test)) {
    ev <- events_test[i,]; ed<-ev$event_date_ym; es<-ev$event_sign; cty<-ev$country_en
    sc_cty <- sc %>% filter(country==cty) %>% arrange(month); if(nrow(sc_cty)==0) next
    pre_m <- sc_cty %>% filter(month>=ed%m+%months(-3), month<ed); if(nrow(pre_m)<2) next
    pre_mean <- mean(pre_m$score,na.rm=T); if(is.na(pre_mean)) next
    for(wn in names(windows)) {
      w<-windows[[wn]]
      if(is.na(w$post[1])) {
        best_delta<-NA; best_hit<-NA; best_abs<--1
        for(k in list(c(0,0),c(0,1),c(0,2))) {
          pm<-sc_cty %>% filter(month>=ed%m+%months(k[1]),month<=ed%m+%months(k[2]))
          if(nrow(pm)==0) next; d<-mean(pm$score,na.rm=T)-pre_mean
          if(is.na(d)) next; if(abs(d)>best_abs){best_delta<-d;best_abs<-abs(d);best_hit<-(d*es>0)}
        }
        delta<-best_delta; hit<-best_hit
      } else {
        pm<-sc_cty %>% filter(month>=ed%m+%months(w$post[1]),month<=ed%m+%months(w$post[2]))
        if(nrow(pm)==0) next; delta<-mean(pm$score,na.rm=T)-pre_mean; hit<-(delta*es)>0
      }
      if(!is.na(hit)) all_hits[[length(all_hits)+1]]<-tibble(db=db,country=cty,event_name=ev$event_name,
        event_category=ev$event_category_en,event_sign=es,window=wn,pre_mean=pre_mean,delta=delta,hit=hit)
    }
  }
}
hit_data <- bind_rows(all_hits)
write_csv(hit_data, "results/hit_data_full.csv")

main <- hit_data %>% group_by(db,window) %>% summarise(n_events=n_distinct(event_name),
  n_hit=sum(hit,na.rm=T),hit_rate=mean(hit,na.rm=T),.groups="drop")
write_csv(main, "results/hit_rate_main.csv")
cat(sprintf("Main hit rates (%d rows):\n", nrow(main)))
print(as.data.frame(main%>%arrange(db,window)), row.names=F)
cat("Done.\n")
