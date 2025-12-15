#' Compute Graph Layout
#'
#' Computes node coordinates for graph visualization using
#' specified layout algorithm. If the graph has not been built yet, it will
#' be built automatically before computing the layout.
#'
#' @param x A `caugi` object. Must contain only directed edges for Sugiyama
#'   layout.
#' @param method Character string specifying the layout method. Options:
#'   * `"auto"`: Automatically choose sugiyama for graphs with only directed
#'     edges, otherwise force (default)
#'   * `"sugiyama"`: Hierarchical layout for DAGs (requires only directed edges)
#'   * `"force"`: Force-directed layout (works with all edge types)
#'
#' @returns A `data.frame` with columns `name`, `x`, and `y` containing node
#'   names and their coordinates.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B + C,
#'   B %-->% D,
#'   C %-->% D,
#'   class = "DAG"
#' )
#' layout <- caugi_layout(cg)
#'
#' @family plotting
#' @concept plotting
#'
#' @export
caugi_layout <- function(x, method = c("auto", "sugiyama", "force")) {
  is_caugi(x, throw_error = TRUE)

  method <- match.arg(method)

  # Ensure graph is built
  if (!x@built) {
    x <- build(x)
  }

  edge_types <- unique(edges(x)[["edge"]])
  non_directed <- setdiff(edge_types, "-->")

  # Auto-select method based on edge types
  if (method == "auto") {
    method <- if (length(non_directed) == 0) "sugiyama" else "force"
  }

  # Sugiyama layout only works reliably with directed edges
  # Check if graph has non-directed edges (undirected, bidirected, partial)
  if (method == "sugiyama" && length(non_directed) > 0) {
    stop(
      "Sugiyama layout only supports graphs with directed edges. ",
      "Found edge type(s): ",
      paste(non_directed, collapse = ", "),
      ". ",
      "Consider using \"force\" for graphs with mixed edge types.",
      call. = FALSE
    )
  }

  coords <- compute_layout_ptr(x@ptr, method)

  data.frame(
    name = nodes(x)[["name"]],
    x = coords[["x"]],
    y = coords[["y"]],
    stringsAsFactors = FALSE
  )
}

get_gpar_params <- function(style) {
  gpar_names <- c(
    "fill",
    "col",
    "lwd",
    "lty",
    "alpha",
    "lineend",
    "linejoin",
    "linemitre",
    "fontsize",
    "fontface",
    "fontfamily",
    "cex",
    "lex"
  )
  params <- style[names(style) %in% gpar_names]
  if (length(params) == 0) {
    return(list())
  }
  params
}

