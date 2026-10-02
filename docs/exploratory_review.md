> **Historical note — superseded for throwing results on 2026-10-01.** The original Arm Strength file was not verified as 2025. The pipeline now uses an official year-tagged 2025 snapshot. Consult `reports/final_report.html` and current generated CSVs for corrected results. Range-only findings are unchanged.

# Exploratory review — 2026-09-30

## Qualification evidence

Published rules checked against official sources on 2026-09-30. These establish
what the current pages say; they do not recover the original download settings
or independently verify the season of exports without a year column.

| Metric | Published rule | Local check |
|---|---|---|
| OF Arm Strength | At least 50 tracked throws; average of hardest 10% | All 153 matched players with an OF strength value have at least 50 OF throws |
| Jump | Two-Star or harder plays; opportunities greater than team games / 5 | All 92 have 33–100 opportunities; consistent with a 162-game season assumption |
| Sprint Speed | At least 10 competitive runs | All 295 matched positive-inning players have at least 10 |
| OAA | OF: one fielding attempt per team game | Attempt counts absent from this CSV; cannot check player qualification locally |
| Arm Value | Page offers a Qualified opportunities setting | Numerical rule not established from the inspected page; do not substitute OAA's rule |

Sources: [Arm Strength](https://baseballsavant.mlb.com/leaderboard/arm-strength),
[Jump](https://baseballsavant.mlb.com/jump),
[Sprint Speed](https://baseballsavant.mlb.com/leaderboard/sprint_speed?max_season=2025&min=10&min_season=2025&position=10&team=),
[OAA](https://baseballsavant.mlb.com/leaderboard/outs_above_average),
[Arm Value](https://baseballsavant.mlb.com/leaderboard/baserunning?type=Fld).

## Data review

- Jump: median 58.5 opportunities, range 33–100 among 92 players.
- Arm Value: median 236 advancement opportunities, range 116–458 among 118 players.
- Sprint Speed: median 84 competitive runs, range 10–291 among 295 positive-inning players.
- The Arm Strength source includes infielders with incidental OF time. Its 186
  roster matches include 33 without an OF-specific strength value. Do not interpret
  these blanks as weak arms or replace them with zeros.
- Using overall arm strength instead of OF strength expands the arm-value sample
  from 97 to 99: Willi Castro (6 tracked OF throws) and Alec Burleson (0). Both are
  multi-position players. Recommendation: use OF-specific strength as the main
  throwing predictor; keep overall strength as a separate sensitivity candidate.
- Arm Value attempt rates reconcile with attempts/opportunities, outs plus safe
  advances reconcile with attempts, and the run components reconcile with totals.

## Reading the figures

Six PNGs in `figures` show speed/range, Jump/range, strength/arm runs,
strength/attempt rate, range/arm runs, and opportunity distributions. They use
candidate samples and contain no fitted trend lines or inferential tests.
The range-versus-arm plot uses the same 107 players and equally scaled axes.
It compares seasonal totals, not skill per opportunity or causal effects.

Qualification uncertainty remains visible in figure captions. Opportunity counts
refer to different events; they are not interchangeable regression weights.
Position labels describe each player's primary OF position, not position-specific
run values. A classified RF's season total can include work at other positions.

The Arm Value documentation describes throwing arm as an input to the underlying
expected-outcome model. A strength-versus-arm-value association therefore needs
careful interpretation; the outcome is not wholly independent of the predictor's
measurement framework. Runner attempt rates also reflect runner and play context,
so an unadjusted plot alone cannot establish deterrence.

## Next methodological decisions

Recover original OAA/Arm Value qualification settings or obtain an export with
verifiable opportunity counts. Confirm season provenance for files without year
columns. Agree on the primary arm measure before models. Keep the descriptive
figures exploratory; no sample thresholds or model choices were selected from
which plots look most convincing.
