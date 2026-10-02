# Sensitivity checks; preserve primary samples and all previous outputs.
# Thresholds: 50%, 60%, 70%. Ties stay multi-position even at 50%.
# Influence: remove each flagged player separately, then all flagged players
# as an intentionally aggressive stress test. Never treat this as data cleaning.
library(tidyverse)
s <- readRDS('data/processed/samples/analysis_samples.rds')
out <- 'data/processed/sensitivity'
dir.create(out, recursive = TRUE, showWarnings = FALSE)
# changing the position cutoff to see whether the results depend on the 60% rule
prepare <- function(d, threshold) d |>
  mutate(position_group = case_when(
    total_of_outs > 0 & !tied_most_played & primary_share >= threshold ~ most_played_position,
    total_of_outs > 0 ~ 'Multi-position OF', TRUE ~ 'No OF innings'),
    position_group = factor(position_group, levels = c('CF','LF','RF','Multi-position OF')),
    of_innings = total_of_outs/3, speed = sprint_speed_sprint_speed,
    jump = jump_rel_league_bootup_distance, burst = jump_rel_league_burst_distance,
    reaction = jump_rel_league_reaction_distance, route = jump_rel_league_routing_distance,
    strength = arm_strength_arm_of, arm_opportunities = arm_value_n_opp_xb,
    attempts = arm_value_n_att_xb, holds = arm_value_n_opp_xb-arm_value_n_att_xb)
formulas <- list(
 range = list(baseline = range_runs ~ of_innings + position_group,
  speed = range_runs ~ of_innings + position_group + speed,
  jump = range_runs ~ of_innings + position_group + jump,
  burst = range_runs ~ of_innings + position_group + burst,
  components = range_runs ~ of_innings + position_group + reaction + burst + route),
 arm = list(baseline = arm_runs ~ arm_opportunities + position_group,
  strength = arm_runs ~ arm_opportunities + position_group + strength),
 attempts = list(baseline = cbind(attempts, holds) ~ position_group,
  strength = cbind(attempts, holds) ~ position_group + strength))
base <- list(range = s$range_speed_and_components |> filter(!is.na(jump_rel_league_bootup_distance)),
             arm = s$arm_value_of_strength, attempts = s$deterrence_of_strength)
