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

    edges_from <- from
    edges_to <- to
  }

  session <- rs_new(reg, n, TRUE, "DAG")
  node_names <- paste0("V", seq_len(n))
  rs_set_names(session, node_names)
  if (m > 0L) {
    rs_set_edges(
      session,
      as.integer(edges_from),
      as.integer(edges_to),
      as.integer(rep.int(code_dir, m))
    )
  }
  if (class == "CPDAG") {
    session <- rs_to_cpdag(session)
  }
  .session_to_caugi(session, node_names = node_names)
}

#' @title Simulate data from a `caugi` DAG.
#'
#' @description Simulate data from a `caugi` object of class DAG using a
#' linear structural equation model (SEM). As standard, the data is
#' simulated from a DAG, where each node is generated as a linear combination
#' of its parents plus Gaussian noise, following the topological order of the
#' graph. Nodes without custom equations are simulated using auto-generated
#' linear Gaussian relationships.
#'
#' @param cg A `caugi` object of class DAG.
#' @param n Integer; number of observations to simulate.
#' @param ... Named expressions for custom structural equations. Names must
#'   match node names in the graph. Expressions can reference parent node names
#'   and the variable `n` (sample size). Nodes without custom equations use
#'   auto-generated linear Gaussian relationships.
#' @param standardize Logical; if `TRUE`, standardize all variables to have
#'   mean 0 and standard deviation 1. Default is `TRUE`.
#' @param coef_range Numeric vector of length 2; range for random edge
#'   coefficients that will be sampled uniformly. Default is `c(0.1, 0.9)`.
#' @param error_sd Numeric; standard deviation for error terms in
#'   auto-generated equations. Default is `1`.
#' @param seed Optional integer; random seed for reproducibility.
#'
#' @returns A `data.frame` with `n` rows and one column per node, ordered
#'   according to the node order in the graph.
#'
#' @examples
#' cg <- caugi(A %-->% B, B %-->% C, A %-->% C, class = "DAG")
#'
#' # Fully automatic simulation
#' df <- simulate_data(cg, n = 100)
#'
#' # With standardization
#' df <- simulate_data(cg, n = 100, standardize = TRUE)
#'
#' # Custom equations for some nodes
#' df <- simulate_data(cg, n = 100,
#'   A = rnorm(n, mean = 10, sd = 2),
#'   B = 0.5 * A + rnorm(n, sd = 0.5)
#' )
#'
#' # Reproducible simulation
#' df <- simulate_data(cg, n = 100, seed = 42)
#'
#' @family simulation functions
#' @concept simulation
#'
#' @export
simulate_data <- function(
  cg,
  n,
  ...,
  standardize = TRUE,
  coef_range = c(0.1, 0.9),
  error_sd = 1,
  seed = NULL
) {
  is_caugi(cg, throw_error = TRUE)
  if (cg@graph_class != "DAG") {
    stop(
      "`simulate_data` currently only supports DAGs. ",
      "Graph class is: ",
      cg@graph_class,
      call. = FALSE
    )
  }

  if (is_empty_caugi(cg)) {
    stop("Cannot simulate data from an empty graph", call. = FALSE)
  }

  if (!is.null(seed)) {
    set.seed(seed)
  }

  n <- as.integer(n)
  if (length(n) != 1L || n <= 0L) {
    stop("n must be a single integer > 0", call. = FALSE)
  }

  # capture custom equations
  equations <- as.list(substitute(list(...)))[-1L]
  node_order <- topological_sort(cg)
  node_names <- nodes(cg)$name

  # validate equation names
  eq_names <- names(equations)
  if (length(eq_names) > 0L) {
    unknown <- setdiff(eq_names, node_names)
    if (length(unknown) > 0L) {
      stop(
        "Unknown node(s) in equations: ",
        paste(unknown, collapse = ", "),
        call. = FALSE
      )
    }
  }

  # create evaluation environment
  env <- new.env(parent = parent.frame())
  env$n <- n

  data <- list()

  for (node in node_order) {
    pa <- parents(cg, node)
    if (is.null(pa)) {
      pa <- character(0)
    }

    if (node %in% eq_names) {
      # user-specified equation: make parent data available
      for (p in pa) {
        env[[p]] <- data[[p]]
      }

      # validate that all parents are referenced in the equation
      if (length(pa) > 0L) {
        eq_vars <- all.vars(equations[[node]])
        missing_parents <- setdiff(pa, eq_vars)
        if (length(missing_parents) > 0L) {
          stop(
            sprintf(
              "Equation for '%s' must reference all parent nodes. Missing: %s",
              node,
              paste(missing_parents, collapse = ", ")
            ),
            call. = FALSE
          )
        }
      }

      data[[node]] <- eval(equations[[node]], envir = env)

      if (length(data[[node]]) != n) {
        stop(
          sprintf(
            "Equation for '%s' produced %d values, expected %d.",
            node,
            length(data[[node]]),
            n
          ),
          call. = FALSE
        )
      }
    } else {
      # auto-generate using linear Gaussian model
      if (length(pa) == 0L) {
        # exogenous node
        data[[node]] <- stats::rnorm(n, sd = error_sd)
      } else {
        coefs <- stats::runif(length(pa), coef_range[1], coef_range[2])
        pa_mat <- do.call(cbind, data[pa])
        data[[node]] <- as.vector(pa_mat %*% coefs) +
          stats::rnorm(n, sd = error_sd)
      }
    }
  }

  # build data.frame in original node order
  out <- as.data.frame(data)[, node_names, drop = FALSE]

  if (standardize) {
    out <- as.data.frame(lapply(out, function(x) {
      (x - mean(x)) / stats::sd(x)
    }))
  }

  out
}