#' Create a caugi Graph Plot Object
#'
#' Creates a grid graphics object (gTree) representing a `caugi` graph.
#' If the graph has not been built yet, it will be built automatically before
#' plotting. This implementation uses idiomatic grid graphics with viewports
#' for proper coordinate handling.
#'
#' @param x A `caugi` object. Must contain only directed edges for Sugiyama
#'   layout.
#' @param layout Character string specifying the layout method. Options:
#'   * `"auto"`: Automatically choose sugiyama for graphs with only directed
#'     edges, otherwise force (default)
#'   * `"sugiyama"`: Hierarchical layout for DAGs (requires only directed edges)
#'   * `"force"`: Force-directed layout (works with all edge types)
#' @param node_style List of node styling parameters. Supports:
#'   * Appearance (passed to `gpar()`): `fill`, `col`, `lwd`, `lty`, `alpha`
#'   * Geometry: `padding` (text padding inside nodes in mm, default 2),
#'     `size` (node size multiplier, default 1)
#' @param edge_style List of edge styling parameters. Can specify global options
#'   or per-type options via `directed`, `undirected`, `bidirected`, `partial`.
#'   Supports:
#'   * Appearance (passed to `gpar()`): `col`, `lwd`, `lty`, `alpha`, `fill`.
#'   * Geometry: `arrow_size` (arrow length in mm, default 3)
#' @param label_style List of label styling parameters. Supports:
#'   * Appearance (passed to `gpar()`): `col`, `fontsize`, `fontface`,
#'     `fontfamily`, `cex`
#' @param ... Additional arguments (currently unused).
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
#' @name plot
#' @family plotting
#' @concept plotting
#'
#' @export
S7::method(plot, caugi) <- function(
  x,
  layout = c("auto", "sugiyama", "force"),
  node_style = list(),
  edge_style = list(),
  label_style = list(),
  ...
) {
  is_caugi(x, throw_error = TRUE)

  layout <- match.arg(layout)

  # Ensure graph is built
  if (!x@built) {
    x <- build(x)
  }

  # TODO: Consider letting this be a parameter
  margin <- grid::unit(2, "mm")

  styles <- make_styles(
    edge_style = edge_style,
    node_style = node_style,
    label_style = label_style
  )

  labels <- nodes(x)[["name"]]

  coords <- caugi_layout(x, method = layout)
  edges <- edges(x)

  nodes_res <- make_nodes(
    coords = coords,
    labels = labels,
    node_style = styles$node_style,
    label_style = styles$label_style
  )

  circle_grobs <- nodes_res$circle_grobs
  label_grobs <- nodes_res$label_grobs
  node_radii <- nodes_res$node_radii

  edge_grobs <- make_edges(
    edges = edges,
    coords = coords,
    node_radii = node_radii,
    edge_styles = styles$edge_styles
  )

  x_range <- range(coords$x)
  y_range <- range(coords$y)

  if (x_range[1] == x_range[2]) {
    x_range <- x_range + c(-1, 1)
  }
  if (y_range[1] == y_range[2]) {
    y_range <- y_range + c(-1, 1)
  }

  node_gtree <- grid::grobTree(
    circle_grobs,
    label_grobs,
    name = "node_gtree"
  )

  final_vp <- grid::viewport(
    xscale = x_range,
    yscale = y_range,
    width = grid::unit(1, "npc") - max(grid::grobWidth(circle_grobs)) - margin,
    height = grid::unit(1, "npc") -
      max(grid::grobHeight(circle_grobs)) -
      margin,
    name = "caugi.vp"
  )

  children <- grid::gList(
    edge_grobs,
    node_gtree
  )

  grob <- grid::gTree(
    children = children,
    vp = final_vp,
    name = "caugi.grob"
  )

  caugi_plot(grob = grob)
}

make_styles <- function(edge_style, node_style, label_style) {
  # Default styles
  node_defaults <- list(
    fill = "lightgrey",
    padding = 2,
    size = 1
  )

  edge_defaults <- list(
    arrow_size = 3,
    fill = "black"
  )

  label_defaults <- list()

  # Merge with user-provided styles
  node_style <- utils::modifyList(node_defaults, node_style)

  # Handle edge styles - support both global and per-type
  edge_type_names <- c("directed", "undirected", "bidirected", "partial")
  global_edge_opts <- edge_style[setdiff(names(edge_style), edge_type_names)]

  # Create per-type edge styles
  edge_styles <- list(
    directed = utils::modifyList(
      utils::modifyList(edge_defaults, global_edge_opts),
      edge_style$directed %||% list()
    ),
    undirected = utils::modifyList(
      utils::modifyList(edge_defaults, global_edge_opts),
      edge_style$undirected %||% list()
    ),
    bidirected = utils::modifyList(
      utils::modifyList(edge_defaults, global_edge_opts),
      edge_style$bidirected %||% list()
    ),
    partial = utils::modifyList(
      utils::modifyList(
        utils::modifyList(edge_defaults, list(lty = 2)),
        global_edge_opts
      ),
      edge_style$partial %||% list()
    )
  )

  label_style <- utils::modifyList(label_defaults, label_style)

  list(
    edge_styles = edge_styles,
    node_style = node_style,
    label_style = label_style
  )
}

