#' Compute Graph Layout
#'
#' Computes node coordinates for graph visualization using
#' specified layout algorithm. If the graph has not been built yet, it will
#' be built automatically before computing the layout.
#'
#' @section Layout Algorithms:
#'
#' **Sugiyama (Hierarchical Layout)**
#'
#' Optimized for directed acyclic graphs (DAGs). Places nodes in layers to
#' emphasize hierarchical structure and causal flow from top to bottom. Edges
#' are routed to minimize crossings. Best for visualizing clear cause-effect
#' relationships. Only works with directed edges.
#'
#' **Fruchterman-Reingold (Spring-Electrical)**
#'
#' Fast force-directed layout using a spring-electrical model. Treats edges as
#' springs and nodes as electrically charged particles. Produces organic,
#' symmetric layouts with uniform edge lengths. Good for general-purpose
#' visualization and works with all edge types. Results are deterministic.
#'
#' **Kamada-Kawai (Stress Minimization)**
#'
#' High-quality force-directed layout that minimizes "stress" by making
#' Euclidean distances proportional to graph-theoretic distances. Better
#' preserves the global structure and path lengths compared to
#' Fruchterman-Reingold. Ideal for publication-quality visualizations where
#' accurate distance representation matters. Works with all edge types and
#' produces deterministic results.
#'
#' @param x A `caugi` object. Must contain only directed edges for Sugiyama
#'   layout.
#' @param method Character string specifying the layout method. Options:
#'   * `"auto"`: Automatically choose sugiyama for graphs with only directed
#'     edges, otherwise fruchterman-reingold (default)
#'   * `"sugiyama"`: Hierarchical layout for DAGs (requires only directed edges)
#'   * `"fruchterman-reingold"`: Fast spring-electrical layout (works with all
#'     edge types)
#'   * `"kamada-kawai"`: High-quality stress minimization (works with all edge
#'     types)
#'   * `"bipartite"`: Bipartite layout (requires `partition` parameter)
#' @param ... Additional arguments passed to the specific layout function.
#'   For bipartite layouts, use `partition` (logical vector) and `orientation`
#'   (`"rows"` or `"columns"`).
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
#'
#' # Default: auto-selects best layout
#' layout <- caugi_layout(cg)
#'
#' # Explicitly use hierarchical layout
#' layout_sug <- caugi_layout(cg, method = "sugiyama")
#'
#' # Use force-directed for organic appearance
#' layout_fr <- caugi_layout(cg, method = "fruchterman-reingold")
#'
#' # Use stress minimization for publication quality
#' layout_kk <- caugi_layout(cg, method = "kamada-kawai")
#'
#' # Bipartite layout with auto-detected partition
#' cg_bp <- caugi(A %-->% X, A %-->% Y, B %-->% X, B %-->% Y)
#' layout_bp_rows <- caugi_layout(
#'   cg_bp,
#'   method = "bipartite",
#'   orientation = "rows"
#' )
#'
#' # Explicit partition
#' partition <- c(TRUE, TRUE, FALSE, FALSE)
#' layout_bp_cols <- caugi_layout(
#'   cg_bp,
#'   method = "bipartite",
#'   partition = partition,
#'   orientation = "columns"
#' )
#'
#' @family plotting
#' @concept plotting
#'
#' @source Fruchterman, T. M. J., & Reingold, E. M. (1991). Graph drawing by
#' force-directed placement. Software: Practice and Experience, 21(11),
#' 1129-1164. \doi{10.1002/spe.4380211102}
#'
#' @source Kamada, T., & Kawai, S. (1989). An algorithm for drawing general
#' undirected graphs. Information Processing Letters, 31(1), 7-15.
#' \doi{10.1016/0020-0190(89)90102-6}
#'
#' @source Sugiyama, K., Tagawa, S., & Toda, M. (1981). Methods for visual
#' understanding of hierarchical system structures. IEEE Transactions on
#' Systems, Man, and Cybernetics, 11(2), 109-125.
#' \doi{10.1109/TSMC.1981.4308636}
#'
#' @export
caugi_layout <- function(
  x,
  method = c(
    "auto",
    "sugiyama",
    "fruchterman-reingold",
    "kamada-kawai",
    "bipartite"
  ),
  ...
) {
  is_caugi(x, throw_error = TRUE)

  method <- match.arg(method)

  # Ensure graph is built
  if (!x@built) {
    x <- build(x)
  }

  # Dispatch to specific layout function
  layout_fn <- switch(
    method,
    "auto" = {
      edge_types <- unique(edges(x)[["edge"]])
      non_directed <- setdiff(edge_types, "-->")
      if (length(non_directed) == 0) {
        caugi_layout_sugiyama
      } else {
        caugi_layout_fruchterman_reingold
      }
    },
    "sugiyama" = caugi_layout_sugiyama,
    "fruchterman-reingold" = caugi_layout_fruchterman_reingold,
    "kamada-kawai" = caugi_layout_kamada_kawai,
    "bipartite" = caugi_layout_bipartite
  )

  layout_fn(x, ...)
}

