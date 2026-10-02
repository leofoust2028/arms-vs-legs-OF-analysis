# Did the project answer its original questions?

**Leo Foust | 2025 outfield study**

The original question was: **What matters more for MLB outfield defensive value—range or throwing ability—and how does the balance differ between LF, CF, and RF?** The supporting questions covered sprint speed, Jump components, arm strength, and runner attempts.

The code now addresses each question with the saved data. Some answers are clear within this sample; others remain uncertain. Completing a test does not guarantee a definitive answer.

## 1. Does range separate players more than throwing?

**Yes, in the observed sample.** On the same 107 players, season-total standard deviations were 6.15 range runs and 2.18 arm runs. Range also had a larger observed spread after adjusting for innings and within each primary-position group.

The table below puts both components on a 450-inning scale. The ratio divides the range standard deviation by the arm standard deviation. A ratio above 1 means range varies more; it is not a claim that a range run is worth more than an arm run.

|Position | Players| Range SD| Arm SD| Range / arm SD|
|:--------|-------:|--------:|------:|--------------:|
|CF       |      32|     3.81|   1.00|           3.82|
|LF       |      24|     2.13|   0.98|           2.18|
|RF       |      32|     2.65|   1.36|           1.95|

All three primary-sample 95% bootstrap intervals for the ratio were above 1. These intervals describe resampling uncertainty for the saved players, not every source of selection or measurement error. Point estimates stayed above 1 in all sensitivity scenarios; at the stricter 900-inning cutoff, the smaller LF sample had an interval that included 1.

## 2. Does the balance change between LF, CF, and RF?

**The primary sample suggests a larger range advantage in CF, but the size and certainty of the difference depend on the sample. We cannot establish a firm position ranking.**

The CF range-to-arm spread ratio was 3.82, compared with 1.95 in RF and 2.18 in LF. The CF/RF comparison was 1.96, with an ordinary 95% interval of 1.03–3.49. After accounting for the three planned position comparisons, its wider interval was 0.90–3.96 and included 1 (no difference).

The table below shows how the balance changes with a 450-inning minimum:

|Position | Players| Range SD| Arm SD| Range / arm SD|
|:--------|-------:|--------:|------:|--------------:|
|CF       |      30|     3.00|   1.02|           2.94|
|LF       |      24|     2.13|   0.98|           2.18|
|RF       |      29|     2.70|   1.05|           2.58|

With that cutoff, the CF/RF comparison falls to 1.14. The difference is much smaller, and RF no longer has the smallest range-to-arm ratio. The omitted players include two CFs with large range rates and three RFs with fewer than 450 innings. This is why the position conclusion should stay cautious.

The three planned contrasts use 98.33% percentile bootstrap intervals as an approximate Bonferroni adjustment; all primary adjusted intervals include 1. The 50% position-label scenario gives stronger CF/RF evidence, but it is a sensitivity check, not a reason to replace the primary result. Failure to resolve a difference does not show that positions are equivalent.

![Position balance and its sensitivity to an innings minimum](../figures/13_position_balance.png)

## 3. Did allowing different relationships by position help?

I compared models without position, with position but a shared skill relationship, and with a separate skill relationship for each position. A position-only baseline is also shown. These comparisons use 77 LF/CF/RF players for range and 98 for throwing and attempts, so their errors should not be directly compared with the larger overall samples.

|Outcome  |Model                            | Players|  RMSE|Units             |
|:--------|:--------------------------------|-------:|-----:|:-----------------|
|range    |Position baseline                |      77| 5.993|runs              |
|range    |Skill without position           |      77| 4.055|runs              |
|range    |Position + shared skill slope    |      77| 3.926|runs              |
|range    |Position + separate skill slopes |      77| 3.950|runs              |
|arm      |Position baseline                |      98| 2.134|runs              |
|arm      |Skill without position           |      98| 1.897|runs              |
|arm      |Position + shared skill slope    |      98| 1.893|runs              |
|arm      |Position + separate skill slopes |      98| 1.924|runs              |
|attempts |Position baseline                |      98| 3.112|percentage points |
|attempts |Skill without position           |      98| 3.364|percentage points |
|attempts |Position + shared skill slope    |      98| 3.133|percentage points |
|attempts |Position + separate skill slopes |      98| 3.096|percentage points |

Adding position to the Jump model lowered range RMSE modestly. Allowing a different Jump or arm-strength slope at each position did not improve range or arm-value RMSE over the shared-slope models. Different slopes slightly improved runner-attempt prediction, but the gain was small. The same direction of these shared-versus-separate-slope comparisons held at 50%, 60%, and 70% position cutoffs.

