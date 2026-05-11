set.seed(1405)
library(caugi)
library(ggplot2)

cg <- caugi(
  A %-->% B + C,
  B %-->% D,
  C %-->% D
)
plot(cg)

generate_graphs <- function(n, m, seed = NULL) {
  cg <- generate_graph(n = n, m = m, class = "DAG", seed = seed)
  ig <- as_igraph(cg)
  ggmg <- as_adjacency(cg)
  bng <- as_bnlearn(cg)
  dg <- as_dagitty(cg)
  list(cg = cg, ig = ig, ggmg = ggmg, bng = bng, dg = dg)
}

algo_colors <- c(
  caugi = "#1b9e77",
  igraph = "#d95f02",
  bnlearn = "#7570b3",
  dagitty = "#e7298a"
)

plot_parameterized_benchmark <- function(bm, title = NULL) {

  bm_mod <- within(
    bm,
    {
      expr <- as.character(expression)
      median <- as.numeric(median)
    }
  )

  ggplot(bm_mod, aes(n, median, color = expr)) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 2.5) +
    scale_y_log10() +
    scale_color_manual(values = algo_colors) +
    labs(
      title = title,
      x = "Number of nodes",
      y = "Time (seconds, log scale)",
      color = NULL
    ) +

    theme_minimal(base_size = 16) +
    theme(
      # --- Title (important for poster) ---
      plot.title = element_text(size = 22, face = "bold", hjust = 0.5),

      axis.title = element_text(size = 18),
      axis.text  = element_text(size = 14),
      legend.text = element_text(size = 14),

      legend.position = "top",
      legend.direction = "horizontal",

      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(linewidth = 0.3),

      plot.margin = margin(10, 15, 10, 10)
    )
}

bm_ancestors_descendants <-
  bench::press(
    n = c(100, 500, 1000, 2500, 5000),
    d = 10,
    {
      m <- as.integer(d * n)

      graphs <- generate_graphs(n, m = m, seed = 1405 + n + d)
      cg <- graphs$cg
      ig <- graphs$ig
      bng <- graphs$bng
      dg <- graphs$dg

      test_node_name <- "V1"

      bench::mark(
        caugi = {
          caugi::ancestors(cg, test_node_name)
          caugi::descendants(cg, test_node_name)
        },

        igraph = {
          igraph::subcomponent(ig, test_node_name, mode = "in")
          igraph::subcomponent(ig, test_node_name, mode = "out")
        },

        bnlearn = {
          bnlearn::ancestors(bng, test_node_name)
          bnlearn::descendants(bng, test_node_name)
        },

        dagitty = {
          dagitty::ancestors(dg, test_node_name)
          dagitty::descendants(dg, test_node_name)
        },

        check = FALSE,
        min_iterations = 50
      )
    },
    .quiet = TRUE
  )

plot_parameterized_benchmark(bm_ancestors_descendants)

bm_dsep <-
  bench::press(
    n = c(100, 500, 1000, 2500, 5000),
    d = 10,
    {
      m <- as.integer(d * n)

      graphs <- generate_graphs(n, m = m, seed = 1405 + n + d)
      cg <- graphs$cg
      bng <- graphs$bng
      dg <- graphs$dg

      x <- "V1"
      y <- "V2"
      z <- paste0("V", 3:10)

      bench::mark(
        caugi = caugi::d_separated(cg, x, y, z),
        bnlearn = bnlearn::dsep(bng, x, y, z),
        dagitty = dagitty::dseparated(dg, x, y, z),
        check = FALSE,
        min_iterations = 50
      )
    },
    .quiet = TRUE
  )

plot_parameterized_benchmark(bm_dsep)

p1 <- plot_parameterized_benchmark(
  bm_ancestors_descendants,
  title = "Ancestors and Descendants"
)
p2 <- plot_parameterized_benchmark(
  bm_dsep,
  title = "d-separation"
)
p1
p2

ggsave(
  filename = "ancesors_descendants.svg",
  plot = p1,
  width = 12,
  height = 7,
  units = "in"
)

ggsave(
  filename = "dsep.svg",
  plot = p2,
  width = 12,
  height = 7,
  units = "in"
)
