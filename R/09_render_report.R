# Use installed Pandoc or the copy bundled with RStudio on this Mac.
if (!rmarkdown::pandoc_available()) {
 candidates <- c('/Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools/aarch64',
                 '/Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools/x86_64')
 for (candidate in candidates) {
  if(file.exists(file.path(candidate,'pandoc'))) {
   Sys.setenv(RSTUDIO_PANDOC=candidate)
   rmarkdown::find_pandoc(cache=FALSE)
   if(rmarkdown::pandoc_available()) break
  }
 }
}
if(!rmarkdown::pandoc_available()) stop('Pandoc required: run in RStudio or install Pandoc.')
# building the HTML report from the saved analysis results
rmarkdown::render('reports/final_report.Rmd',output_file='final_report.html',
  knit_root_dir=normalizePath('.'),envir=new.env(parent=globalenv()),quiet=TRUE)
# A Markdown companion lets visitors read the full analysis directly on GitHub.
rmarkdown::render('reports/final_report.Rmd',
  output_format=rmarkdown::md_document(variant='gfm', preserve_yaml=FALSE),
  output_file='final_report.md', knit_root_dir=normalizePath('.'),
  envir=new.env(parent=globalenv()),quiet=TRUE)
report <- readLines('reports/final_report.md',warn=FALSE)
# changing local file paths so the links work in the GitHub copy
report <- gsub(paste0(normalizePath('.'), '/'), '../', report, fixed=TRUE)
# GitHub does not apply the HTML report's style block.
report <- gsub('(?s)<style>.*?</style>', '', paste(report,collapse='\n'),perl=TRUE)
writeLines(c('# Arm or Legs? Outfield Range and Throwing Value', '',
             'Leo Foust | Saved 2025 analysis', '', report),
           'reports/final_report.md')
