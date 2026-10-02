# Arm or Legs? Outfield Defensive Value
# Import, audit, classify positions, and join the 2025 outfield dataset.
# Run from the arm_or_legs_outfield RStudio project.
# This section preserves all rows and columns; it does not fit models.

# ---- Packages ----
library(tidyverse)
library(janitor)

# ---- File locations ----
# Relative paths make this work on another computer with the same project.
raw_dir <- file.path("data", "raw")
output_dir <- file.path("data", "processed")
files <- c(
  arm_strength = "arm_strength_2025_verified.csv",
  arm_value = "arm_value.csv",
  jump = "outfield_jump.csv",
  oaa = "outs_above_average.csv",
  sprint_speed = "sprint_speed.csv",
  lf = "lf_2025.csv",
  cf = "cf_2025.csv",
  rf = "rf_2025.csv"
)
paths <- file.path(raw_dir, files)
if (any(!file.exists(paths))) {
  stop("Open the arm_or_legs_outfield project. Missing files: ",
       paste(paths[!file.exists(paths)], collapse = ", "))
}

# ---- Import ----
# Read as text first so identifiers and baseball innings retain their exact
# representation. Numeric conversion comes later, after inspecting the fields.
# clean_names() changes column names in memory, never the raw CSVs.
# reading in each CSV and cleaning the column names
raw <- map(set_names(paths, names(files)), function(path) {
  x <- read_csv(path, col_types = cols(.default = col_character()),
                na = c("", "NA"), show_col_types = FALSE)
  if (nrow(problems(x)) > 0) stop("CSV parsing problem in ", path)
  clean_names(x)
})

# ---- Validate identifiers and embedded seasons ----
# MLBAM IDs have different column names in the source exports.
id_columns <- c(arm_strength = "player_id", arm_value = "entity_id",
                jump = "resp_fielder_id", oaa = "player_id",
                sprint_speed = "player_id", lf = "mlbamid",
                cf = "mlbamid", rf = "mlbamid")
for (dataset in names(raw)) {
  x <- raw[[dataset]]
  key <- id_columns[[dataset]]
  if (!key %in% names(x)) stop("Missing ID column in ", dataset)
  ids <- x[[key]]
  if (any(is.na(ids) | !str_detect(ids, "^[0-9]+$"))) {
    stop("Missing or malformed MLBAM ID in ", dataset)
  }
  if ("year" %in% names(x) && any(is.na(x$year) | x$year != "2025")) {
    stop("Missing or unexpected season in ", dataset)
  }
}

# FanGraphs position files must contain only their named position.
for (position in c("lf", "cf", "rf")) {
  x <- raw[[position]]
  if (!all(c("pos", "inn") %in% names(x))) stop("Missing positional fields")
  if (any(is.na(x$pos) | x$pos != toupper(position))) {
    stop("Unexpected position in ", position)
  }
}

# ---- Audit tables ----
# Duplicate IDs are reported, not automatically removed: traded players may
# have multiple team rows. We must inspect these before joining the files.
# counting rows and player IDs in each file
import_audit <- imap_dfr(raw, function(x, dataset) {
  ids <- x[[id_columns[[dataset]]]]
  tibble(dataset = dataset, rows = nrow(x), columns = ncol(x),
         unique_players = n_distinct(ids), duplicate_id_rows = sum(duplicated(ids)),
         season_in_file = if ("year" %in% names(x)) "2025" else "not encoded")
})
# checking which columns have missing values
column_audit <- imap_dfr(raw, function(x, dataset) {
  tibble(dataset = dataset, column = names(x),
         missing = map_int(x, ~ sum(is.na(.x))),
         missing_pct = round(100 * missing / nrow(x), 1))
})
# checking whether a player appears more than once in a file
duplicate_ids <- imap_dfr(raw, function(x, dataset) {
  tibble(mlbam_id = x[[id_columns[[dataset]]]]) |>
    count(mlbam_id, name = "source_rows") |>
    filter(source_rows > 1) |>
    mutate(dataset = dataset, .before = 1)
})

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
write_csv(import_audit, file.path(output_dir, "import_audit.csv"))
write_csv(column_audit, file.path(output_dir, "column_audit.csv"))
write_csv(duplicate_ids, file.path(output_dir, "duplicate_ids.csv"))
print(import_audit, width = Inf)
message("Import complete. Review the audit tables before cleaning and joining.")

