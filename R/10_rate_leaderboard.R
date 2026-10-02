# Run from the RStudio project root after building master_of_2025.rds.
# Rates use true innings (outs / 3), not baseball decimal notation.
master <- readRDS("data/processed/master_of_2025.rds")
# Rebuild the season-total ranking from the same master, without a rate cutoff.
total_ok <- with(master, is.finite(range_runs) & is.finite(arm_runs) &
                  is.finite(total_of_outs) & total_of_outs > 0)
totals <- master[total_ok, c("mlbam_id", "player_name", "position_group",
                            "range_runs", "arm_runs")]
# adding range runs and arm runs to get combined defensive runs
totals$combined_runs <- totals$range_runs + totals$arm_runs
# sorting players from most to fewest combined runs
totals <- totals[order(-totals$combined_runs, totals$mlbam_id), ]
totals$rank <- seq_len(nrow(totals))
stopifnot(!anyDuplicated(totals$mlbam_id), all(diff(totals$combined_runs) <= 0))
write.csv(totals[c("rank", "player_name", "position_group", "range_runs",
                  "arm_runs", "combined_runs")],
          "data/processed/combined_runs_ranking.csv", row.names=FALSE,
          fileEncoding="UTF-8")
writeLines(c("# 2025 outfield season-total leaderboard", "",
             sprintf("%d players with both range and arm measurements and positive outfield innings. No additional innings minimum.", nrow(totals)), "",
             "Combined runs = range runs + arm runs above average. Season totals reflect playing time. Rankings use unrounded values and cover the saved sample, not every MLB outfielder.", "",
             "Source: data/processed/master_of_2025.rds.", "",
             "| Rank | Player | Position | Range runs | Arm runs | Combined runs |",
             "|---:|---|---|---:|---:|---:|",
             sprintf("| %d | %s | %s | %+.1f | %+.1f | %+.1f |",
                     totals$rank, totals$player_name, totals$position_group,
                     totals$range_runs, totals$arm_runs, totals$combined_runs)),
           "reports/combined_runs_leaderboard.md")
# requiring 450 outfield innings for the rate leaderboard
minimum_innings <- 450
# using 450 innings to represent 50 full games in the field
rate_innings <- 450
eligible <- with(master, is.finite(range_runs) & is.finite(arm_runs) &
                   is.finite(total_of_outs) & total_of_outs >= minimum_innings * 3)
x <- master[eligible, c("mlbam_id", "player_name", "position_group",
                       "total_of_outs", "range_runs", "arm_runs")]
x$of_innings <- x$total_of_outs / 3
x$combined_runs <- x$range_runs + x$arm_runs
# putting each player's runs on the same playing-time scale
x$range_per_450 <- x$range_runs / x$of_innings * rate_innings
x$arm_per_450 <- x$arm_runs / x$of_innings * rate_innings
x$runs_per_450 <- x$combined_runs / x$of_innings * rate_innings
# ranking by the unrounded rates so rounding does not change the order
x <- x[order(-x$runs_per_450, x$mlbam_id), ]
x$rank <- seq_len(nrow(x))
stopifnot(!anyDuplicated(x$mlbam_id), all(x$of_innings >= minimum_innings),
          all(diff(x$runs_per_450) <= 0),
          max(abs(x$runs_per_450 - x$range_per_450 - x$arm_per_450)) < 1e-10)
saveRDS(x, "data/processed/runs_per_450_leaderboard.rds")
# formatting the leaderboard as a table for GitHub
rows <- sprintf("| %d | %s | %s | %.1f | %+.1f | %+.2f |",
                x$rank, x$player_name, x$position_group, x$of_innings,
                x$combined_runs, x$runs_per_450)
writeLines(c("# 2025 outfield runs per 450 innings", "",
             sprintf("%d eligible players; minimum %d outfield innings and both range and arm measurements.", nrow(x), minimum_innings), "",
             "Runs per 450 innings = (range runs + arm runs) / (outfield outs / 3) * 450.", "",
             "450 innings represents 50 full nine-inning games. This is an observed rate, not a forecast. It adjusts for playing time, not opportunity difficulty. Rankings use unrounded values; innings below are ordinary decimals, not baseball notation.", "",
             "Source: data/processed/master_of_2025.rds; saved 2025 sample.", "",
             "| Rank | Player | Position | OF innings | Season runs | Runs per 450 |",
             "|---:|---|---|---:|---:|---:|", rows),
           "reports/runs_per_450_leaderboard.md")
cat(sprintf("Eligible players: %d\n", nrow(x)))
cat(paste(head(rows, 30), collapse = "\n"), "\n")
