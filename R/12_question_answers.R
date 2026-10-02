# Render a plain-language answer to every original research question.
library(tidyverse)
out <- 'data/processed/original_questions'
# making a shortcut to read the saved results for the original questions
read_result <- function(name) read_csv(file.path(out,name),show_col_types=FALSE)
balance <- read_result('position_balance.csv')
contrasts <- read_result('position_contrasts.csv')
scores <- read_result('interaction_scores.csv')
curves <- read_result('arm_curvature_scores.csv')
slopes <- read_result('position_slopes.csv')
tradeoffs <- read_result('within_position_tradeoffs.csv')
a <- read_result('arm_components_by_player.csv')
models <- read_csv('data/processed/models/model_comparison.csv',show_col_types=FALSE)
components <- read_csv('data/processed/jump_components/model_comparison.csv',show_col_types=FALSE)
attempts <- read_csv('data/processed/runner_attempts/model_comparison.csv',show_col_types=FALSE)
rmse <- function(f,m) models$loocv_rmse[models$family==f & models$model==m]
# formatting the results as tables for the written answers
md_table <- function(d,digits=2) {
 labels <- c(position='Position',players='Players',range_sd='Range SD',arm_sd='Arm SD',sd_ratio='Range / arm SD',
   family='Outcome',model='Model',rmse='RMSE',units='Units',range_player='Better range',arm_player='Better arm',
   range_advantage='Range advantage',arm_disadvantage='Arm disadvantage',combined_rate_advantage='Net advantage')
 names(d) <- ifelse(names(d) %in% names(labels),labels[names(d)],names(d))
 paste(knitr::kable(d,format='pipe',digits=digits,row.names=FALSE),collapse='\n')
}
# selecting the main results and the 450-inning comparison
p <- filter(balance,scenario=='primary')
q <- filter(balance,scenario=='minimum_450')
cfrf <- filter(contrasts,scenario=='primary',contrast=='CF / RF')
cfrf450 <- filter(contrasts,scenario=='minimum_450',contrast=='CF / RF')
curve <- filter(curves,group=='Overall')
# labeling the position models and showing attempt errors in percentage points
interaction_table <- scores |> filter(scenario=='primary',group=='Overall') |>
 mutate(rmse=if_else(family=='attempts',100*rmse,rmse),
   units=if_else(family=='attempts','percentage points','runs'),
   model=recode(model,position_only='Position baseline',no_position='Skill without position',
                common_slope='Position + shared skill slope',position_slopes='Position + separate skill slopes')) |>
 select(family,model,players,rmse,units)
# selecting two CF comparisons to show how range and arm advantages can offset each other
trade_example <- tradeoffs |> filter(arm_player=='Brenton Doyle',range_player %in% c('Victor Scott II','Michael Harris II')) |>
 select(range_player,arm_player,range_advantage,arm_disadvantage,combined_rate_advantage)