fit_one <- function(formula, d, family_name) {
  if (family_name == 'attempts') {
    fit <- glm(formula, d, family = quasibinomial(), na.action = na.fail)
    stopifnot(fit$converged)
  } else fit <- lm(formula, d, na.action = na.fail)
  stopifnot(fit$rank == ncol(model.matrix(fit)))
  fit
}
# rerunning the model comparisons for each version of the sample
evaluate <- function(d, family_name, scenario, threshold) {
 imap_dfr(formulas[[family_name]], function(formula, model_name) {
  fit <- fit_one(formula, d, family_name)
  # leaving each player out before predicting his result
  predictions <- vapply(seq_len(nrow(d)), function(i) {
    f <- fit_one(formula, d[-i,], family_name)
    as.numeric(if (family_name == 'attempts') predict(f,d[i,],type='response') else predict(f,d[i,]))
  }, numeric(1))
  actual <- if(family_name=='attempts') d$attempts/d$arm_opportunities else model.response(model.frame(fit))
  stopifnot(all(is.finite(predictions)))
  tibble(family = family_name, scenario = scenario, threshold = threshold,
    model = model_name, players = nrow(d), rmse = sqrt(mean((actual-predictions)^2)),
    mae = mean(abs(actual-predictions)),
    strength_coefficient = if ('strength' %in% names(coef(fit))) unname(coef(fit)['strength']) else NA_real_)
 })
}
# Same overall players across thresholds; only position controls change.
threshold_scores <- map_dfr(c(.5,.6,.7), function(threshold) {
 imap_dfr(base, ~ evaluate(prepare(.x,threshold),.y,'all_players',threshold))
})
position_counts <- map_dfr(c(.5,.6,.7), function(threshold) {
 prepare(s$range_vs_arm,threshold) |> count(position_group,name='players') |>
   mutate(threshold = threshold, .before=1)
})
# Direct comparison uses the matched run components, not the model samples.
component_dispersion <- map_dfr(c(.5,.6,.7), function(threshold) {
 d <- prepare(s$range_vs_arm,threshold)
 groups <- c(list(Overall=d), split(filter(d,position_group!='Multi-position OF'),
                                   droplevels(filter(d,position_group!='Multi-position OF')$position_group)))
 imap_dfr(groups,function(x,group) {
  tibble(threshold=threshold,group=group,players=nrow(x),
    range_sd=sd(x$range_runs),arm_sd=sd(x$arm_runs),
    range_rate_sd=sd(1000*x$range_runs/x$of_innings),
    arm_rate_sd=sd(1000*x$arm_runs/x$of_innings))
 })
})
# Flag from prespecified main fits at 60%. Union across models within a family
# ensures each comparison uses identical retained players, not model-specific cuts.
flags <- imap_dfr(base,function(raw,family_name) {
 d <- prepare(raw,.6)
 imap_dfr(formulas[[family_name]],function(formula,model_name) {
  fit <- fit_one(formula,d,family_name)
  tibble(family=family_name,model=model_name,mlbam_id=d$mlbam_id,
    player_name=d$player_name,cooks_distance=cooks.distance(fit),cutoff=4/nrow(d)) |>
    filter(cooks_distance>cutoff)
 })
})
# checking results without each flagged player, then without all flagged players
influence_scores <- imap_dfr(base,function(raw,family_name) {
 d <- prepare(raw,.6)
 ids <- flags |> filter(family==family_name) |> distinct(mlbam_id,player_name)
 individual <- map_dfr(ids$mlbam_id,function(id) {
   evaluate(filter(d,mlbam_id!=id),family_name,paste0('omit_',id),.6)
 })
 all_flagged <- evaluate(filter(d,!mlbam_id %in% ids$mlbam_id),family_name,'omit_all_flagged',.6)
 bind_rows(individual,all_flagged)
})
# Within each scenario, compare predictors to a baseline on the exact same rows.
all_scores <- bind_rows(threshold_scores,influence_scores) |>
 group_by(family,scenario,threshold) |>
 mutate(rmse_improvement_vs_baseline = rmse[model=='baseline']-rmse) |> ungroup()
write_csv(all_scores,file.path(out,'model_scores.csv'))
write_csv(flags,file.path(out,'influential_players.csv'))
write_csv(position_counts,file.path(out,'position_counts.csv'))
write_csv(component_dispersion,file.path(out,'component_dispersion.csv'))
# Direct component comparison: leave each of the 107 players out in turn.
leave_one <- map_dfr(s$range_vs_arm$mlbam_id,function(id) {
 d <- filter(s$range_vs_arm,mlbam_id!=id)
 tibble(omitted_id=id,range_sd=sd(d$range_runs),arm_sd=sd(d$arm_runs))
})
write_csv(leave_one,file.path(out,'component_leave_one_out.csv'))
# Verify 60% reproduced previous scores before interpreting sensitivity.
old <- read_csv('data/processed/models/model_comparison.csv',show_col_types=FALSE)
for(name in c('baseline','speed','jump')) {
 new <- threshold_scores |> filter(family=='range',threshold==.6,model==name)
 reference <- old |> filter(family=='range',model==name)
 stopifnot(abs(new$rmse-reference$loocv_rmse)<1e-8)
}
# summarizing how much the improvement over the baseline changes across these checks
summary <- all_scores |> filter(scenario!='all_players',model!='baseline') |>
 group_by(family,model) |>
 summarise(scenarios=n(),min_rmse_improvement=min(rmse_improvement_vs_baseline),
           max_rmse_improvement=max(rmse_improvement_vs_baseline),
           .groups='drop')
write_csv(summary,file.path(out,'influence_summary.csv'))
print(threshold_scores,width=Inf)
print(summary,width=Inf)
print(component_dispersion,width=Inf)
cat('Range SD exceeds arm SD in every single-player omission:',all(leave_one$range_sd>leave_one$arm_sd),'\n')
