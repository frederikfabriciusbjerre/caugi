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

#' Error when `x` has an edge glyph that is not built in. The exporters only
#' know the built-in glyphs, so they would write a custom one reversed or drop
#' it.
#' @keywords internal
#' @noRd
.stop_if_custom_glyphs <- function(x, fn) {
  custom <- setdiff(edge_types(x), .caugi_defaults_glyph_map)
  if (length(custom) > 0L) {
    stop(
      "`",
      fn,
      "` only converts built-in edges, not ",
      paste0("`", custom, "`", collapse = ", "),
      ".",
      call. = FALSE
    )
  }
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

# nocov start
#' @title Call a function whose arguments were renamed
#'
#' @description Re-matches the caller's call as the old signature did, so
#' positional arguments keep their old meaning, renames the old arguments
#' with a deprecation warning, and evaluates the call again.
#'
#' @param fn Function name, without `()`.
#' @param old_formals The old formal arguments, in order.
#' @param renamed Named character vector mapping old to new names.
#'
#' @returns The result of calling `fn` with the new names.
#'
#' @keywords internal
#' @noRd
.call_renamed <- function(fn, old_formals, renamed) {
  def <- function() NULL
  all <- c(old_formals, unname(renamed))
  formals(def) <- stats::setNames(rep(list(quote(expr = )), length(all)), all)
  call <- match.call(def, sys.call(-1L), envir = parent.frame(2L))
  for (old in intersect(names(renamed), names(call))) {
    .warn_renamed_arg(fn, old, renamed[[old]])
    names(call)[names(call) == old] <- renamed[[old]]
  }
  call[[1L]] <- get(fn, envir = asNamespace("caugi"))
  eval(call, parent.frame(2L))
}

#' @title Warn that an argument was renamed
#'
#' @param fn Function name, without `()`.
#' @param old,new Old and new argument names.
#'
#' @keywords internal
#' @noRd
.warn_renamed_arg <- function(fn, old, new) {
  warning(
    sprintf(
      "The `%s` argument of `%s()` is deprecated and will be removed in caugi 2.0.0. Use `%s` instead.",
      old,
      fn,
      new
    ),
    call. = FALSE
  )
}

#' @title Warn that a function is deprecated
#'
#' @param old,new The old and new calls, as shown to the user.
#'
#' @keywords internal
#' @noRd
.warn_deprecated_fn <- function(old, new) {
  warning(
    sprintf(
      "`%s` is deprecated and will be removed in caugi 2.0.0. Use `%s` instead.",
      old,
      new
    ),
    call. = FALSE
  )
}
# nocov end
