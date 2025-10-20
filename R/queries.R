# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Queries ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────────── Checks ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Is it a `caugi` graph?
#'
#' @description Checks if the given object is a `caugi_graph`.
#'
#' @param x An object to check.
#' @param throw_error Logical; if `TRUE`, throws an error if `x` is not a
#' `caugi_graph`.
#'
#' @returns A logical value indicating whether the object is a `caugi_graph`.
#' @export
is_caugi <- function(x, throw_error = FALSE) {
  it_is <- inherits(x, caugi_graph)

  if (!it_is && throw_error) {
    stop("Input must be a caugi_graph", call. = FALSE)
  }
  it_is
}

#' @title Is the `caugi` graph empty?
#'
#' @description Checks if the given `caugi` graph is empty (has no nodes).
#'
#' @param cg A `caugi_graph` object.
#'
#' @returns A logical value indicating whether the graph is empty.
#' @export
is_empty_caugi <- function(cg) {
  is_caugi(cg, throw_error = TRUE)
  nrow(cg@nodes) == 0L
}

#' @title Same nodes?
#'
#' @description Check if two `caugi_graph` objects have the same nodes.
#'
#' @param cg1 A `caugi_graph` object.
#' @param cg2 A `caugi_graph` object.
#' @param throw_error Logical; if `TRUE`, throws an error if the graphs do not
#' have the same nodes.
#'
#' @returns A logical indicating if the two graphs have the same nodes.
#' @export
same_nodes <- function(cg1, cg2, throw_error = FALSE) {
  is_caugi(cg1, throw_error)
  is_caugi(cg2, throw_error)
  if (!identical(sort(cg1@nodes$name), sort(cg2@nodes$name))) {
    differing_nodes <- setdiff(
      union(cg1@nodes$name, cg2@nodes$name),
      intersect(cg1@nodes$name, cg2@nodes$name)
    )

    stop(
      "Graphs must have the same nodes.\n",
      "Differing nodes are: [", paste(differing_nodes, collapse = ", "),
      "]."
    )
  }
  TRUE
}

#' @title Is the `caugi` acyclic?
#'
#' @description Checks if the given `caugi` graph is acyclic.
#'
#' @param cg A `caugi_graph` object.
#' @param force_check Logical; if `TRUE`, the function will test if the graph is
#' acyclic, if `FALSE` (default), it will look at the graph class.
#'
#' @details
#' __Lazy building__
#'
#' If the graph is not built, the graph will be built before making the query.
#'
#' __Check logic__
#'
#' By the construction of the `caugi_graph`, if the graph class is "DAG" or
#' "PDAG", the graph should be guaranteed to be acyclic. If the graph class is
#' "Unknown", the graph may or may not be acyclic. If `force_check = TRUE`, the
#' function will check if the graph is acyclic using the Rust backend, no matter
#' the class. If the graph class is not inherently acyclic, `is_acyclic` will
#' run the check.
#'
#' __Note__
#'
#' We do not think that it is possible to introduce a cycle in a `caugi_graph`
#' on acyclic classes without the package throwing errors. We might be wrong,
#' though, so `force_check` is e a feature that is there for peace of mind.
#'
#'
#' @returns A logical value indicating whether the graph is acyclic.
#' @export
is_acyclic <- function(cg, force_check = FALSE) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  if (force_check) {
    is_it <- is_acyclic_ptr(cg@ptr)
  } else if (identical(cg@graph_class, "DAG") ||
    identical(cg@graph_class, "PDAG")) {
    is_it <- TRUE
  } else {
    is_it <- is_acyclic_ptr(cg@ptr)
  }
  is_it
}

#' @title Is the `caugi` graph a DAG?
#'
#' @description Checks if the given `caugi` graph is a
#' Directed Acyclic Graph (DAG).
#'
#' @param cg A `caugi_graph` object.
#' @param force_check Logical; if `TRUE`, the function will test if the graph is
#' a DAG, if `FALSE` (default), it will look at the graph class and match
#' it, if possible.
#'
#' @returns A logical value indicating whether the graph is a DAG.
#' @export
is_dag <- function(cg, force_check = FALSE) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  if (identical(cg@graph_class, "DAG") && !force_check) {
    is_it <- TRUE
  } else {
    # if we can't be sure from the class, we check
    is_it <- is_dag_type_ptr(cg@ptr)
  }
  is_it
}

#' @title Is the `caugi` graph a PDAG?
#'
#' @description Checks if the given `caugi` graph is a
#' Partially Directed Acyclic Graph (PDAG).
#'
#' @param cg A `caugi_graph` object.
#' @param force_check Logical; if `TRUE`, the function will test if the graph is
#' a PDAG, if `FALSE` (default), it will look at the graph class and match
#' it, if possible.
#'
#' @returns A logical value indicating whether the graph is a PDAG.
#' @export
is_pdag <- function(cg, force_check = FALSE) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  if (identical(cg@graph_class, "PDAG") && !force_check) {
    is_it <- TRUE
  } else {
    # if we can't be sure from the class, we check
    is_it <- is_pdag_type_ptr(cg@ptr)
  }
  is_it
}

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── Relations ───────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Get nodes or edges of a `caugi_graph`
#'
#' @description
#' Get nodes or edges of a `caugi_graph`.
#'
#' @param cg A `caugi_graph` object.
#'
#' @returns __nodes__: A tibble with a `name` column.
#' __edges__: A tibble with `from`, `edge`, and `to` columns.
#'
#' @rdname nodes_and_edges
#' @export
nodes <- function(cg) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  cg@nodes
}

