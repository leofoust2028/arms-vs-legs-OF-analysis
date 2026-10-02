# Main linear comparisons; corrected sources documented in docs/provenance_audit.md.
library(tidyverse)
s <- readRDS('data/processed/samples/analysis_samples.rds')
out <- 'data/processed/models'
dir.create(out, recursive = TRUE, showWarnings = FALSE)
# shortening column names and converting outs into innings for the models
prepare <- function(d) d |> mutate(of_innings = total_of_outs / 3,
  position_group = factor(position_group, levels = c('CF', 'LF', 'RF', 'Multi-position OF')),
  speed = sprint_speed_sprint_speed, jump = jump_rel_league_bootup_distance,
  of_strength = arm_strength_arm_of, overall_strength = arm_strength_arm_overall,
  arm_opportunities = arm_value_n_opp_xb)
r <- prepare(s$range_speed_and_components) |> filter(!is.na(jump))
a <- prepare(s$arm_value_of_strength)
stopifnot(nrow(r) == 92, nrow(a) > 20, all(!is.na(a$overall_strength)))
# comparing the baseline with speed, Jump, and both together
range_formulas <- list(baseline = range_runs ~ of_innings + position_group,
  speed = range_runs ~ of_innings + position_group + speed,
  jump = range_runs ~ of_innings + position_group + jump,
  speed_and_jump = range_runs ~ of_innings + position_group + speed + jump)
# checking whether arm strength adds information beyond opportunities and position
arm_formulas <- list(baseline = arm_runs ~ arm_opportunities + position_group,
  of_strength = arm_runs ~ arm_opportunities + position_group + of_strength,
  overall_strength_sensitivity = arm_runs ~ arm_opportunities + position_group + overall_strength)

# running each model and saving its predictions and results
fit_set <- function(d, formulas, family_name) {
  imap(formulas, function(formula, model_name) {
    fit <- lm(formula, data = d, na.action = na.fail)
    X <- model.matrix(fit)
    stopifnot(fit$rank == ncol(X))
    # Fit every training set explicitly so each held-out player is excluded.
    prediction <- vapply(seq_len(nrow(d)), function(i) {
      train_fit <- lm(formula, data = d[-i, ], na.action = na.fail)
      stopifnot(train_fit$rank == ncol(model.matrix(train_fit)))
      as.numeric(predict(train_fit, newdata = d[i, ]))
    }, numeric(1))
    actual <- model.response(model.frame(fit))
    # HC3 covariance adjusts standard errors for unequal residual variance.
    bread <- solve(crossprod(X))
    adjusted <- residuals(fit) / (1 - hatvalues(fit))
    V <- bread %*% crossprod(X, X * as.numeric(adjusted^2)) %*% bread
    se <- sqrt(diag(V))
    coefficients <- tibble(term = names(coef(fit)), estimate = coef(fit),
                           hc3_se = se)
    # checking which players have large errors or a strong effect on the fitted model
    diagnostics <- tibble(mlbam_id = d$mlbam_id, player_name = d$player_name,
      fitted = fitted(fit), residual = residuals(fit), standardized_residual = rstandard(fit),
      leverage = hatvalues(fit), cooks_distance = cooks.distance(fit),
      influence_flag = cooks_distance > 4/nrow(d), actual = actual,
      held_out_prediction = prediction)
    scaled_X <- scale(X[, colnames(X) != '(Intercept)', drop = FALSE])
    # calculating prediction errors; RMSE squares the misses, averages them, then takes the square root
    score <- tibble(family = family_name, model = model_name, players = nrow(d),
      loocv_rmse = sqrt(mean((actual-prediction)^2)), loocv_mae = mean(abs(actual-prediction)),
      adjusted_r_squared = summary(fit)$adj.r.squared,
      scaled_condition_number = kappa(scaled_X, exact = TRUE),
      influence_flags = sum(diagnostics$influence_flag))
    list(fit = fit, coefficients = coefficients, diagnostics = diagnostics, score = score)
  })
}
# running the range and arm comparisons on their own fixed samples
results <- list(range = fit_set(r, range_formulas, 'range'), arm = fit_set(a, arm_formulas, 'arm'))
scores <- map_dfr(results, ~ map_dfr(.x, 'score'))
write_csv(scores, file.path(out, 'model_comparison.csv'))
coefficients <- imap_dfr(results, function(models, family_name) {
  imap_dfr(models, ~ mutate(.x$coefficients, family = family_name, model = .y, .before = 1))
})
diagnostics <- imap_dfr(results, function(models, family_name) {
  imap_dfr(models, ~ mutate(.x$diagnostics, family = family_name, model = .y, .before = 1))
})
write_csv(coefficients, file.path(out, 'coefficients_hc3.csv'))
write_csv(diagnostics, file.path(out, 'player_diagnostics.csv'))
saveRDS(results, file.path(out, 'first_models.rds'))

# Observed variance identity, with exposure sensitivities on identical players.
both <- prepare(s$range_vs_arm)
groups <- c(list(Overall = both), split(filter(both, position_comparison_eligible),
                                      droplevels(filter(both, position_comparison_eligible)$position_group)))
# comparing the spread of range and arm runs before and after playing-time adjustments
dispersion <- imap_dfr(groups, function(d, group_name) {
  variants <- list(season_totals = cbind(d$range_runs, d$arm_runs),
    per_1000_of_innings = cbind(d$range_runs, d$arm_runs) * (1000/d$of_innings),
    innings_adjusted_residuals = cbind(resid(lm(range_runs ~ of_innings, d)),
                                      resid(lm(arm_runs ~ of_innings, d))))
  imap_dfr(variants, function(v, scale_name) {
    vr <- var(v[,1]); va <- var(v[,2]); cv <- cov(v[,1],v[,2]); vt <- var(rowSums(v))
    stopifnot(isTRUE(all.equal(vt, vr + va + 2*cv)))
    tibble(group = group_name, scale = scale_name, players = nrow(d),
      range_sd = sqrt(vr), arm_sd = sqrt(va), range_variance = vr,
      arm_variance = va, twice_covariance = 2*cv, total_variance = vt)
  })
})
write_csv(dispersion, file.path(out, 'component_dispersion.csv'))
# Predictor correlations use the same 92-player sample.
write.csv(cor(select(r, speed, jump, of_innings)), file.path(out, 'range_predictor_correlations.csv'))
theme_set(theme_minimal(base_size = 11))
selected <- diagnostics |> filter((family == 'range' & model == 'speed_and_jump') |
                                  (family == 'arm' & model == 'of_strength'))
# plotting the model errors to look for patterns
p <- ggplot(selected, aes(fitted, residual)) + geom_hline(yintercept = 0, color = 'grey60') +
  geom_point(alpha = .7) + facet_wrap(~family, scales = 'free') +
  labs(title = 'Linear-model residual checks', subtitle = 'Observations retained regardless of influence',
       x = 'Fitted runs', y = 'Residual runs')
ggsave('figures/07_model_residuals.png', p, width = 9, height = 5, dpi = 160)
# checking how closely the errors follow a normal distribution
p <- ggplot(selected, aes(sample = standardized_residual)) + stat_qq() + stat_qq_line() +
  facet_wrap(~family) + labs(title = 'Normal Q-Q checks', x = 'Theoretical quantile', y = 'Standardized residual')
ggsave('figures/08_model_qq.png', p, width = 9, height = 5, dpi = 160)
print(scores, width = Inf)
print(dispersion |> filter(scale == 'season_totals'), width = Inf)
