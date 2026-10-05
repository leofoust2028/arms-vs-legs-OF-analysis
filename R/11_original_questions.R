# Finish the original position and arm-shape questions on saved 2025 data.
# Exploratory follow-up using the saved 2025 samples; see the README for limits.
library(tidyverse)
s <- readRDS('data/processed/samples/analysis_samples.rds')
out <- 'data/processed/original_questions'
dir.create(out, recursive=TRUE, showWarnings=FALSE)
# setting the random seed so these results can be reproduced
set.seed(20261002)
# using 5,000 bootstrap samples for each position group
B <- 5000L
positions <- c('CF','LF','RF')
# selecting players who meet the position and innings rules, then calculating runs per 450 innings
classify <- function(d, cutoff=.6, minimum=0) {
 d |> filter(total_of_outs/3 >= minimum, total_of_outs > 0,
             !tied_most_played, primary_share >= cutoff) |>
  mutate(position=factor(most_played_position,levels=positions),
    innings=total_of_outs/3, range_rate=450*range_runs/innings,
    arm_rate=450*arm_runs/innings, jump=jump_rel_league_bootup_distance,
    strength=arm_strength_arm_of, opportunities=arm_value_n_opp_xb,
    attempts=arm_value_n_att_xb, holds=opportunities-attempts)
}
# A paired bootstrap preserves range/arm dependence within each player.
metrics <- function(d) {
 r <- sd(d$range_rate); a <- sd(d$arm_rate)
 c(range_sd=r,arm_sd=a,sd_difference=r-a,sd_ratio=r/a,
   twice_covariance=2*cov(d$range_rate,d$arm_rate),
   total_variance=var(d$range_rate+d$arm_rate))
}
# checking different position cutoffs and minimum innings requirements
scenarios <- tibble(scenario=c('primary','position_50','position_70','minimum_450','minimum_900'),
 cutoff=c(.6,.5,.7,.6,.6), minimum=c(0,0,0,450,900))
all_summaries <- list(); all_contrasts <- list(); all_members <- list(); draws_saved <- list()
pairs <- list(c('CF','RF'),c('CF','LF'),c('RF','LF'))
for(k in seq_len(nrow(scenarios))) {
 sc <- scenarios[k,]; d <- classify(s$range_vs_arm,sc$cutoff,sc$minimum)
 all_members[[k]] <- d |> select(mlbam_id,player_name,position,innings,range_runs,arm_runs,range_rate,arm_rate) |>
   mutate(scenario=sc$scenario,.before=1)
 groups <- split(d,d$position,drop=TRUE)
 stopifnot(setequal(names(groups),positions),all(lengths(lapply(groups,rownames))>=10))
 # resampling within each position and keeping each player's range and arm values together
 draws <- lapply(groups,function(g) t(replicate(B,metrics(g[sample.int(nrow(g),replace=TRUE),]))))
 stopifnot(all(vapply(draws,function(z) all(is.finite(z)),logical(1))))
 draws_saved[[sc$scenario]] <- draws
 all_summaries[[k]] <- imap_dfr(groups,function(g,pos) {
  m <- metrics(g); z <- draws[[pos]]
  stopifnot(abs(m['total_variance']-(m['range_sd']^2+m['arm_sd']^2+m['twice_covariance']))<1e-8)
  tibble(scenario=sc$scenario,position=pos,players=nrow(g),
   minimum_innings=min(g$innings),median_innings=median(g$innings),
   range_sd=m['range_sd'],arm_sd=m['arm_sd'],sd_difference=m['sd_difference'],sd_ratio=m['sd_ratio'],
   difference_lower=quantile(z[,'sd_difference'],.025),difference_upper=quantile(z[,'sd_difference'],.975),
   ratio_lower=quantile(z[,'sd_ratio'],.025),ratio_upper=quantile(z[,'sd_ratio'],.975),
   twice_covariance=m['twice_covariance'],total_variance=m['total_variance'])
 })
 # comparing CF with RF, CF with LF, and RF with LF
 all_contrasts[[k]] <- map_dfr(pairs,function(pair) {
  left <- pair[1]; right <- pair[2]
  # Log-ratio contrasts: >0 means greater range/arm spread ratio in left group.
  z <- log(draws[[left]][,'sd_ratio'])-log(draws[[right]][,'sd_ratio'])
  diff_draw <- draws[[left]][,'sd_difference']-draws[[right]][,'sd_difference']
  estimate <- metrics(groups[[left]])['sd_ratio']/metrics(groups[[right]])['sd_ratio']
  tibble(scenario=sc$scenario,contrast=paste(left,'/',right),balance_ratio=estimate,
    lower_95=exp(quantile(z,.025)),upper_95=exp(quantile(z,.975)),
    # widening the intervals because I am making three position comparisons
    lower_family=exp(quantile(z,.05/(2*3))),upper_family=exp(quantile(z,1-.05/(2*3))),
    range_arm_gap_difference=metrics(groups[[left]])['sd_difference']-metrics(groups[[right]])['sd_difference'],
    gap_lower_95=quantile(diff_draw,.025),gap_upper_95=quantile(diff_draw,.975))
 })
}
summary <- bind_rows(all_summaries); contrasts <- bind_rows(all_contrasts)
write_csv(summary,file.path(out,'position_balance.csv'))
write_csv(contrasts,file.path(out,'position_contrasts.csv'))
write_csv(bind_rows(all_members),file.path(out,'position_membership.csv'))
saveRDS(draws_saved,file.path(out,'position_bootstrap_draws.rds'))
# Single-player omission sensitivity of the primary between-position comparison.
d <- classify(s$range_vs_arm)
omissions <- map_dfr(d$mlbam_id,function(id) {
 z <- filter(d,mlbam_id!=id); m <- lapply(split(z,z$position),metrics)
 map_dfr(pairs,function(pair) tibble(omitted_id=id,contrast=paste(pair,collapse=' / '),
   balance_ratio=m[[pair[1]]]['sd_ratio']/m[[pair[2]]]['sd_ratio']))
})
write_csv(omissions,file.path(out,'position_leave_one_out.csv'))

