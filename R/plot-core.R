#' Create a caugi Graph Plot Object
#'
#' Creates a grid graphics object (gTree) representing a `caugi` graph.
#' If the graph has not been built yet, it will be built automatically before
#' plotting. This implementation uses idiomatic grid graphics with viewports
#' for proper coordinate handling.
#'
#' @param x A `caugi` object. Must contain only directed edges for Sugiyama
#'   layout.
#' @param layout Specifies the graph layout method. Can be:
#'   * A character string: `"auto"` (default), `"sugiyama"`,
#'     `"fruchterman-reingold"`, `"kamada-kawai"`, `"bipartite"`.
#'     See [caugi_layout()] for details.
#'   * A layout function: e.g., `caugi_layout_sugiyama`,
#'     `caugi_layout_bipartite`, etc. The function will be called with `x` and
#'     any additional arguments passed via `...`.
#'   * A pre-computed layout data.frame with columns `name`, `x`, and `y`.
#' @param ... Additional arguments passed to [caugi_layout()]. For bipartite
#'   layouts, include `partition` (logical vector) and `orientation` (`"rows"`
#'   or `"columns"`).
#' @param node_style List of node styling parameters. Supports:
#'   * Appearance (passed to `gpar()`): `fill`, `col`, `lwd`, `lty`, `alpha`
#'   * Geometry: `padding` (text padding inside nodes in mm, default 2),
#'     `size` (node size multiplier, default 1)
#'   * Local overrides via `by_node`: a named list of nodes with their
#'     own style lists, e.g.
#'     `by_node = list(A = list(fill = "red"), B = list(col = "blue"))`
#' @param edge_style List of edge styling parameters. Can specify global options
#'   or per-type options via `directed`, `undirected`, `bidirected`, `partial`.
#'   Supports:
#'   * Appearance (passed to `gpar()`): `col`, `lwd`, `lty`, `alpha`, `fill`.
#'   * Geometry: `arrow_size` (arrow length in mm, default 3), `circle_size`
#'     (radius of endpoint circles for partial edges in mm, default 1.5)
#'   * Local overrides via `by_edge`: a named list with:
#'       - Node-wide styles: applied to all edges touching a node, e.g.
#'         `A = list(col = "red", lwd = 2)`
#'       - Specific edges: nested named lists for particular edges, e.g.
#'         `A = list(B = list(col = "blue", lwd = 4))`
#'
#'       Multiple levels can be combined: **Style precedence** (highest to lowest):
#'       specific edge settings > node-wide settings > edge type settings > global
#'       settings.
#' @param label_style List of label styling parameters. Supports:
#'   * Appearance (passed to `gpar()`): `col`, `fontsize`, `fontface`,
#'     `fontfamily`, `cex`
#' @param tier_style List of tier box styling parameters. Tier boxes are shown
#'   when `boxes = TRUE` is set within this list. Supports:
#'   * Appearance (passed to `gpar()`): `fill`, `col` (border color), `lwd`,
#'     `lty`, `alpha`
#'   * Geometry: `padding` (padding around tier nodes as proportion of plot range,
#'     default 0.05)
#'   * Labels: `labels` (logical or character vector). If `TRUE`, uses tier names
#'     from `tiers` argument. If a character vector, uses custom labels (one per
#'     tier). If `FALSE` or `NULL` (default), no labels are shown.
#'   * Label styling: `label_style` (list with `col`, `fontsize`, `fontface`, etc.)
#'   * Values can be scalars (applied to all tiers) or vectors (auto-expanded to
#'     each tier in order)
#'   * Local overrides via `by_tier`: a named list (using tier names from `tiers`
#'     argument) or indexed list for per-tier customization, e.g.
#'     `by_tier = list(exposures = list(fill = "lightblue"), outcome = list(fill = "yellow"))`
#'     or `by_tier = list("1" = list(fill = "lightblue"))`
#' @param main Optional character string for plot title. If `NULL` (default),
#'   no title is displayed.
#' @param title_style List of title styling parameters. Supports:
#'   * Appearance (passed to `gpar()`): `col`, `fontsize`, `fontface`,
#'     `fontfamily`, `cex`
#' @param asp Numeric value for the y/x aspect ratio. If `NA` or `NULL` (default),
#'   the aspect ratio is automatically determined to fill the available space.
#'   Use `asp = 1` to ensure that one unit on the x-axis equals one unit on
#'   the y-axis, which respects the layout coordinates. Values other than 1
#'   will stretch the plot accordingly (e.g., `asp = 2` makes the y-axis
#'   twice as tall as the x-axis for the same data range).
#' @param outer_margin Grid unit specifying outer margin around the plot.
#'   Default is `grid::unit(2, "mm")`.
#' @param title_gap Grid unit specifying gap between title and graph.
#'   Default is `grid::unit(1, "lines")`.
#'
#' @returns A `caugi_plot` object that wraps a `gTree` for grid graphics
#'   display. The plot is automatically drawn when printed or explicitly
#'   plotted.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B + C,
#'   B %-->% D,
#'   C %-->% D,
#'   class = "DAG"
#' )
#'
#' plot(cg)
#'
#' # Use a specific layout method (as string)
#' plot(cg, layout = "kamada-kawai")
#'
#' # Use a layout function
#' plot(cg, layout = caugi_layout_sugiyama)
#'
#' # Pre-compute layout and use it
#' coords <- caugi_layout_fruchterman_reingold(cg)
#' plot(cg, layout = coords)
#'
#' # Bipartite layout with a function
#' cg_bp <- caugi(A %-->% X, B %-->% X, C %-->% Y)
#' partition <- c(TRUE, TRUE, TRUE, FALSE, FALSE)
#' plot(cg_bp, layout = caugi_layout_bipartite, partition = partition)
#'
#' # Customize nodes
#' plot(cg, node_style = list(fill = "lightgreen", padding = 0.8))
#'
#' # Customize edges by type
#' plot(
#'   cg,
#'   edge_style = list(
#'     directed = list(col = "blue", arrow_size = 4),
#'     undirected = list(col = "red")
#'   )
#' )
#'
#' # Add a title
#' plot(cg, main = "Causal Graph")
#'
#' # Customize title
#' plot(
#'   cg,
#'   main = "My Graph",
#'   title_style = list(fontsize = 18, col = "blue", fontface = "italic")
#' )
#'
#' # Respect aspect ratio (1:1)
#' plot(cg, asp = 1)
#'
#' @name plot
#' @family plotting
#' @concept plotting
#'
#' @export
S7::method(plot, caugi) <- function(
  x,
  layout = "auto",
  node_style = list(),
  edge_style = list(),
  label_style = list(),
  tier_style = list(),
  main = NULL,
  title_style = list(),
  asp = NA,
  outer_margin = grid::unit(2, "mm"),
  title_gap = grid::unit(1, "lines"),
  ...
) {
  is_caugi(x, throw_error = TRUE)

  # Ensure graph is built
  if (!x@built) {
    x <- build(x)
  }

  stopifnot(
    is.null(asp) ||
      is.na(asp) ||
      isTRUE(is.numeric(asp) && length(asp) == 1 && asp > 0)
  )

  dots <- list(...)

  # Compute layout coordinates
  if (is.character(layout)) {
    # String method name - pass through to caugi_layout
    coords <- caugi_layout(x, method = layout, ...)
  } else if (is.function(layout)) {
    # Layout function - call directly with ...
    coords <- layout(x, ...)
  } else if (is.data.frame(layout)) {
    # Pre-computed layout - validate thoroughly
    required_cols <- c("name", "x", "y")
    missing_cols <- setdiff(required_cols, names(layout))

    if (length(missing_cols) > 0) {
      stop(
        "Layout data.frame is missing required column",
        if (length(missing_cols) > 1) "s" else "",
        ": ",
        paste(missing_cols, collapse = ", "),
        call. = FALSE
      )
    }

    # Validate data types
    if (!is.numeric(layout$x)) {
      stop("Layout column 'x' must be numeric", call. = FALSE)
    }

    if (!is.numeric(layout$y)) {
      stop("Layout column 'y' must be numeric", call. = FALSE)
    }

    # Check for NA/NaN/Inf values
    if (any(is.na(layout$x) | is.nan(layout$x) | is.infinite(layout$x))) {
      stop(
        "Layout column 'x' contains NA, NaN, or infinite values",
        call. = FALSE
      )
    }

    if (any(is.na(layout$y) | is.nan(layout$y) | is.infinite(layout$y))) {
      stop(
        "Layout column 'y' contains NA, NaN, or infinite values",
        call. = FALSE
      )
    }

    # Check that number of nodes matches
    graph_nodes <- nodes(x)[["name"]]
    if (nrow(layout) != length(graph_nodes)) {
      stop(
        "Layout has ",
        nrow(layout),
        " row",
        if (nrow(layout) != 1) "s" else "",
        " but graph has ",
        length(graph_nodes),
        " node",
        if (length(graph_nodes) != 1) "s" else "",
        call. = FALSE
      )
    }

    # Check that all node names are present
    missing_nodes <- setdiff(graph_nodes, layout$name)
    if (length(missing_nodes) > 0) {
      stop(
        "Layout is missing coordinate",
        if (length(missing_nodes) > 1) "s" else "",
        " for node",
        if (length(missing_nodes) > 1) "s" else "",
        ": ",
        paste(head(missing_nodes, 5), collapse = ", "),
        if (length(missing_nodes) > 5) {
          paste0(" (and ", length(missing_nodes) - 5, " more)")
        } else {
          ""
        },
        call. = FALSE
      )
    }

    graph_nodes <- nodes(x)[["name"]]
    coords <- layout[match(graph_nodes, layout$name), , drop = FALSE]

    # Extract tier information from layout if present
    if ("tier" %in% names(layout) && is.null(dots$tiers)) {
      # Reconstruct tiers from tier column
      tier_vec <- stats::setNames(layout$tier, layout$name)
      dots$tiers <- tier_vec

      # Extract orientation from attribute if present
      if (is.null(dots$orientation) && !is.null(attr(layout, "orientation"))) {
        dots$orientation <- attr(layout, "orientation")
      }
    }
  } else {
    stop(
      "layout must be a character string, function, or data.frame",
      call. = FALSE
    )
  }

  styles <- make_styles(
    edge_style = edge_style,
    node_style = node_style,
    label_style = label_style,
    title_style = title_style,
    tier_style = tier_style
  )

  labels <- nodes(x)[["name"]]
  edges <- edges(x)

  # Set up viewport parameters
  vp_x <- grid::unit(0.5, "npc")
  vp_y <- grid::unit(0.5, "npc")
  vp_width <- grid::unit(1, "npc")
  vp_height <- grid::unit(1, "npc")

  x_range <- range(coords$x)
  y_range <- range(coords$y)

  if (x_range[1] == x_range[2]) {
    x_range <- x_range + c(-1, 1)
  }
  if (y_range[1] == y_range[2]) {
    y_range <- y_range + c(-1, 1)
  }

  # Nodes
  nodes_res <- make_nodes(
    coords = coords,
    labels = labels,
    node_style = styles$node_style,
    label_style = styles$label_style
  )

  circle_grobs <- nodes_res$circle_grobs
  label_grobs <- nodes_res$label_grobs
  node_radii <- nodes_res$node_radii

  # Edges
  edge_grobs <- make_edges(
    edges = edges,
    coords = coords,
    node_radii = node_radii,
    edge_styles = styles$edge_styles,
    edge_by_edge = styles$edge_by_edge
  )

  do_tier_boxes <- isTRUE(styles$tier_style$global$boxes)
  do_tier_labels <- isTRUE(styles$tier_style$global$labels) ||
    is.character(styles$tier_style$global$labels)
  do_tiers <- (do_tier_boxes || do_tier_labels) && !is.null(dots$tiers)

  tier_box_grobs <- NULL
  tier_label_grobs <- NULL

  if (do_tiers) {
    orientation <- dots$orientation %||% "columns"

    tier_box_result <- make_tiers(
      circle_grobs,
      coords = coords,
      tiers = dots$tiers,
      tier_style = styles$tier_style,
      orientation = orientation
    )

    tier_box_grobs <- tier_box_result$grobs
    tier_label_grobs <- tier_box_result$label_grobs
  }

  # Figure out viewport center and size
  # This is a piece of intricate voodoo, but basically we are
  # starting out with a viewport that is [0, 1] x [0, 1] in npc units,
  # and then shrink it based on how much the nodes (circles) protrude
  # beyond this box, or how much the tier boxes/labels protrude beyond
  # this box.
  #
  # TODO: For some reason, we cannot use the same logic for just the
  # circle grobs as for the tier boxes/labels - if we do that, the
  # viewport ends up being wrongly placed and/or too small. It would
  # be nice to understand why and fix this.
  if (!is.null(tier_box_grobs)) {
    x0 <- min(grid::grobX(tier_box_grobs, "west"))
    x1 <- max(grid::grobX(tier_box_grobs, "east"))
    y0 <- min(grid::grobY(tier_box_grobs, "south"))
    y1 <- max(grid::grobY(tier_box_grobs, "north"))

    if (!is.null(tier_label_grobs) && length(tier_label_grobs) > 0) {
      x0 <- min(x0, min(grid::grobX(tier_label_grobs, "west")))
      x1 <- max(x1, max(grid::grobX(tier_label_grobs, "east")))
      y0 <- min(y0, min(grid::grobY(tier_label_grobs, "south")))
      y1 <- max(y1, max(grid::grobY(tier_label_grobs, "north")))
    }

    vp_width <- 2 * grid::unit(1, "npc") - (x1 - x0)
    vp_height <- 2 * grid::unit(1, "npc") - (y1 - y0)
    vp_x <- grid::unit(1, "npc") - (x0 + x1) / 2
    vp_y <- grid::unit(1, "npc") - (y0 + y1) / 2
  } else {
    # Set up viewport parameters
    vp_x <- grid::unit(0.5, "npc")
    vp_y <- grid::unit(0.5, "npc")
    vp_width <- grid::unit(1, "npc") - max(grid::grobWidth(circle_grobs))
    vp_height <- grid::unit(1, "npc") - max(grid::grobHeight(circle_grobs))
  }

  # Apply aspect ratio if specified
  if (!is.null(asp) && !is.na(asp) && is.numeric(asp) && asp > 0) {
    # asp is y/x aspect ratio (same as base R)
    # Calculate the data aspect ratio
    data_width <- diff(x_range)
    data_height <- diff(y_range)
    data_asp <- data_height / data_width

    # If asp is specified, we need to adjust the viewport dimensions
    # to match the desired aspect ratio
    if (data_asp > asp) {
      # Data is taller than desired - constrain by height
      # Keep vp_height, adjust vp_width
      vp_width <- vp_height * (data_width / data_height) * asp
    } else {
      # Data is wider than desired - constrain by width
      # Keep vp_width, adjust vp_height
      vp_height <- vp_width * (data_height / data_width) / asp
    }
  }

  # TODO: Find the actual node in each direction to size viewport better
  graph_vp <- grid::viewport(
    x = vp_x,
    y = vp_y,
    xscale = x_range,
    yscale = y_range,
    width = vp_width,
    height = vp_height,
    name = "caugi.vp"
  )

  # Assemble the grobs
  graph_children_list <- list()

  if (!is.null(tier_box_grobs)) {
    graph_children_list <- c(graph_children_list, list(tier_box_grobs))
  }

  if (!is.null(tier_label_grobs) && length(tier_label_grobs) > 0) {
    graph_children_list <- c(graph_children_list, list(tier_label_grobs))
  }

  node_gtree <- grid::grobTree(
    circle_grobs,
    label_grobs,
    name = "node_gtree"
  )

  graph_children_list <- c(
    graph_children_list,
    list(edge_grobs, node_gtree)
  )

  graph_children <- do.call(grid::gList, graph_children_list)

  graph_grob <- grid::gTree(
    children = graph_children,
    vp = graph_vp,
    name = "caugi.graph"
  )

  title_grob <- if (is.null(main)) {
    grid::nullGrob(name = "title")
  } else {
    title_gpar <- do.call(grid::gpar, get_gpar_params(styles$title_style))
    grid::textGrob(
      label = main,
      gp = title_gpar,
      name = "title"
    )
  }

  title_height <- grid::unit(1, "grobheight", list(title_grob))

  if (is.null(main)) {
    title_gap <- grid::unit(0, "mm")
  }

  layout_vp <- grid::viewport(
    layout = grid::grid.layout(
      nrow = 5,
      ncol = 3,
      heights = grid::unit.c(
        outer_margin,
        title_height,
        title_gap,
        grid::unit(1, "null"),
        outer_margin
      ),
      widths = grid::unit.c(
        outer_margin,
        grid::unit(1, "null"),
        outer_margin
      )
    ),
    name = "layout"
  )

  title_grob$vp <- grid::vpStack(
    layout_vp,
    grid::viewport(layout.pos.row = 2, layout.pos.col = 2)
  )

  graph_grob$vp <- grid::vpStack(
    layout_vp,
    grid::viewport(layout.pos.row = 4, layout.pos.col = 2),
    graph_vp
  )

  # Wrap in gTree (viewport already on children)
  final_grob <- grid::gTree(
    children = grid::gList(title_grob, graph_grob),
    name = "caugi.titled"
  )

  caugi_plot(grob = final_grob)
}

