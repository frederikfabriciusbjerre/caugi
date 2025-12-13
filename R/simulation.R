#' @title Generate a `caugi` using Erdős-Rényi.
#'
#' @description Sample a random DAG or CPDAG using
#' Erdős-Rényi for random graph generation.
#'
#' @param n Integer >= 0. Number of nodes in the graph.
#' @param m Integer in `0, n*(n-1)/2`. Number of edges in the graph. Exactly one
#' of `m` or `p` must be supplied.
#' @param p Numeric in `[0,1]`. Probability of edge creation. Exactly one of
#' `m` or `p` must be supplied.
#' @param class "DAG" or "CPDAG".
#'
#' @returns The sampled `caugi` object.
#'
#' @examples
#' # generate a random DAG with 5 nodes and 4 edges
#' dag <- generate_graph(n = 5, m = 4, class = "DAG")
#'
#' # generate a random CPDAG with 5 nodes and edge probability 0.3
#' cpdag <- generate_graph(n = 5, p = 0.3, class = "CPDAG")
#'
#' @family simulation functions
#' @concept simulation
#'
#' @export
generate_graph <- function(n, m = NULL, p = NULL, class = c("DAG", "CPDAG")) {
  class <- match.arg(class)
  n <- as.integer(n)
  if (length(n) != 1L || n <= 0L) {
    stop("n must be a single integer > 0", call. = FALSE)
  }
  if (xor(is.null(m), is.null(p)) == FALSE) {
    stop("Supply exactly one of m or p", call. = FALSE)
  }

  tot <- as.integer(n * (n - 1L) / 2L)

  if (!is.null(p)) {
    if (length(p) != 1L || !is.finite(p) || p < 0 || p > 1) {
      stop("p must be in [0,1]", call. = FALSE)
    }
    m <- as.integer(stats::rbinom(1L, tot, p))
  } else {
    m <- as.integer(m)
    if (length(m) != 1L || m < 0L || m > tot) {
      stop(sprintf("m must be in 0..%d", tot), call. = FALSE)
    }
  }

  reg <- caugi_registry()
  code_dir <- edge_registry_code_of(reg, "-->")
  b <- graph_builder_new(reg, n, simple = TRUE)

  ord <- sample.int(n) - 1L

  if (m > 0L) {
    ranks <- sample.int(tot, m) - 1L
    row_len <- (n - 1L):1L
    cum <- cumsum(row_len)
    i <- as.integer(findInterval(ranks, cum))
    cum0 <- c(0L, cum)
    offset <- ranks - cum0[i + 1L]
    j <- i + 1L + offset

    ord <- sample.int(n) - 1L
    from <- ord[i + 1L]
    to <- ord[j + 1L]

    graph_builder_add_edges(b, from, to, rep.int(code_dir, m))
  }

  ptr <- graph_builder_build_view(b, "DAG")
  if (class == "CPDAG") {
    ptr <- to_cpdag_ptr(ptr)
  }
  .view_to_caugi(ptr)
}
