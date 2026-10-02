# Final integrity checks and uncertainty for descriptive dispersion.
library(tidyverse)
m <- readRDS('data/processed/master_of_2025.rds')
s <- readRDS('data/processed/samples/analysis_samples.rds')
# keeping track of the checks that pass; a failed check stops the script
checks <- character()
check <- function(name,condition) { if(!isTRUE(condition)) stop(name); checks <<- c(checks,name) }
check('One master row per MLBAM ID', !anyDuplicated(m$mlbam_id))
check('Verified strength records have 2025 year',all(m$arm_strength_year[m$has_arm_strength]==2025))
check('No zero-innings players in analysis samples',all(vapply(s,function(d) all(d$total_of_outs>0),logical(1))))
check('All OF strength candidates meet 50-throw rule',all(s$arm_value_of_strength$arm_strength_total_throws_of>=50))
check('Direct comparison has both run values',all(complete.cases(s$range_vs_arm[c('range_runs','arm_runs')])) )
counts <- read_csv('data/processed/samples/sample_counts.csv',show_col_types=FALSE)
check('Sample counts reconcile with full roster',all(counts$included+counts$excluded==nrow(m)))
# Compare source snapshot IDs, seasons and values independently of joins.
oaa <- jsonlite::fromJSON('docs/verification/oaa_2025_web_data.json')
check('OAA roster matches official qualified snapshot',setequal(m$mlbam_id[m$has_oaa],as.character(oaa$entity_id)))
check('OAA snapshot all qualified in 2025',all(oaa$is_qualified_leaderboard==1 & oaa$year==2025))
av <- jsonlite::fromJSON('docs/verification/arm_2025_web_data.json')
check('Arm Value roster matches official qualified snapshot',setequal(m$mlbam_id[m$has_arm_value],as.character(av$entity_id)))
check('Arm Value snapshot season is 2025',all(av$start_year==2025 & av$end_year==2025))
# Bootstrap players in each group, pairing range and arm values within player.
# Conditional descriptive uncertainty only: not measurement error, selection
# bias, or a random sample of all MLB players. No model-selection inference.
# setting the random seed so the bootstrap results can be reproduced
set.seed(20261001)
b <- s$range_vs_arm
groups <- c(list(Overall=b),split(filter(b,position_comparison_eligible),filter(b,position_comparison_eligible)$position_group))
uncertainty <- imap_dfr(groups,function(d,group) {
  # resampling players 2,000 times and comparing the spread of range and arm runs
  draws <- replicate(2000,{
    z <- d[sample.int(nrow(d),nrow(d),replace=TRUE),]
    sd(z$range_runs)-sd(z$arm_runs)
  })
  # using the middle 95% of the bootstrap results for the uncertainty interval
  tibble(group=group,players=nrow(d),sd_difference=sd(d$range_runs)-sd(d$arm_runs),
    lower_95=quantile(draws,.025),upper_95=quantile(draws,.975),bootstrap_draws=2000L)
})
dir.create('data/processed/final',recursive=TRUE,showWarnings=FALSE)
write_csv(uncertainty,'data/processed/final/dispersion_uncertainty.csv')
write_csv(tibble(check=checks,status='PASS'),'data/processed/final/validation.csv')
# plotting the range-minus-arm difference and its uncertainty interval
p <- ggplot(uncertainty,aes(sd_difference,forcats::fct_rev(factor(group,levels=c('Overall','CF','LF','RF'))))) +
 geom_vline(xintercept=0,linetype='dashed',color='grey50') +
 geom_segment(aes(x=lower_95,xend=upper_95,yend=group),color='#0072B2',linewidth=1) +
 geom_point(size=3,color='#0072B2') + theme_minimal(base_size=12) +
 labs(title='Range runs have greater observed spread',subtitle='Paired player bootstrap: 2,000 resamples per group',
 x='Range SD minus arm SD (runs)',y=NULL,
 caption='Conditional on the saved sample; intervals exclude data selection and measurement uncertainty.')
ggsave('figures/12_dispersion_uncertainty.png',p,width=9,height=5,dpi=160,bg='white')
print(uncertainty)
message(length(checks),' final integrity checks passed.')
