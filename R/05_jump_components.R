# Exploratory follow-up: compare movement components on the same players.
# Run after scripts 01–04. Model comparisons were specified before these fits:
# baseline, Jump benchmark, each component alone, all three, speed plus all
# three, and removing each component from the three-component model.
# Do not put Jump and its components in the same model: they share information.
library(tidyverse)
s <- readRDS('data/processed/samples/analysis_samples.rds')
previous <- readRDS('data/processed/models/first_models.rds')$range
out <- 'data/processed/jump_components'
dir.create(out, recursive = TRUE, showWarnings = FALSE)
# keeping the same players as the earlier range models
d <- s$range_speed_and_components |>
  mutate(of_innings = total_of_outs/3,
    position_group = factor(position_group, levels = c('CF','LF','RF','Multi-position OF')),
    speed = sprint_speed_sprint_speed, jump = jump_rel_league_bootup_distance,
    reaction = jump_rel_league_reaction_distance,
    burst = jump_rel_league_burst_distance, route = jump_rel_league_routing_distance) |>
  filter(!is.na(jump))
stopifnot(identical(d$mlbam_id, previous$jump$diagnostics$mlbam_id),
          all(complete.cases(select(d, range_runs, of_innings, position_group, speed, jump, reaction, burst, route))))
# testing Reaction, Burst, and Route separately, together, and with one removed
formulas <- list(
  baseline = range_runs ~ of_innings + position_group,
  jump = range_runs ~ of_innings + position_group + jump,
  reaction = range_runs ~ of_innings + position_group + reaction,
  burst = range_runs ~ of_innings + position_group + burst,
  route = range_runs ~ of_innings + position_group + route,
  all_components = range_runs ~ of_innings + position_group + reaction + burst + route,
  speed_and_components = range_runs ~ of_innings + position_group + speed + reaction + burst + route,
  without_reaction = range_runs ~ of_innings + position_group + burst + route,
  without_burst = range_runs ~ of_innings + position_group + reaction + route,
  without_route = range_runs ~ of_innings + position_group + reaction + burst)
models <- imap(formulas, function(formula, model_name) {
  fit <- lm(formula, d, na.action = na.fail)
  X <- model.matrix(fit)
  stopifnot(fit$rank == ncol(X))
  # leaving one player out at a time and predicting his range runs
  pred <- vapply(seq_len(nrow(d)), function(i) {
    train <- lm(formula, d[-i,], na.action = na.fail)
    stopifnot(train$rank == ncol(model.matrix(train)))
    as.numeric(predict(train, d[i,]))
  }, numeric(1))
  # Independent check of the explicit leave-one-out training procedure.
  stopifnot(max(abs((d$range_runs-pred) - residuals(fit)/(1-hatvalues(fit)))) < 1e-7)
  # calculating HC3 standard errors, which allow the error size to vary across players
  bread <- solve(crossprod(X))
  adjusted <- residuals(fit)/(1-hatvalues(fit))
  V <- bread %*% crossprod(X, X*as.numeric(adjusted^2)) %*% bread
  coefficients <- tibble(model = model_name, term = names(coef(fit)),
    estimate = coef(fit), hc3_se = sqrt(diag(V)))
  # comparing predicted runs with actual runs; lower RMSE and MAE are better
  scores <- tibble(model = model_name, players = nrow(d),
    loocv_rmse = sqrt(mean((d$range_runs-pred)^2)), loocv_mae = mean(abs(d$range_runs-pred)),
    scaled_condition_number = kappa(scale(X[,-1,drop=FALSE]), exact = TRUE))
  diagnostics <- tibble(model = model_name, mlbam_id = d$mlbam_id, player_name = d$player_name,
    actual = d$range_runs, prediction = pred, fitted = fitted(fit), residual = residuals(fit),
    standardized_residual = rstandard(fit), leverage = hatvalues(fit),
    cooks_distance = cooks.distance(fit))
  list(fit = fit, coefficients = coefficients, scores = scores, diagnostics = diagnostics)
})
comparison <- map_dfr(models, 'scores')
# Benchmarks must reproduce script 04 exactly on this shared sample.
for (name in c('baseline','jump')) {
  stopifnot(isTRUE(all.equal(models[[name]]$diagnostics$prediction,
                            previous[[name]]$diagnostics$held_out_prediction)))
}
# checking how much prediction error changes when I remove each component
removal <- comparison |> filter(startsWith(model, 'without_')) |>
  mutate(rmse_change_vs_all_components = loocv_rmse - models$all_components$scores$loocv_rmse,
         mae_change_vs_all_components = loocv_mae - models$all_components$scores$loocv_mae)
# checking how closely the movement measurements are related
correlations <- cor(select(d, speed, jump, reaction, burst, route))
# Coefficients are runs per foot of a component, conditional on other predictors.
# VIF here measures each component's overlap with all other model columns.
full_X <- model.matrix(models$all_components$fit)
# checking how much each component overlaps with the other model variables
vif <- map_dfr(c('reaction','burst','route'), function(term) {
  y <- full_X[,term]
  others <- full_X[,!colnames(full_X) %in% c('(Intercept)',term),drop=FALSE]
  tibble(component = term, vif = 1/(1-summary(lm(y ~ others))$r.squared))
})
# saving the model scores, player predictions, and component comparisons
write_csv(comparison, file.path(out, 'model_comparison.csv'))
write_csv(removal, file.path(out, 'component_removal.csv'))
write_csv(map_dfr(models, 'coefficients'), file.path(out, 'coefficients_hc3.csv'))
write_csv(map_dfr(models, 'diagnostics'), file.path(out, 'player_diagnostics.csv'))
write_csv(vif, file.path(out, 'component_vif.csv'))
write.csv(correlations, file.path(out, 'predictor_correlations.csv'))
saveRDS(models, file.path(out, 'component_models.rds'))

# Show prespecified model families separately; avoid declaring a winner by a
# tiny error difference. These exploratory comparisons have no external test set.
# labeling the models for the prediction-error plot
plot_data <- comparison |> filter(!startsWith(model,'without_')) |>
  mutate(label = recode(model, baseline = 'Playing time + position', jump = '+ Jump',
    reaction = '+ Reaction', burst = '+ Burst', route = '+ Route',
    all_components = '+ Reaction, Burst, Route', speed_and_components = '+ Speed and components'),
    label = factor(label, levels = rev(label)))
p <- ggplot(plot_data, aes(loocv_rmse, label)) + geom_point(size = 3, color = '#0072B2') +
  labs(title = 'Which movement measures add predictive information?',
    subtitle = paste(nrow(d), 'identical players | Every model controls OF innings and position'),
    x = 'Held-out RMSE (runs; lower is better)', y = NULL,
    caption = 'Exploratory within-2025 associations; qualification provenance remains incomplete.') +
  theme_minimal(base_size = 12)
ggsave('figures/09_jump_component_comparison.png', p, width = 10, height = 6, dpi = 160, bg = 'white')
diag <- models$all_components$diagnostics
p <- ggplot(diag, aes(fitted, residual)) + geom_hline(yintercept = 0, color = 'grey60') +
  geom_point(alpha = .75) + theme_minimal(base_size = 12) +
  labs(title = 'Combined component model: residual check', x = 'Fitted range runs', y = 'Residual runs')
ggsave('figures/10_component_residuals.png', p, width = 8, height = 5, dpi = 160, bg = 'white')
print(comparison, width = Inf)
print(removal, width = Inf)
print(round(correlations, 3))
print(vif)
print(models$all_components$coefficients)
