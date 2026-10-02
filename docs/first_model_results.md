> **Historical note — superseded for throwing results on 2026-10-01.** The original Arm Strength file was not verified as 2025. The pipeline now uses an official year-tagged 2025 snapshot. Consult `reports/final_report.html` and current generated CSVs for corrected results. Range-only findings are unchanged.

# First model results — provisional

Run `R/04_first_models.R` after scripts 01–03. The plan is in `analysis_plan.md`.
Qualification provenance remains incomplete; these are candidate-sample results.

## Range: fair comparison on 92 players

All models include OF innings and primary-position group. Leave-one-player-out
validation trains on the other 91 players, then predicts the held-out player's
2025 range runs. Lower RMSE is better; units are runs.

| Added predictor | Held-out RMSE | Held-out MAE |
|---|---:|---:|
| None | 5.90 | 4.71 |
| Sprint Speed | 5.66 | 4.68 |
| Jump | 3.95 | 3.15 |
| Speed + Jump | 3.95 | 3.23 |

Jump improves prediction much more than speed in this sample. Adding speed to
Jump offers essentially no RMSE improvement and slightly worsens MAE. This does
not establish that speed is unimportant or that Jump causes range value. Jump
and OAA also share aspects of their tracking/opportunity framework.

## Throwing: 97 players

With advancement opportunities and position in both models, adding OF arm
strength lowers held-out RMSE from 2.24 to 2.06 runs (MAE: 1.79 to 1.57).
Overall arm strength is exactly equal to OF strength for these 97 players, so
that sensitivity model produces identical results. The expanded 99-player
sample would instead change the population and is not fitted here.
Do not compare range-model and arm-model RMSE directly: outcomes and samples differ.

## Between-player variation

On the same 107 players, range-run SD is 6.15 and arm-run SD is 2.18 runs.
Range dispersion is also greater within CF (32 players), LF (24), and RF (32).
That pattern persists using runs per 1,000 OF innings and residuals after linear
innings adjustment. These describe observed variation, not causal effects or
true-talent variance. Primary-position groups contain full-season player values,
including any work at other positions. Neither approach controls actual OAA
opportunity difficulty. Covariance is reported separately in the output rather
than allocating misleading percentages of total defensive value.

## Diagnostics and verification

All seven fits have full-rank design matrices. Scaled condition numbers are
approximately 1.85–2.45. Explicit held-out predictions match the independent
linear-model PRESS identity within 1e-7.

Residual and Q-Q plots show tail departures, particularly positive arm residuals;
normal errors should not simply be assumed. HC3 robust standard errors are saved.
The speed-plus-Jump fit flags eight observations at Cook's distance > 4/n; the
OF-strength fit flags seven. These are review flags, not automatic deletions.
Examples with the largest influence: Mike Tauchman, JJ Bleday, Jarren Duran
(range); Steven Kwan, Mike Yastrzemski, Mickey Moniak (arm).

Outputs include per-player held-out predictions, diagnostics, robust coefficient
standard errors, the fitted models, and the component variance identity checks.
No uncertainty interval for the difference in prediction errors has been
estimated; small RMSE differences should not be treated as established gains.

## Next

Resolve OAA/Arm Value download qualification and yearless-file provenance before
publishing conclusions. Review flagged players and exposure sensitivity, then
consider components, nonlinear patterns, or runner deterrence with explicit
attention to sample size and contextual confounding. These first models are
within-season association models, not validated forecasts for another season.