stopifnot(nrow(trade_example)==2)
# Dynamic evidence references ensure regeneration reflects current saved results.
# putting the saved numbers into the written answers so they update when the analysis is rerun
lines <- c(
 '# Did the project answer its original questions?', '',
 '**Leo Foust | 2025 outfield study**', '',
 'The original question was: **What matters more for MLB outfield defensive value—range or throwing ability—and how does the balance differ between LF, CF, and RF?** The supporting questions covered sprint speed, Jump components, arm strength, and runner attempts.', '',
 'The code now addresses each question with the saved data. Some answers are clear within this sample; others remain uncertain. Completing a test does not guarantee a definitive answer.', '',
 '## 1. Does range separate players more than throwing?', '',
 '**Yes, in the observed sample.** On the same 107 players, season-total standard deviations were 6.15 range runs and 2.18 arm runs. Range also had a larger observed spread after adjusting for innings and within each primary-position group.', '',
 'The table below puts both components on a 450-inning scale. The ratio divides the range standard deviation by the arm standard deviation. A ratio above 1 means range varies more; it is not a claim that a range run is worth more than an arm run.', '',
 md_table(p |> select(position,players,range_sd,arm_sd,sd_ratio)), '',
 'All three primary-sample 95% bootstrap intervals for the ratio were above 1. These intervals describe resampling uncertainty for the saved players, not every source of selection or measurement error. Point estimates stayed above 1 in all sensitivity scenarios; at the stricter 900-inning cutoff, the smaller LF sample had an interval that included 1.', '',
 '## 2. Does the balance change between LF, CF, and RF?', '',
 '**The primary sample suggests a larger range advantage in CF, but the size and certainty of the difference depend on the sample. We cannot establish a firm position ranking.**', '',
 sprintf('The CF range-to-arm spread ratio was %.2f, compared with %.2f in RF and %.2f in LF. The CF/RF comparison was %.2f, with an ordinary 95%% interval of %.2f–%.2f. After accounting for the three planned position comparisons, its wider interval was %.2f–%.2f and included 1 (no difference).',
 p$sd_ratio[p$position=='CF'],p$sd_ratio[p$position=='RF'],p$sd_ratio[p$position=='LF'],
 cfrf$balance_ratio,cfrf$lower_95,cfrf$upper_95,cfrf$lower_family,cfrf$upper_family), '',
 'The table below shows how the balance changes with a 450-inning minimum:', '',
 md_table(q |> select(position,players,range_sd,arm_sd,sd_ratio)), '',
 sprintf('With that cutoff, the CF/RF comparison falls to %.2f. The difference is much smaller, and RF no longer has the smallest range-to-arm ratio. The omitted players include two CFs with large range rates and three RFs with fewer than 450 innings. This is why the position conclusion should stay cautious.',cfrf450$balance_ratio), '',
 'The three planned contrasts use 98.33% percentile bootstrap intervals as an approximate Bonferroni adjustment; all primary adjusted intervals include 1. The 50% position-label scenario gives stronger CF/RF evidence, but it is a sensitivity check, not a reason to replace the primary result. Failure to resolve a difference does not show that positions are equivalent.', '',
 '![Position balance and its sensitivity to an innings minimum](../figures/13_position_balance.png)', '',
 '## 3. Did allowing different relationships by position help?', '',
 'I compared models without position, with position but a shared skill relationship, and with a separate skill relationship for each position. A position-only baseline is also shown. These comparisons use 77 LF/CF/RF players for range and 98 for throwing and attempts, so their errors should not be directly compared with the larger overall samples.', '',
 md_table(interaction_table,3), '',
 'Adding position to the Jump model lowered range RMSE modestly. Allowing a different Jump or arm-strength slope at each position did not improve range or arm-value RMSE over the shared-slope models. Different slopes slightly improved runner-attempt prediction, but the gain was small. The same direction of these shared-versus-separate-slope comparisons held at 50%, 60%, and 70% position cutoffs.', '',
 'These are exploratory predictive checks, not equivalence tests or proof of what would happen if a player changed position. Position labels summarize full-season outfield values, including innings played elsewhere.', '',
 '## 4. Is sprint speed enough, or does movement matter more?', '',
 sprintf('**Jump was more informative than speed alone.** Among the same 92 players, range RMSE was %.2f for the innings-and-position baseline, %.2f with speed, %.2f with Jump, and %.2f with both. Speed barely changed RMSE once Jump was included.',rmse('range','baseline'),rmse('range','speed'),rmse('range','jump'),rmse('range','speed_and_jump')), '',
 sprintf('Burst had the lowest individual-component RMSE (%.2f), versus %.2f for Reaction and %.2f for Route. This does not establish Burst as a universal winner over Jump, and it does not show that Reaction or Route are unimportant. The measurements overlap and the comparisons were explored within one season.',components$loocv_rmse[components$model=='burst'],components$loocv_rmse[components$model=='reaction'],components$loocv_rmse[components$model=='route']), '',
 '## 5. Does arm strength translate into arm value? Is there a threshold?', '',
 sprintf('**Stronger arms helped explain observed arm value.** On the same 118 players, RMSE fell from %.2f to %.2f after adding verified 2025 outfield strength to opportunities and position. The fitted linear relationship was positive.',rmse('arm','baseline'),rmse('arm','of_strength')), '',
 sprintf('A simple curved relationship (a quadratic) changed RMSE from %.3f to %.3f, only %.3f runs. That small gain does not establish a useful velocity threshold or prove that the relationship is linear. This was a limited curve check, not a search for a best breakpoint.',curve$rmse[curve$model=='linear'],curve$rmse[curve$model=='quadratic'],curve$rmse[curve$model=='linear']-curve$rmse[curve$model=='quadratic']), '',
 'Savant’s arm-value framework uses throwing arm among its inputs. These are related measurements, and the model does not estimate how much a training program would improve a player.', '',
 '## 6. Do strong arms discourage runners, even without recording outs?', '',
 sprintf('**The overall evidence for better attempt prediction is weak.** In the 118-player analysis, player-rate RMSE changed from %.3f to %.3f percentage points after adding strength. The estimated 5-mph odds ratio was 0.971, with an approximate 95%% interval of 0.942–1.002. That interval includes no association.',100*attempts$player_rate_rmse[attempts$model=='position'],100*attempts$player_rate_rmse[attempts$model=='position_and_arm']), '',
 'The position-specific model showed a negative estimated strength–attempt relationship in RF, but not consistently across all positions. The ordinary RF interval excluded zero; the interval adjusted for examining three position slopes included zero. Combined with the small predictive gains and missing runner/play context, this is a tentative pattern, not established causal deterrence.', '',
 'The saved arm-value data do assign value to holds as well as advances and outs. For example, Michael Harris II had about +5.40 hold runs and no recorded outs in the tracked advancement data, but −6.39 advance runs, for about −0.99 arm runs overall. Hold value without an out is possible; that does not prove arm strength caused the hold. Components reconcile to arm runs for all 118 players.', '',
 '## 7. Would I choose a range-first outfielder over an arm-first outfielder?', '',
 '**Not automatically. Compare how much range is gained with how much throwing value is lost.** On the same run scale and over equal exposure, a one-run range advantage exactly offsets a one-run arm disadvantage. One run has the same value in either component.', '',
 'Two observed CF comparisons illustrate this. Both players in each pair exceeded 450 innings. Values below are runs per 450 innings; the first player has better range and the second has better arm value:', '',
 md_table(trade_example), '',
 'Victor Scott II’s range advantage over Brenton Doyle more than covered his arm disadvantage. Michael Harris II’s range advantage did not. These examples describe 2025 rates, not future talent or a complete roster decision. The saved pair table contains every eligible within-position tradeoff; overlapping pairs are not independent evidence.', '',
 'There is no useful universal percentage of signed defensive runs attributable to range. Positive and negative components can cancel, and the variation in their sum includes covariance. This project reports the components and their spread instead of inventing a share.', '',
 '## Final answer', '',
 '**Range was the bigger separator in this 2025 sample, including within LF, CF, and RF. Jump and Burst helped explain range better than raw speed alone. Arm strength helped explain throwing value, but strong causal deterrence was not established. The evidence is not robust enough to claim a fixed position hierarchy, and the better player depends on the size of both component advantages.**', '',
 'The original questions are now covered as an exploratory analysis of the available data. Establishing future player value, causal effects, or the effect of switching positions would require additional evidence, especially more seasons and play-level context.', '',
 '## Evidence and reproducibility', '',
 '- [Extension design](../docs/final_questions_plan.md)',
 '- [Analysis code](../R/11_original_questions.R)',
 '- [Generated answer code](../R/12_question_answers.R)',
 '- [All extension tables](../data/processed/original_questions/)',
 '- [Main model results](../data/processed/models/model_comparison.csv)',
 '- [Runner-attempt results](../data/processed/runner_attempts/model_comparison.csv)', '',
 'Run `source("run_all.R")` from the project root to rebuild the analysis and this answer sheet. The extension is exploratory and was designed after reviewing the original results. Bootstrap uncertainty is conditional on the selected sample. No additional season or play-level data were used.'
)
writeLines(lines,'reports/original_questions_answered.md')
