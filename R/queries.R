# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Queries ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────────── Checks ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Is it a `caugi` graph?
#'
#' @description Checks if the given object is a `caugi`. Mostly used
#' internally to validate inputs.
#'
#' @param x An object to check.
#' @param throw_error Logical; if `TRUE`, throws an error if `x` is not a
#' `caugi`.
#'
#' @returns A logical value indicating whether the object is a `caugi`.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   class = "DAG"
#' )
#'
#' is_caugi(cg) # TRUE
#'
#' @family queries
#' @concept queries
#'
#' @export
is_caugi <- function(x, throw_error = FALSE) {
  is_it <- inherits(x, caugi)

  if (!is_it && throw_error) {
    stop("Input must be a caugi", call. = FALSE)
  }
  is_it
}

#' @title Is the `caugi` graph empty?
#'
#' @description Checks if the given `caugi` graph is empty (has no nodes).
#'
#' @param cg A `caugi` object.
#'
#' @returns A logical value indicating whether the graph is empty.
#'
#' @examples
#' cg_empty <- caugi(class = "DAG")
#' is_empty_caugi(cg_empty) # TRUE
#' cg_non_empty <- caugi(
#'   A %-->% B,
#'   class = "DAG"
#' )
#' is_empty_caugi(cg_non_empty) # FALSE
#'
#' cg_no_edges_but_has_nodes <- caugi(
#'   A, B,
#'   class = "DAG"
#' )
#' is_empty_caugi(cg_no_edges_but_has_nodes) # FALSE
#'
#' @family queries
#' @concept queries
#'
#' @export
is_empty_caugi <- function(cg) {
  is_caugi(cg, throw_error = TRUE)
  nrow(cg@nodes) == 0L
}

#' @title Same nodes?
#'
#' @description Check if two `caugi` objects have the same nodes.
#'
#' @param cg1 A `caugi` object.
#' @param cg2 A `caugi` object.
#' @param throw_error Logical; if `TRUE`, throws an error if the graphs do not
#' have the same nodes.
#'
#' @returns A logical indicating if the two graphs have the same nodes.
#'
#' @examples
#' cg1 <- caugi(
#'   A %-->% B,
#'   class = "DAG"
#' )
#' cg2 <- caugi(
#'   A %-->% B + C,
#'   class = "DAG"
#' )
#' same_nodes(cg1, cg2) # FALSE
#'
#' @family queries
#' @concept queries
#'
#' @export
same_nodes <- function(cg1, cg2, throw_error = FALSE) {
  is_caugi(cg1, throw_error)
  is_caugi(cg2, throw_error)
  if (!setequal(cg1@nodes$name, cg2@nodes$name)) {
    if (throw_error) {
      differing_nodes <- setdiff(
        union(cg1@nodes$name, cg2@nodes$name),
        intersect(cg1@nodes$name, cg2@nodes$name)
      )
      stop(
        "Graphs must have the same nodes.\n",
        "Differing nodes are: [",
        paste(differing_nodes, collapse = ", "),
        "]."
      )
    }
    return(FALSE)
  }
  return(TRUE)
}

