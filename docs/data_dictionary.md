# What the main data fields mean

The main R dataset is `data/processed/master_of_2025.rds`. There is also a CSV version for viewing the data. The RDS file keeps player IDs as text and yes/no flags in their original R types. Columns named after a source keep that source’s measurements with cleaned column names. See `data/processed/master_column_audit.csv` for the full column inventory.

| Field | Meaning / units |
|---|---|
| `mlbam_id` | MLB player identifier, stored as text; the join key. |
| `player_name` | Display name; not used as a join key. |
| `study_season` | Intended study year: 2025. Source verification is documented separately. |
| `outs_LF`, `outs_CF`, `outs_RF` | Outs played at each outfield position, converted from baseball innings notation. |
| `total_of_outs` | Sum of positional outs; divide by 3 for actual innings. |
| `primary_share` | Largest positional share of total outfield outs. |
| `position_group` | LF, CF, RF, or multi-position group under the 60% rule. |
| `position_comparison_eligible` | Whether a player qualifies for a primary-position comparison. |
| `range_runs` | Saved Statcast fielding runs prevented from the OAA export; runs above average. |
| `arm_runs` | Saved Arm Value fielder runs; runs above average. |
| `available_range_vs_arm` | Both run components and required playing time are available. |
| `arm_strength_arm_of` | Outfield throwing velocity, mph; verified 2025 source. |
| `sprint_speed_sprint_speed` | Sprint speed, feet per second. |
| `jump_rel_league_bootup_distance` | Overall Jump, feet relative to average. |
| `jump_rel_league_reaction_distance` | Reaction component, feet relative to average. |
| `jump_rel_league_burst_distance` | Burst component, feet relative to average. |
| `jump_rel_league_routing_distance` | Route component, feet relative to average. |
| `arm_value_n_opp_xb` | Count of tracked advancement opportunities. |
| `arm_value_n_att_xb` | Count of advancement attempts. |

A missing measurement is not the same as zero. If a player is absent from a positional innings file, the code treats that as zero innings at that position, based on how the files were collected. The report explains that assumption.

## Leaderboards

`combined_runs` is `range_runs + arm_runs`. The season-total ranking requires both components and positive outfield innings. The rate ranking additionally requires at least 450 innings.

`of_innings = total_of_outs / 3`; `runs_per_450 = combined_runs / of_innings * 450`. The rate output also retains `range_per_450` and `arm_per_450`. Displayed innings are ordinary decimals, not baseball decimal notation. Rankings are sorted before rounding.

## Evaluation outputs

- `loocv_rmse`: root mean squared held-out error, in runs for run models.
- `loocv_mae`: mean absolute held-out error, in runs for run models.
- `player_rate_rmse` / `player_rate_mae`: attempt-rate errors in proportions in saved tables; multiply by 100 for percentage points.
- Dispersion tables report standard deviations, variances, and covariance; these are descriptions of the selected players, not causal effects.
- `sample_membership.csv` records inclusion and exclusion reasons for each analysis; `sample_counts.csv` reconciles those samples to the roster.

For more about the sources and their limits, see the [final report](../reports/final_report.md) and [provenance audit](provenance_audit.md).
