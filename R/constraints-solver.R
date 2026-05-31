# ──────────────────────────────────────────────────────────────────────────────
# ──────────────── caugi_constraints — solver-backed operations ────────────────
# ──────────────────────────────────────────────────────────────────────────────
#
# `consistent(ctr, nodes)` and `enumerate(ctr, nodes, limit)` are
# powered by the Rust-side splr backend. Both take an explicit node
# set because constraints can reference nodes that need not all appear
# in any particular `caugi`.
#
# v1 supports the DAG class only. Tier-A edge atoms, tier-B ancestor /
# descendant atoms, cardinality, quantifiers, and boolean structure
# all work; tier-C atoms (`dsep`) are evaluator-only and rejected here.

#' Supported graph classes for the constraint solver.
.solver_supported_classes <- function() c("DAG", "UG", "PDAG", "ADMG")

#' Check whether a constraint set is satisfiable by some graph of the
#' chosen class.
#'
#' @description
#' Returns `TRUE` if there exists a graph of class `class` over `nodes`
#' that satisfies every formula in `ctr`, `FALSE` otherwise. Powered
#' by splr behind the scenes.
#'
#' Supported atom surface depends on the class:
#' \itemize{
#'   \item `"DAG"`: `-->` edges only; `parents`, `children`,
#'     `neighbors`, `ancestors`, `descendants`.
#'   \item `"UG"`: `---` edges only; `neighbors`.
#'   \item `"PDAG"`: `-->` and `---` edges; `parents`, `children`,
#'     `neighbors`, `ancestors`, `descendants`.
#'   \item `"ADMG"`: `-->` and `<->` edges; `parents`, `children`,
#'     `spouses`, `neighbors`, `ancestors`, `descendants`.
#' }
#' Common to all: `acyclic()`, `collider()`, `v_structure()`,
#' cardinality, quantifiers, boolean combinators. Tier-C atoms
#' (`dsep`) are evaluator-only.
#'
#' @param ctr A `caugi_constraints` object.
#' @param nodes Character vector of node names.
#' @param class One of `"DAG"`, `"UG"`, `"PDAG"`, `"ADMG"`. Defaults
#'   to `"DAG"`.
#'
#' @returns `TRUE` if `ctr` is satisfiable over `nodes`, `FALSE`
#'   otherwise.
#'
#' @examples
#' ctr <- caugi_constraints(A %-->% B, !(B %-->% A))
#' consistent(ctr, nodes = c("A", "B"))
#' consistent(
#'   caugi_constraints(A %---% B),
#'   nodes = c("A", "B"),
#'   class = "UG"
#' )
#'
#' @family constraints
#' @concept constraints
#' @export
consistent <- function(ctr, nodes, class = "DAG") {
  .check_solver_inputs(ctr, nodes, class)
  rs_constraints_consistent(ctr@formulas, nodes, class)
}

#' Enumerate graphs satisfying a constraint set.
#'
#' @description
#' Returns up to `limit` distinct graphs of the chosen class over
#' `nodes` that satisfy every formula in `ctr`. Each result is a
#' `caugi` object. With no constraints and `class = "DAG"`,
#' `enumerate()` produces all unique DAGs on `nodes` (the Robinson
#' sequence: 1, 3, 25, 543, … for n = 1, 2, 3, 4, …).
#'
#' @param ctr A `caugi_constraints` object.
#' @param nodes Character vector of node names.
#' @param class One of `"DAG"`, `"UG"`, `"PDAG"`, `"ADMG"`. Defaults
#'   to `"DAG"`.
#' @param limit Integer; maximum number of graphs to return. Defaults
#'   to `100`.
#'
#' @returns A list of `caugi` objects (each carrying the requested
#'   `class`).
#'
#' @examples
#' # All DAGs on 3 nodes — 25.
#' length(enumerate(caugi_constraints(), c("A", "B", "C"), limit = 200))
#'
#' # All UGs on 3 nodes — 2^3 = 8 (one var per unordered pair).
#' length(enumerate(caugi_constraints(), c("A", "B", "C"),
#'                  class = "UG", limit = 50))
#'
#' @family constraints
#' @concept constraints
#' @export
enumerate <- function(ctr, nodes, class = "DAG", limit = 100L) {
  .check_solver_inputs(ctr, nodes, class)
  if (!is.numeric(limit) || length(limit) != 1L || !is.finite(limit) || limit < 0) {
    stop("`limit` must be a non-negative integer.", call. = FALSE)
  }
  edge_frames <- rs_constraints_enumerate(
    ctr@formulas,
    nodes,
    class,
    as.integer(limit)
  )
  lapply(edge_frames, function(edf) {
    if (nrow(edf) == 0L) {
      caugi(nodes = nodes, class = class)
    } else {
      caugi(edges_df = edf, nodes = nodes, class = class)
    }
  })
}

#' @keywords internal
#' @noRd
.check_solver_inputs <- function(ctr, nodes, class) {
  if (!S7::S7_inherits(ctr, caugi_constraints_class)) {
    stop("`ctr` must be a `caugi_constraints` object.", call. = FALSE)
  }
  if (!is.character(nodes) || any(is.na(nodes)) || length(nodes) == 0L) {
    stop("`nodes` must be a non-empty character vector of node names.", call. = FALSE)
  }
  if (anyDuplicated(nodes) > 0L) {
    stop("`nodes` must contain unique names.", call. = FALSE)
  }
  supported <- .solver_supported_classes()
  if (!is.character(class) || length(class) != 1L || !(class %in% supported)) {
    stop(
      "`class` must be one of: ",
      paste(supported, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  invisible(NULL)
}