#' @export
S7::method(print, caugi_plot) <- function(x, ...) {
  graphics::plot(x, ...)
}

#' @export
S7::method(plot, caugi_plot) <- function(x, newpage = TRUE, ...) {
  if (newpage) {
    grid::grid.newpage()
  }
  grid::grid.draw(x@grob)
  invisible(x)
}

#' Compose Plots Horizontally
#'
#' Arrange two plots side-by-side with configurable spacing. The `+` and `|`
#' operators are equivalent and can be used interchangeably. Compositions can
#' be nested to create complex multi-plot layouts.
#'
#' @param e1 A `caugi_plot` object (left plot)
#' @param e2 A `caugi_plot` object (right plot)
#'
#' @returns A `caugi_plot` object containing the composed layout
#'
#' @details
#' The spacing between plots is controlled by the global option
#' `caugi_options()$plot$spacing`, which defaults to `grid::unit(1, "lines")`.
#' Compositions can be nested arbitrarily:
#'
#' - `p1 + p2` - two plots side-by-side
#' - `(p1 + p2) + p3` - three plots in a row
#' - `(p1 + p2) / p3` - two plots on top, one below
#'
#' @family plotting
#' @seealso [caugi_options()] for configuring spacing and default styles
#'
#' @examples
#' cg1 <- caugi(A %-->% B, B %-->% C)
#' cg2 <- caugi(X %-->% Y, Y %-->% Z)
#'
#' p1 <- plot(cg1, main = "Graph 1")
#' p2 <- plot(cg2, main = "Graph 2")
#'
#' # Horizontal composition
#' p1 + p2
#' p1 | p2 # equivalent
#'
#' # Adjust spacing
#' caugi_options(plot = list(spacing = grid::unit(2, "lines")))
#' p1 + p2
#'
#' @name add-caugi_plot-caugi_plot
NULL

