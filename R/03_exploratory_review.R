# Descriptive review only: no fitted models or new sample restrictions.
library(tidyverse)
m <- readRDS('data/processed/master_of_2025.rds')
samples <- readRDS('data/processed/samples/analysis_samples.rds')
dir.create('data/processed/review', recursive = TRUE, showWarnings = FALSE)
dir.create('figures', showWarnings = FALSE)
review_dir <- 'data/processed/review'

# Missingness is evaluated among players with recorded OF playing time.
fields <- c('range_runs', 'arm_runs', 'sprint_speed_sprint_speed',
            'jump_rel_league_bootup_distance', 'arm_strength_arm_of',
            'arm_strength_arm_overall')
# checking how many outfielders have each measurement
coverage <- m |> filter(has_of_playing_time) |>
  select(mlbam_id, position_group, all_of(fields)) |>
  pivot_longer(all_of(fields), names_to = 'metric', values_to = 'value') |>
  group_by(position_group, metric) |>
  summarise(players = n(), available = sum(!is.na(value)),
            missing = sum(is.na(value)), .groups = 'drop')
write_csv(coverage, file.path(review_dir, 'metric_coverage_by_position.csv'))

# Opportunity distributions use each source's matched OF players. These counts
# describe different events and must not be treated as interchangeable weights.
counts <- c('jump_n', 'sprint_speed_competitive_runs',
            'arm_strength_total_throws_of', 'arm_value_n_opp_xb')
opportunities <- m |> filter(has_of_playing_time) |>
  select(mlbam_id, player_name, all_of(counts)) |>
  pivot_longer(all_of(counts), names_to = 'metric', values_to = 'count') |>
  filter(!is.na(count))
stopifnot(all(opportunities$count >= 0), all(opportunities$count == floor(opportunities$count)))
# summarizing how many opportunities are behind each measurement
opportunity_summary <- opportunities |> group_by(metric) |>
  summarise(players = n(), minimum = min(count), q25 = quantile(count, .25),
            median = median(count), q75 = quantile(count, .75), maximum = max(count),
            .groups = 'drop')
write_csv(opportunity_summary, file.path(review_dir, 'opportunity_summary.csv'))
write_csv(opportunities |> group_by(metric) |> slice_min(count, n = 10, with_ties = TRUE),
          file.path(review_dir, 'lowest_opportunity_players.csv'))

# Verify rate arithmetic without treating rate_safe as rate_safe_per_attempt.
a <- m |> filter(has_arm_value)
stopifnot(all(a$arm_value_n_att_xb <= a$arm_value_n_opp_xb),
          all(a$arm_value_n_out + a$arm_value_n_safe == a$arm_value_n_att_xb),
          all(abs(a$arm_value_rate_att_xb - a$arm_value_n_att_xb / a$arm_value_n_opp_xb) < 1e-8),
          all(abs(a$arm_runs - a$arm_value_fielder_runs_advances -
                    a$arm_value_fielder_runs_thrown_out - a$arm_value_fielder_runs_hold) < 1e-8))
# Numeric checks can support documented rules but do not recover export settings.
# checking the sample against the recorded qualification rules
qualification_checks <- tibble(
  check = c('Nonmissing OF strength has at least 50 OF throws',
            'Jump opportunities exceed 162 / 5 (full-season assumption)',
            'Sprint Speed has at least 10 competitive runs'),
  evaluated = c(sum(!is.na(m$arm_strength_arm_of)), sum(m$has_jump), sum(m$has_sprint_speed & m$has_of_playing_time)),
  failures = c(sum(!is.na(m$arm_strength_arm_of) & (is.na(m$arm_strength_total_throws_of) | m$arm_strength_total_throws_of < 50)),
               sum(m$has_jump & (is.na(m$jump_n) | m$jump_n <= 162/5)),
               sum(m$has_sprint_speed & m$has_of_playing_time & (is.na(m$sprint_speed_competitive_runs) | m$sprint_speed_competitive_runs < 10)))
)
write_csv(qualification_checks, file.path(review_dir, 'qualification_checks.csv'))