#' @title Is the `caugi` acyclic?
#'
#' @description Checks if the given `caugi` graph is acyclic.
#'
#' @param cg A `caugi` object.
#' @param force_check Logical; if `TRUE`, the function will test if the graph is
#' acyclic, if `FALSE` (default), it will look at the graph class and match
#' it, if possible.
#'
#' @details
#' Logically, it should not be possible to have a graph class of "DAG" or "PDAG"
#' that has cycles, but in case the user modified the graph after creation in
#' some unforeseen way that could have introduced cycles, this function allows
#' to force a check of acyclicity, if needed.
#'
#' @returns A logical value indicating whether the graph is acyclic.
#'
#' @examples
#' cg_acyclic <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   class = "DAG"
#' )
#' is_acyclic(cg_acyclic) # TRUE
#' cg_cyclic <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   C %-->% A,
#'   class = "UNKNOWN"
#' )
#' is_acyclic(cg_cyclic) # FALSE
#'
#' @family queries
#' @concept queries
#'
#' @export
is_acyclic <- function(cg, force_check = FALSE) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  if (force_check) {
    is_it <- is_acyclic_ptr(cg@ptr)
  } else if (
    identical(cg@graph_class, "DAG") ||
      identical(cg@graph_class, "PDAG")
  ) {
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
#' @param cg A `caugi` object.
#' @param force_check Logical; if `TRUE`, the function will test if the graph is
#' a DAG, if `FALSE` (default), it will look at the graph class and match
#' it, if possible.
#'
#' @returns A logical value indicating whether the graph is a DAG.
#'
#' @examples
#' cg_dag_class <- caugi(
#'   A %-->% B,
#'   class = "DAG"
#' )
#' is_dag(cg_dag_class) # TRUE
#' cg_dag_but_pdag_class <- caugi(
#'   A %-->% B,
#'   class = "PDAG"
#' )
#' is_dag(cg_dag_but_pdag_class) # TRUE
#' cg_cyclic <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   C %-->% A,
#'   class = "UNKNOWN",
#'   simple = FALSE
#' )
#' is_dag(cg_cyclic) # FALSE
#'
#' cg_undirected <- caugi(
#'   A %---% B,
#'   class = "UNKNOWN"
#' )
#' is_dag(cg_undirected) # FALSE
#'
#' @family queries
#' @concept queries
#'
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
#' @param cg A `caugi` object.
#' @param force_check Logical; if `TRUE`, the function will test if the graph is
#' a PDAG, if `FALSE` (default), it will look at the graph class and match
#' it, if possible.
#'
#' @returns A logical value indicating whether the graph is a PDAG.
#' @examples
#' cg_dag_class <- caugi(
#'   A %-->% B,
#'   class = "DAG"
#' )
#' is_pdag(cg_dag_class) # TRUE
#' cg_dag_but_pdag_class <- caugi(
#'   A %-->% B,
#'   class = "PDAG"
#' )
#' is_pdag(cg_dag_but_pdag_class) # TRUE
#' cg_cyclic <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   C %-->% A,
#'   D %---% A,
#'   class = "UNKNOWN",
#'   simple = FALSE
#' )
#' is_pdag(cg_cyclic) # FALSE
#'
#' cg_undirected <- caugi(
#'   A %---% B,
#'   class = "UNKNOWN"
#' )
#' is_pdag(cg_undirected) # TRUE
#'
#' cg_pag <- caugi(
#'   A %o->% B,
#'   class = "UNKNOWN"
#' )
#' is_pdag(cg_pag) # FALSE
#'
#' @family queries
#' @concept queries
#'
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

#' @title Is the `caugi` graph a CPDAG?
#'
#' @description Checks if the given `caugi` graph is a
#' Complete Partially Directed Acyclic Graph (CPDAG).
#'
#' @param cg A `caugi` object.
#'
#' @returns A logical value indicating whether the graph is a CPDAG.
#'
#' @examples
#' cg_cpdag <- caugi(
#'   A %---% B,
#'   A %-->% C,
#'   B %-->% C,
#'   class = "PDAG"
#' )
#' is_cpdag(cg_cpdag) # TRUE
#'
#' cg_not_cpdag <- caugi(
#'   A %---% B,
#'   A %---% C,
#'   B %-->% C,
#'   class = "PDAG"
#' )
#' is_cpdag(cg_not_cpdag) # FALSE
#'
#' @family queries
#' @concept queries
#'
#' @export
is_cpdag <- function(cg) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  is_it <- is_cpdag_ptr(cg@ptr)
  is_it
}

#' @title Is the `caugi` graph an UG?
#'
#' @description Checks if the given `caugi` graph is an undirected graph (UG).
#'
#' @param cg A `caugi` object.
#' @param force_check Logical; if `TRUE`, the function will test if the graph is
#' an UG, if `FALSE` (default), it will look at the graph class and match
#' it, if possible.
#'
#' @returns A logical value indicating whether the graph is an UG.
#'
#' @examples
#' cg_ug_class <- caugi(
#'   A %---% B,
#'   class = "UG"
#' )
#' is_ug(cg_ug_class) # TRUE
#' cg_not_ug <- caugi(
#'   A %-->% B,
#'   class = "DAG"
#' )
#' is_ug(cg_not_ug) # FALSE
#'
#' @family queries
#' @concept queries
#'
#' @export
is_ug <- function(cg, force_check = FALSE) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  if (identical(cg@graph_class, "UG") && !force_check) {
    is_it <- TRUE
  } else {
    # if we can't be sure from the class, we check
    is_it <- is_ug_type_ptr(cg@ptr)
  }
  is_it
}

#' @title Is the `caugi` graph an ADMG?
#'
#' @description Checks if the given `caugi` graph is an
#' Acyclic Directed Mixed Graph (ADMG).
#'
#' An ADMG contains only directed (`-->`) and bidirected (`<->`) edges,
#' and the directed part must be acyclic.
#'
#' @param cg A `caugi` object.
#' @param force_check Logical; if `TRUE`, the function will test if the graph is
#' an ADMG, if `FALSE` (default), it will look at the graph class and match
#' it, if possible.
#'
#' @returns A logical value indicating whether the graph is an ADMG.
#'
#' @examples
#' cg_admg <- caugi(
#'   A %-->% B,
#'   A %<->% C,
#'   class = "ADMG"
#' )
#' is_admg(cg_admg) # TRUE
#'
#' cg_dag <- caugi(
#'   A %-->% B,
#'   class = "DAG"
#' )
#' is_admg(cg_dag) # TRUE (DAGs are valid ADMGs)
#'
#' @family queries
#' @concept queries
#'
#' @export
is_admg <- function(cg, force_check = FALSE) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  if (identical(cg@graph_class, "ADMG") && !force_check) {
    is_it <- TRUE
  } else {
    # if we can't be sure from the class, we check
    is_it <- is_admg_type_ptr(cg@ptr)
  }
  is_it
}