S7::method(`+`, list(caugi_plot, caugi_plot)) <- function(e1, e2) {
  compose_plots(e1, e2, horizontal = TRUE)
}

#' @rdname add-caugi_plot-caugi_plot
#' @name pipe-caugi_plot-caugi_plot
NULL

S7::method(`|`, list(caugi_plot, caugi_plot)) <- function(e1, e2) {
  e1 + e2
}

#' Compose Plots Vertically
#'
#' Stack two plots vertically with configurable spacing. Compositions can
#' be nested to create complex multi-plot layouts.
#'
#' @param e1 A `caugi_plot` object (top plot)
#' @param e2 A `caugi_plot` object (bottom plot)
#'
#' @returns A `caugi_plot` object containing the composed layout
#'
#' @details
#' The spacing between plots is controlled by the global option
#' `caugi_options()$plot$spacing`, which defaults to `grid::unit(1, "lines")`.
#' Compositions can be nested arbitrarily:
#'
#' - `p1 / p2` - two plots stacked vertically
#' - `p1 / p2 / p3` - three plots in a column
#' - `(p1 + p2) / p3` - two plots on top, one below
#'
#' @family plotting
#' @seealso [caugi_options()] for configuring spacing and default styles
#'
#' @examples
#' cg1 <- caugi(A %-->% B, B %-->% C)
#' cg2 <- caugi(X %-->% Y, Y %-->% Z)
#'
#' p1 <- plot(cg1, main = "Graph 1")
#' p2 <- plot(cg2, main = "Graph 2")
#'
#' # Vertical composition
#' p1 / p2
#'
#' # Mixed composition
#' (p1 + p2) / p1
#'
#' @name divide-caugi_plot-caugi_plot
NULL