#' Bipartite Graph Layout
#'
#' Computes node coordinates for bipartite graphs, placing nodes in two
#' parallel lines (rows or columns) based on a partition. If the graph
#' has not been built yet, it will be built automatically before computing
#' the layout.
#'
#' @param x A `caugi` object.
#' @param partition Optional logical vector indicating node partitions.
#'   Nodes with `TRUE` are placed in one partition and nodes with `FALSE`
#'   in the other. Length must equal the number of nodes. Both partitions
#'   must be non-empty. If `NULL` (default), attempts to detect bipartite
#'   structure automatically by assigning nodes without incoming edges to
#'   one partition and others to the second partition.
#' @param orientation Character string specifying the layout orientation:
#'   * `"rows"`: Two horizontal rows (default). First partition on top (y=1),
#'     second partition on bottom (y=0).
#'   * `"columns"`: Two vertical columns. First partition on right (x=1),
#'     second partition on left (x=0).
#'
#' @returns A `data.frame` with columns `name`, `x`, and `y` containing node
#'   names and their coordinates.
#'
#' @examples
#' # Create a bipartite graph (causes -> effects)
#' cg <- caugi(A %-->% X, A %-->% Y, B %-->% X, B %-->% Y)
#' partition <- c(TRUE, TRUE, FALSE, FALSE)  # A, B = causes, X, Y = effects
#'
#' # Two horizontal rows (causes on top)
#' layout_rows <- caugi_layout_bipartite(cg, partition, orientation = "rows")
#'
#' # Two vertical columns (causes on right)
#' layout_cols <- caugi_layout_bipartite(cg, partition, orientation = "columns")
#'
#' @family plotting
#' @concept plotting
#'
#' @export
caugi_layout_bipartite <- function(
  x,
  partition = NULL,
  orientation = c("rows", "columns")
) {
  is_caugi(x, throw_error = TRUE)

  orientation <- match.arg(orientation)

  # Ensure graph is built
  if (!x@built) {
    x <- build(x)
  }

  # Auto-detect partition if not provided
  if (is.null(partition)) {
    # Simple heuristic: nodes with no incoming edges vs nodes with
    # incoming edges
    edges_df <- edges(x)
    node_names <- nodes(x)[["name"]]

    # Check which nodes have incoming edges
    has_incoming <- node_names %in% edges_df$to

    partition <- !has_incoming # TRUE for source nodes, FALSE for others

    # Check if partition is valid (both parts non-empty)
    if (all(partition) || all(!partition)) {
      stop(
        "Could not automatically detect bipartite structure. ",
        "Please provide a 'partition' argument explicitly.",
        call. = FALSE
      )
    }
  } else {
    if (!is.logical(partition)) {
      stop("partition must be a logical vector", call. = FALSE)
    }

    if (length(partition) != nrow(nodes(x))) {
      stop(
        "partition length (",
        length(partition),
        ") ",
        "does not match number of nodes (",
        nrow(nodes(x)),
        ")",
        call. = FALSE
      )
    }
  }

  coords <- compute_bipartite_layout_ptr(x@ptr, partition, orientation)

  data.frame(
    name = nodes(x)[["name"]],
    x = coords[["x"]],
    y = coords[["y"]],
    stringsAsFactors = FALSE
  )
}