#' @title Is the `caugi` graph an AG?
#'
#' @description Checks if the given `caugi` graph is an
#' Ancestral Graph (AG).
#'
#' An AG contains directed (`-->`), bidirected (`<->`), and undirected (`---`)
#' edges, and must satisfy ancestral graph constraints (no directed cycles,
#' anterior constraint, and undirected constraint).
#'
#' @param cg A `caugi` object.
#' @param force_check Logical; if `TRUE`, the function will test if the graph is
#' an AG, if `FALSE` (default), it will look at the graph class and match
#' it, if possible.
#'
#' @returns A logical value indicating whether the graph is an AG.
#'
#' @examples
#' cg_ag <- caugi(
#'   A %-->% B,
#'   C %<->% D,
#'   E %---% F,
#'   class = "AG"
#' )
#' is_ag(cg_ag) # TRUE
#'
#' cg_ug <- caugi(
#'   A %---% B,
#'   class = "UG"
#' )
#' is_ag(cg_ug) # TRUE (UGs are valid AGs)
#'
#' @family queries
#' @concept queries
#'
#' @export
is_ag <- function(cg, force_check = FALSE) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  if (identical(cg@graph_class, "AG") && !force_check) {
    is_it <- TRUE
  } else {
    # if we can't be sure from the class, we check
    is_it <- is_ag_type_ptr(cg@ptr)
  }
  is_it
}

#' @title Is the `caugi` graph a MAG?
#'
#' @description Checks if the given `caugi` graph is a
#' Maximal Ancestral Graph (MAG).
#'
#' A MAG is an ancestral graph where no additional edge can be added without
#' violating the ancestral graph constraints or changing the encoded
#' independence model.
#'
#' @param cg A `caugi` object.
#' @param force_check Logical; if `TRUE`, the function will test if the graph is
#' a MAG, if `FALSE` (default), it will look at the graph class and match
#' it, if possible.
#'
#' @returns A logical value indicating whether the graph is a MAG.
#'
#' @examples
#' cg_ag <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   class = "AG"
#' )
#' is_mag(cg_ag) # TRUE (0 and 2 are m-separated by {B})
#'
#' @family queries
#' @concept queries
#'
#' @export
is_mag <- function(cg, force_check = FALSE) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  if (identical(cg@graph_class, "MAG") && !force_check) {
    is_it <- TRUE
  } else {
    is_it <- is_mag_ptr(cg@ptr)
  }
  is_it
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Nodes and edges ────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Get nodes or edges of a `caugi`
#'
#' @param cg A `caugi` object.
#'
#' @param ... Additional arguments (currently unused).
#'
#' @returns A `data.table` with a `name` column.
#'
#' @rdname nodes
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   D,
#'   class = "DAG"
#' )
#' nodes(cg) # returns the data.table with nodes A, B, C, D
#'
#' @family queries
#' @concept queries
#'
#' @export
nodes <- S7::new_generic("nodes", "cg")

#' @export
S7::method(nodes, caugi) <- function(cg) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  cg@nodes
}

#' @rdname nodes
#' @export
vertices <- nodes

#' @rdname nodes
#' @export
V <- nodes # igraph notation

#' @title Get edges of a `caugi`.
#'
#' @param cg A `caugi` object.
#'
#' @param ... Additional arguments (currently unused).
#'
#' @rdname edges
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   D,
#'   class = "DAG"
#' )
#' edges(cg) # returns the data.table with columns from, edge, to
#'
#' @family queries
#' @concept queries
#'
#' @returns A `data.table` with columns `from`, `edge`, and `to`.
#'
#' @export
edges <- S7::new_generic("edges", "cg")

#' @export
S7::method(edges, caugi) <- function(cg) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  cg@edges
}

#' @rdname edges
#' @export
E <- edges # igraph notation

#' @title Get the edge types of a `caugi`.
#'
#' @param cg A `caugi` object.
#'
#' @returns A character vector of edge types.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   B %--o% C,
#'   C %<->% D,
#'   D %---% E,
#'   A %o-o% E,
#'   class = "UNKNOWN"
#' )
#' edge_types(cg) # returns c("-->", "o-o", "--o", "<->", "---")
#'
#' @family queries
#' @concept queries
#'
#' @export
edge_types <- function(cg) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  unique(cg@edges$edge)
}
# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── Relations ───────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Get parents of nodes in a `caugi`
#'
#' @description
#' Get parents of nodes in a graph (nodes with directed edges pointing INTO
#' the target node). This is equivalent to `neighbors(cg, nodes, mode = "in")`.
#'
#' Note that not both nodes and index can be given.
#'
#' @param cg A `caugi` object.
#' @param nodes A vector of node names, a vector of unquoted
#' node names, or an expression combining these with `+` and `c()`.
#' @param index A vector of node indexes.
#'
#' @returns Either a character vector of node names (if a single node is
#' requested) or a list of character vectors (if multiple nodes are requested).
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   class = "DAG"
#' )
#' parents(cg, "A") # NULL
#' parents(cg, index = 2) # "A"
#' parents(cg, "B") # "A"
#' parents(cg, c("B", "C"))
#' #> $B
#' #> [1] "A"
#' #>
#' #> $C
#' #> [1] "B"
#'
#' @family queries
#' @concept queries
#'
#' @export
parents <- function(cg, nodes = NULL, index = NULL) {
  nodes_supplied <- !missing(nodes)
  index_supplied <- !missing(index) && !is.null(index)
  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (!cg@built) {
    cg <- build(cg)
  }
  if (index_supplied) {
    return(.getter_output(
      cg,
      parents_of_ptr(cg@ptr, as.integer(index - 1L)),
      cg@nodes$name[index]
    ))
  }
  if (!nodes_supplied) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }
  if (!is.character(nodes)) {
    stop("`nodes` must be a character vector of node names.", call. = FALSE)
  }

  index <- cg@name_index_map$mget(
    nodes,
    missing = stop(
      paste(
        "Non-existent node name:",
        paste(setdiff(nodes, cg@nodes$name), collapse = ", ")
      ),
      call. = FALSE
    )
  )

  .getter_output(cg, parents_of_ptr(cg@ptr, as.integer(index)), nodes)
}