# ---- Convert baseball innings to outs ----
# In baseball notation, 10.1 means 10 innings and one out, not 10.1
# decimal innings. Integer outs let us add playing time without rounding.
innings_to_outs <- function(innings) {
  valid <- !is.na(innings) & str_detect(innings, "^[0-9]+([.][012])?$")
  if (any(!valid)) {
    stop("Missing or invalid baseball innings: ",
         paste(unique(innings[!valid]), collapse = ", "))
  }
  whole_innings <- as.numeric(str_extract(innings, "^[0-9]+"))
  extra_outs <- if_else(str_detect(innings, "[.]"),
                        as.numeric(str_extract(innings, "[0-2]$")), 0)
  3 * whole_innings + extra_outs
}

# ---- One record per player and position ----
# combining the LF, CF, and RF innings into one table
position_rows <- map_dfr(raw[c("lf", "cf", "rf")], function(x) {
  transmute(x, mlbam_id = mlbamid, player_name = name,
            position = pos, innings_original = inn,
            outs = innings_to_outs(inn))
})
# Current exports have one row per player within each position, including
# traded players. If a future export adds team splits or total rows, stop for
# review rather than summing and potentially counting the same innings twice.
if (anyDuplicated(position_rows[c("mlbam_id", "position")])) {
  stop("Duplicate player-position rows: review team splits before proceeding.")
}
# checking for different names attached to the same player ID
name_conflicts <- position_rows |>
  distinct(mlbam_id, player_name) |>
  count(mlbam_id) |>
  filter(n > 1)
if (nrow(name_conflicts) > 0) stop("Review inconsistent names across positions.")

# These are unrestricted positional exports. A missing player-position row
# is treated as zero playing time at that position. Preserve source flags so
# an absent row remains distinguishable from an explicit zero-inning record.
position_threshold <- 0.60
# putting each player on one row and finding his main outfield position
positions_of_2025 <- position_rows |>
  mutate(in_source = TRUE) |>
  select(-innings_original) |>
  pivot_wider(names_from = position, values_from = c(outs, in_source),
              values_fill = list(outs = 0, in_source = FALSE)) |>
  mutate(
    total_of_outs = outs_LF + outs_CF + outs_RF,
    most_position_outs = pmax(outs_LF, outs_CF, outs_RF),
    # No position or percentage can be assigned when total playing time is 0.
    primary_share = most_position_outs / na_if(total_of_outs, 0),
    tied_most_played = total_of_outs > 0 &
      ((outs_LF == most_position_outs) + (outs_CF == most_position_outs) +
       (outs_RF == most_position_outs) > 1),
    most_played_position = case_when(
      total_of_outs == 0 | tied_most_played ~ NA_character_,
      outs_LF == most_position_outs ~ "LF",
      outs_CF == most_position_outs ~ "CF",
      TRUE ~ "RF"
    ),
    position_group = case_when(
      total_of_outs == 0 ~ "No OF innings",
      primary_share >= position_threshold & !tied_most_played ~ most_played_position,
      TRUE ~ "Multi-position OF"
    ),
    position_comparison_eligible = position_group %in% c("LF", "CF", "RF")
  ) |>
  arrange(mlbam_id)

# Validate that reshaping conserved every recorded out and every player.
stopifnot(
  !anyDuplicated(positions_of_2025$mlbam_id),
  nrow(positions_of_2025) == n_distinct(position_rows$mlbam_id),
  sum(positions_of_2025$total_of_outs) == sum(position_rows$outs),
  all(positions_of_2025$primary_share >= 1/3 &
        positions_of_2025$primary_share <= 1, na.rm = TRUE)
)
# counting players in each position group
position_summary <- positions_of_2025 |>
  count(position_group, name = "players")
position_review <- positions_of_2025 |>
  filter(total_of_outs == 0 | tied_most_played)
write_csv(positions_of_2025, file.path(output_dir, "positions_of_2025.csv"))
write_csv(position_summary, file.path(output_dir, "position_summary.csv"))
write_csv(position_review, file.path(output_dir, "position_review.csv"))
print(position_summary)
message("Position classification complete. Zero-inning records are retained for audit.")

# ---- Prepare Statcast tables ----
# Prefix source columns so similarly named measures remain distinct. In
# particular, Jump's OAA is not interchangeable with the OAA leaderboard's OAA.
text_columns <- list(
  arm_strength = c("fielder_name", "team_name", "primary_position", "primary_position_name"),
  arm_value = c("entity_name", "team_name"),
  jump = "last_name_first_name",
  oaa = c("last_name_first_name", "display_team_name", "primary_pos_formatted"),
  sprint_speed = c("last_name_first_name", "team_id", "team", "position")
)
percent_columns <- c("actual_success_rate_formatted",
                     "adj_estimated_success_rate_formatted", "diff_success_rate_formatted")
