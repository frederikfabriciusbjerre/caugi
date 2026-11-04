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
#' Validate that either `nodes` or `index` is supplied (but not both) and that
#' they are of the correct type (non-NA character vector for `nodes`, non-NA
#' numeric vector for `index`).
#'
#' @param nodes A character vector of node names. If supplied, must be non-NA character vector.
#' @param index A numeric vector of node indices. If supplied, must be non-NA numeric vector.
#'
#' @returns A list with `nodes_supplied` and `index_supplied` logical values.
#'
#' @keywords internal
.validate_nodes_and_index <- function(nodes = NULL, index = NULL) {
  nodes_supplied <- !is.null(nodes)
  index_supplied <- !is.null(index)

  if (nodes_supplied && index_supplied) {
    stop("Supply either `nodes` or `index`, not both.", call. = FALSE)
  }

  if (!nodes_supplied && !index_supplied) {
    stop("Must supply either `nodes` or `index`.", call. = FALSE)
  }

  if (nodes_supplied) {
    if (!is.character(nodes)) {
      stop(
        "`nodes` must be a character vector of node names.",
        call. = FALSE
      )
    }

    if (anyNA(nodes)) {
      stop(
        "`nodes` cannot contain NA values.",
        call. = FALSE
      )
    }
  }

  if (index_supplied) {
    if (!is.numeric(index)) {
      stop("`index` must be numeric.", call. = FALSE)
    }

    if (anyNA(index)) {
      stop(
        "`index` cannot contain NA values.",
        call. = FALSE
      )
    }
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

#' Error on named arguments in `...`, which takes only edges and nodes, so a
#' misspelt or removed argument (such as `simple`) is not read as a node.
#' @keywords internal
#' @noRd
.stop_if_named_dots <- function(calls, fn) {
  nm <- names(calls)[nzchar(names(calls))]
  if (length(nm) > 0L) {
    stop(
      "`",
      fn,
      "()` has no argument ",
      paste0("`", nm, "`", collapse = ", "),
      ".",
      call. = FALSE
    )
  }
}