#' @title Get children of nodes in a `caugi`
#'
#' @description
#' Get children of nodes in a graph (nodes with directed edges pointing OUT
#' from the target nodes).
#' This is equivalent to `neighbors(cg, nodes, mode = "out")`.
#'
#' @param cg A `caugi` object.
#' @param nodes A vector of node names, a vector of unquoted
#' node names, or an expression combining these with `+` and `c()`.
#' @param index A vector of node indexes.
#'
#' @returns Either a character vector of node names (if a single node is
#' requested) or a list of character vectors (if multiple nodes are requested).
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   class = "DAG"
#' )
#' children(cg, "A") # "B"
#' children(cg, index = 2) # "C"
#' children(cg, "B") # "C"
#' children(cg, c("B", "C"))
#' #> $B
#' #> [1] "C"
#' #>
#' #> $C
#' #> NULL
#'
#' @family queries
#' @concept queries
#'
#' @export
children <- function(cg, nodes = NULL, index = NULL) {
  nodes_supplied <- !missing(nodes)
  index_supplied <- !missing(index) && !is.null(index)
  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (!cg@built) {
    cg <- build(cg)
  }
  if (index_supplied) {
    return(.getter_output(
      cg,
      children_of_ptr(cg@ptr, as.integer(index - 1L)),
      cg@nodes$name[index]
    ))
  }
  if (!nodes_supplied) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }
  if (!is.character(nodes)) {
    stop("`nodes` must be a character vector of node names.", call. = FALSE)
  }

  index <- cg@name_index_map$mget(
    nodes,
    missing = stop(
      paste(
        "Non-existent node name:",
        paste(setdiff(nodes, cg@nodes$name), collapse = ", ")
      ),
      call. = FALSE
    )
  )

  .getter_output(cg, children_of_ptr(cg@ptr, as.integer(index)), nodes)
}

#' @title Get neighbors of nodes in a `caugi`
#'
#' @description
#' Get neighbors of a node in the graph, optionally filtered by edge direction
#' or type. This function works for all graph classes including `UNKNOWN`.
#'
#' @param cg A `caugi` object.
#' @param nodes A vector of node names, a vector of unquoted
#' node names, or an expression combining these with `+` and `c()`.
#' @param index A vector of node indexes.
#' @param mode Character; specifies which types of neighbors to return:
#' \describe{
#'   \item{`"all"`}{All neighbors (default)}
#'   \item{`"in"`}{Parents: nodes with directed edges pointing
#'     INTO the target node (equivalent to `parents()`)}
#'   \item{`"out"`}{Children: nodes with directed edges pointing
#'     OUT from the target node (equivalent to `children()`)}
#'   \item{`"undirected"`}{Nodes connected via undirected (`---`) edges}
#'   \item{`"bidirected"`}{Nodes connected via bidirected (`<->`) edges
#'     (equivalent to `spouses()` for ADMGs)}
#'   \item{`"partial"`}{Nodes connected via partial edges (edges with circle
#'     endpoints: `o-o`, `o->`, `--o`)}
#' }
#'
#' Not all modes are valid for all graph classes:
#' \itemize{
#'   \item DAG: `"in"`, `"out"`, `"all"` only
#'   \item PDAG: `"in"`, `"out"`, `"undirected"`, `"all"`
#'   \item UG: `"undirected"`, `"all"` only
#'   \item ADMG: `"in"`, `"out"`, `"bidirected"`, `"all"`
#'   \item UNKNOWN: all modes allowed
#' }
#'
#' @returns Either a character vector of node names (if a single node is
#' requested) or a list of character vectors (if multiple nodes are requested).
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   class = "DAG"
#' )
#' neighbors(cg, "A") # "B"
#' neighbors(cg, index = 2) # "A" "C"
#' neighbors(cg, "B") # "A" "C"
#' neighbors(cg, c("B", "C"))
#' #> $B
#' #> [1] "A" "C"
#' #>
#' #> $C
#' #> [1] "B"
#'
#' # Using mode to filter by edge direction
#' neighbors(cg, "B", mode = "in") # "A" (parents)
#' neighbors(cg, "B", mode = "out") # "C" (children)
#'
#' # Works for UNKNOWN graphs too
#' cg_unknown <- caugi(
#'   A %-->% B,
#'   B %---% C,
#'   C %o->% D,
#'   class = "UNKNOWN"
#' )
#' neighbors(cg_unknown, "B", mode = "in") # "A"
#' neighbors(cg_unknown, "B", mode = "undirected") # "C"
#' neighbors(cg_unknown, "C", mode = "partial") # "D"
#'
#' @family queries
#' @concept queries
#'
#' @export
neighbors <- function(
  cg,
  nodes = NULL,
  index = NULL,
  mode = c(
    "all",
    "in",
    "out",
    "undirected",
    "bidirected",
    "partial"
  )
) {
  nodes_supplied <- !missing(nodes)
  index_supplied <- !missing(index) && !is.null(index)
  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (!cg@built) {
    cg <- build(cg)
  }

  mode <- match.arg(mode)

  if (index_supplied) {
    return(.getter_output(
      cg,
      neighbors_of_ptr(cg@ptr, as.integer(index - 1L), mode),
      cg@nodes$name[index]
    ))
  }
  if (!nodes_supplied) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }
  if (!is.character(nodes)) {
    stop("`nodes` must be a character vector of node names.", call. = FALSE)
  }

  index <- cg@name_index_map$mget(
    nodes,
    missing = stop(
      paste(
        "Non-existent node name:",
        paste(setdiff(nodes, cg@nodes$name), collapse = ", ")
      ),
      call. = FALSE
    )
  )

  .getter_output(
    cg,
    neighbors_of_ptr(cg@ptr, as.integer(index), mode),
    nodes
  )
}

