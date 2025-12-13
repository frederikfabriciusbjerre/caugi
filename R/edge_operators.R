# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Infix operators ────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Edge specification infix operators
#'
#' @description These infix operators are used to specify edges in
#' `caugi()`. This function helps build infix operators.
#'
#' @param from_sym A symbol representing the source node.
#' @param to_expr An expression representing the target node(s).
#' Can be a symbol, string, number, `c(...)`, or a combination using `+`.
#' @param glyph A string representing the edge glyph (e.g., `"-->"`, `"<->"`).
#'
#' @returns A `data.table` with columns `from`, `to`, and `edge`.
#'
#' @keywords internal
.edge_spec <- function(from_sym, to_expr, glyph) {
  from <- deparse1(from_sym)
  to <- .expand_targets(to_expr)
  .edge_constructor(from = from, edge = glyph, to = to)
}

#' @title Helper to expand the right-hand side of an edge specification
#'
#' @description This function expands the right-hand side of an edge
#' specification into a character vector of target node names. It handles
#' various forms of input, including symbols, calls with `+`, calls with `c()`,
#' and character literals.
#'
#' @param expr An expression representing the target node(s).
#'
#' @returns A character vector of target node names.
#'
#' @keywords internal
.expand_targets <- function(expr) {
  # unwrap parentheses: ( ... )
  if (is.call(expr) && identical(expr[[1L]], as.name("("))) {
    return(.expand_targets(expr[[2L]]))
  }
  if (is.symbol(expr)) {
    return(deparse1(expr))
  }
  if (is.call(expr) && identical(expr[[1L]], as.name("+"))) {
    return(c(.expand_targets(expr[[2L]]), .expand_targets(expr[[3L]])))
  }
  if (is.call(expr) && identical(expr[[1L]], as.name("c"))) {
    args <- as.list(expr)[-1L]
    return(unlist(lapply(args, .expand_targets), use.names = FALSE))
  }
  if (is.character(expr) && length(expr) == 1L) {
    return(expr)
  }
  if (is.numeric(expr) && length(expr) == 1L) {
    return(as.character(expr))
  }
  stop(
    "Unsupported right-hand side in edge operator: ",
    deparse(expr),
    call. = FALSE
  )
}


#' @title Infix operators for edge specifications
#'
#' @description These operators are used to specify edges in `caugi()`.
#' Should be used internally in `caugi()` calls.
#'
#' @param lhs The left-hand side node expression.
#' @param rhs The right-hand side node expression.
#'
#' @returns A `data.table` with columns `from`, `to`, and `edge`.
#'
#' @name edge_operators
#'
#' @keywords internal
`%-->%` <- function(lhs, rhs) {
  .edge_spec(substitute(lhs), substitute(rhs), "-->")
}

#' @rdname edge_operators
#' @keywords internal
`%---%` <- function(lhs, rhs) {
  .edge_spec(substitute(lhs), substitute(rhs), "---")
}


#' @rdname edge_operators
#' @keywords internal
`%<->%` <- function(lhs, rhs) {
  .edge_spec(substitute(lhs), substitute(rhs), "<->")
}

#' @rdname edge_operators
#' @keywords internal
`%o-o%` <- function(lhs, rhs) {
  .edge_spec(substitute(lhs), substitute(rhs), "o-o")
}

#' @rdname edge_operators
#' @keywords internal
`%--o%` <- function(lhs, rhs) {
  .edge_spec(substitute(lhs), substitute(rhs), "--o")
}

#' @rdname edge_operators
#' @keywords internal
`%o->%` <- function(lhs, rhs) {
  .edge_spec(substitute(lhs), substitute(rhs), "o->")
}
