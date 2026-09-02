#!/usr/bin/env Rscript

# Prune non-build files from the vendored Rust crates in vendor.tar.xz.
#
# `cargo vendor` (run via `rextendr::vendor_pkgs()`) copies each dependency
# wholesale, including directories that cargo never compiles into a
# dependency's library: `tests/`, `examples/`, and trybuild-style fixture trees
# such as `zerocopy-derive/src/output_tests/`. Besides being dead weight, some
# of those fixtures have paths longer than 100 characters, which makes `pak`
# warn about "very long paths" and can break installation on Windows without
# long-path support (see issue #319).
#
# This script extracts `src/rust/vendor.tar.xz`, removes those directories,
# rewrites the affected `.cargo-checksum.json` manifests so cargo's offline
# checksum verification still passes (cargo only checks files listed under
# `files`), and repacks the tarball deterministically.
#
# Run it from the package root after `rextendr::vendor_pkgs(overwrite = TRUE)`
# and commit the updated `src/rust/vendor.tar.xz`:
#
#     Rscript tools/prune-vendor.R
#
# Requires: jsonlite, and a GNU `tar` with `xz` support on PATH.

# Directory names (matched as a full path component, never the basename) that
# cargo does not compile into a dependency's library and that nothing embeds at
# build time, so they are safe to drop from vendored crates.
#
# Note: `benches` is deliberately NOT pruned. Some crates embed bench data into
# the library at compile time (e.g. zerocopy's `codegen_section!` macro reads
# files under benches/), so removing it breaks the build. Anything pruned here
# is validated by `cargo build --offline` against the vendored sources.
PRUNE_DIRS <- c("tests", "examples", "output_tests")

tarball <- file.path(getwd(), "src", "rust", "vendor.tar.xz")
if (!file.exists(tarball)) {
  stop(
    "Could not find ",
    tarball,
    "\nRun this script from the package root.",
    call. = FALSE
  )
}
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("The 'jsonlite' package is required.", call. = FALSE)
}

# TRUE if any *directory* component of a vendored-relative path is in PRUNE_DIRS.
.should_prune <- function(rel_path) {
  parts <- strsplit(rel_path, "/", fixed = TRUE)[[1]]
  dir_parts <- parts[-length(parts)]
  any(dir_parts %in% PRUNE_DIRS)
}

# Remove pruned dirs in one crate and sync its checksum manifest.
# Returns the number of files removed from the manifest.
.prune_crate <- function(crate_dir) {
  checksum_file <- file.path(crate_dir, ".cargo-checksum.json")
  if (!file.exists(checksum_file)) {
    return(0L)
  }

  data <- jsonlite::fromJSON(checksum_file, simplifyVector = TRUE)
  paths <- names(data$files)
  prune <- vapply(paths, .should_prune, logical(1))
  if (!any(prune)) {
    return(0L)
  }

  data$files <- as.list(data$files[!prune])

  # Physically delete the now-unreferenced directories.
  dirs <- list.dirs(crate_dir, recursive = TRUE, full.names = TRUE)
  unlink(dirs[basename(dirs) %in% PRUNE_DIRS], recursive = TRUE, force = TRUE)

  writeLines(jsonlite::toJSON(data, auto_unbox = TRUE), checksum_file)
  sum(prune)
}

work <- tempfile("prune-vendor-")
dir.create(work)
on.exit(unlink(work, recursive = TRUE), add = TRUE)

stopifnot(system2("tar", c("xJf", shQuote(tarball), "-C", shQuote(work))) == 0L)
vendor_root <- file.path(work, "vendor")
if (!dir.exists(vendor_root)) {
  stop("Tarball does not contain a top-level vendor/ directory.", call. = FALSE)
}

crates <- list.dirs(vendor_root, recursive = FALSE)
removed <- vapply(crates, .prune_crate, integer(1))

rel <- file.path("vendor", list.files(vendor_root, recursive = TRUE))
longest <- rel[which.max(nchar(rel))]

# Repack deterministically so re-vendoring produces tidy diffs.
status <- system2(
  "tar",
  c(
    "--sort=name",
    "--owner=0",
    "--group=0",
    "--numeric-owner",
    "--mtime=@0",
    "-C",
    shQuote(work),
    "-cJf",
    shQuote(tarball),
    "vendor"
  )
)
stopifnot(status == 0L)

cat(sprintf(
  "Pruned %d files across %d crates.\n",
  sum(removed),
  sum(removed > 0)
))
cat(sprintf(
  "Longest remaining vendored path: %d chars (%s)\n",
  nchar(longest),
  longest
))
if (nchar(longest) > 100) {
  warning(
    "A vendored path still exceeds 100 chars; pak may warn.",
    call. = FALSE
  )
}
