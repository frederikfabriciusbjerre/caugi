# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── caugi options ─────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' Default options for caugi
#'
#' Returns the default options for the caugi package. Useful for resetting
#' options to their original state.
#'
#' @return A list of default options for caugi.
#'
#' @seealso [caugi_options()] for setting and getting options
#' @concept options
#' @export
#'
#' @examples
#' # Get defaults
#' caugi_default_options()
#'
#' # Reset to defaults
#' caugi_options(caugi_default_options())
caugi_default_options <- function() {
  list(
    plot = list(
      spacing = grid::unit(1, "lines"),
      node_style = list(
        fill = "lightgrey",
        padding = 2,
        size = 1
      ),
      edge_style = list(
        arrow_size = 3,
        circle_size = 1.5,
        fill = "black"
      ),
      label_style = list(),
      title_style = list(
        col = "black",
        fontface = "bold",
        fontsize = 14.4
      )
    )
  )
}

#' Get or set global options for caugi
#'
#' Configure global defaults for caugi, including plot composition spacing and
#' default visual styles for nodes, edges, labels, and titles.
#'
#' @param ... Named values to update options with, or unnamed option names to
#'   retrieve. To query all options, call without arguments.
#'
#' @return When setting, returns (invisibly) the previous values for the updated
#'   options. When getting (no arguments or unnamed character vector), returns
#'   the requested options.
#'
#' @details
#' Currently supported options are nested under the `plot` key:
#'
#' - `spacing`: A [grid::unit()] controlling space between composed plots
#'   (default: `grid::unit(1, "lines")`)
#' - `node_style`: List of default node appearance parameters:
#'   - `fill`: Fill color (default: `"lightgrey"`)
#'   - `padding`: Padding around labels in mm (default: `2`)
#'   - `size`: Size multiplier (default: `1`)
#' - `edge_style`: List of default edge appearance parameters:
#'   - `arrow_size`: Arrow size in mm (default: `3`)
#'   - `circle_size`: Radius of endpoint circles for partial edges in mm (default: `1.5`)
#'   - `fill`: Arrow/line color (default: `"black"`)
#' - `label_style`: List of label text parameters (see [grid::gpar()])
#' - `title_style`: List of title text parameters:
#'   - `col`: Text color (default: `"black"`)
#'   - `fontface`: Font face (default: `"bold"`)
#'   - `fontsize`: Font size in pts (default: `14.4`)
#'
#' Options set via `caugi_options()` serve as global defaults that can be
#' overridden by arguments to [caugi::plot()].
#'
#' @seealso [caugi::plot()] for per-plot style arguments, [grid::gpar()] for
#'   available graphical parameters
#'
#' @concept options
#'
#' @examples
#' # Query all options
#' caugi_options()
#'
#' # Query specific option
#' caugi_options("plot")
#'
#' # Set plot spacing
#' caugi_options(plot = list(spacing = grid::unit(2, "lines")))
#'
#' # Set default node style
#' caugi_options(plot = list(
#'   node_style = list(fill = "lightblue", padding = 3)
#' ))
#'
#' # Set multiple options at once
#' caugi_options(plot = list(
#'   spacing = grid::unit(1.5, "lines"),
#'   node_style = list(fill = "lightblue", padding = 3),
#'   edge_style = list(arrow_size = 4, fill = "darkgray"),
#'   title_style = list(col = "blue", fontsize = 16)
#' ))
#'
#' # Reset to defaults
#' caugi_options(caugi_default_options())
#'
#' @export
caugi_options <- function(...) {
  new <- list(...)
  if (is.null(names(new)) && length(new) == 1L && is.list(new[[1L]])) {
    new <- new[[1L]]
  }

  old <- get0("options", .caugi_env, ifnotfound = caugi_default_options())

  if (length(new) == 0L) {
    return(old)
  }

  nm <- names(new)
  if (is.null(nm)) {
    return(old[unlist(new)])
  }

  out <- old[nm]
  names(out) <- nm

  .caugi_env$options <- utils::modifyList(old, new)
  invisible(out)
}