make_nodes <- function(coords, labels, node_style, label_style) {
  n_nodes <- nrow(coords)

  circle_grobs <- grid::gList()
  label_grobs <- grid::gList()
  node_radii <- vector("list", n_nodes)

  padding <- grid::unit(node_style$padding, "mm")

  node_gpar <- do.call(grid::gpar, get_gpar_params(node_style))
  label_gpar <- do.call(grid::gpar, get_gpar_params(label_style))

  do_labels <- !is.null(labels) && length(labels) > 0

  for (i in seq_len(n_nodes)) {
    r <- (0.5 * grid::stringWidth(labels[i]) + padding) * node_style$size
    x <- grid::unit(coords$x[i], "native")
    y <- grid::unit(coords$y[i], "native")

    circle_grob <- grid::circleGrob(
      x = x,
      y = y,
      r = r,
      gp = node_gpar,
      name = paste0("node.", i)
    )

    label_grob <- if (do_labels) {
      grid::textGrob(
        labels[i],
        x = x,
        y = y,
        gp = label_gpar,
        name = paste0("label.", i)
      )
    } else {
      grid::nullGrob()
    }

    circle_grobs[[i]] <- circle_grob
    label_grobs[[i]] <- label_grob
    node_radii[[i]] <- r
  }

  list(
    circle_grobs = circle_grobs,
    label_grobs = label_grobs,
    node_radii = node_radii
  )
}

# Create a custom edge grob that adjusts endpoints at draw time
#
# This function creates a gTree with a custom makeContent method that
# dynamically calculates edge endpoints to account for node sizes and
# viewport aspect ratio. The adjustment happens at draw time to ensure
# edges always point to node centers regardless of window resizing.
#
# @param x0,y0 Starting coordinates in native units
# @param x1,y1 Ending coordinates in native units
# @param r_from,r_to Node radii as grid units (typically from stringWidth)
# @param arrow Optional arrow specification from grid::arrow()
# @param gp Graphics parameters from grid::gpar()
# @param name Optional grob name
#
# @returns A gTree of class "caugi_edge_grob"
make_edge_grob <- function(
  x0,
  y0,
  x1,
  y1,
  r_from,
  r_to,
  arrow = NULL,
  gp = grid::gpar(),
  name = NULL
) {
  grid::gTree(
    x0 = x0,
    y0 = y0,
    x1 = x1,
    y1 = y1,
    r_from = r_from,
    r_to = r_to,
    arrow = arrow,
    gp = gp,
    name = name,
    cl = "caugi_edge_grob"
  )
}

