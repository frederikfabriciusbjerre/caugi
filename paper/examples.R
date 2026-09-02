#!/usr/bin/env Rscript
# Generates the PDF figures referenced by paper.md into paper/figures/.

library(caugi)

out_dir <- file.path("figures")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

dag <- caugi(
  U %-->% X + Y,
  W %-->% X,
  X %-->% M %-->% Y,
  class = "DAG"
)

obs <- latent_project(dag, latents = "U")

fig <- plot(dag, main = "DAG") + plot(obs, main = "ADMG")

pdf(file.path(out_dir, "example-plot.pdf"), width = 5, height = 2.5)
plot(fig)
dev.off()
