# library(caugi)
library(devtools)
load_all()

cg1 <- caugi(
  A %-->% B,
  B %-->% C,
  A %-->% C
)

cg2 <- caugi(
  X %-->% Y,
  Y %-->% Z,
  X %-->% Z
)

# Set global defaults
caugi_options(
  plot = list(
    spacing = grid::unit(2, "lines"),
    node_style = list(fill = "lightblue", padding = 3),
    edge_style = list(arrow_size = 5, fill = "darkgray"),
    label_style = list(fontsize = 12),
    title_style = list(col = "blue", fontsize = 18)
  )
)

p1 <- plot(cg1, main = "A")
p2 <- plot(cg2, main = "B")

caugi_options(plot = list(spacing = grid::unit(2, "lines")))

p3 <- p1 + p2

(p3 | p1) / p2
