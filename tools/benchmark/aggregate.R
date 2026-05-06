#!/usr/bin/env Rscript
# Merge per-language CSVs into a single tidy benchmarks.rds + metadata.json
# consumed by vignettes/performance.Rmd.

suppressPackageStartupMessages({
  library(data.table)
  library(jsonlite)
})

RESULTS_DIR <- "results"
DATA_DIR <- file.path("..", "..", "vignettes", "data")
dir.create(DATA_DIR, showWarnings = FALSE, recursive = TRUE)

csv_files <- list.files(RESULTS_DIR, pattern = "\\.csv$", full.names = TRUE)
if (length(csv_files) == 0L) {
  stop(
    "No CSVs found in ",
    RESULTS_DIR,
    " - run the per-language benchmarks first."
  )
}

parts <- lapply(csv_files, fread)
benchmarks <- rbindlist(parts, use.names = TRUE, fill = TRUE)

# Enrich with p_raw (the user-set density level) from spec.json so the vignette
# can facet on it. Each runner only emits the post-scaling `p`, which is
# unique per (n, p_raw) cell and therefore not a clean facet variable.
spec_path <- file.path("fixtures", "spec.json")
if (file.exists(spec_path)) {
  spec_for_lookup <- fromJSON(spec_path, simplifyVector = FALSE)
  lookup <- data.table(
    fixture_id = vapply(
      spec_for_lookup$fixtures,
      function(fx) fx$id,
      character(1)
    ),
    p_raw = vapply(spec_for_lookup$fixtures, function(fx) fx$p_raw, numeric(1))
  )
  benchmarks <- merge(benchmarks, lookup, by = "fixture_id", all.x = TRUE)
}

setorder(benchmarks, fixture_id, operation, language, package)

saveRDS(benchmarks, file.path(DATA_DIR, "benchmarks.rds"), compress = "xz")

# Capture provenance for the vignette's "last benchmarked" stamp.
get_version <- function(cmd, args, pattern = "[0-9][0-9.]+") {
  out <- tryCatch(
    processx::run(cmd, args, error_on_status = FALSE, stderr_to_stdout = TRUE),
    error = function(e) NULL
  )
  if (is.null(out)) {
    return(NA_character_)
  }
  m <- regmatches(out$stdout, regexpr(pattern, out$stdout))
  if (length(m) == 0L) {
    return(NA_character_)
  }
  m[1]
}

read_pkg <- function(name) {
  v <- tryCatch(as.character(utils::packageVersion(name)), error = function(e) {
    NA_character_
  })
  v
}

read_gradle_version <- function(coord, path = "build.gradle") {
  if (!file.exists(path)) {
    return(NA_character_)
  }
  lines <- readLines(path, warn = FALSE)
  pattern <- paste0("['\"]", coord, ":([^'\"]+)['\"]")
  m <- regmatches(lines, regexec(pattern, lines))
  hits <- vapply(
    m,
    function(x) if (length(x) >= 2L) x[[2]] else NA_character_,
    character(1)
  )
  hits <- hits[!is.na(hits)]
  if (length(hits) == 0L) NA_character_ else hits[[1]]
}

uname <- tryCatch(Sys.info(), error = function(e) NULL)
spec <- if (file.exists(spec_path)) {
  fromJSON(spec_path, simplifyVector = FALSE)
} else {
  NULL
}

metadata <- list(
  generated = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  host = list(
    nodename = if (!is.null(uname)) {
      unname(uname["nodename"])
    } else {
      NA_character_
    },
    sysname = if (!is.null(uname)) unname(uname["sysname"]) else NA_character_,
    release = if (!is.null(uname)) unname(uname["release"]) else NA_character_,
    machine = if (!is.null(uname)) unname(uname["machine"]) else NA_character_
  ),
  versions = list(
    R = paste(R.version$major, R.version$minor, sep = "."),
    python = get_version("python", "--version"),
    java = get_version("java", "-version"),
    caugi = read_pkg("caugi"),
    igraph = read_pkg("igraph"),
    bnlearn = read_pkg("bnlearn"),
    dagitty = read_pkg("dagitty"),
    ggm = read_pkg("ggm"),
    pgmpy = get_version(
      "uv",
      c("run", "python", "-c", "import pgmpy; print(pgmpy.__version__)")
    ),
    tetrad = read_gradle_version("io.github.cmu-phil:tetrad-lib")
  ),
  fixtures = if (!is.null(spec)) {
    lapply(spec$fixtures, function(fx) {
      list(id = fx$id, n = fx$n, p = fx$p, n_edges = fx$n_edges)
    })
  } else {
    NULL
  },
  n_rows = nrow(benchmarks),
  source_files = basename(csv_files)
)

write_json(
  metadata,
  path = file.path(DATA_DIR, "metadata.json"),
  auto_unbox = TRUE,
  pretty = TRUE,
  null = "null"
)

message(sprintf(
  "[aggregate] %d rows -> %s/benchmarks.rds",
  nrow(benchmarks),
  DATA_DIR
))
message(sprintf("[aggregate] metadata -> %s/metadata.json", DATA_DIR))
