# Task 02: Bai-Perron structural break tests on GDELT monthly political

suppressPackageStartupMessages({
  library(strucchange); library(ggplot2)
})

SD  <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data"
OUT <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/修订补充检验_202607/02_结构性断点正规检验"
dir.create(file.path(OUT, "results"), showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(OUT, "figures"), showWarnings = FALSE, recursive = TRUE)

sc <- read.csv(file.path(SD, "scores_v3_GDELT_ICEWS_2025.csv"),
               fileEncoding = "UTF-8", stringsAsFactors = FALSE)
sc <- sc[sc$db == "GDELT", ]
sc$month <- as.Date(sc$month)
countries <- sort(unique(sc$country))
MIN_SEG <- 12   # minimum segment length in months

add_months <- function(dt, k) {
  y <- as.integer(format(dt, "%Y")); m <- as.integer(format(dt, "%m")) + k
  y <- y + (m - 1) %/% 12; m <- (m - 1) %% 12 + 1
  as.Date(sprintf("%04d-%02d-01", y, m))
}

bp_rows <- list()
fit_store <- list()

for (cty in countries) {
  d <- sc[sc$country == cty, ]; d <- d[order(d$month), ]
  y <- d$value; n <- length(y)

  pick_bic <- function(bp) {
    b <- breakpoints(bp)$breakpoints          # default = BIC-optimal
    if (is.null(b) || all(is.na(b))) integer(0) else as.integer(b)
  }

  ## --- main: BIC on raw levels ---
  bp_raw <- breakpoints(y ~ 1, h = MIN_SEG)
  b_raw  <- pick_bic(bp_raw)

  ## --- robustness: BIC on AR(1)-prewhitened series ---
  phi <- as.numeric(ar(y, aic = FALSE, order.max = 1)$ar[1])
  yp  <- y[-1] - phi * y[-n]
  bp_pw <- breakpoints(yp ~ 1, h = MIN_SEG)
  b_pw  <- pick_bic(bp_pw)
  b_pw  <- b_pw + 1            # prewhitened index -> raw index

  fmt_dates <- function(b) if (length(b)) paste(format(d$month[pmin(b + 1, n)], "%Y-%m"), collapse = ";") else ""

  ## segment means under the prewhitened-BIC partition (levels scale)
  seg_id <- cut(seq_len(n), breaks = c(0, b_pw, n), labels = FALSE)
  seg_means <- tapply(y, seg_id, mean)

  bp_rows[[cty]] <- data.frame(
    country = cty, db = "GDELT", n_obs = n,
    full_sample_ar1 = round(phi, 3),
    n_breaks_BIC_raw = length(b_raw),
    break_dates_BIC_raw = fmt_dates(b_raw),
    n_breaks_BIC_prewhitened = length(b_pw),
    break_dates_BIC_prewhitened = fmt_dates(b_pw),
    n_segments_prewhitened = length(b_pw) + 1,
    segment_means_levels = paste(sprintf("%.3f", seg_means), collapse = ";"),
    stringsAsFactors = FALSE)
  fit_store[[cty]] <- list(data = d, b_raw = b_raw, b_pw = b_pw, phi = phi,
                           seg_id = seg_id, seg_means = seg_means)
  cat(sprintf("%-22s phi=%.2f | BIC(raw)=%d | BIC(pw)=%d : %s\n",
              cty, phi, length(b_raw), length(b_pw), fmt_dates(b_pw)))
}

