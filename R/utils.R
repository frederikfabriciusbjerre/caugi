# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── Utility functions ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Set names to an object
#'
#' @description
#' Only made to avoid using `stats::setNames`.
#'
#' @param object An R object to which names are to be assigned.
#' @param nm A character vector of names to assign to the object.
#'
#' @returns The input object with the assigned names.
#'
#' @keywords internal
.set_names <- function(object = nm, nm) {
  names(object) <- nm
  object
}

#' @title Validate nodes or index argument
#'
#' @description
#' Check that either nodes or index is supplied, but not both.
#'
#' @param nodes_missing Logical; result of `missing(nodes)`.
#' @param index An index argument.
#' @param index_missing Logical; result of `missing(index)`.
#'
#' @returns A list with `nodes_supplied` and `index_supplied` logical values.
#'
#' @keywords internal
.validate_nodes_or_index <- function(nodes_missing, index, index_missing) {
  nodes_supplied <- !nodes_missing
  index_supplied <- !index_missing && !is.null(index)
  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }
  list(nodes_supplied = nodes_supplied, index_supplied = index_supplied)
}

#' @title Convert node names to 0-based indices
#'
#' @description
#' Convert node names to 0-based indices using the Rust session's name lookup.
#'
#' @param cg A `caugi` object.
#' @param nodes A character vector of node names.
#'
#' @returns An integer vector of 0-based indices.
#'
#' @keywords internal
.nodes_to_indices <- function(cg, nodes) {
  if (is.null(cg@session)) {
    stop("Cannot look up indices for empty graph.", call. = FALSE)
  }
  rs_indices_of(cg@session, nodes)
}