# Fixed samples within each question and scenario. No outcome-based exclusions.
fit_one <- function(f,d,family_name) {
 if(family_name=='attempts') {
  fit <- glm(f,d,family=quasibinomial(),na.action=na.fail)
  stopifnot(fit$converged)
 } else fit <- lm(f,d,na.action=na.fail)
 stopifnot(fit$rank==ncol(model.matrix(fit)))
 fit
}
# fitting each model and testing predictions by leaving one player out at a time
evaluate <- function(d,f,family_name,model,scenario='primary') {
 fit <- fit_one(f,d,family_name)
 pred <- vapply(seq_len(nrow(d)),function(i) {
  z <- fit_one(f,d[-i,],family_name)
  as.numeric(if(family_name=='attempts') predict(z,d[i,],type='response') else predict(z,d[i,]))
 },numeric(1))
 actual <- if(family_name=='attempts') d$attempts/d$opportunities else model.response(model.frame(fit))
 stopifnot(all(is.finite(pred)))
 if(family_name=='attempts') stopifnot(all(pred>0 & pred<1))
 diagnostics <- tibble(scenario=scenario,family=family_name,model=model,mlbam_id=d$mlbam_id,
  player_name=d$player_name,position=as.character(d$position),actual=actual,predicted=pred)
 score <- function(idx,label) {
  a <- actual[idx]; p <- pred[idx]
  tibble(scenario=scenario,family=family_name,model=model,group=label,players=sum(idx),
   rmse=sqrt(mean((a-p)^2)),mae=mean(abs(a-p)),
   event_brier=if(family_name=='attempts') sum(d$attempts[idx]*(1-p)^2+d$holds[idx]*p^2)/sum(d$opportunities[idx]) else NA_real_)
 }
 scores <- bind_rows(score(rep(TRUE,nrow(d)),'Overall'),map_dfr(unique(as.character(d$position)),~score(d$position==.x,.x)))
 list(fit=fit,scores=scores,predictions=diagnostics)
}
# comparing models with no position term, shared skill slopes, and different slopes by position
formula_sets <- list(
 range=list(position_only=range_runs~innings+position,
   no_position=range_runs~innings+jump,
   common_slope=range_runs~innings+position+jump,
   position_slopes=range_runs~innings+position*jump),
 arm=list(position_only=arm_runs~opportunities+position,
   no_position=arm_runs~opportunities+strength,
   common_slope=arm_runs~opportunities+position+strength,
   position_slopes=arm_runs~opportunities+position*strength),
 attempts=list(position_only=cbind(attempts,holds)~position,
   no_position=cbind(attempts,holds)~strength,
   common_slope=cbind(attempts,holds)~position+strength,
   position_slopes=cbind(attempts,holds)~position*strength))
