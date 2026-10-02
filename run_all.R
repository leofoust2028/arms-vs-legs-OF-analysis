# Open arm_or_legs_outfield.Rproj, then Source this file once.
# Terminal alternative: Rscript --vanilla run_all.R
if (!file.exists('arm_or_legs_outfield.Rproj')) stop('Run from the project root.')
# checking that the packages needed for the project are installed
required <- c('tidyverse','janitor','digest','rmarkdown','knitr','jsonlite')
missing <- required[!vapply(required,requireNamespace,logical(1),quietly=TRUE)]
if(length(missing)) stop('Install missing packages first: ',paste(missing,collapse=', '))
# reading the saved file fingerprints used to check the original data
manifest <- read.csv('docs/source_manifest.csv',stringsAsFactors=FALSE)
# checking that none of the raw data files have changed
check_raw <- function() {
 for(i in seq_len(nrow(manifest))) {
  f <- file.path('data/raw',manifest$project_filename[i])
  if(!identical(digest::digest(file=f,algo='sha256'),manifest$sha256[i])) stop('Raw file changed: ',f)
 }
}
check_raw()
# finding the numbered scripts and putting them in order
scripts <- sort(list.files('R',pattern='^[0-9]{2}_.*[.]R$',full.names=TRUE))
# Render only after every analysis and leaderboard has been refreshed.
report_script <- 'R/09_render_report.R'
scripts <- c(setdiff(scripts,report_script),report_script)
# running each script, with the report saved for last
for(script in scripts) {
 message('\nRunning ',script)
 # Isolate script variables so stale RStudio objects cannot affect the build.
 source(script,local=new.env(parent=globalenv()),echo=FALSE)
}
check_raw()
dir.create('reports',showWarnings=FALSE)
# saving the R and package versions used for this run
writeLines(capture.output(sessionInfo()),'reports/session_info.txt')
write.csv(as.data.frame(installed.packages()[,c('Package','Version')]),'reports/package_versions.csv',row.names=FALSE)
message('Complete. Open reports/final_report.html for the current results.')