#' Make Content for Custom Edge Grob
#'
#' This S3 method for grid::makeContent handles dynamic edge endpoint
#' calculation at draw time. It converts edge direction to absolute
#' coordinates (mm) to properly handle aspect ratio, then applies node
#' radius offsets before converting back to native coordinates.
#'
#' @param x A caugi_edge_grob object
#' @returns The modified grob with children set to the adjusted line
#'
#' @keywords internal
#'
#' @export
makeContent.caugi_edge_grob <- function(x) {
  x0_unit <- grid::unit(x$x0, "native")
  y0_unit <- grid::unit(x$y0, "native")
  x1_unit <- grid::unit(x$x1, "native")
  y1_unit <- grid::unit(x$y1, "native")

  # Calculate direction in absolute coordinates at draw time
  dx_mm <- grid::convertWidth(x1_unit - x0_unit, "mm", valueOnly = TRUE)
  dy_mm <- grid::convertHeight(y1_unit - y0_unit, "mm", valueOnly = TRUE)

  length_mm <- sqrt(dx_mm^2 + dy_mm^2)

  if (length_mm > 0) {
    # Normalized direction in absolute coordinates
    ux_mm <- dx_mm / length_mm
    uy_mm <- dy_mm / length_mm

    # Get radius in mm
    r_from_mm <- grid::convertWidth(x$r_from, "mm", valueOnly = TRUE)
    r_to_mm <- grid::convertWidth(x$r_to, "mm", valueOnly = TRUE)

    # Calculate offsets in mm
    offset_x0_mm <- ux_mm * r_from_mm
    offset_y0_mm <- uy_mm * r_from_mm
    offset_x1_mm <- ux_mm * r_to_mm
    offset_y1_mm <- uy_mm * r_to_mm

    # Apply offsets: convert mm offsets back to native
    x0_adj <- x0_unit +
      grid::convertWidth(grid::unit(offset_x0_mm, "mm"), "native")
    y0_adj <- y0_unit +
      grid::convertHeight(grid::unit(offset_y0_mm, "mm"), "native")
    x1_adj <- x1_unit -
      grid::convertWidth(grid::unit(offset_x1_mm, "mm"), "native")
    y1_adj <- y1_unit -
      grid::convertHeight(grid::unit(offset_y1_mm, "mm"), "native")
  } else {
    x0_adj <- x0_unit
    y0_adj <- y0_unit
    x1_adj <- x1_unit
    y1_adj <- y1_unit
  }

  grid::setChildren(
    x,
    grid::gList(
      grid::linesGrob(
        x = grid::unit.c(x0_adj, x1_adj),
        y = grid::unit.c(y0_adj, y1_adj),
        arrow = x$arrow,
        gp = x$gp
      )
    )
  )
}

make_edges <- function(edges, coords, node_radii, edge_styles) {
  n_edges <- nrow(edges)

  edge_grobs <- grid::gList()

  if (n_edges > 0) {
    for (i in seq_len(n_edges)) {
      from_idx <- match(edges$from[i], coords$name)
      to_idx <- match(edges$to[i], coords$name)

      x0 <- coords$x[from_idx]
      y0 <- coords$y[from_idx]
      x1 <- coords$x[to_idx]
      y1 <- coords$y[to_idx]

      # Get node radii
      r_from <- node_radii[[from_idx]]
      r_to <- node_radii[[to_idx]]

      # Determine edge style based on type
      edge_type <- edges$edge[i]

      style <- switch(
        edge_type,
        "-->" = edge_styles$directed,
        "---" = edge_styles$undirected,
        "<->" = edge_styles$bidirected,
        "o->" = edge_styles$partial,
        edge_styles$undirected
      )

      arrow <- switch(
        edge_type,
        "-->" = grid::arrow(
          length = grid::unit(style$arrow_size, "mm"),
          type = "closed"
        ),
        "<->" = grid::arrow(
          length = grid::unit(style$arrow_size, "mm"),
          ends = "both",
          type = "closed"
        ),
        # TODO: Partial edges (o->) should have a circle at the tail
        "o->" = grid::arrow(
          length = grid::unit(style$arrow_size, "mm"),
          type = "open"
        ),
        NULL
      )

      # Get gpar for this edge type
      edge_gpar <- do.call(grid::gpar, get_gpar_params(style))

      edge_grobs[[i]] <- make_edge_grob(
        x0 = x0,
        y0 = y0,
        x1 = x1,
        y1 = y1,
        r_from = r_from,
        r_to = r_to,
        arrow = arrow,
        gp = edge_gpar,
        name = paste0("edge.", i)
      )
    }
  }

  edge_grobs
}

#' S7 Class for caugi Plot
#'
#' An S7 object that wraps a grid gTree for displaying caugi graphs.
#' Similar to ggplot objects, these are created by the plot method but
#' not drawn until explicitly printed or plotted. This allows for
#' returning plot objects from functions and controlling when/where
#' they are displayed.
#'
#' @param grob A grid gTree representing the graph plot.
#'
#' @family plotting
#' @concept plotting
#'
#' @export
caugi_plot <- S7::new_class(
  "caugi_plot",
  properties = list(
    grob = S7::class_any
  )
)

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