#' Sugiyama Hierarchical Layout
#'
#' Computes node coordinates using the Sugiyama hierarchical layout algorithm.
#' Optimized for directed acyclic graphs (DAGs), placing nodes in layers to
#' emphasize hierarchical structure and causal flow from top to bottom.
#'
#' @param x A `caugi` object. Must contain only directed edges.
#'
#' @returns A `data.frame` with columns `name`, `x`, and `y` containing node
#'   names and their coordinates.
#'
#' @examples
#' cg <- caugi(A %-->% B + C, B %-->% D, C %-->% D, class = "DAG")
#' layout <- caugi_layout_sugiyama(cg)
#'
#' @family plotting
#' @concept plotting
#'
#' @source Sugiyama, K., Tagawa, S., & Toda, M. (1981). Methods for visual
#' understanding of hierarchical system structures. IEEE Transactions on
#' Systems, Man, and Cybernetics, 11(2), 109-125.
#' \doi{10.1109/TSMC.1981.4308636}
#'
#' @export
caugi_layout_sugiyama <- function(x) {
  is_caugi(x, throw_error = TRUE)

  # Ensure graph is built
  if (!x@built) {
    x <- build(x)
  }

  edge_types <- unique(edges(x)[["edge"]])
  non_directed <- setdiff(edge_types, "-->")

  if (length(non_directed) > 0) {
    stop(
      "Sugiyama layout only supports graphs with directed edges. ",
      "Found edge type(s): ",
      paste(non_directed, collapse = ", "),
      ". ",
      "Consider using caugi_layout_fruchterman_reingold() or ",
      "caugi_layout_kamada_kawai() for graphs with mixed edge types.",
      call. = FALSE
    )
  }

  coords <- compute_layout_ptr(x@ptr, "sugiyama")

  data.frame(
    name = nodes(x)[["name"]],
    x = coords[["x"]],
    y = coords[["y"]],
    stringsAsFactors = FALSE
  )
}

#' Fruchterman-Reingold Force-Directed Layout
#'
#' Computes node coordinates using the Fruchterman-Reingold force-directed
#' layout algorithm. Fast spring-electrical model that treats edges as springs
#' and nodes as electrically charged particles. Produces organic, symmetric
#' layouts with uniform edge lengths. Works with all edge types and produces
#' deterministic results.
#'
#' @param x A `caugi` object.
#'
#' @returns A `data.frame` with columns `name`, `x`, and `y` containing node
#'   names and their coordinates.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   B %<->% C,
#'   C %-->% D
#' )
#' layout <- caugi_layout_fruchterman_reingold(cg)
#'
#' @family plotting
#' @concept plotting
#'
#' @source Fruchterman, T. M. J., & Reingold, E. M. (1991). Graph drawing by
#' force-directed placement. Software: Practice and Experience, 21(11),
#' 1129-1164. \doi{10.1002/spe.4380211102}
#'
#' @export
caugi_layout_fruchterman_reingold <- function(x) {
  is_caugi(x, throw_error = TRUE)

  # Ensure graph is built
  if (!x@built) {
    x <- build(x)
  }

  coords <- compute_layout_ptr(x@ptr, "fruchterman-reingold")

  data.frame(
    name = nodes(x)[["name"]],
    x = coords[["x"]],
    y = coords[["y"]],
    stringsAsFactors = FALSE
  )
}

#' Kamada-Kawai Stress Minimization Layout
#'
#' Computes node coordinates using the Kamada-Kawai stress minimization
#' algorithm. High-quality force-directed layout that minimizes "stress" by
#' making Euclidean distances proportional to graph-theoretic distances. Better
#' preserves global structure and path lengths compared to Fruchterman-Reingold.
#' Ideal for publication-quality visualizations. Works with all edge types and
#' produces deterministic results.
#'
#' @param x A `caugi` object.
#'
#' @returns A `data.frame` with columns `name`, `x`, and `y` containing node
#'   names and their coordinates.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   B %<->% C,
#'   C %-->% D
#' )
#' layout <- caugi_layout_kamada_kawai(cg)
#'
#' @family plotting
#' @concept plotting
#'
#' @source Kamada, T., & Kawai, S. (1989). An algorithm for drawing general
#' undirected graphs. Information Processing Letters, 31(1), 7-15.
#' \doi{10.1016/0020-0190(89)90102-6}
#'
#' @export
caugi_layout_kamada_kawai <- function(x) {
  is_caugi(x, throw_error = TRUE)

  # Ensure graph is built
  if (!x@built) {
    x <- build(x)
  }

  coords <- compute_layout_ptr(x@ptr, "kamada-kawai")

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
  ...
) {
  is_caugi(x, throw_error = TRUE)

  # Ensure graph is built
  if (!x@built) {
    x <- build(x)
  }

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

    coords <- layout
  } else {
    stop(
      "layout must be a character string, function, or data.frame",
      call. = FALSE
    )
  }

  # TODO: Consider letting this be a parameter
  margin <- grid::unit(2, "mm")

  styles <- make_styles(
    edge_style = edge_style,
    node_style = node_style,
    label_style = label_style
  )

  labels <- nodes(x)[["name"]]
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
