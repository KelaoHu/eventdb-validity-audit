# 02_国家层面双边关系结构性断点分析

library(tidyverse); library(lubridate); library(zoo)
SD <- "../../data"; dir.create("results", showWarnings=F, recursive=T)

sc <- read_csv(file.path(SD, "scores_v3_GDELT_ICEWS_2025.csv"), show_col_types=F, locale=locale(encoding="UTF-8"))
cat("Module 2: Structural Breakpoints\n")
vol <- sc %>% group_by(db, country) %>% arrange(month) %>%
  mutate(roll_sd_6m = rollapply(value, width=6, FUN=sd, fill=NA, align="right")) %>% ungroup()
thresh <- vol %>% summarise(t = mean(roll_sd_6m, na.rm=T) + 2*sd(roll_sd_6m, na.rm=T))
bp <- vol %>% filter(roll_sd_6m > thresh$t[1]) %>%
  group_by(db, country) %>% summarise(n_bp=n(), max_vol=max(roll_sd_6m, na.rm=T),
  avg_vol=mean(roll_sd_6m, na.rm=T), .groups="drop")
write_csv(bp, "results/breakpoints.csv")
cat(sprintf("Done: %d breakpoint combinations\n", nrow(bp)))
