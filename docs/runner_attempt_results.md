> **Historical note — superseded for throwing results on 2026-10-01.** The original Arm Strength file was not verified as 2025. The pipeline now uses an official year-tagged 2025 snapshot. Consult `reports/final_report.html` and current generated CSVs for corrected results. Range-only findings are unchanged.

# Runner attempts — exploratory results

Script 06 compares position alone against position plus OF arm strength using
97 identical players and 25,078 advancement opportunities. Both models are
quasibinomial regressions of attempts versus non-attempts. Every held-out
prediction is trained without that player. The denominator enters the model
as counts, not as an arbitrary minimum-opportunity cutoff.

## Results

Adding arm strength changes held-out player-rate RMSE from 3.06 to 3.03 percentage
points and MAE from 2.45 to 2.42 percentage points. This is a very small predictive
improvement; no uncertainty interval for that improvement has been estimated.
Event-weighted Brier and log loss are also saved for both models. These use counts
to reconstruct binary-event scores, not squared errors on aggregate rates.

A 5 mph harder arm is associated with an attempt odds ratio of 0.960, conditional
on position (approximate model-based 95% interval 0.931–0.990). This means about
4% lower odds, not a four-percentage-point decrease in attempts. The model has a
single common arm slope across positions; position interactions were not fitted.

This is consistent with a modest deterrence association, but it does not prove
runners change behavior because of arm strength. Runner speed, batted-ball
geometry, base/out situations, park, and other play context are not controlled.
Position is the player's primary OF group, not the location of every opportunity.

## Checks and caveats

All full and held-out fits converged with full-rank designs and valid prediction
probabilities. Count validity is checked before fitting. Quasibinomial dispersion
is estimated (0.886 in the arm model), rather than assumed to exceed one. Its
standard errors do not resolve omitted contextual confounding or shared game/
runner dependencies. The interval is conditional on this model and sample.

The figure shows position-specific intercepts and the common arm slope only over
each group's observed arm-strength range. Point sizes represent opportunities.
Per-player residuals, leverage, Cook's distance and held-out rates are saved;
no player was removed for influence. Export qualification/provenance remains
incompletely verified. Treat this as exploratory supporting evidence.

## Run in RStudio

Open `R/06_runner_attempts.R` and click Source after building the samples.
Outputs are in `data/processed/runner_attempts`; the plot is
`figures/11_runner_attempts.png`.