bp_tab <- do.call(rbind, bp_rows); rownames(bp_tab) <- NULL
write.csv(bp_tab, file.path(OUT, "results", "breakpoints_bai_perron.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")

# ---------------------------------------------------------------------
# Case studies: Australia & Philippines
# partition = prewhitened-BIC (raw-BIC selects 0 breaks for both).
# Per segment: level mean, AR(1), half-life; events within +/-3 months.
# ---------------------------------------------------------------------
ev <- read.csv(file.path(SD, "events_713.csv"),
               fileEncoding = "UTF-8-BOM", stringsAsFactors = FALSE)
ev$event_month <- as.Date(paste0(ev$event_date, "-01"))

ar1_ols <- function(x) {
  x <- as.numeric(x)
  if (length(x) < 6) return(NA_real_)
  fit <- try(ar(x, aic = FALSE, order.max = 1, method = "ols"), silent = TRUE)
  if (inherits(fit, "try-error") || length(fit$ar) == 0) return(NA_real_)
  as.numeric(fit$ar[1])
}
half_life <- function(phi) {
  if (is.na(phi)) return(NA_real_)
  if (phi <= 0) return(0)
  if (phi >= 1) return(Inf)
  log(0.5) / log(phi)
}

case_rows <- list()
for (cty in c("Australia", "Philippines")) {
  fs <- fit_store[[cty]]; d <- fs$data; n <- nrow(d)
  seg_bounds <- c(0, fs$b_pw, n)
  for (k in seq_along(fs$seg_means)) {
    idx <- (seg_bounds[k] + 1):seg_bounds[k + 1]
    phi_k <- ar1_ols(d$value[idx])
    case_rows[[length(case_rows) + 1]] <- data.frame(
      country = cty, record_type = "segment", seg_id = k,
      seg_start = format(d$month[min(idx)], "%Y-%m"),
      seg_end   = format(d$month[max(idx)], "%Y-%m"),
      n_months  = length(idx),
      seg_mean  = round(fs$seg_means[k], 4),
      ar1       = round(phi_k, 4),
      half_life_months = round(half_life(phi_k), 2),
      break_date = NA, event_date = NA, event_name = NA, event_impact = NA,
      stringsAsFactors = FALSE)
  }
  if (length(fs$b_pw)) {
    for (b in fs$b_pw) {
      bdate <- d$month[min(b + 1, n)]           # first month of new regime
      evc <- ev[ev$country_en == cty, ]
      hit <- evc[!is.na(evc$event_month) &
                   evc$event_month >= add_months(bdate, -3) &
                   evc$event_month <= add_months(bdate, 3), ]
      if (nrow(hit) == 0) {
        case_rows[[length(case_rows) + 1]] <- data.frame(
          country = cty, record_type = "event_near_break", seg_id = NA,
          seg_start = NA, seg_end = NA, n_months = NA, seg_mean = NA,
          ar1 = NA, half_life_months = NA,
          break_date = format(bdate, "%Y-%m"),
          event_date = NA, event_name = "(no 713-event within +/-3 months)",
          event_impact = NA, stringsAsFactors = FALSE)
      } else {
        for (j in seq_len(nrow(hit))) {
          case_rows[[length(case_rows) + 1]] <- data.frame(
            country = cty, record_type = "event_near_break", seg_id = NA,
            seg_start = NA, seg_end = NA, n_months = NA, seg_mean = NA,
            ar1 = NA, half_life_months = NA,
            break_date = format(bdate, "%Y-%m"),
            event_date = hit$event_date[j], event_name = hit$event_name[j],
            event_impact = hit$impact[j], stringsAsFactors = FALSE)
        }
      }
    }
  }
}
case_tab <- do.call(rbind, case_rows)
write.csv(case_tab, file.path(OUT, "results", "case_australia_philippines.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")

# ---------------------------------------------------------------------
# Figures: levels + break vlines (prewhitened-BIC) + segment mean steps
#          + 713-event annotations near each break. 320 dpi PNG.
# ---------------------------------------------------------------------
for (cty in c("Australia", "Philippines")) {
  fs <- fit_store[[cty]]; d <- fs$data; n <- nrow(d)
  d$seg_mean <- fs$seg_means[fs$seg_id]
  evc <- ev[ev$country_en == cty, ]
  p <- ggplot(d, aes(x = month, y = value)) +
    geom_line(color = "grey55", linewidth = 0.5) +
    geom_point(size = 0.7, color = "grey40") +
    geom_step(aes(y = seg_mean), color = "#B2182B", linewidth = 0.9,
              direction = "hv") +
    labs(title = paste0("Bai-Perron structural breaks: China-", cty,
                        " relations (GDELT monthly index)"),
         subtitle = paste0("Breaks selected by BIC on AR(1)-prewhitened series (n = ",
                           length(fs$b_pw), "; plain BIC on levels selects n = ",
                           length(fs$b_raw), "). Red step = segment mean of levels."),
         x = NULL, y = "GDELT political score (Geometric-Mean Aggregated)",
         caption = "Vertical dashed lines: break dates (first month of new regime). Labels: 713-events within +/-3 months of each break.") +
    theme_bw(base_size = 11) +
    scale_x_date(expand = expansion(mult = c(0.02, 0.16))) +
    theme(plot.title = element_text(face = "bold", size = 12))
  if (length(fs$b_pw)) {
    bdates <- d$month[pmin(fs$b_pw + 1, n)]
    p <- p + geom_vline(xintercept = bdates, linetype = "dashed",
                        color = "#2166AC", linewidth = 0.7)
    yr <- range(d$value, na.rm = TRUE)
    lab_y <- seq(yr[2], yr[1], length.out = length(bdates) + 2)[-c(1, length(bdates) + 2)]
    ann <- data.frame(bdate = bdates, y = lab_y,
                      lab = format(bdates, "%Y-%m"))
    for (i in seq_along(bdates)) {
      hit <- evc[!is.na(evc$event_month) &
                   evc$event_month >= add_months(bdates[i], -3) &
                   evc$event_month <= add_months(bdates[i], 3), ]
      if (nrow(hit)) ann$lab[i] <- paste0(ann$lab[i], "\n",
        paste(substr(hit$event_name, 1, 45), collapse = "\n"))
    }
    p <- p + geom_label(data = ann, aes(x = bdate, y = y, label = lab),
                        inherit.aes = FALSE, size = 2.6, hjust = 0,
                        nudge_x = 60, fill = "#FEE090", alpha = 0.85,
                        label.size = 0.2, lineheight = 0.95)
  }
  ggsave(file.path(OUT, "figures", paste0("breakpoints_", cty, ".png")),
         p, width = 11, height = 6, dpi = 320)
  cat("figure saved:", cty, "\n")
}
cat("Task 02 done.\n")