S7::method(`/`, list(caugi_plot, caugi_plot)) <- function(e1, e2) {
  compose_plots(e1, e2, horizontal = FALSE)
}

#' Internal function for plot composition
#'
#' @param e1 First caugi_plot
#' @param e2 Second caugi_plot
#' @param horizontal Logical, TRUE for horizontal, FALSE for vertical
#' @keywords internal
#' @noRd
compose_plots <- function(e1, e2, horizontal = TRUE) {
  # Compose using a fixed layout to avoid grob size conversions
  # (which can fail for nested viewports).
  opts <- get0("options", .caugi_env, ifnotfound = caugi_default_options())
  spacing <- opts$plot$spacing
  if (is.null(spacing)) {
    spacing <- grid::unit(1, "lines")
  }
  if (!inherits(spacing, "unit")) {
    stop("`caugi_options()$plot$spacing` must be a grid::unit()", call. = FALSE)
  }

  if (horizontal) {
    layout_vp <- grid::viewport(
      layout = grid::grid.layout(
        nrow = 1,
        ncol = 3,
        widths = grid::unit.c(
          grid::unit(1, "null"),
          spacing,
          grid::unit(1, "null")
        )
      )
    )

    first <- grid::gTree(
      children = grid::gList(e1@grob),
      vp = grid::viewport(layout.pos.col = 1),
      name = "caugi.composed.left"
    )

    spacer_grob <- grid::nullGrob(
      vp = grid::viewport(layout.pos.col = 2)
    )

    second <- grid::gTree(
      children = grid::gList(e2@grob),
      vp = grid::viewport(layout.pos.col = 3),
      name = "caugi.composed.right"
    )
  } else {
    layout_vp <- grid::viewport(
      layout = grid::grid.layout(
        nrow = 3,
        ncol = 1,
        heights = grid::unit.c(
          grid::unit(1, "null"),
          spacing,
          grid::unit(1, "null")
        )
      )
    )

    first <- grid::gTree(
      children = grid::gList(e1@grob),
      vp = grid::viewport(layout.pos.row = 1),
      name = "caugi.composed.top"
    )

    spacer_grob <- grid::nullGrob(
      vp = grid::viewport(layout.pos.row = 2)
    )

    second <- grid::gTree(
      children = grid::gList(e2@grob),
      vp = grid::viewport(layout.pos.row = 3),
      name = "caugi.composed.bottom"
    )
  }

  final_grob <- grid::gTree(
    children = grid::gList(first, spacer_grob, second),
    vp = layout_vp,
    name = "caugi.composed"
  )

  caugi_plot(grob = final_grob)
}
