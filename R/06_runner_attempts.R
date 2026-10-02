# Exploratory deterrence association; no causal interpretation.
# Prespecified comparison: position alone versus position + OF arm strength.
# Counts supply denominators; quasibinomial allows extra player-level variation.
library(tidyverse)
s <- readRDS('data/processed/samples/analysis_samples.rds')
# calculating attempts, holds, and the attempt rate for each player
d <- s$deterrence_of_strength |>
  mutate(position_group = factor(position_group, levels = c('CF','LF','RF','Multi-position OF')),
    strength = arm_strength_arm_of, attempts = arm_value_n_att_xb,
    opportunities = arm_value_n_opp_xb, holds = opportunities-attempts,
    attempt_rate = attempts/opportunities)
stopifnot(!anyDuplicated(d$mlbam_id), all(d$opportunities > 0),
          all(d$attempts >= 0 & d$holds >= 0), all(complete.cases(select(d,strength,position_group,attempts,holds))))
out <- 'data/processed/runner_attempts'
dir.create(out, recursive = TRUE, showWarnings = FALSE)
# comparing position alone with position plus arm strength
formulas <- list(position = cbind(attempts, holds) ~ position_group,
                 position_and_arm = cbind(attempts, holds) ~ position_group + strength)
models <- imap(formulas, function(formula, name) {
  # using attempts and holds so the model accounts for each player's number of opportunities
  fit <- glm(formula, data = d, family = quasibinomial(), na.action = na.fail)
  stopifnot(fit$converged, fit$rank == ncol(model.matrix(fit)))
  # predicting each player's attempt rate using a model fitted without him
  pred <- vapply(seq_len(nrow(d)), function(i) {
    f <- glm(formula, data = d[-i,], family = quasibinomial(), na.action = na.fail)
    stopifnot(f$converged, f$rank == ncol(model.matrix(f)))
    as.numeric(predict(f, d[i,], type = 'response'))
  }, numeric(1))
  stopifnot(all(is.finite(pred) & pred > 0 & pred < 1))
  # Equal-player rate errors and event-weighted errors answer different questions.
  # Brier/log loss below are reconstructed from aggregate binary-event counts.
  score <- tibble(model = name, players = nrow(d), opportunities = sum(d$opportunities),
    player_rate_rmse = sqrt(mean((pred-d$attempt_rate)^2)),
    player_rate_mae = mean(abs(pred-d$attempt_rate)),
    event_brier = sum(d$attempts*(1-pred)^2+d$holds*pred^2)/sum(d$opportunities),
    event_log_loss = -sum(d$attempts*log(pred)+d$holds*log1p(-pred))/sum(d$opportunities),
    dispersion = summary(fit)$dispersion)
  co <- as.data.frame(coef(summary(fit)))
  coefficients <- tibble(model = name, term = rownames(co), estimate = co[[1]], quasi_se = co[[2]])
  diagnostics <- tibble(model = name, mlbam_id = d$mlbam_id, player_name = d$player_name,
    position_group = d$position_group, opportunities = d$opportunities, attempts = d$attempts,
    observed_rate = d$attempt_rate, held_out_rate = pred, fitted_rate = fitted(fit),
    pearson_residual = residuals(fit, type = 'pearson'), leverage = hatvalues(fit),
    cooks_distance = cooks.distance(fit))
  list(fit = fit, score = score, coefficients = coefficients, diagnostics = diagnostics)
})
# combining the scores and saving the model results
scores <- map_dfr(models, 'score')
write_csv(scores, file.path(out,'model_comparison.csv'))
write_csv(map_dfr(models,'coefficients'), file.path(out,'coefficients.csv'))
write_csv(map_dfr(models,'diagnostics'), file.path(out,'player_diagnostics.csv'))
saveRDS(models, file.path(out,'attempt_models.rds'))
fit <- models$position_and_arm$fit
b <- coef(fit)['strength']; se <- sqrt(vcov(fit)['strength','strength'])
critical <- qt(.975, df.residual(fit))
# expressing the strength relationship as a 5 mph difference; an odds ratio of 1 means no difference
effect <- tibble(contrast = '5 mph harder OF arm', odds_ratio = exp(5*b),
  lower_95 = exp(5*(b-critical*se)), upper_95 = exp(5*(b+critical*se)))
write_csv(effect, file.path(out,'arm_odds_ratio.csv'))
# Lines stay within each position group's observed strength range.
grid <- d |> group_by(position_group) |>
  summarise(low = min(strength), high = max(strength), .groups = 'drop') |>
  rowwise() |> mutate(strength = list(seq(low, high, length.out = 100))) |>
  unnest(strength) |> ungroup()
grid$fitted_rate <- predict(fit, grid, type = 'response')
# plotting actual attempt rates and the fitted relationship at each position
p <- ggplot(d, aes(strength, attempt_rate)) +
  geom_point(aes(size = opportunities), alpha = .65, color = '#0072B2') +
  geom_line(data = grid, aes(y = fitted_rate), color = '#D55E00', linewidth = .8) +
  facet_wrap(~position_group) + scale_y_continuous(labels = scales::label_percent()) +
  labs(title = 'Do runners challenge stronger outfield arms less often?',
    subtitle = paste(nrow(d), 'players | Quasibinomial model: position + OF arm strength'),
    x = 'OF arm strength (mph)', y = 'Extra-base attempt rate', size = 'Opportunities',
    caption = 'Descriptive association; runner/play context is not controlled. See the source audit for qualification limits.') +
  theme_minimal(base_size = 12) + theme(legend.position = 'bottom')
ggsave('figures/11_runner_attempts.png', p, width = 10, height = 7, dpi = 160, bg = 'white')
print(scores, width = Inf)
print(effect)
print(models$position_and_arm$coefficients)
