# figS3_v1.R — 附录图 S3：SIFCCT 日本对华温度计 24 波月频曲线（2011.10–2013.09）

suppressMessages({source("C:/Users/胡克劳/Desktop/311工程论文_图件_R/00_theme_v4.R"); library(data.table)})

BASE <- "C:/Users/胡克劳/Desktop/全球好感度数据_2000-2025/研究文章公开数据/SIFCCT_日本24波/datasets"
OUT <- "C:/Users/胡克劳/Desktop/311工程论文_图件_R/figS_附录图/output/figS3"

dt <- rbindlist(lapply(c("sifcct_hdv_wave1-12.csv", "sifcct_hdv_wave13-24.csv"), function(f) {
  fread(file.path(BASE, f), select = c("wave", "date", "i14a2"))
}))
dt[, `:=`(i14a2 = as.numeric(i14a2), date = as.POSIXct(date))]
dt <- dt[!i14a2 %in% c(888, 999)]
g <- dt[, .(n = .N, mean = mean(i14a2), date = median(date)), by = wave][order(wave)]

# QA 闸门
stopifnot(nrow(g) == 24,
          abs(g[wave == 10]$mean - 21.2) < 0.3,
          abs(g[wave == 12]$mean - 14.3) < 0.3)

nat <- as.POSIXct("2012-09-11")
p <- ggplot(g, aes(date, mean)) +
  annotate("rect", xmin = as.POSIXct("2012-07-01"), xmax = as.POSIXct("2012-10-01"),
           ymin = -Inf, ymax = Inf, fill = COL_BAND, alpha = 0.6) +
  geom_line(linewidth = 0.8, colour = COL_POS) +
  geom_point(size = 1.8, colour = COL_POS) +
  geom_vline(xintercept = nat, linetype = "dashed", linewidth = 0.45, colour = COL_REF) +
  annotate("text", x = nat, y = 25.8, label = "2012-09-11\nDiaoyu Islands\nnationalization",
           size = 2.3, lineheight = 0.9, hjust = -0.08, colour = COL_INK, family = "Arial") +
  annotate("text", x = as.POSIXct("2012-07-21"), y = 22.3, label = "21.2",
           size = 2.3, fontface = "bold", colour = COL_POS, family = "Arial") +
  annotate("text", x = as.POSIXct("2012-09-22"), y = 13.2, label = "14.3",
           size = 2.3, fontface = "bold", colour = COL_NEG, family = "Arial") +
  scale_y_continuous(limits = c(12, 27), name = "Feeling thermometer toward China (0–100°)") +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "3 months", name = NULL) +
  labs(tag = NULL) +
  theme_nature()

save_pub(p, OUT, 180, 90)
cat("figS3 done; QA passed (wave10 21.2 / wave12 14.3, n=24 waves)\n")
