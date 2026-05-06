#!/usr/bin/env Rscript
# Tangle the R benchmark code out of vignettes/performance.Rmd and run it.
#
# bench_r.R is a *generated* artifact -- do not edit it by hand. To change a
# benchmark, edit the `bench-*` chunks in vignettes/performance.Rmd.

suppressPackageStartupMessages(library(knitr))

here <- normalizePath(".", winslash = "/", mustWork = TRUE)
repo_root <- normalizePath(
  file.path(here, "..", ".."),
  winslash = "/",
  mustWork = TRUE
)
vignette_rmd <- file.path(repo_root, "vignettes", "performance.Rmd")
out_script <- file.path(here, "bench_r.R")

knitr::purl(
  input = vignette_rmd,
  output = out_script,
  documentation = 0L,
  quiet = TRUE
)

# knitr::purl() comments out code from chunks with `eval = FALSE`. All of the
# `bench-*` chunks in the vignette are `eval = FALSE` (so the vignette renders
# without running the benchmarks), so every tangled line has a leading "# "
# that we strip. A legitimate "# comment" line in the source was turned into
# "# # comment" by purl, which becomes "# comment" again -- so comments
# survive.
lines <- readLines(out_script)
lines <- sub("^# ?", "", lines)
writeLines(lines, out_script)

if (file.info(out_script)$size < 200) {
  stop("knitr::purl produced an unexpectedly small script at ", out_script)
}

source(out_script, echo = FALSE)