#' @rdname neighbors
#' @export
neighbours <- neighbors

#' @title Get ancestors of nodes in a `caugi`
#'
#' @param cg A `caugi` object.
#' @param nodes A vector of node names, a vector of unquoted
#' node names, or an expression combining these with `+` and `c()`.
#' @param index A vector of node indexes.
#' @param graph_definition Character; either `"open"` or `"closed"`. Determines
#'   how the graph is interpreted when retrieving ancestors. If `NULL` (default),
#'   the value is taken from the global `caugi_options("graph_definition")`.
#'
#' @returns Either a character vector of node names (if a single node is
#' requested) or a list of character vectors (if multiple nodes are requested).
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   class = "DAG"
#' )
#' ancestors(cg, "A") # NULL
#' ancestors(cg, "A", graph_definition = "closed") # A
#' ancestors(cg, index = 2) # "A"
#' ancestors(cg, "B") # "A"
#' ancestors(cg, c("B", "C"))
#' #> $B
#' #> [1] "A"
#' #>
#' #> $C
#' #> [1] "A" "B"
#'
#' @family queries
#' @concept queries
#'
#' @export
ancestors <- function(cg, nodes = NULL, index = NULL, graph_definition = NULL) {
  if (is.null(graph_definition)) {
    graph_def <- caugi_options("graph_definition")[[1L]]
  } else {
    graph_def <- graph_definition
  }

  graph_def <- match.arg(graph_def, c("open", "closed"))
  open <- graph_def == "open"

  nodes_supplied <- !missing(nodes)
  index_supplied <- !missing(index) && !is.null(index)

  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (!cg@built) {
    cg <- build(cg)
  }
  if (index_supplied) {
    return(.getter_output(
      cg,
      ancestors_of_ptr(cg@ptr, as.integer(index - 1L), open = open),
      cg@nodes$name[index]
    ))
  }
  if (!nodes_supplied) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }
  if (!is.character(nodes)) {
    stop("`nodes` must be a character vector of node names.", call. = FALSE)
  }

  index <- cg@name_index_map$mget(
    nodes,
    missing = stop(
      paste(
        "Non-existent node name:",
        paste(setdiff(nodes, cg@nodes$name), collapse = ", ")
      ),
      call. = FALSE
    )
  )

  .getter_output(
    cg,
    ancestors_of_ptr(cg@ptr, as.integer(index), open = open),
    nodes
  )
}

#' @title Get descendants of nodes in a `caugi`
#'
#' @param cg A `caugi` object.
#' @param nodes A vector of node names, a vector of unquoted
#' node names, or an expression combining these with `+` and `c()`.
#' @param index A vector of node indexes.
#' @param graph_definition Character; either `"open"` or `"closed"`. Determines
#'   how the graph is interpreted when retrieving descendants. If `NULL` (default),
#'   the value is taken from the global `caugi_options("graph_definition")`.
#'
#' @returns Either a character vector of node names (if a single node is
#' requested) or a list of character vectors (if multiple nodes are requested).
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   class = "DAG"
#' )
#' descendants(cg, "A") # "B" "C"
#' descendants(cg, "A", graph_definition = "closed") # "A" "B" "C"
#' descendants(cg, index = 2) # "C"
#' descendants(cg, "B") # "C"
#' descendants(cg, c("B", "C"))
#' #> $B
#' #> [1] "C"
#' #>
#' #> $C
#' #> NULL
#'
#' @family queries
#' @concept queries
#'
#' @export
descendants <- function(
  cg,
  nodes = NULL,
  index = NULL,
  graph_definition = NULL
) {
  if (is.null(graph_definition)) {
    graph_def <- caugi_options("graph_definition")[[1L]]
  } else {
    graph_def <- graph_definition
  }

  graph_def <- match.arg(graph_def, c("open", "closed"))
  open <- graph_def == "open"

  nodes_supplied <- !missing(nodes)
  index_supplied <- !missing(index) && !is.null(index)
  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (!cg@built) {
    cg <- build(cg)
  }
  if (index_supplied) {
    return(.getter_output(
      cg,
      descendants_of_ptr(cg@ptr, as.integer(index - 1L), open = open),
      cg@nodes$name[index]
    ))
  }
  if (!nodes_supplied) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }
  if (!is.character(nodes)) {
    stop("`nodes` must be a character vector of node names.", call. = FALSE)
  }

  index <- cg@name_index_map$mget(
    nodes,
    missing = stop(
      paste(
        "Non-existent node name:",
        paste(setdiff(nodes, cg@nodes$name), collapse = ", ")
      ),
      call. = FALSE
    )
  )

  .getter_output(
    cg,
    descendants_of_ptr(cg@ptr, as.integer(index), open = open),
    nodes
  )
}