#' @rdname nodes_and_edges
#' @export
vertices <- nodes

#' @rdname nodes_and_edges
#' @export
V <- nodes # igraph notation

#' @rdname nodes_and_edges
#' @export
edges <- function(cg) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  cg@edges
}

#' @rdname nodes_and_edges
#' @export
E <- edges # igraph notation

#' @title Get parents of nodes in a `caugi_graph`
#'
#' @description
#' Get parents of node in a graph. Note that not both nodes and index can be
#' given.
#'
#' @param cg A `caugi_graph` object.
#' @param nodes A vector of node names, a vector of unquoted
#' node names, or an expression combining these with `+` and `c()`.
#' @param index A vector of node indexes.
#'
#' @export
parents <- function(cg, nodes = NULL, index = NULL) {
  nodes_supplied <- !missing(nodes)
  index_supplied <- !missing(index) && !is.null(index)
  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (index_supplied) {
    return(.relations(cg, NULL, index, parents_of_ptr))
  }
  if (!nodes_supplied) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }
  expr <- substitute(nodes)
  env <- parent.frame()
  .relations(cg, .expand_nodes(expr, env), NULL, parents_of_ptr)
}

#' @title Get children of nodes in a `caugi_graph`
#'
#' @param cg A `caugi_graph` object.
#' @param nodes A vector of node names, a vector of unquoted
#' node names, or an expression combining these with `+` and `c()`.
#' @param index A vector of node indexes.
#'
#' @export
children <- function(cg, nodes = NULL, index = NULL) {
  nodes_supplied <- !missing(nodes)
  index_supplied <- !missing(index) && !is.null(index)
  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (index_supplied) {
    return(.relations(cg, NULL, index, children_of_ptr))
  }
  if (!nodes_supplied) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }
  expr <- substitute(nodes)
  env <- parent.frame()
  .relations(cg, .expand_nodes(expr, env), NULL, children_of_ptr)
}

#' @title Get neighbors of nodes in a `caugi_graph`
#'
#' @param cg A `caugi_graph` object.
#' @param nodes A vector of node names, a vector of unquoted
#' node names, or an expression combining these with `+` and `c()`.
#' @param index A vector of node indexes.
#'
#' @export
neighbors <- function(cg, nodes = NULL, index = NULL) {
  nodes_supplied <- !missing(nodes)
  index_supplied <- !missing(index) && !is.null(index)
  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (index_supplied) {
    return(.relations(cg, NULL, index, neighbors_of_ptr))
  }
  if (!nodes_supplied) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }
  expr <- substitute(nodes)
  env <- parent.frame()
  .relations(cg, .expand_nodes(expr, env), NULL, neighbors_of_ptr)
}

#' @rdname neighbors
#' @export
neighbours <- neighbors

#' @title Get bidirected neighbors of nodes in a `caugi_graph`
#'
#' @description For ADMG graphs, returns nodes connected by bidirected edges
#' (representing latent confounding).
#'
#' @param cg A `caugi_graph` object.
#' @param nodes A vector of node names, a vector of unquoted
#' node names, or an expression combining these with `+` and `c()`.
#' @param index A vector of node indexes.
#'
#' @export
bidirected <- function(cg, nodes = NULL, index = NULL) {
  nodes_supplied <- !missing(nodes)
  index_supplied <- !missing(index) && !is.null(index)
  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (index_supplied) {
    return(.relations(cg, NULL, index, bidirected_of_ptr))
  }
  if (!nodes_supplied) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }
  expr <- substitute(nodes)
  env <- parent.frame()
  .relations(cg, .expand_nodes(expr, env), NULL, bidirected_of_ptr)
}

#' @title Get ancestors of nodes in a `caugi_graph`
#'
#' @param cg A `caugi_graph` object.
#' @param nodes A vector of node names, a vector of unquoted
#' node names, or an expression combining these with `+` and `c()`.
#' @param index A vector of node indexes.
#'
#' @export
ancestors <- function(cg, nodes = NULL, index = NULL) {
  nodes_supplied <- !missing(nodes)
  index_supplied <- !missing(index) && !is.null(index)
  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (index_supplied) {
    return(.relations(cg, NULL, index, ancestors_of_ptr))
  }
  if (!nodes_supplied) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }
  expr <- substitute(nodes)
  env <- parent.frame()
  .relations(cg, .expand_nodes(expr, env), NULL, ancestors_of_ptr)
}