These are exploratory predictive checks, not equivalence tests or proof of what would happen if a player changed position. Position labels summarize full-season outfield values, including innings played elsewhere.

## 4. Is sprint speed enough, or does movement matter more?

**Jump was more informative than speed alone.** Among the same 92 players, range RMSE was 5.90 for the innings-and-position baseline, 5.66 with speed, 3.95 with Jump, and 3.95 with both. Speed barely changed RMSE once Jump was included.

Burst had the lowest individual-component RMSE (3.69), versus 5.55 for Reaction and 5.93 for Route. This does not establish Burst as a universal winner over Jump, and it does not show that Reaction or Route are unimportant. The measurements overlap and the comparisons were explored within one season.

## 5. Does arm strength translate into arm value? Is there a threshold?

**Stronger arms helped explain observed arm value.** On the same 118 players, RMSE fell from 2.15 to 1.91 after adding verified 2025 outfield strength to opportunities and position. The fitted linear relationship was positive.

A simple curved relationship (a quadratic) changed RMSE from 1.912 to 1.907, only 0.005 runs. That small gain does not establish a useful velocity threshold or prove that the relationship is linear. This was a limited curve check, not a search for a best breakpoint.

Savant’s arm-value framework uses throwing arm among its inputs. These are related measurements, and the model does not estimate how much a training program would improve a player.

## 6. Do strong arms discourage runners, even without recording outs?

**The overall evidence for better attempt prediction is weak.** In the 118-player analysis, player-rate RMSE changed from 3.045 to 3.060 percentage points after adding strength. The estimated 5-mph odds ratio was 0.971, with an approximate 95% interval of 0.942–1.002. That interval includes no association.

The position-specific model showed a negative estimated strength–attempt relationship in RF, but not consistently across all positions. The ordinary RF interval excluded zero; the interval adjusted for examining three position slopes included zero. Combined with the small predictive gains and missing runner/play context, this is a tentative pattern, not established causal deterrence.

The saved arm-value data do assign value to holds as well as advances and outs. For example, Michael Harris II had about +5.40 hold runs and no recorded outs in the tracked advancement data, but −6.39 advance runs, for about −0.99 arm runs overall. Hold value without an out is possible; that does not prove arm strength caused the hold. Components reconcile to arm runs for all 118 players.

## 7. Would I choose a range-first outfielder over an arm-first outfielder?

**Not automatically. Compare how much range is gained with how much throwing value is lost.** On the same run scale and over equal exposure, a one-run range advantage exactly offsets a one-run arm disadvantage. One run has the same value in either component.

Two observed CF comparisons illustrate this. Both players in each pair exceeded 450 innings. Values below are runs per 450 innings; the first player has better range and the second has better arm value:

|Better range      |Better arm    | Range advantage| Arm disadvantage| Net advantage|
|:-----------------|:-------------|---------------:|----------------:|-------------:|
|Michael Harris II |Brenton Doyle |            0.19|             2.42|         -2.23|
|Victor Scott II   |Brenton Doyle |            3.97|             3.36|          0.61|

Victor Scott II’s range advantage over Brenton Doyle more than covered his arm disadvantage. Michael Harris II’s range advantage did not. These examples describe 2025 rates, not future talent or a complete roster decision. The saved pair table contains every eligible within-position tradeoff; overlapping pairs are not independent evidence.

There is no useful universal percentage of signed defensive runs attributable to range. Positive and negative components can cancel, and the variation in their sum includes covariance. This project reports the components and their spread instead of inventing a share.

## Final answer

**Range was the bigger separator in this 2025 sample, including within LF, CF, and RF. Jump and Burst helped explain range better than raw speed alone. Arm strength helped explain throwing value, but strong causal deterrence was not established. The evidence is not robust enough to claim a fixed position hierarchy, and the better player depends on the size of both component advantages.**

The original questions are now covered as an exploratory analysis of the available data. Establishing future player value, causal effects, or the effect of switching positions would require additional evidence, especially more seasons and play-level context.

## Evidence and reproducibility

- [Extension design](../docs/final_questions_plan.md)
- [Analysis code](../R/11_original_questions.R)
- [Generated answer code](../R/12_question_answers.R)
- [All extension tables](../data/processed/original_questions/)
- [Main model results](../data/processed/models/model_comparison.csv)
- [Runner-attempt results](../data/processed/runner_attempts/model_comparison.csv)

Run `source("run_all.R")` from the project root to rebuild the analysis and this answer sheet. The extension is exploratory and was designed after reviewing the original results. Bootstrap uncertainty is conditional on the selected sample. No additional season or play-level data were used.