#' @title Get anteriors of nodes in a `caugi`
#'
#' @description
#' Get the anterior set of nodes in a graph. The anterior set (Richardson and
#' Spirtes, 2002) includes all nodes reachable by following paths where every
#' edge is either undirected or directed toward the target node.
#'
#' For DAGs, the anterior set equals the ancestor set (since there are no
#' undirected edges). For PDAGs, it includes both ancestors and nodes reachable
#' via undirected edges.
#'
#' @param cg A `caugi` object of class DAG or PDAG.
#' @param nodes A vector of node names, a vector of unquoted
#' node names, or an expression combining these with `+` and `c()`.
#' @param index A vector of node indexes.
#' @param graph_definition Character; either `"open"` or `"closed"`. Determines
#'   how the graph is interpreted when retrieving anteriors. If `NULL` (default),
#'   the value is taken from the global `caugi_options("graph_definition")`.
#'
#' @returns Either a character vector of node names (if a single node is
#' requested) or a list of character vectors (if multiple nodes are requested).
#'
#' @examples
#' # PDAG example with directed and undirected edges
#' cg <- caugi(
#'   A %-->% B %---% C,
#'   B %-->% D,
#'   class = "PDAG"
#' )
#' anteriors(cg, "A") # NULL (no anteriors)
#' anteriors(cg, "A", graph_definition = "closed") # A
#' anteriors(cg, "C") # A, B
#' anteriors(cg, "D") # A, B, C
#'
#' # For DAGs, anteriors equals ancestors
#' cg_dag <- caugi(
#'   A %-->% B %-->% C,
#'   class = "DAG"
#' )
#' anteriors(cg_dag, "C") # A, B
#'
#' @references
#' Richardson, T. and Spirtes, P. (2002). Ancestral graph Markov models.
#' \emph{The Annals of Statistics}, 30(4):962-1030.
#'
#' @family queries
#' @concept queries
#'
#' @export
anteriors <- function(cg, nodes = NULL, index = NULL, graph_definition = NULL) {
  if (is.null(graph_definition)) {
    graph_def <- caugi_options("graph_definition")[[1L]]
  } else {
    graph_def <- graph_definition
  }

  graph_def <- match.arg(graph_def, c("open", "closed"))
  open <- graph_def == "open"

  nodes_supplied <- !missing(nodes)
  index_supplied <- !missing(index) && !is.null(index)
  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (!cg@built) {
    cg <- build(cg)
  }
  if (index_supplied) {
    return(.getter_output(
      cg,
      anteriors_of_ptr(cg@ptr, as.integer(index - 1L), open = open),
      cg@nodes$name[index]
    ))
  }
  if (!nodes_supplied) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }
  if (!is.character(nodes)) {
    stop("`nodes` must be a character vector of node names.", call. = FALSE)
  }

  index <- cg@name_index_map$mget(
    nodes,
    missing = stop(
      paste(
        "Non-existent node name:",
        paste(setdiff(nodes, cg@nodes$name), collapse = ", ")
      ),
      call. = FALSE
    )
  )

  .getter_output(
    cg,
    anteriors_of_ptr(cg@ptr, as.integer(index), open = open),
    nodes
  )
}

#' @title Get Markov blanket of nodes in a `caugi`
#'
#' @param cg A `caugi` object.
#' @param nodes A vector of node names, a vector of unquoted
#' node names, or an expression combining these with `+` and `c()`.
#' @param index A vector of node indexes.
#'
#' @returns Either a character vector of node names (if a single node is
#' requested) or a list of character vectors (if multiple nodes are requested).
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   class = "DAG"
#' )
#' markov_blanket(cg, "A") # "B"
#' markov_blanket(cg, index = 2) # "A" "C"
#' markov_blanket(cg, "B") # "A" "C"
#' markov_blanket(cg, c("B", "C"))
#' #> $B
#' #> [1] "A" "C"
#' #>
#' #> $C
#' #> [1] "B"
#'
#' @family queries
#' @concept queries
#'
#' @export
markov_blanket <- function(cg, nodes = NULL, index = NULL) {
  nodes_supplied <- !missing(nodes)
  index_supplied <- !missing(index) && !is.null(index)
  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (!cg@built) {
    cg <- build(cg)
  }
  if (index_supplied) {
    return(.getter_output(
      cg,
      markov_blanket_of_ptr(cg@ptr, as.integer(index - 1L)),
      cg@nodes$name[index]
    ))
  }
  if (!nodes_supplied) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }
  if (!is.character(nodes)) {
    stop("`nodes` must be a character vector of node names.", call. = FALSE)
  }

  index <- cg@name_index_map$mget(
    nodes,
    missing = stop(
      paste(
        "Non-existent node name:",
        paste(setdiff(nodes, cg@nodes$name), collapse = ", ")
      ),
      call. = FALSE
    )
  )

  .getter_output(cg, markov_blanket_of_ptr(cg@ptr, as.integer(index)), nodes)
}