raw_samples <- list(range=s$range_speed_and_components |> filter(is.finite(jump_rel_league_bootup_distance)),
 arm=s$arm_value_of_strength, attempts=s$deterrence_of_strength)
results <- list(); slopes <- list()
for(cutoff in c(.5,.6,.7)) for(family_name in names(raw_samples)) {
 scenario <- if(cutoff==.6) 'primary' else paste0('position_',100*cutoff)
 d <- classify(raw_samples[[family_name]],cutoff)
 for(model in names(formula_sets[[family_name]])) {
  key <- paste(scenario,family_name,model,sep='_')
  results[[key]] <- evaluate(d,formula_sets[[family_name]][[model]],family_name,model,scenario)
 }
 if(cutoff==.6) {
  fit <- results[[paste(scenario,family_name,'position_slopes',sep='_')]]$fit
  X <- model.matrix(fit)
  if(family_name=='attempts') V <- vcov(fit) else {
   bread <- solve(crossprod(X)); adj <- residuals(fit)/(1-hatvalues(fit))
   V <- bread %*% crossprod(X,X*as.numeric(adj^2)) %*% bread
  }
  skill <- if(family_name=='range') 'jump' else 'strength'
  # calculating the skill relationship and its uncertainty for each position
  slopes[[family_name]] <- map_dfr(positions,function(pos) {
   v <- setNames(rep(0,length(coef(fit))),names(coef(fit)));v[skill]<-1
   if(pos!='CF') v[paste0('position',pos,':',skill)]<-1
   estimate<-sum(v*coef(fit));se<-sqrt(drop(t(v)%*%V%*%v));crit<-qt(.975,df.residual(fit))
   family_crit<-qt(1-.05/(2*3),df.residual(fit))
   tibble(family=family_name,position=pos,players=sum(d$position==pos),slope=estimate,
    lower_95=estimate-crit*se,upper_95=estimate+crit*se,
    lower_family=estimate-family_crit*se,upper_family=estimate+family_crit*se,
    units=if(family_name=='range') 'range runs per foot of Jump' else if(family_name=='arm') 'arm runs per mph' else 'log odds per mph',
    interval=if(family_name=='attempts') 'quasibinomial t interval' else 'HC3 t interval')
  })
 }
}
write_csv(map_dfr(results,'scores'),file.path(out,'interaction_scores.csv'))
write_csv(map_dfr(results,'predictions'),file.path(out,'interaction_predictions.csv'))
write_csv(bind_rows(slopes),file.path(out,'position_slopes.csv'))
saveRDS(map(results,'fit'),file.path(out,'interaction_models.rds'))

# Full arm sample, matching the previous overall throwing comparison.
a <- s$arm_value_of_strength |> mutate(position=factor(position_group),
 opportunities=arm_value_n_opp_xb,strength=arm_strength_arm_of,
 # A fixed reference merely centers the polynomial; it is not a learned threshold.
 centered_strength=strength-90)
# adding squared arm strength to check whether a curve improves predictions
curves <- list(baseline=arm_runs~opportunities+position,
 linear=arm_runs~opportunities+position+centered_strength,
 quadratic=arm_runs~opportunities+position+centered_strength+I(centered_strength^2))
curve_results <- imap(curves,~evaluate(a,.x,'arm',.y,'curvature'))
write_csv(map_dfr(curve_results,'scores'),file.path(out,'arm_curvature_scores.csv'))
write_csv(map_dfr(curve_results,'predictions'),file.path(out,'arm_curvature_predictions.csv'))
saveRDS(map(curve_results,'fit'),file.path(out,'arm_curvature_models.rds'))
old <- read_csv('data/processed/models/model_comparison.csv',show_col_types=FALSE)
stopifnot(abs(curve_results$linear$scores$rmse[1]-old$loocv_rmse[old$family=='arm' & old$model=='of_strength'])<1e-8)

# Arm component accounting, including value associated with holds.
a <- s$arm_value_of_strength |> mutate(innings=total_of_outs/3,
 hold_runs=arm_value_fielder_runs_hold,advance_runs=arm_value_fielder_runs_advances,
 out_runs=arm_value_fielder_runs_thrown_out)
stopifnot(max(abs(a$arm_runs-a$hold_runs-a$advance_runs-a$out_runs))<1e-8)
# separating arm value into holds, advances, and outs
arm_components <- a |> select(mlbam_id,player_name,position_group,innings,arm_runs,hold_runs,advance_runs,out_runs,
 arm_value_n_opp_xb,arm_value_n_att_xb,arm_value_n_out) |>
 mutate(across(c(arm_runs,hold_runs,advance_runs,out_runs),~450*.x/innings,.names='{.col}_per_450'))
