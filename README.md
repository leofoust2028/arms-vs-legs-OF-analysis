# Arm or Legs? Outfield Defense in MLB

**By Leo Foust**  
**Tools:** R, tidyverse, ggplot2, R Markdown

## Overview

A strong throw from the outfield is easy to notice, but getting to a ball in the gap can save runs too. I wanted to know which part of outfield defense separates players more: their range or their throwing ability.

Using 2025 MLB data, I compared range and arm runs, looked at the differences between LF, CF, and RF, and tested whether speed, Jump, and arm strength helped explain defensive results. I also made leaderboards for season totals and runs per 450 innings, the equivalent of 50 full games in the field.

## Main Findings

### Range made the bigger difference between players

Among the same 107 outfielders, range runs had a **standard deviation of 6.15 runs**, compared with **2.18 for arm runs**. Standard deviation measures how spread out the results are, so range accounted for larger differences between players in this sample. That pattern also held after adjusting for playing time.

This does not mean I would always pick the player with better range. A one-run advantage in range offsets a one-run disadvantage in throwing. The overall comparison depends on how much better each player is at both.

### The position question had a less clear answer

Range varied more than arm value in LF, CF, and RF. Center field initially showed a larger balance toward range than right field, but that difference became much smaller when I required at least 450 innings. The uncertainty was too large to establish a firm ranking between positions.

Allowing Jump and arm strength to have different relationships at each position also did not improve the range or arm models' prediction errors. That does **not** establish that position does not matter.

### Jump helped explain range more than speed alone

Adding Jump to the range model lowered prediction error from **5.90 to 3.95 runs**. Adding Sprint Speed lowered it to **5.66 runs**. This suggests that how an outfielder moves to the ball adds information beyond how fast he can run.

Burst stood out among the Jump components, although its small advantage over overall Jump needs more testing.

![Prediction errors for range models using Jump and its components; lower is better](figures/09_jump_component_comparison.png)

### Arm strength helped, but did not explain everything

Adding arm strength lowered the arm model's prediction error from **2.15 to 1.91 runs**. A curved relationship improved the score by only another **0.005 runs**, so I did not find evidence for a useful velocity threshold in this model.

Stronger arms also did not meaningfully improve predictions of how often runners attempted to advance. This analysis did not provide strong evidence that arm strength alone explained those decisions.

### The leaderboard changed after adjusting for playing time

**Pete Crow-Armstrong** led the combined season leaderboard with **24.5 runs above average**. **Ceddanne Rafaela** led per 450 innings at **8.20 runs**, just ahead of Crow-Armstrong at **8.13**. The rate leaderboard requires at least 450 outfield innings.

## Data and Methods

I joined **2025 Baseball Savant** range runs, arm runs, Sprint Speed, Jump, and Arm Strength with **FanGraphs outfield innings**, using player IDs. I checked missing values and seasons, converted innings to outs before adding them, and assigned a main position when a player spent at least 60% of his outfield innings there.

The samples included **107 players** for range versus arm, **92** for movement models, and **118** for throwing models. Competing models within each question used the same players.

I used **multiple linear regression** to compare skill measurements while accounting for innings or advancement opportunities and position. A **quasibinomial model** compared runner attempts with non-attempts, accounting for the number of opportunities behind each player's rate.

I tested predictions by leaving one player out, fitting the model on everyone else, and predicting that player's result. **RMSE (root mean squared error)** squares those prediction errors, averages them, and takes the square root. Lower is better, and large misses count more heavily. Range and arm scores are measured in runs. These are within-season predictions, not future forecasts.

I checked different position cutoffs, innings minimums, and individual-player exclusions. **Bootstrap sampling**, repeatedly resampling players, helped estimate uncertainty in the range and arm comparisons.

## Takeaways and Limitations

My main takeaway is that range was the bigger source of differences in defensive runs in this sample, and Jump helped explain those results better than speed alone. Throwing still mattered, and evaluating an individual player means looking at both parts of his defense.

This covers one season and selected players with available data. It shows relationships, not cause and effect. The position comparisons use each player's full outfield season, rather than separate run values for innings at each position. Arm strength is also an input to the arm-value framework, so those measures are not fully independent.

A season check caught a problem with the original arm-strength file. I replaced it with verified 2025 data and reran the affected analyses. [Data sources and correction details](docs/provenance_audit.md).

## Code and Leaderboards

- [R scripts](R/)
- [Season leaderboard](reports/combined_runs_leaderboard.md)
- [Leaderboard per 450 innings](reports/runs_per_450_leaderboard.md)

Intermediate tables, saved models, and the full report are generated locally by the code. The repository keeps the main charts and leaderboards.

*Source data remain subject to their providers' terms.*