#' @title Get all exogenous nodes in a `caugi`
#'
#' @description Get all exogenous nodes (nodes with no parents) in a
#' `caugi`.
#'
#' @param cg A `caugi` object.
#' @param undirected_as_parents Logical; if `TRUE`, undirected edges are treated
#' as (possible) parents, if `FALSE` (default), undirected edges are ignored.
#'
#' @returns Either a character vector of node names (if a single node is
#' requested) or a list of character vectors (if multiple nodes are requested).
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   class = "DAG"
#' )
#' exogenous(cg) # "A"
#'
#' @family queries
#' @concept queries
#'
#' @export
exogenous <- function(cg, undirected_as_parents = FALSE) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  idx0 <- exogenous_nodes_of_ptr(cg@ptr, undirected_as_parents)
  cg@nodes$name[idx0 + 1L]
}

#' @title Get a topological ordering of a DAG
#'
#' @description Returns a topological ordering of the nodes in a DAG. For every
#' directed edge u -> v in the graph, u will appear before v in the returned
#' ordering.
#'
#' @param cg A `caugi` object of class DAG.
#'
#' @returns A character vector of node names in topological order.
#'
#' @examples
#' # Simple DAG: A -> B -> C
#' cg <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   class = "DAG"
#' )
#' topological_sort(cg) # Returns c("A", "B", "C") or equivalent valid ordering
#'
#' # DAG with multiple valid orderings
#' cg2 <- caugi(
#'   A %-->% C,
#'   B %-->% C,
#'   class = "DAG"
#' )
#' # Could return c("A", "B", "C") or c("B", "A", "C")
#' topological_sort(cg2)
#'
#' @family queries
#' @concept queries
#'
#' @export
topological_sort <- function(cg) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  idx0 <- topological_sort_ptr(cg@ptr)
  cg@nodes$name[idx0 + 1L]
}

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────── ADMG-specific queries ────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Get spouses (bidirected neighbors) of nodes in an ADMG
#'
#' @description Get nodes connected via bidirected edges in an ADMG.
#'
#' @param cg A `caugi` object of class ADMG.
#' @param nodes A vector of node names.
#' @param index A vector of node indexes.
#'
#' @returns Either a character vector of node names (if a single node is
#' requested) or a list of character vectors (if multiple nodes are requested).
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   A %<->% C,
#'   B %<->% C,
#'   class = "ADMG"
#' )
#' spouses(cg, "A") # "C"
#' spouses(cg, "C") # c("A", "B")
#'
#' @family queries
#' @concept queries
#'
#' @export
spouses <- function(cg, nodes = NULL, index = NULL) {
  nodes_supplied <- !missing(nodes)
  index_supplied <- !missing(index) && !is.null(index)
  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (!cg@built) {
    cg <- build(cg)
  }
  if (index_supplied) {
    return(.getter_output(
      cg,
      spouses_of_ptr(cg@ptr, as.integer(index - 1L)),
      cg@nodes$name[index]
    ))
  }
  if (!nodes_supplied) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }
  if (!is.character(nodes)) {
    stop("`nodes` must be a character vector of node names.", call. = FALSE)
  }

  index <- cg@name_index_map$mget(
    nodes,
    missing = stop(
      paste(
        "Non-existent node name:",
        paste(setdiff(nodes, cg@nodes$name), collapse = ", ")
      ),
      call. = FALSE
    )
  )

  .getter_output(cg, spouses_of_ptr(cg@ptr, as.integer(index)), nodes)
}

#' @title Get districts (c-components) of an ADMG
#'
#' @description Get the districts (c-components) of an ADMG.
#' A district is a maximal set of nodes connected via bidirected edges.
#'
#' @param cg A `caugi` object of class ADMG.
#'
#' @returns A list of character vectors,
#' each containing the nodes in a district.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   A %<->% C,
#'   D %<->% E,
#'   class = "ADMG"
#' )
#' districts(cg)
#' # Returns list with districts: {A, C}, {B}, {D, E}
#'
#' @family queries
#' @concept queries
#'
#' @export
districts <- function(cg) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)
  idx0_list <- districts_ptr(cg@ptr)
  lapply(idx0_list, function(idx0) cg@nodes$name[idx0 + 1L])
}

