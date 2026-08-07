# 04_??????????????

library(tidyverse); library(lubridate); library(zoo); SD <- "../../data"; dir.create("results",showWarnings=F,recursive=T)
leaders <- read_csv(file.path(SD,"leaders.csv"),show_col_types=F,locale=locale(encoding="UTF-8"))
cat("Module 4: Leadership Turnover\n")
# Count turnovers >2002 per country
t <- leaders %>% mutate(country=.[[1]],start=ymd(.[[7]])) %>% filter(start>=as.Date("2002-01-01")) %>% group_by(country) %>% summarise(n_turnovers=n(),.groups="drop")
# Correlate with score volatility
sc <- read_csv(file.path(SD,"scores_v3_GDELT_ICEWS_2025.csv"),show_col_types=F,locale=locale(encoding="UTF-8"))
vol <- sc %>% group_by(db,country) %>% arrange(month) %>% mutate(roll_sd=rollapply(value,width=12,FUN=sd,fill=NA,align="right")) %>% summarise(mean_vol=mean(roll_sd,na.rm=T),.groups="drop")
m <- t %>% left_join(vol,by="country") %>% filter(!is.na(mean_vol))
corr <- m %>% group_by(db) %>% summarise(r=cor(n_turnovers,mean_vol,use="complete.obs"),.groups="drop")
write_csv(corr,"results/turnover_vol_corr.csv"); write_csv(m,"results/country_metrics.csv")
cat(sprintf("Done: corr=%.3f\n",corr$r[1]))