write_csv(arm_components,file.path(out,'arm_components_by_player.csv'))
component_summary <- arm_components |> group_by(position_group) |>
 summarise(players=n(),across(c(hold_runs,advance_runs,out_runs,arm_runs),sum),.groups='drop')
write_csv(component_summary,file.path(out,'arm_components_by_position.csv'))

# All within-position tradeoff pairs with >=450 innings; descriptive, not forecasts.
b <- classify(s$range_vs_arm,.6,450)
pair_rows <- list();i<-0L
# comparing players at the same position when one has better range and the other has better arm value
for(pos in positions) {
 g <- filter(b,position==pos)
 for(pair in combn(seq_len(nrow(g)),2,simplify=FALSE)) {
  x<-g[pair[1],];y<-g[pair[2],]
  if(x$range_rate<y$range_rate){temp<-x;x<-y;y<-temp}
  if(x$range_rate<=y$range_rate || x$arm_rate>=y$arm_rate) next
  i<-i+1L
  pair_rows[[i]]<-tibble(position=pos,range_player=x$player_name,arm_player=y$player_name,
   range_player_id=x$mlbam_id,arm_player_id=y$mlbam_id,
   range_player_innings=x$innings,arm_player_innings=y$innings,
   range_advantage=x$range_rate-y$range_rate,arm_disadvantage=y$arm_rate-x$arm_rate,
   combined_rate_advantage=(x$range_rate+x$arm_rate)-(y$range_rate+y$arm_rate))
 }
}
# combining the player comparisons and checking that the run differences add up
tradeoffs<-bind_rows(pair_rows)
stopifnot(max(abs(tradeoffs$combined_rate_advantage-(tradeoffs$range_advantage-tradeoffs$arm_disadvantage)))<1e-10)
write_csv(tradeoffs,file.path(out,'within_position_tradeoffs.csv'))
# These overlapping pairs are dependent, so do not treat their count as sample size for inference.
write_csv(tradeoffs |> group_by(position) |> summarise(pairs=n(),range_player_higher_total=sum(combined_rate_advantage>0),
 arm_player_higher_total=sum(combined_rate_advantage<0),ties=sum(combined_rate_advantage==0),.groups='drop'),
 file.path(out,'tradeoff_summary.csv'))

primary <- filter(summary,scenario=='primary')
# comparing the position results with and without a 450-inning minimum
plot_data <- summary |> filter(scenario %in% c('primary','minimum_450')) |>
 mutate(sample=factor(scenario,levels=c('primary','minimum_450'),
   labels=c('Primary sample: no extra innings minimum','Sensitivity: at least 450 OF innings')))
p <- ggplot(plot_data,aes(x=position,y=sd_ratio,ymin=ratio_lower,ymax=ratio_upper)) +
 geom_hline(yintercept=1,linetype='dashed',color='grey50')+
 geom_errorbar(width=.12,color='#0072B2',linewidth=.7)+geom_point(size=3,color='#0072B2')+
 geom_text(aes(label=sprintf('%.2f (n=%d)',sd_ratio,players)),vjust=-1,nudge_x=.15,size=3.2)+
 facet_wrap(~sample)+
 labs(title='Range varies more than arm value at all three positions',
 subtitle='SD of range runs per 450 innings / SD of arm runs per 450 innings',
 x='Primary outfield position (60% of innings)',y='Range-to-arm spread ratio',
 caption='95% paired-player bootstrap intervals; 5,000 draws. These are spread ratios, not value multipliers.\nPosition contrasts are tested separately; full-season values include innings at other positions.')+
 theme_minimal(base_size=12)
ggsave('figures/13_position_balance.png',p,width=10,height=6,dpi=160,bg='white')
write_csv(tibble(check=c('Position variance identity','Fixed-sample full-rank held-out fits',
 'Previous arm RMSE reproduced','Arm components reconcile','Player tradeoff arithmetic'),status='PASS'),
 file.path(out,'validation.csv'))
print(primary,width=Inf)
print(filter(contrasts,scenario=='primary'),width=Inf)
print(map_dfr(results,'scores') |> filter(scenario=='primary',group=='Overall'),width=Inf)
print(map_dfr(curve_results,'scores') |> filter(group=='Overall'),width=Inf)