# converting text to numbers and stopping if a value cannot be converted
strict_numeric <- function(x, label) {
  value <- suppressWarnings(parse_double(x))
  if (nrow(problems(value)) > 0 || any(!is.finite(value) & !is.na(value))) {
    stop("Invalid numeric value in ", label)
  }
  value
}
metrics <- imap(raw[names(text_columns)], function(x, dataset) {
  key <- id_columns[[dataset]]
  if (anyDuplicated(x[[key]])) stop("Duplicate Statcast IDs in ", dataset)
  for (column in setdiff(names(x), c(key, text_columns[[dataset]]))) {
    if (dataset == "oaa" && column %in% percent_columns) {
      if (any(!is.na(x[[column]]) & !str_detect(x[[column]], "^-?[0-9]+([.][0-9]+)?%$"))) {
        stop("Unexpected percentage format in ", column)
      }
      x[[column]] <- strict_numeric(str_remove(x[[column]], "%$"), column) / 100
    } else {
      x[[column]] <- strict_numeric(x[[column]], paste(dataset, column))
    }
  }
  x <- rename(x, mlbam_id = all_of(key))
  x <- rename_with(x, ~ paste0(dataset, "_", .x), -mlbam_id)
  x[[paste0("has_", dataset)]] <- TRUE
  x
})

# ---- Join onto the positional roster ----
# Keep all 336 positional records, including the zero-inning audit record.
# Players absent from a metric source retain NA, never an invented zero.
# adding the Statcast measurements to the outfield roster by player ID
master_of_2025 <- reduce(metrics, function(roster, source) {
  left_join(roster, source, by = "mlbam_id", relationship = "one-to-one")
}, .init = positions_of_2025) |>
  mutate(across(starts_with("has_"), ~ replace_na(.x, FALSE)),
         study_season = 2025L,
         has_of_playing_time = total_of_outs > 0,
         range_runs = oaa_fielding_runs_prevented,
         arm_runs = arm_value_fielder_runs,
         # Availability is not a claim of verified leaderboard qualification.
         available_range_comparison = has_of_playing_time & !is.na(range_runs),
         available_arm_comparison = has_of_playing_time & !is.na(arm_runs),
         available_range_vs_arm = available_range_comparison & available_arm_comparison,
         available_range_vs_arm_by_position = available_range_vs_arm & position_comparison_eligible)
stopifnot(nrow(master_of_2025) == nrow(positions_of_2025),
          !anyDuplicated(master_of_2025$mlbam_id))

# ---- Join coverage and missingness ----
# Arm Strength and Sprint Speed include non-outfielders. Save unmatched IDs
# for review rather than expanding the OF roster to include all of them.
unmatched_metric_ids <- imap_dfr(metrics, function(x, dataset) {
  anti_join(select(x, mlbam_id), select(positions_of_2025, mlbam_id), by = "mlbam_id") |>
    mutate(dataset = dataset, .before = 1)
})
join_coverage <- imap_dfr(metrics, function(x, dataset) {
  matched <- master_of_2025[[paste0("has_", dataset)]]
  tibble(dataset = dataset, source_players = nrow(x),
         matched_to_roster = sum(matched),
         source_players_outside_roster = sum(!x$mlbam_id %in% master_of_2025$mlbam_id),
         positive_inning_players_without_source = sum(master_of_2025$has_of_playing_time & !matched))
})
# counting how many players have the measurements needed for each comparison
sample_availability <- tibble(
  sample = c("Range runs", "Arm runs", "Both run components", "Both components with LF/CF/RF classification"),
  players = c(sum(master_of_2025$available_range_comparison),
              sum(master_of_2025$available_arm_comparison),
              sum(master_of_2025$available_range_vs_arm),
              sum(master_of_2025$available_range_vs_arm_by_position))
)
master_column_audit <- tibble(
  column = names(master_of_2025),
  storage_type = map_chr(master_of_2025, ~ class(.x)[1]),
  missing = map_int(master_of_2025, ~ sum(is.na(.x)))
)
# saving the final dataset and the tables used to check it
write_csv(master_of_2025, file.path(output_dir, "master_of_2025.csv"))
# RDS preserves character IDs and logical flags when reloaded into R.
saveRDS(master_of_2025, file.path(output_dir, "master_of_2025.rds"))
write_csv(unmatched_metric_ids, file.path(output_dir, "unmatched_metric_ids.csv"))
write_csv(join_coverage, file.path(output_dir, "join_coverage.csv"))
write_csv(sample_availability, file.path(output_dir, "sample_availability.csv"))
write_csv(master_column_audit, file.path(output_dir, "master_column_audit.csv"))
print(join_coverage, width = Inf)
print(sample_availability, width = Inf)
message("Master dataset saved. Availability flags describe data presence, not final model eligibility.")
