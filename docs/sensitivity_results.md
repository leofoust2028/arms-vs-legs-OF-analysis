> **Historical note — superseded for throwing results on 2026-10-01.** The original Arm Strength file was not verified as 2025. The pipeline now uses an official year-tagged 2025 snapshot. Consult `reports/final_report.html` and current generated CSVs for corrected results. Range-only findings are unchanged.

# Sensitivity checks

Script 07 reruns model comparisons at 50%, 60%, and 70% primary-position shares.
Overall model samples stay fixed at 92 range players and 97 throwing/attempt
players; their positional labels change. Tied positions remain multi-position.
Position-specific descriptive comparisons require meeting the threshold.

## Position thresholds

| Threshold | Classified players in direct comparison | Jump RMSE | Burst RMSE | Speed RMSE |
|---|---:|---:|---:|---:|
| 50% | 98 | 3.87 | 3.67 | 5.81 |
| 60% | 88 | 3.95 | 3.69 | 5.66 |
| 70% | 77 | 3.77 | 3.55 | 5.52 |

Jump and Burst remain more informative than speed across these thresholds.
Adding OF arm strength to throwing-value models improves held-out RMSE by about
0.18 runs at each threshold. Its association with runner attempts remains
negative, but its predictive improvement remains very small.

Range-run standard deviation exceeds arm-run standard deviation in every LF,
CF, and RF group at each threshold. The pattern also holds per 1,000 OF innings.
The overall 107-player dispersion comparison remains unchanged because threshold
changes do not remove multi-position players from overall analyses.

## Influence checks

Flag players using Cook's distance > 4/n, taking the union across compared models
within each family. This flags 14 range players, 10 throwing-value players, and
10 attempt-model players. Refit all compared models on the same retained rows
within each scenario. Remove each flagged player separately, then all flagged
players together as an aggressive stress test. None of these exclusions changes
the primary data or analysis samples.

Against a baseline fitted on the same retained players, held-out RMSE improvement
remains positive in every influence scenario for Jump (1.49–2.02 runs), Burst
(1.97–2.33), speed (0.05–0.34), and OF strength predicting arm runs (0.16–0.22).
These are scenario ranges, not confidence intervals. Absolute errors from different
retained samples should not be compared as if they measure model improvement.

For runner attempts, removing one flagged player at a time preserves the tiny
predictive gain. Removing all ten together eliminates it: RMSE becomes worse by
0.0066 percentage points than the position-only baseline. The strength coefficient
stays negative in every scenario. Thus a negative conditional association is more
stable than the claim that strength meaningfully improves attempt prediction.

The 107-player overall dispersion comparison was also recalculated after omitting
each individual player in turn. Range SD exceeds arm SD in all 107 versions.
This does not prove stability to deleting multiple extreme players together.

## Verification and scope

All full and held-out fits converged where applicable and had full-rank designs.
The 60% range baseline, speed, and Jump results reproduce script 04 within 1e-8.
Outputs preserve every scenario, retained sample size, flags, position counts,
and dispersion comparison. Primary models and data remain untouched.

Influence flags depend on fitted outcomes. These exclusions are diagnostics,
not a basis for cleaning data or selecting a publishable sample. These are
one-factor-at-a-time checks: influence is evaluated at 60%, not crossed with
all thresholds. We have not estimated uncertainty intervals for model differences,
validated another season, or resolved original export qualification/provenance.
The defensible conclusion is that the main descriptive range findings survive
these specific checks; the deterrence finding remains tentative.
