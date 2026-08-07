# 07_????????

library(tidyverse); library(lubridate); SD <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data_fair"; dir.create("results",showWarnings=F,recursive=T)
events <- read_csv(file.path(SD,"events_712.csv"),show_col_types=F,locale=locale(encoding="UTF-8")) %>% mutate(event_date_ym=ymd(paste0(event_date,"-01")))
sc <- read_csv(file.path(SD,"scores_v3_GDELT_ICEWS_2025.csv"),show_col_types=F,locale=locale(encoding="UTF-8"))
cat("Module 7: Trust Asymmetry\n")
non_leader <- events %>% filter(event_type_original!="leader_visit",impact %in% c("positive","negative"))
res <- list()
for(db in unique(sc$db)){ db_sc<-sc%>%filter(db==!!db)
 for(cty in unique(non_leader$country_en)){ cty_ev<-non_leader%>%filter(country_en==cty); cty_sc<-db_sc%>%filter(country==cty)
  if(nrow(cty_ev)==0||nrow(cty_sc)==0)next
  for(i in 1:nrow(cty_ev)){ ed<-cty_ev$event_date_ym[i]; pre<-cty_sc%>%filter(month>=ed%m-%months(3),month<ed)
   bl<-mean(pre$value,na.rm=T); if(is.na(bl))next
   for(pm in c(0,1,3,6)){ post<-cty_sc%>%filter(month==ed%m+%months(pm))
    if(nrow(post)>0&&!is.na(post$value[1])) res[[length(res)+1]]<-tibble(db=db,country=cty,
     valence=cty_ev$impact[i],category=cty_ev$event_category_en[i],post_month=pm,shock=post$value[1]-bl)
}}}}
out<-bind_rows(res)
s <- out %>% group_by(db,valence,post_month) %>% summarise(mean_shock=mean(shock,na.rm=T),n=n(),.groups="drop") %>% filter(n>=10)
write_csv(s,"results/asymmetry.csv")
cat(sprintf("Done: %d obs, positive mean=%.3f, negative mean=%.3f\n",nrow(s),
  mean(s$mean_shock[s$valence=="positive"]),mean(s$mean_shock[s$valence=="negative"])))
