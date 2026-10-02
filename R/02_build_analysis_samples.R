# Arm or Legs? Candidate samples and transparent exclusion reasons.
# Run 01_build_dataset.R first, then source this script from the project root.
# These are data-availability samples; source verification and remaining limits
# are in docs/provenance_audit.md. No universal playing-time cutoff is imposed.
library(tidyverse)

master <- readRDS("data/processed/master_of_2025.rds")
stopifnot(!anyDuplicated(master$mlbam_id))
output_dir <- "data/processed/samples"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Each question needs its own columns. The combined range sample is useful for
# comparing speed and movement on the same players; it does not replace the
# larger samples available for individual relationships.
# OF and overall arm strength are separate candidates pending metric selection.
# listing the measurements I need for each research question
sample_specs <- list(
  range_speed = c("range_runs", "sprint_speed_sprint_speed"),
  range_jump = c("range_runs", "jump_rel_league_bootup_distance"),
  range_components = c("range_runs", "jump_rel_league_reaction_distance",
                       "jump_rel_league_burst_distance", "jump_rel_league_routing_distance"),
  range_speed_and_components = c("range_runs", "sprint_speed_sprint_speed",
                                 "jump_rel_league_reaction_distance",
                                 "jump_rel_league_burst_distance", "jump_rel_league_routing_distance"),
  arm_value_of_strength = c("arm_runs", "arm_strength_arm_of"),
  arm_value_overall_strength = c("arm_runs", "arm_strength_arm_overall"),
  deterrence_of_strength = c("arm_strength_arm_of", "arm_value_n_opp_xb", "arm_value_n_att_xb"),
  deterrence_overall_strength = c("arm_strength_arm_overall", "arm_value_n_opp_xb", "arm_value_n_att_xb"),
  range_vs_arm = c("range_runs", "arm_runs")
)
required <- unique(unlist(sample_specs))
stopifnot(all(required %in% names(master)))

# A rate needs a positive denominator and valid counts. Zero attempts is valid.
# This is a consistency check, not a minimum-opportunity eligibility threshold.
opp <- master$arm_value_n_opp_xb
att <- master$arm_value_n_att_xb
valid_attempt_counts <- !is.na(opp) & !is.na(att) &
  opp > 0 & att >= 0 & att <= opp & opp == floor(opp) & att == floor(att)

# Record every reason, rather than only the first failure. An included player's
# reason string is empty. Positional variants add the existing 60% rule.
# recording which players can be used and why others are excluded
sample_membership <- imap_dfr(sample_specs, function(columns, sample_name) {
  reasons <- vapply(seq_len(nrow(master)), function(i) {
    issues <- character()
    if (!master$has_of_playing_time[i]) issues <- c(issues, "no OF playing time")
    missing_columns <- columns[vapply(columns, function(column) {
      !is.finite(master[[column]][i])
    }, logical(1))]
    if (length(missing_columns)) {
      issues <- c(issues, paste0("missing/nonfinite: ", missing_columns))
    }
    if (startsWith(sample_name, "deterrence") && !valid_attempt_counts[i]) {
      issues <- c(issues, "advancement counts missing or invalid")
    }
    paste(issues, collapse = "; ")
  }, character(1))
  overall <- tibble(mlbam_id = master$mlbam_id, player_name = master$player_name,
                    position_group = master$position_group,
                    sample = sample_name, included = reasons == "",
                    exclusion_reasons = reasons,
                    qualification_status = "saved source roster; see docs/provenance_audit.md for verification and limits")
  positional <- overall |>
    mutate(sample = paste0(sample_name, "_by_position"),
           included = included & master$position_comparison_eligible,
           exclusion_reasons = if_else(
             master$position_comparison_eligible, exclusion_reasons,
             if_else(exclusion_reasons == "", "no qualifying LF/CF/RF classification",
                     paste0(exclusion_reasons, "; no qualifying LF/CF/RF classification"))))
  bind_rows(overall, positional)
})

# Keep complete master rows in each sample, including opportunity counts,
# source-presence flags, and the alternative arm metrics for later review.
# creating a separate dataset for each question
analysis_samples <- map(set_names(unique(sample_membership$sample)), function(sample_name) {
  ids <- sample_membership |>
    filter(sample == sample_name, included) |>
    select(mlbam_id)
  semi_join(master, ids, by = "mlbam_id")
})
# counting included and excluded players for each dataset
sample_counts <- sample_membership |>
  group_by(sample) |>
  summarise(excluded = sum(!included), included = sum(included), .groups = "drop") |>
  select(sample, included, excluded)
# counting the included players by position
position_counts <- sample_membership |>
  filter(included) |>
  count(sample, position_group, name = "players")
sample_rules <- imap_dfr(sample_specs, function(columns, sample_name) {
  tibble(sample = sample_name, required_column = columns)
})

# Check nested samples and prohibit undefined/ambiguous membership flags.
stopifnot(!anyNA(sample_membership$included))
stopifnot(all(sample_counts$included + sample_counts$excluded == nrow(master)))
for (sample_name in names(sample_specs)) {
  overall <- analysis_samples[[sample_name]]
  positional <- analysis_samples[[paste0(sample_name, "_by_position")]]
  stopifnot(all(positional$mlbam_id %in% overall$mlbam_id),
            all(positional$position_comparison_eligible),
            all(overall$total_of_outs > 0))
}
stopifnot(setequal(analysis_samples$range_vs_arm$mlbam_id,
                   master$mlbam_id[master$available_range_vs_arm]))

# saving the datasets and the reasons for excluding players
write_csv(sample_membership, file.path(output_dir, "sample_membership.csv"))
write_csv(sample_counts, file.path(output_dir, "sample_counts.csv"))
write_csv(position_counts, file.path(output_dir, "position_counts.csv"))
write_csv(sample_rules, file.path(output_dir, "sample_rules.csv"))
saveRDS(analysis_samples, file.path(output_dir, "analysis_samples.rds"))
iwalk(analysis_samples, ~ write_csv(.x, file.path(output_dir, paste0(.y, ".csv"))))
print(sample_counts, n = Inf)
message("Analysis samples saved; source verification and limits are documented in docs/provenance_audit.md.")
