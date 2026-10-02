# Jump components — exploratory follow-up

Run `source("R/05_jump_components.R")` after script 04. The comparison uses the
same 92 players and the same controls (OF innings and primary-position group).
Every held-out prediction is made after training on the other 91 players.

Before fitting, script 05 specifies: baseline, Jump benchmark, individual
components, combined components, speed plus components, and removal of each
component from the combined model. This is an exploratory follow-up to earlier
results, not a preregistered confirmatory test. No players were removed for influence.

| Added predictor(s) | Held-out RMSE | Held-out MAE |
|---|---:|---:|
| None | 5.90 | 4.71 |
| Jump | 3.95 | 3.15 |
| Reaction | 5.55 | 4.42 |
| Burst | 3.69 | 2.96 |
| Route | 5.93 | 4.75 |
| Reaction + Burst + Route | 3.79 | 3.05 |
| Speed + all components | 3.86 | 3.10 |

Burst has the strongest individual predictive signal in this sample. Removing
Burst from the combined model raises RMSE from 3.79 to 5.20. Removing Reaction
or Route produces RMSEs of 3.75 and 3.74. Thus they do not improve this particular
model's held-out errors beyond the other components. This does not establish
that reaction or route quality is unimportant to baseball defense.

## Shared information

Reaction and Route have correlation -0.849; Burst and Jump correlate 0.948.
In the combined model, variance inflation factors are 6.70 for Reaction, 2.16
for Burst, and 5.33 for Route. The Reaction and Route coefficients are therefore
harder to separate. Jump is never fitted alongside its component variables.
Unstable conditional coefficients should not be interpreted as independent
causal effects. The component model estimates Burst at about 4.55 additional
range runs per additional foot, conditional on its other predictors; its HC3
standard error is 0.52. This remains an association within this selected sample.

## Verification and limitations

All ten models and their held-out training fits have full-rank designs. Explicit
held-out errors agree with the independent PRESS identity within 1e-7. Baseline
and Jump predictions reproduce script 04 exactly, and player IDs/order match.
Outputs include coefficients with HC3 standard errors, player diagnostics,
correlations, VIFs, model objects, and comparison/removal tables.

The small gap between Burst (3.69) and Jump (3.95) has no estimated uncertainty
interval; do not declare a definitive winner. Multiple exploratory comparisons
on one season can produce optimistic choices. Independent-season validation
would be needed before forecasting claims. OF innings only approximate exposure;
OAA qualification and original export provenance remain incomplete. No causal
claim or final player-skill ranking follows from these fits.
