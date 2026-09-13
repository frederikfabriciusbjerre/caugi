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
#' Logically, it should not be possible to have a graph class of "DAG", "PDAG",
#' "MPDAG", or "CPDAG"
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

  if (force_check) {
    is_it <- rs_is_acyclic(cg@session)
  } else if (
    identical(cg@graph_class, "DAG") ||
      identical(cg@graph_class, "PDAG") ||
      identical(cg@graph_class, "MPDAG") ||
      identical(cg@graph_class, "CPDAG")
  ) {
    is_it <- TRUE
  } else {
    is_it <- rs_is_acyclic(cg@session)
  }
  is_it
}

#' @title Is the `caugi` graph simple?
#'
#' @description Checks if the given `caugi` graph is simple (no self-loops and
#' no parallel edges).
#'
#' @param cg A `caugi` object.
#' @param force_check Logical; if `TRUE`, force a check against the compiled
#' graph representation. If `FALSE` (default), return the declared `simple`
#' property.
#'
#' @returns A logical value indicating whether the graph is simple.
#'
#' @examples
#' cg_simple <- caugi(
#'   A %-->% B,
#'   class = "DAG"
#' )
#' is_simple(cg_simple) # TRUE
#'
#' cg_nonsimple <- caugi(
#'   A %-->% B,
#'   A %<->% B,
#'   class = "UNKNOWN",
#'   simple = FALSE
#' )
#' is_simple(cg_nonsimple) # FALSE
#'
#' @family queries
#' @concept queries
#'
#' @export
is_simple <- function(cg, force_check = FALSE) {
  is_caugi(cg, throw_error = TRUE)

  if (force_check) {
    return(rs_is_simple(cg@session))
  }

  cg@simple
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

  if (identical(cg@graph_class, "DAG") && !force_check) {
    is_it <- TRUE
  } else {
    # if we can't be sure from the class, we check
    is_it <- rs_is_dag_type(cg@session)
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

  if (cg@graph_class %in% c("PDAG", "MPDAG", "CPDAG") && !force_check) {
    is_it <- TRUE
  } else {
    # if we can't be sure from the class, we check
    is_it <- rs_is_pdag_type(cg@session)
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
#' @references
#' C. Meek (1995). Causal inference and causal explanation with background
#' knowledge. In \emph{Proceedings of the Eleventh Conference on Uncertainty in
#' Artificial Intelligence (UAI-95)}, pp. 403--411. Morgan Kaufmann.
#'
#' @family queries
#' @concept queries
#'
#' @export
is_cpdag <- function(cg) {
  is_caugi(cg, throw_error = TRUE)

  # The "CPDAG" class label is only assigned after Rust validates the full
  # CPDAG invariant at construction, so it is authoritative.
  if (identical(cg@graph_class, "CPDAG")) {
    return(TRUE)
  }
  is_it <- rs_is_cpdag(cg@session)
  is_it
}

#' @title Is the `caugi` graph an MPDAG?
#'
#' @description Checks if the given `caugi` graph is a
#' Maximally oriented Partially Directed Acyclic Graph
#' (MPDAG), i.e. a PDAG where no additional edge orientations
#' are implied by Meek's rules (R1--R4).
#'
#' @details
#' If the graph is not PDAG-compatible, the function returns `FALSE`.
#'
#' @param cg A `caugi` object.
#'
#' @returns A logical value indicating whether the graph is an MPDAG.
#'
#' @examples
#' cg_not_mpdag <- caugi(
#'   A %---% B,
#'   A %-->% C,
#'   C %-->% B,
#'   class = "PDAG"
#' )
#' is_mpdag(cg_not_mpdag) # FALSE
#'
#' @references
#' C. Meek (1995). Causal inference and causal explanation with background
#' knowledge. In \emph{Proceedings of the Eleventh Conference on Uncertainty in
#' Artificial Intelligence (UAI-95)}, pp. 403--411. Morgan Kaufmann.
#'
#' @family queries
#' @concept queries
#'
#' @export
is_mpdag <- function(cg) {
  is_caugi(cg, throw_error = TRUE)

  # Every CPDAG is an MPDAG, and both class labels are validated at
  # construction, so they are authoritative.
  if (cg@graph_class %in% c("MPDAG", "CPDAG")) {
    return(TRUE)
  }
  rs_is_mpdag(cg@session)
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

  if (identical(cg@graph_class, "UG") && !force_check) {
    is_it <- TRUE
  } else {
    # if we can't be sure from the class, we check
    is_it <- rs_is_ug_type(cg@session)
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

  if (identical(cg@graph_class, "ADMG") && !force_check) {
    is_it <- TRUE
  } else {
    # if we can't be sure from the class, we check
    is_it <- rs_is_admg_type(cg@session)
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

  if (identical(cg@graph_class, "AG") && !force_check) {
    is_it <- TRUE
  } else {
    # if we can't be sure from the class, we check
    is_it <- rs_is_ag_type(cg@session)
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

  if (identical(cg@graph_class, "MAG") && !force_check) {
    is_it <- TRUE
  } else {
    is_it <- rs_is_mag(cg@session)
  }
  is_it
}

#' @title Is the `caugi` graph a PAG?
#'
#' @description
#' Checks whether the given graph is a Partial Ancestral Graph, i.e. whether
#' there exists a maximal ancestral graph `M` whose Markov equivalence class
#' this graph represents.
#'
#' @details
#' This is a *complete* check, in four stages:
#'
#' 1. every endpoint mark is an arrowhead, a tail or a circle, on a simple
#'    graph with no self-loops;
#' 2. the definite directed part is acyclic, no undirected endpoint carries an
#'    arrowhead, and every definite arrowhead respects the anterior
#'    constraint;
#' 3. [pag_to_mag()] yields a graph that really is a maximal ancestral graph;
#' 4. [mag_to_pag()] maps that MAG back to exactly this graph.
#'
#' Stage 4 is what makes the check complete. Stages 1-3 are all necessary but
#' none of them can see whether the *circles* are in the right places, so
#' without it both an over-oriented graph (a definite mark that is not in fact
#' invariant across the class) and an under-oriented one (a circle where an
#' invariant mark belongs) would pass.
#'
#' All four stages run when a `class = "PAG"` graph is constructed, so this
#' function simply attempts that construction. There is no `force_check`
#' argument: a graph already carrying the class has been verified, and one that
#' does not is checked in full.
#'
#' Stage 3 tests maximality, which is exhaustive and exponential in the worst
#' case, the same cost as [is_mag()].
#'
#' @param cg A `caugi` object.
#'
#' @returns A logical value indicating whether the graph is a PAG.
#'
#' @examples
#' # The PAG of a MAG is a PAG, by construction.
#' is_pag(mag_to_pag(caugi(A %-->% B, C %-->% B, class = "AG"))) # TRUE
#'
#' # A graph that is not a PAG cannot carry the class at all, so to ask about
#' # one you have to hold it as `"UNKNOWN"`. This one is over-oriented: with A
#' # and C non-adjacent, whether B is a collider would differ between members,
#' # so those marks are not invariant.
#' is_pag(caugi(A %o->% B, B %o-o% C, class = "UNKNOWN")) # FALSE
#'
#' # Trying to build it as a PAG is an error rather than a FALSE.
#' try(caugi(A %o->% B, B %o-o% C, class = "PAG"))
#'
#' @family queries
#' @concept queries
#'
#' @export
is_pag <- function(cg) {
  is_caugi(cg, throw_error = TRUE)

  # Constructing a `"PAG"` runs the complete check, so the class is a
  # guarantee and can be trusted here.
  if (identical(cg@graph_class, "PAG")) {
    return(TRUE)
  }

  ok <- tryCatch(
    {
      caugi(
        nodes = nodes(cg)$name,
        edges_df = edges(cg),
        class = "PAG",
        simple = TRUE
      )
      TRUE
    },
    error = function(cnd) FALSE
  )
  ok
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
#' @param nodes A character vector of node names.
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
# Implemented directly in Rust via `parents()` in `src/rust/src/lib.rs`.
parents <- parents
formals(parents) <- alist(cg = , nodes = NULL, index = NULL)

#' @title Get children of nodes in a `caugi`
#'
#' @description
#' Get children of nodes in a graph (nodes with directed edges pointing OUT
#' from the target nodes).
#' This is equivalent to `neighbors(cg, nodes, mode = "out")`.
#'
#' @inheritParams parents
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
# Implemented directly in Rust via `children()` in `src/rust/src/lib.rs`.
children <- children
formals(children) <- alist(cg = , nodes = NULL, index = NULL)

#' @title Get neighbors of nodes in a `caugi`
#'
#' @description
#' Get neighbors of a node in the graph, optionally filtered by edge direction
#' or type. This function works for all graph classes including `UNKNOWN`.
#'
#' @inheritParams parents
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
# Implemented directly in Rust via `neighbors()` in `src/rust/src/lib.rs`.
neighbors <- neighbors
formals(neighbors) <- alist(cg = , nodes = NULL, index = NULL, mode = "all")

#' @rdname neighbors
#' @export
neighbours <- neighbors

#' @title Get ancestors of nodes in a `caugi`
#'
#' @inheritParams parents
#' @param open Boolean. Determines how the graph is interpreted when retrieving ancestors.
#'   Default is taken from `caugi_options("use_open_graph_definition")`,
#'   which by default is `r caugi_options("use_open_graph_definition")`.
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
#' ancestors(cg, "A", open = FALSE) # A
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
# Implemented directly in Rust via `ancestors()` in `src/rust/src/lib.rs`.
ancestors <- ancestors
formals(ancestors) <- alist(
  cg = ,
  nodes = NULL,
  index = NULL,
  open = caugi_options("use_open_graph_definition")
)

#' @title Is a directed edge in a PAG visible?
#'
#' @description
#' A directed edge `from --> to` in a PAG is *visible* when every MAG in the
#' represented Markov equivalence class rules out an inducing path between the
#' two nodes that is into `from`. Visibility is what licenses reading the edge
#' as an unconfounded direct effect, and it is the ingredient the generalized
#' adjustment criterion needs for amenability.
#'
#' @details
#' The graphical criterion is Zhang (2008, Def. 8), equivalently Maathuis and
#' Colombo (2015, Def. 3.1): `from --> to` is visible if and only if there is a
#' node `c` **not** adjacent to `to` such that either
#'
#' * there is an edge between `c` and `from` with an arrowhead at `from`, or
#' * there is a collider path between `c` and `from` with an arrowhead at
#'   `from`, every non-endpoint of which is a parent of `to`.
#'
#' Otherwise the edge is invisible. Only `-->` edges can be visible: `FALSE` is
#' returned for any other edge type, for a non-adjacent pair, and for the
#' reverse orientation of a directed edge.
#'
#' Defined for both MAGs (`"AG"`) and PAGs, by the same criterion. Visibility
#' is not about circle marks: a directed edge in a MAG can perfectly well be
#' invisible, which is exactly what makes the notion useful there -- an
#' invisible `A --> B` means some member of the represented DAG class has a
#' latent path into `A`, so the edge cannot simply be cut.
#'
#' @param cg A `caugi` object of class `"AG"` or `"PAG"`.
#' @param from,to Node names, or `NULL`. Use `from_index`/`to_index` to pass
#'   1-based indices instead.
#' @param from_index,to_index Optional numeric 1-based indices (exclusive with
#'   `from`, `to` respectively).
#'
#' @returns A logical value; `TRUE` if the edge `from --> to` is visible.
#'
#' @examples
#' # The `pcalg::visibleEdge` documentation fixture, which is a MAG rather than
#' # a PAG: `a --> b`, `b <-> c`, `b --> d`, `c --> d`.
#' mag <- caugi(
#'   A %-->% B,
#'   B %<->% C,
#'   B %-->% D,
#'   C %-->% D,
#'   class = "AG"
#' )
#' # Every other node is adjacent to B, so there is no witness.
#' is_visible_edge(mag, "A", "B") # FALSE
#' # A is not adjacent to D and `A --> B` is into B.
#' is_visible_edge(mag, "B", "D") # TRUE
#' # The collider path `A --> B <-> C` is into C and its only non-endpoint, B,
#' # is a parent of D.
#' is_visible_edge(mag, "C", "D") # TRUE
#'
#' # A valid PAG carrying both a visible and an invisible directed edge.
#' cg <- caugi(
#'   A %-->% B,
#'   C %o->% A,
#'   D %o->% A,
#'   C %-->% B,
#'   class = "PAG"
#' )
#'
#' # `A --> B` is visible: D has an arrowhead into A and is not adjacent to B,
#' # which is the witness condition (a).
#' is_visible_edge(cg, "A", "B") # TRUE
#'
#' # `C --> B` is invisible: every node with an arrowhead into C, and every
#' # collider path into it, fails the condition.
#' is_visible_edge(cg, "C", "B") # FALSE
#'
#' # Only `-->` edges can be visible.
#' is_visible_edge(cg, "C", "A") # FALSE, that edge is `o->`
#'
#' @references
#' Zhang, J. (2008). Causal reasoning with ancestral graphs.
#' *Journal of Machine Learning Research*, 9, 1437-1474.
#'
#' Maathuis, M. H. and Colombo, D. (2015). A generalized back-door criterion.
#' *The Annals of Statistics*, 43(3), 1060-1088.
#'
#' @family queries
#' @concept queries
#'
#' @export
is_visible_edge <- function(
  cg,
  from = NULL,
  to = NULL,
  from_index = NULL,
  to_index = NULL
) {
  is_caugi(cg, throw_error = TRUE)

  from_idx0 <- .resolve_idx0_mget(cg@session, from, from_index)
  to_idx0 <- .resolve_idx0_mget(cg@session, to, to_index)

  if (length(from_idx0) != 1L || length(to_idx0) != 1L) {
    stop("`from` and `to` must each name exactly one node.", call. = FALSE)
  }

  rs_is_visible_edge(cg@session, from_idx0, to_idx0)
}

#' @title Get descendants of nodes in a `caugi`
#'
#' @inheritParams parents
#' @param open Boolean. Determines how the graph is interpreted when retrieving descendants.
#'   Default is taken from `caugi_options("use_open_graph_definition")`,
#'   which by default is `r caugi_options("use_open_graph_definition")`.
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
#' descendants(cg, "A", open = FALSE) # "A" "B" "C"
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
# Implemented directly in Rust via `descendants()` in `src/rust/src/lib.rs`.
descendants <- descendants
formals(descendants) <- alist(
  cg = ,
  nodes = NULL,
  index = NULL,
  open = caugi_options("use_open_graph_definition")
)

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
#' @inheritParams parents
#' @param cg A `caugi` object of class DAG or PDAG.
#' @param open Boolean. Determines how the graph is interpreted when retrieving anteriors.
#'   Default is taken from `caugi_options("use_open_graph_definition")`,
#'   which by default is `r caugi_options("use_open_graph_definition")`.
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
#' anteriors(cg, "A", open = FALSE) # A
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
# Implemented directly in Rust via `anteriors()` in `src/rust/src/lib.rs`.
anteriors <- anteriors
formals(anteriors) <- alist(
  cg = ,
  nodes = NULL,
  index = NULL,
  open = caugi_options("use_open_graph_definition")
)

#' @title Get posteriors of nodes in a `caugi`
#'
#' @description
#' Get the posterior set of nodes in a graph. The posterior set (dual of the
#' anterior set from Richardson and Spirtes, 2002) includes all nodes reachable
#' by following paths where every edge is either undirected or directed away from
#' the source node.
#'
#' For DAGs, the posterior set equals the descendant set (since there are no
#' undirected edges). For PDAGs, it includes both descendants and nodes reachable
#' via undirected edges.
#'
#' @inheritParams parents
#' @param cg A `caugi` object of class DAG, PDAG, or AG.
#' @param open Boolean. Determines how the graph is interpreted when retrieving posteriors.
#'   Default is taken from `caugi_options("use_open_graph_definition")`,
#'   which by default is `r caugi_options("use_open_graph_definition")`.
#'
#' @returns Either a character vector of node names (if a single node is
#'   requested) or a list of character vectors (if multiple nodes are requested).
#'
#' @examples
#' # PDAG example with directed and undirected edges
#' cg <- caugi(
#'   A %-->% B %---% C,
#'   B %-->% D,
#'   class = "PDAG"
#' )
#'
#' posteriors(cg, "A") # B, C, D
#' posteriors(cg, "A", open = FALSE) # A, B, C, D
#' posteriors(cg, "B") # C, D
#' posteriors(cg, "D") # NULL (no posteriors)
#'
#' # For DAGs, posteriors equals descendants
#' cg_dag <- caugi(
#'   A %-->% B %-->% C,
#'   class = "DAG"
#' )
#' posteriors(cg_dag, "A") # B, C
#'
#' @family queries
#' @concept queries
#'
#' @export
# Implemented directly in Rust via `posteriors()` in `src/rust/src/lib.rs`.
posteriors <- posteriors
formals(posteriors) <- alist(
  cg = ,
  nodes = NULL,
  index = NULL,
  open = caugi_options("use_open_graph_definition")
)

#' @title Get Markov blanket of nodes in a `caugi`
#'
#' @inheritParams parents
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
# Implemented directly in Rust via `markov_blanket()` in `src/rust/src/lib.rs`.
markov_blanket <- markov_blanket
formals(markov_blanket) <- alist(cg = , nodes = NULL, index = NULL)

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
# Implemented directly in Rust via `exogenous()` in `src/rust/src/lib.rs`.
exogenous <- exogenous
formals(exogenous) <- alist(cg = , undirected_as_parents = FALSE)

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
# Implemented directly in Rust via `topological_sort()` in `src/rust/src/lib.rs`.
topological_sort <- topological_sort

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────── ADMG-specific queries ────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Get spouses (bidirected neighbors) of nodes in an ADMG
#'
#' @description Get nodes connected via bidirected edges in an ADMG.
#'
#' @inheritParams parents
#' @param cg A `caugi` object of class ADMG.
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
# Implemented directly in Rust via `spouses()` in `src/rust/src/lib.rs`.
spouses <- spouses
formals(spouses) <- alist(cg = , nodes = NULL, index = NULL)

#' @title Get districts (c-components) of an ADMG or AG
#'
#' @description Get districts (c-components) for all nodes, or for selected
#' nodes in an ADMG/AG. A district is a maximal set of nodes connected via
#' bidirected edges. If both `nodes` and `index` are `NULL`, returns all districts in the graph.
#'
#' @param cg A `caugi` object of class ADMG or AG.
#' @param nodes Optional character vector of node names. If supplied, returns
#' district(s) containing these nodes.
#' @param index Optional numeric vector of 1-based node indices. If supplied,
#' returns district(s) containing these indices.
#' @param all DEPRECATED (If `TRUE`, return all districts explicitly.
#' Cannot be combined with `nodes` or `index`.)
#'
#' @returns If all districts are requested: a list of character vectors, one per
#' district. If `nodes`/`index` are supplied: either a character vector (single
#' target) or a named list of character vectors (multiple targets).
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
#' districts(cg, nodes = "A") # Returns c("A", "C")
#' districts(cg, index = c(1, 4))
#'
#' @family queries
#' @concept queries
#'
#' @export
# Implemented directly in Rust via `districts()` in `src/rust/src/lib.rs`,
# with deprecation-warning compatibility handled in R.
districts <- function(cg, nodes = NULL, index = NULL, all = NULL) {
  if (!missing(all)) {
    warning(
      "`all` argument is deprecated and will be removed in a future version. ",
      "To get all districts, simply call `districts(cg)` without `nodes` or `index`.",
      call. = FALSE
    )
  }

  .Call(wrap__districts, cg, nodes, index, all)
}

#' @title M-separation test for AGs and ADMGs
#'
#' @description Test whether two sets of nodes are m-separated given a
#' conditioning set in an ancestral graph (AG) or an ADMG.
#'
#' M-separation generalizes d-separation to AGs/ADMGs and applies to DAGs.
#'
#' @param cg A `caugi` object of class AG, ADMG, or DAG.
#' @param X,Y,Z Character vectors of node names, or `NULL`. Use `*_index` to
#'   pass 1-based indices. If `Z` is `NULL` or missing, no nodes are conditioned
#'   on.
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

  X_idx0 <- .resolve_idx0_mget(cg@session, X, X_index)
  Y_idx0 <- .resolve_idx0_mget(cg@session, Y, Y_index)
  Z_idx0 <- .resolve_idx0_mget(cg@session, Z, Z_index)

  rs_m_separated(cg@session, X_idx0, Y_idx0, Z_idx0)
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Subgraph ───────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Get the induced subgraph
#'
#' @inheritParams parents
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
# Implemented directly in Rust via `subgraph()` in `src/rust/src/lib.rs`.
subgraph <- subgraph
formals(subgraph) <- alist(cg = , nodes = NULL, index = NULL)