# Identify exactly what changes when overall strength replaces OF strength.
arm_difference <- anti_join(samples$arm_value_overall_strength,
                            samples$arm_value_of_strength, by = 'mlbam_id') |>
  select(mlbam_id, player_name, position_group, arm_strength_arm_of,
         arm_strength_arm_overall, arm_strength_total_throws_of, arm_runs)
write_csv(arm_difference, file.path(review_dir, 'overall_only_arm_players.csv'))

# Consistent plot styling; points represent players, with no regression lines.
theme_set(theme_minimal(base_size = 12) + theme(panel.grid.minor = element_blank(),
          plot.title = element_text(face = 'bold'), legend.position = 'bottom'))
colors <- c(LF = '#D55E00', CF = '#0072B2', RF = '#009E73', 'Multi-position OF' = '#777777')
caption <- '2025 source exports | Candidate samples; qualification provenance remains incomplete.'
# making a function to save the plots with the same size and quality
save_plot <- function(p, filename, width = 9, height = 6) {
  ggsave(file.path('figures', paste0(filename, '.png')), p, width = width, height = height, dpi = 160, bg = 'white')
}
# making scatterplots with one point per player
scatter <- function(d, x, y, title, xlabel, ylabel, filename) {
  p <- ggplot(d, aes(x = .data[[x]], y = .data[[y]], color = position_group)) +
    geom_point(size = 2.4, alpha = .8) + scale_color_manual(values = colors) +
    labs(title = title, subtitle = paste(nrow(d), 'players | Descriptive association'),
         x = xlabel, y = ylabel, color = 'Primary OF position', caption = caption)
  save_plot(p, filename)
}
scatter(samples$range_speed, 'sprint_speed_sprint_speed', 'range_runs',
        'Sprint speed and range value', 'Sprint speed (ft/s)', 'Range runs', '01_speed_range')
scatter(samples$range_jump, 'jump_rel_league_bootup_distance', 'range_runs',
        'Outfielder Jump and range value', 'Jump relative to league (feet)', 'Range runs', '02_jump_range')
scatter(samples$arm_value_of_strength, 'arm_strength_arm_of', 'arm_runs',
        'OF arm strength and throwing value', 'OF arm strength (mph)', 'Arm runs', '03_arm_value')
d <- samples$deterrence_of_strength |>
  mutate(attempt_rate = arm_value_n_att_xb / arm_value_n_opp_xb)
scatter(d, 'arm_strength_arm_of', 'attempt_rate', 'OF arm strength and runner attempts',
        'OF arm strength (mph)', 'Extra-base attempts / opportunities', '04_arm_attempts')
# plotting range runs against arm runs for the same players
p <- ggplot(samples$range_vs_arm, aes(range_runs, arm_runs, color = position_group)) +
  geom_hline(yintercept = 0, color = 'grey75') + geom_vline(xintercept = 0, color = 'grey75') +
  geom_abline(slope = 1, intercept = 0, linetype = 'dashed', color = 'grey60') +
  geom_point(size = 2.4, alpha = .8) + coord_equal() + scale_color_manual(values = colors) +
  labs(title = 'Range and throwing runs on the same players',
       subtitle = '107 players | Dashed line: equal run values; totals depend on exposure',
       x = 'Range runs', y = 'Arm runs', color = 'Primary OF position', caption = caption)
save_plot(p, '05_range_vs_arm')
labels <- c(jump_n = 'Jump opportunities', sprint_speed_competitive_runs = 'Competitive runs',
            arm_strength_total_throws_of = 'Tracked OF throws', arm_value_n_opp_xb = 'Advancement opportunities')
# showing how opportunity counts are spread across players
p <- ggplot(opportunities, aes(count)) + geom_histogram(bins = 20, fill = '#0072B2', color = 'white') +
  facet_wrap(~metric, scales = 'free', labeller = as_labeller(labels)) +
  labs(title = 'How much evidence is available per player?',
       subtitle = 'Matched players with positive OF playing time; each panel uses its own source sample',
       x = 'Opportunities / events', y = 'Players', caption = caption)
save_plot(p, '06_opportunity_counts', height = 7)
print(opportunity_summary, width = Inf)
print(qualification_checks, width = Inf)
print(arm_difference, width = Inf)
