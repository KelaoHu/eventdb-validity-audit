# 08_????????????????

library(tidyverse); library(lubridate); SD <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data_fair"; dir.create("results",showWarnings=F,recursive=T)
nodes <- read_csv(file.path(SD,"us_china_nodes.csv"),show_col_types=F,locale=locale(encoding="UTF-8")) %>% mutate(node_date_ym=ymd(paste0(node_date,"-01")))
sc <- read_csv(file.path(SD,"scores_v3_GDELT_ICEWS_2025.csv"),show_col_types=F,locale=locale(encoding="UTF-8"))
cat("Module 8: US-China Third-Party Effects\n")
cat(sprintf("  US-China nodes: %d (positive=%d, negative=%d)\n",nrow(nodes),
  sum(nodes$node_valence=="positive"),sum(nodes$node_valence=="negative")))
res <- list()
for(db in unique(sc$db)){ db_sc<-sc%>%filter(db==!!db)
 for(i in 1:nrow(nodes)){ nd<-nodes$node_date_ym[i]
  pre<-db_sc%>%filter(month>=nd%m-%months(3),month<nd)
  post<-db_sc%>%filter(month>=nd,month<=nd%m+%months(6))
  third<-post%>%left_join(pre%>%group_by(country)%>%summarise(bl=mean(value,na.rm=T),.groups="drop"),by="country")%>%
    filter(!is.na(bl),country!="United States")%>%
    group_by(country)%>%summarise(avg_shock=mean(value-bl,na.rm=T),.groups="drop")%>%
    mutate(db=db,node=nodes$node_name[i],valence=nodes$node_valence[i],node_date=nd)
  res[[length(res)+1]]<-third
}}
out<-bind_rows(res)
write_csv(out,"results/third_party_effects.csv")
s2<-out%>%group_by(db,valence)%>%summarise(mean_effect=mean(avg_shock,na.rm=T),n=n(),.groups="drop")
cat(sprintf("  Positive events mean spillover: %.3f\n",s2$mean_effect[s2$valence=="positive"]))
cat(sprintf("  Negative events mean spillover: %.3f\n",s2$mean_effect[s2$valence=="negative"]))
cat(sprintf("Done: %d obs\n",nrow(out)))