#' @title M-separation test for AGs and ADMGs
#'
#' @description Test whether two sets of nodes are m-separated given a
#' conditioning set in an ancestral graph (AG) or an ADMG.
#'
#' M-separation generalizes d-separation to AGs/ADMGs and applies to DAGs.
#'
#' @param cg A `caugi` object of class AG, ADMG, or DAG.
#' @param X,Y,Z Node selectors: character vector of names, unquoted expression
#'   (supports `+` and `c()`), or `NULL`. Use `*_index` to pass 1-based indices.
#'   If `Z` is `NULL` or missing, no nodes are conditioned on.
#' @param X_index,Y_index,Z_index Optional numeric 1-based indices (exclusive
#'   with `X`,`Y`,`Z` respectively).
#'
#' @returns A logical value; `TRUE` if `X` and `Y` are m-separated given `Z`.
#'
#' @examples
#' # Classic confounding example
#' cg <- caugi(
#'   L %-->% X,
#'   X %-->% Y,
#'   L %-->% Y,
#'   class = "ADMG"
#' )
#' m_separated(cg, X = "X", Y = "Y") # FALSE (connected via L)
#' m_separated(cg, X = "X", Y = "Y", Z = "L") # TRUE (L blocks the path)
#'
#' @family queries
#' @concept queries
#'
#' @export
m_separated <- function(
  cg,
  X = NULL,
  Y = NULL,
  Z = NULL,
  X_index = NULL,
  Y_index = NULL,
  Z_index = NULL
) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)

  X_idx0 <- .resolve_idx0_mget(cg@name_index_map, X, X_index)
  Y_idx0 <- .resolve_idx0_mget(cg@name_index_map, Y, Y_index)
  Z_idx0 <- .resolve_idx0_mget(cg@name_index_map, Z, Z_index)

  m_separated_ptr(cg@ptr, X_idx0, Y_idx0, Z_idx0)
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Subgraph ───────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Get the induced subgraph
#'
#' @param cg A `caugi` object.
#' @param nodes A vector of node names, a vector of unquoted
#' node names, or an expression combining these with `+` and `c()`.
#' @param index A vector of node indexes.
#'
#' @returns A new `caugi` that is a subgraph of the selected nodes.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   class = "DAG"
#' )
#' sub_cg <- subgraph(cg, c("B", "C"))
#' cg2 <- caugi(B %-->% C, class = "DAG")
#' all(nodes(sub_cg) == nodes(cg2)) # TRUE
#' all(edges(sub_cg) == edges(cg2)) # TRUE
#'
#' @family queries
#' @concept queries
#'
#' @export
subgraph <- function(cg, nodes = NULL, index = NULL) {
  is_caugi(cg, throw_error = TRUE)
  cg <- build(cg)

  nodes_supplied <- !missing(nodes) && !is.null(nodes)
  index_supplied <- !missing(index) && !is.null(index)

  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  if (!nodes_supplied && !index_supplied) {
    stop("Supply one of `nodes` or `index`.", call. = FALSE)
  }

  if (index_supplied) {
    if (!is.numeric(index) || anyNA(index)) {
      stop("`index` must be numeric without NA.", call. = FALSE)
    }
    idx1 <- as.integer(index)
    n <- nrow(cg@nodes)
    if (any(idx1 < 1L) || any(idx1 > n)) {
      stop("`index` out of range (1..n).", call. = FALSE)
    }
    keep_idx0 <- idx1 - 1L
    keep_names <- cg@nodes$name[idx1]
  } else {
    if (!is.character(nodes)) {
      stop("`nodes` must be a character vector.", call. = FALSE)
    }
    if (anyNA(nodes)) {
      stop("`nodes` contains NA.", call. = FALSE)
    }
    pos <- match(nodes, cg@nodes$name)
    if (anyNA(pos)) {
      miss <- nodes[is.na(pos)]
      stop(
        "Unknown node(s): ",
        paste(unique(miss), collapse = ", "),
        call. = FALSE
      )
    }
    keep_names <- nodes
    keep_idx0 <- pos - 1L
  }

  if (anyDuplicated(keep_idx0)) {
    dpos <- duplicated(keep_idx0) | duplicated(keep_idx0, fromLast = TRUE)
    stop(
      "`nodes`/`index` contains duplicates: ",
      paste(unique(keep_names[dpos]), collapse = ", "),
      call. = FALSE
    )
  }

  ptr_sub <- induced_subgraph_ptr(cg@ptr, as.integer(keep_idx0))

  nodes_sub <- .node_constructor(names = keep_names)

  if (nrow(cg@edges)) {
    dt <- data.table::as.data.table(cg@edges)

    sel_from <- !is.na(data.table::chmatch(dt[["from"]], keep_names))
    sel_to <- !is.na(data.table::chmatch(dt[["to"]], keep_names))
    sel <- sel_from & sel_to

    if (any(sel)) {
      dt <- dt[which(sel), ] # force row-subset even if class slips
      data.table::setorder(dt, from, to, edge)
    } else {
      dt <- dt[0L, ] # empty, preserve columns
    }
    edges_sub <- dt
  } else {
    edges_sub <- cg@edges
  }

  name_index_map_sub <- fastmap::fastmap()
  do.call(
    name_index_map_sub$mset,
    .set_names(as.list(seq_len(nrow(nodes_sub)) - 1L), nodes_sub$name)
  )

  state_sub <- .cg_state(
    nodes = nodes_sub,
    edges = edges_sub,
    ptr = ptr_sub,
    built = TRUE,
    simple = cg@simple,
    class = cg@graph_class,
    name_index_map = name_index_map_sub
  )
  caugi(state = state_sub)
}

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── Relations helpers ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Output object of getter queries
#'
#' @description Helper to format the output of getter queries.
#'
#' @param cg A `caugi` object.
#' @param idx0 A vector of zero-based node indices.
#' @param nodes A vector of node names.
#'
#' @returns A list of character vectors, each a set of node names.
#' If only one node is requested, returns a character vector.
#'
#' @keywords internal
.getter_output <- function(cg, idx0, nodes) {
  nm <- cg@nodes$name
  to_names <- function(ix0) {
    if (length(ix0) == 0L) {
      return(NULL)
    }
    nm[ix0 + 1L]
  }

  # faster check than doing is.null and length == 1, since length(NULL) == 0
  if (length(nodes) <= 1L && length(idx0) == 1L) {
    ix <- idx0[[1L]]
    return(to_names(ix))
  }

  out <- lapply(idx0, to_names)
  names(out) <- nodes
  out
}