#' @title Get descendants of nodes in a `caugi_graph`
#'
#' @param cg A `caugi_graph` object.
#' @param nodes A vector of node names, a vector of unquoted
#' node names, or an expression combining these with `+` and `c()`.
#' @param index A vector of node indexes.
#'
#' @export
descendants <- function(cg, nodes = NULL, index = NULL) {
  nodes_supplied <- !missing(nodes)
  index_supplied <- !missing(index) && !is.null(index)
  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (index_supplied) {
    return(.relations(cg, NULL, index, descendants_of_ptr))
  }
  if (!nodes_supplied) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }
  expr <- substitute(nodes)
  env <- parent.frame()
  .relations(cg, .expand_nodes(expr, env), NULL, descendants_of_ptr)
}
#' @title Get Markov blanket of nodes in a `caugi_graph`
#'
#' @param cg A `caugi_graph` object.
#' @param nodes A vector of node names, a vector of unquoted
#' node names, or an expression combining these with `+` and `c()`.
#' @param index A vector of node indexes.
#'
#' @export
markov_blanket <- function(cg, nodes = NULL, index = NULL) {
  nodes_supplied <- !missing(nodes)
  index_supplied <- !missing(index) && !is.null(index)
  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (index_supplied) {
    return(.relations(cg, NULL, index, markov_blanket_of_ptr))
  }
  if (!nodes_supplied) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }
  expr <- substitute(nodes)
  env <- parent.frame()
  .relations(cg, .expand_nodes(expr, env), NULL, markov_blanket_of_ptr)
}

#' @title Get all exogenous nodes in a `caugi_graph`
#'
#' @description Get all exogenous nodes (nodes with no parents) in a
#' `caugi_graph`.
#'
#' @param cg A `caugi_graph` object.
#' @param undirected_as_parents Logical; if `TRUE`, undirected edges are treated
#' as (possible) parents, if `FALSE` (default), undirected edges are ignored.
#'
#' @returns A tibble with a `name` column.
#' @export
exogenous <- function(cg, undirected_as_parents = FALSE) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  idx0 <- exogenous_nodes_of_ptr(cg@ptr, undirected_as_parents)
  .getter_output(cg, idx0)
}

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── Relations helpers ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Resolve node names or indices to zero-based indices
#'
#' @description Convert node names or one-based indices to zero-based indices.
#'
#' @param cg A `caugi_graph` object.
#' @param nodes A vector of node names or one-based indices.
#'
#' @returns An integer vector of zero-based node indices.
#'
#' @keywords internal
.resolve_idx <- function(cg, nodes) {
  nm <- cg@nodes$name
  # extra precaution
  if (is.null(nm)) {
    stop("Node names unavailable on this graph.", call. = FALSE) # nocov
  }
  m <- match(as.character(nodes), nm)
  if (anyNA(m)) {
    bad <- nodes[is.na(m)]
    stop("Unknown node(s): ", paste(bad, collapse = ", "), call. = FALSE)
  }
  m - 1L
}

#' @title Resolve 1-based indices to zero-based
#' @keywords internal
.resolve_idx_from_index <- function(cg, index) {
  if (!is.numeric(index)) {
    stop("`index` must be numeric.", call. = FALSE)
  }
  ix <- as.integer(index)
  if (any(ix < 1L) || any(ix > nrow(cg@nodes))) {
    stop("`index` out of bounds [1, ", nrow(cg@nodes), "].", call. = FALSE)
  }
  ix - 1L
}

#' @title Output object of getter queries
#'
#' @description Helper to format the output of getter queries.
#'
#' @param cg A `caugi_graph` object.
#' @param idx0 A vector of zero-based node indices.
#'
#' @returns A tibble with a `name` column.
#'
#' @keywords internal
.getter_output <- function(cg, idx0) {
  id <- as.integer(idx0) + 1L
  nm <- cg@nodes$name
  tibble::tibble(name = if (is.null(nm)) as.character(id) else nm[id])
}

#' @title Get relations of nodes in a `caugi_graph`
#'
#' @description Helper to get relations (parents, children, etc.) of nodes.
#'
#' @param cg A `caugi_graph` object.
#' @param nodes_expr A node expression from .expand_nodes.
#' @param index A vector of node indices.
#' @param getter A function that takes a pointer to the graph and a zero-based
#' node index, and returns a vector of zero-based indices of related nodes.
#'
#' @returns A tibble with a `name` column.
#'
#' @keywords internal
#' @title Get relations of nodes in a `caugi_graph`
#' @keywords internal
.relations <- function(cg, nodes_expr, index, getter) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)

  # exactly one of nodes or index
  has_nodes <- !missing(nodes_expr) && !is.null(nodes_expr)
  has_index <- !missing(index) && !is.null(index)
  # extra precaution
  if (has_nodes && has_index) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (!has_nodes && !has_index) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }

  if (has_index) {
    idx0 <- .resolve_idx_from_index(cg, index)
  } else {
    idx0 <- .resolve_idx(cg, nodes_expr)
  }

  rows <- lapply(idx0, function(i0) .getter_output(cg, getter(cg@ptr, i0)))
  if (length(rows) == 1L) rows[[1]] else do.call(rbind, rows)
}
