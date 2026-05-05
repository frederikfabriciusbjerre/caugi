#!/usr/bin/env Rscript
# Generates the PDF figures referenced by paper.md into paper/figures/.

library(caugi)

out_dir <- file.path("figures")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

cg <- caugi(
  A %-->% B %-->% C + D,
  A %-->% C,
  class = "DAG"
)

cg

# Figure 1

pdf(file.path(out_dir, "example-plot.pdf"), width = 2, height = 2)
plot(cg)
dev.off()

# Example 2

adjustment_set(cg, "B", "C", type = "backdoor")
