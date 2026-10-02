# Final provenance audit — 2026-10-01

Exact URLs, ID comparisons and maximum numeric differences are recorded in
`verification/source_comparison.json`. Extracted JSON snapshots preserve the
public data used for the check; they are not model inputs except for the newly
normalized verified Arm Strength CSV. No original CSV was overwritten.

- **OAA:** exact match of all 110 IDs to the qualified 2025 OF leaderboard;
  every current record has `is_qualified_leaderboard=1`, year 2025, and range runs
  equal to the saved file. Current source also supplies attempt counts.
- **Arm Value:** exact match of 118 IDs and opportunity counts to the 2025
  `n=top` (Qualified) fielders page. The numerical formula behind Qualified was
  not exposed in inspected client code. We verify membership, not a guessed formula.
  Run totals differ by at most 0.0712031 runs. Original snapshot retained.
- **Sprint Speed:** all 579 IDs, displayed speeds and competitive-run counts match
  the official 2025 page. This independently corroborates the intended season.
- **Original Arm Strength:** 78 saved players are absent from the 2025 snapshot;
  overlapping overall strength differs by up to 12.3 mph. All original IDs appear
  in the checked 2026 page, but values differ, so the exact original season/date
  is not claimed. Its provenance is inadequate for a 2025 study.
- **Replacement Arm Strength:** official 2025 page has 395 unique player records,
  all explicitly tagged year 2025. The normalized CSV preserves the original
  schema plus year. `team_name` maps from `fld_name_display_club`, primary position
  from `primary_pos`, and position name from `primary_pos_name`; other fields use
  their same names. The source has null position names for some players; these
  are not used for classification. No qualification is inferred from primary position.
- **Jump:** the source embeds year 2025; qualifying counts are consistent with the
  documented more-than-team-games/5 rule under a 162-game assumption.
- **FanGraphs:** exports have no season field. The 2025 designation comes from the
  original download discussion and filenames. This remains an explicit limitation.

The corrected input changes the throwing and runner-attempt samples to 118 players.
All affected figures, scores and sensitivity checks were rebuilt. Earlier claims
of a 97-player throwing sample or a 0.960 runner-attempt odds ratio are superseded.

The reproducible claim is analysis of these preserved, documented snapshots.
A public page may change again; matching a later page is evidence about the
snapshot, not proof of every historical download setting.
