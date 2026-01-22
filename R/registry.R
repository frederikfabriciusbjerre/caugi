# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────── Registry API ─────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title `caugi` edge registry
#'
#' @description
#' The `caugi` edge registry stores information about the different edge types
#' that can be used in `caugi` graphs. It maps edge glyphs (e.g., `"-->"`,
#' `"<->"`, `"o->"`, etc.) to their specifications, including tail and head
#' marks, class, and symmetry. The registry allows for dynamic registration of
#' new edge types, enabling users to extend the set of supported edges in
#' `caugi.` It is implemented as a singleton, ensuring that there is a single
#' global instance of the registry throughout the R session.
#'
#' @details
#' The intended use of the `caugi` registry is mostly for advanced users and
#' developers. The registry enables users who need to define their own custom
#' edge types in `caugi` directly. . It currently mostly supports the
#' _representation_ of new edges, but for users that might want to represent
#' reverse edges, this preserves correctness of reason over these edges.
#'
#' @name registry
#'
#' @examples
#' # first, for reproducability, we reset the registry to default
#' reset_caugi_registry()
#'
#' # create a new registry
#' reg <- caugi_registry()
#'
#' # register an edge
#' register_caugi_edge(
#'   glyph = "<--",
#'   tail_mark = "arrow",
#'   head_mark = "tail",
#'   class = "directed",
#'   symmetric = FALSE
#' )
#'
#' # now, this edge is available for caugi graphs:
#' cg <- caugi(A %-->% B, B %<--% C, class = "DAG")
#'
#' # reset the registry to default
#' reset_caugi_registry()
#'
#' @family registry
#' @concept registry
NULL

#' @describeIn registry Access the global edge registry, creating it if needed.
#'
#' @returns An `edge_registry` external pointer.
#'
#' @export
caugi_registry <- function() {
  if (
    !exists("reg", envir = .caugi_env, inherits = FALSE) ||
      is.null(.caugi_env$reg)
  ) {
    reg <- edge_registry_new()
    edge_registry_register_builtins(reg) # once per session
    .caugi_env$reg <- reg
  }
  .caugi_env$reg
}

#' @describeIn registry Reset the global edge registry to its default state.
#'
#' @export
reset_caugi_registry <- function() {
  .caugi_env$reg <- NULL
  .caugi_env$edge_ops <- .caugi_defaults_edge_ops
  .caugi_env$glyph_map <- .caugi_defaults_glyph_map
  invisible(TRUE)
}

#' @describeIn registry Seal the global edge registry to prevent further
#' modifications.
#'
#' @export
seal_caugi_registry <- function() {
  reg <- caugi_registry()
  edge_registry_seal(reg)
  invisible(TRUE)
}

#' @title Register a new edge type in the global registry.
#'
#' @param glyph A string representing the edge glyph (e.g., `"-->"`, `"<->"`).
#' @param tail_mark One of "arrow", "tail", "circle", "other".
#' @param head_mark One of "arrow", "tail", "circle", "other".
#' @param class One of "directed","undirected","bidirected","partial".
#' @param symmetric Logical.
#' @returns TRUE, invisibly.
#'
#' @examples
#' # first, for reproducability, we reset the registry to default
#' reset_caugi_registry()
#'
#' # create a new registry
#' reg <- caugi_registry()
#'
#' # register an edge
#' register_caugi_edge(
#'   glyph = "<--",
#'   tail_mark = "arrow",
#'   head_mark = "tail",
#'   class = "directed",
#'   symmetric = FALSE
#' )
#'
#' # now, this edge is available for caugi graphs:
#' cg <- caugi(A %-->% B, B %<--% C, class = "DAG")
#'
#' # reset the registry to default
#' reset_caugi_registry()
#'
#' @family registry
#' @concept registry
#'
#' @export
register_caugi_edge <- function(
  glyph,
  tail_mark,
  head_mark,
  class,
  symmetric = FALSE
) {
  if (!is.character(glyph) || length(glyph) != 1L) {
    stop("glyph must be a single string")
  }
  if (nchar(glyph) != 3L) {
    stop("glyph must be a non-empty string of length 3 (e.g., '-->')")
  }
  if (grepl("%", glyph)) {
    stop("glyph must not contain '%'")
  }
  if (
    class %in%
      c("directed", "partially_directed", "partially_undirected") &&
      symmetric
  ) {
    stop("This class cannot be symmetric")
  }
  if (class %in% c("undirected", "bidirected", "partial") && !symmetric) {
    stop("This class must be symmetric")
  }

  reg <- caugi_registry()
  edge_registry_register(
    reg,
    glyph,
    tail_mark,
    head_mark,
    class,
    symmetric
  )
  .register_edge(glyph)
  invisible(TRUE)
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Registry helpers ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Register a new edge operator
#'
#' @description Register a new edge operator for use in `caugi()`.
#'
#' @param glyph A string representing the edge glyph (e.g., `"-->"`, `"<->"`).
#'
#' @returns The operator name (e.g., `"%-->%"`), invisibly.
#'
#' @keywords internal
.register_edge <- function(glyph) {
  op <- paste0("%", glyph, "%")

  # check if in the global registry
  if (op %in% .edge_ops_get()) {
    stop("Operator ", op, " is already registered")
  }

  # update glyph map
  m <- .glyph_map_get()
  m[[op]] <- glyph
  assign("glyph_map", m, envir = .caugi_env)

  # update known operators
  ops <- .edge_ops_get()
  if (!(op %in% ops)) {
    assign("edge_ops", c(ops, op), envir = .caugi_env)
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────── Edge helpers ─────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Is the edge symmetric?
#'
#' @description Check if the given edge glyph is symmetric in the edge registry.
#'
#' @param glyph A string representing the edge glyph (e.g., `"-->"`, `"<->"`).
#'
#' @returns Logical, `TRUE` if the edge is symmetric, otherwise throws error.
#'
#' @keywords internal
is_edge_symmetric <- function(glyph) {
  reg <- caugi_registry()

  tryCatch(
    code <- edge_registry_code_of(reg, glyph),
    error = function(e) {
      stop(
        "glyph '",
        glyph,
        "' is not registered in caugi",
        " edge registry. Please either register it first with ",
        "register_caugi_edge() or use a glyph from the registry.",
        call. = FALSE
      )
    }
  )
  # check if symmetric glyph
  edge_spec <- edge_registry_spec_of_code(reg, code)
  if (!edge_spec$symmetric) {
    stop(
      "glyph '",
      glyph,
      "' is not symmetric. ",
      "Please use a symmetric glyph.",
      call. = FALSE
    )
  }
  TRUE
}
