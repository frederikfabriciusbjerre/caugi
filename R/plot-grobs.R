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

make_tiers <- function(
  circle_grobs,
  coords,
  tiers,
  tier_style,
  orientation = "rows"
) {
  # Reconstruct tier assignments from tiers_arg
  node_names <- coords$name
  n_nodes <- length(node_names)
  assignments <- integer(n_nodes)
  names(assignments) <- node_names

  if (is.list(tiers) && !is.data.frame(tiers)) {
    # Named list format
    for (tier_idx in seq_along(tiers)) {
      tier_nodes <- tiers[[tier_idx]]
      for (node_name in tier_nodes) {
        assignments[node_name] <- tier_idx - 1 # 0-indexed
      }
    }
  } else if (is.numeric(tiers) && !is.null(names(tiers))) {
    # Named numeric vector
    assignments <- as.integer(tiers[node_names])
  } else if (is.data.frame(tiers)) {
    # Data.frame format
    for (i in seq_len(nrow(tiers))) {
      node_name <- as.character(tiers$name[i])
      tier_idx <- as.integer(tiers$tier[i])
      assignments[node_name] <- tier_idx
    }
  }

  # Normalize to 0-indexed
  min_tier <- min(assignments)
  if (min_tier > 0) {
    assignments <- assignments - min_tier
  }

  # Extract components
  by_tier <- tier_style$by_tier

  padding <- tier_style$global$padding

  do_labels <- tier_style$global$labels
  do_boxes <- tier_style$global$boxes

  # Extract tier names if tiers_arg is a named list
  tier_names <- NULL
  if (
    is.list(tiers) &&
      !is.null(names(tiers)) &&
      any(names(tiers) != "")
  ) {
    tier_names <- names(tiers)
  }

  # Determine tier assignments based on user-specified orientation
  # For rows orientation: tiers are horizontal (group by y coordinate)
  # For columns orientation: tiers are vertical (group by x coordinate)

  n_tiers <- length(unique(assignments))

  if (n_tiers == 0) {
    return(list(grobs = grid::gList(grid::nullGrob())))
  }

  label_grobs <- NULL
  tier_labels <- NULL

  if (!is.null(do_labels)) {
    if (is.logical(do_labels) && do_labels[1]) {
      # Use tier names if available
      if (!is.null(tier_names) && length(tier_names) >= n_tiers) {
        tier_labels <- tier_names[seq_len(n_tiers)]
      }
    } else if (is.character(do_labels)) {
      # Use custom labels
      tier_labels <- do_labels
      if (length(tier_labels) < n_tiers) {
        # Recycle if needed
        tier_labels <- rep_len(tier_labels, n_tiers)
      }
    }

    label_grobs <- grid::gList()
  }

  # Create grobs for each tier
  tier_grobs <- grid::gList()

  for (i in seq_len(n_tiers)) {
    ind <- which((assignments + 1L) %in% i)

    if (!any(ind)) {
      next
    }

    circle_grobs_i <- circle_grobs[ind]

    x_min <- min(grid::grobX(circle_grobs_i, "west")) - padding
    x_max <- max(grid::grobX(circle_grobs_i, 0)) + padding

    y_min <- min(grid::grobY(circle_grobs_i, "south")) - padding
    y_max <- max(grid::grobY(circle_grobs_i, "north")) + padding
    y_mid <- (y_min + y_max) / 2

    h <- y_max - y_min
    w <- x_max - x_min

    # Calculate bounding box for this tier
    tier_coords <- coords[ind, , drop = FALSE]

    # Get style for this tier
    # Start with global/vector style
    style <- lapply(tier_style$global, function(val) {
      if (length(val) >= i) val[i] else val[1]
    })

    # Apply by_tier overrides (try both index and name)
    tier_override <- NULL

    # Try numeric index first
    if (!is.null(by_tier[[as.character(i)]])) {
      tier_override <- by_tier[[as.character(i)]]
    }

    # Try tier name if available
    if (!is.null(tier_names) && i <= length(tier_names)) {
      tier_name <- tier_names[i]
      if (!is.null(by_tier[[tier_name]])) {
        tier_override <- utils::modifyList(
          tier_override %||% list(),
          by_tier[[tier_name]]
        )
      }
    }

    if (!is.null(tier_override)) {
      style <- utils::modifyList(style, tier_override)
    }

    gpar_params <- get_gpar_params(style)

    # Only create box grob if boxes are enabled
    if (isTRUE(do_boxes)) {
      tier_grobs[[i]] <- grid::rectGrob(
        x = x_min,
        y = y_mid,
        width = w,
        height = h,
        just = c("left", "center"),
        gp = do.call(grid::gpar, gpar_params),
        name = paste0("tier_box_", i)
      )
    }

    # TODO: Make this padding configurable
    tier_label_padding <- grid::unit(3, "mm")

    # Create label grob if labels are enabled
    if (!is.null(tier_labels) && i <= length(tier_labels)) {
      label_text <- tier_labels[i]
      label_style <- tier_style$global$label_style

      if (!is.null(tier_style$by_tier[[label_text]]$label_style)) {
        label_style <- utils::modifyList(
          label_style,
          tier_style$by_tier[[label_text]]$label_style
        )
      }

      if (!is.na(label_text) && label_text != "") {
        label_gpar <- do.call(grid::gpar, get_gpar_params(label_style))

        if (orientation == "rows") {
          # Rows: horizontal tiers stacked vertically, label to the right
          label_x <- x_max + tier_label_padding
          label_y <- y_mid
          label_just <- c("left", "center")
        } else {
          # Columns: vertical tiers side-by-side, label above
          label_x <- (x_min + x_max) / 2
          label_y <- y_max + tier_label_padding
          label_just <- c("center", "bottom")
        }

        label_grobs[[i]] <- grid::textGrob(
          label = label_text,
          x = label_x,
          y = label_y,
          just = label_just,
          gp = label_gpar,
          name = paste0("tier_label_", i)
        )
      }
    }
  }

  if (length(tier_grobs) == 0) {
    return(list(grobs = NULL, label_grobs = NULL))
  }

  # Return grobs and bounding box
  list(
    grobs = tier_grobs,
    label_grobs = label_grobs,
    orientation = orientation
  )
}

make_styles <- function(
  edge_style,
  node_style,
  label_style,
  title_style,
  tier_style
) {
  # Get global options
  opts <- get0("options", .caugi_env, ifnotfound = caugi_default_options())
  plot_opts <- opts$plot %||% list()

  # Default styles from options (with fallbacks)
  node_defaults <- plot_opts$node_style
  edge_defaults <- plot_opts$edge_style
  label_defaults <- plot_opts$label_style
  main_defaults <- plot_opts$title_style
  tier_defaults <- plot_opts$tier_style

  # Merge with user-provided styles
  node_style_global <- utils::modifyList(node_defaults, node_style)

  # Extract by-node overrides
  by_node <- node_style$by_node %||% list()
  node_style <- list(
    global = node_style_global,
    by_node = by_node
  )

  # Handle edge styles - support both global and per-type
  edge_type_names <- c("directed", "undirected", "bidirected", "partial")
  global_edge_opts <- edge_style[setdiff(
    names(edge_style),
    c(edge_type_names, "by_edge")
  )]

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
      utils::modifyList(edge_defaults, global_edge_opts),
      edge_style$partial %||% list()
    )
  )

  # Extract by-edge overrides
  by_edge <- edge_style$by_edge %||% list()

  # Handle tier style - extract by_tier overrides
  tier_style <- list(
    global = utils::modifyList(tier_defaults, tier_style),
    by_tier = tier_style$by_tier %||% list()
  )

  list(
    edge_styles = edge_styles,
    edge_by_edge = by_edge,
    node_style = node_style,
    tier_style = tier_style,
    label_style = utils::modifyList(label_defaults, label_style),
    title_style = utils::modifyList(main_defaults, title_style)
  )
}

make_nodes <- function(coords, labels, node_style, label_style) {
  n_nodes <- nrow(coords)

  circle_grobs <- grid::gList()
  label_grobs <- grid::gList()
  node_radii <- vector("list", n_nodes)

  padding_global <- grid::unit(node_style$padding %||% 2, "mm")
  do_labels <- !is.null(labels) && length(labels) > 0

  for (i in seq_len(n_nodes)) {
    node_name <- coords$name[i]

    # Start with global node style
    style <- node_style$global

    # Apply per-node override if it exists
    if (!is.null(node_style$by_node[[node_name]])) {
      style <- utils::modifyList(style, node_style$by_node[[node_name]])
    }

    # Compute radius
    padding <- grid::unit(style$padding %||% padding_global, "mm")
    r <- (0.5 * grid::stringWidth(labels[i]) + padding) * style$size

    # Convert coords to grid units
    x <- grid::unit(coords$x[i], "native")
    y <- grid::unit(coords$y[i], "native")

    # Build grobs
    node_gpar <- do.call(grid::gpar, get_gpar_params(style))
    circle_grob <- grid::circleGrob(
      x = x,
      y = y,
      r = r,
      gp = node_gpar,
      name = paste0("node.", i)
    )

    label_gpar <- do.call(grid::gpar, get_gpar_params(label_style))
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
  name = NULL,
  edge_type = NULL,
  circle_size = 1.5
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
    edge_type = edge_type,
    circle_size = circle_size,
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

  # Initialize direction variables
  ux_mm <- 0
  uy_mm <- 0

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

  # Create line grob
  line_grob <- grid::linesGrob(
    x = grid::unit.c(x0_adj, x1_adj),
    y = grid::unit.c(y0_adj, y1_adj),
    arrow = x$arrow,
    gp = x$gp
  )

  # Add circles for o-> and o-o edges
  grob_list <- grid::gList(line_grob)

  if (!is.null(x$edge_type)) {
    circle_radius <- grid::unit(x$circle_size %||% 1.5, "mm")
    circle_radius_mm <- grid::convertWidth(
      circle_radius,
      "mm",
      valueOnly = TRUE
    )

    # Place circle centers just outside the node boundary.
    # x0_adj/x1_adj are already at the node boundary, so we offset by the
    # circle radius.
    if (length_mm > 0) {
      circle_x0 <- x0_adj +
        grid::convertWidth(grid::unit(ux_mm * circle_radius_mm, "mm"), "native")
      circle_y0 <- y0_adj +
        grid::convertHeight(
          grid::unit(uy_mm * circle_radius_mm, "mm"),
          "native"
        )

      circle_x1 <- x1_adj -
        grid::convertWidth(grid::unit(ux_mm * circle_radius_mm, "mm"), "native")
      circle_y1 <- y1_adj -
        grid::convertHeight(
          grid::unit(uy_mm * circle_radius_mm, "mm"),
          "native"
        )
    } else {
      circle_x0 <- x0_adj
      circle_y0 <- y0_adj
      circle_x1 <- x1_adj
      circle_y1 <- y1_adj
    }

    if (x$edge_type == "o->" || x$edge_type == "o-o") {
      grob_list <- grid::gList(
        grob_list,
        grid::circleGrob(
          x = circle_x0,
          y = circle_y0,
          r = circle_radius,
          gp = grid::gpar(col = x$gp$col, fill = "white", lwd = x$gp$lwd)
        )
      )
    }

    if (x$edge_type == "o-o") {
      grob_list <- grid::gList(
        grob_list,
        grid::circleGrob(
          x = circle_x1,
          y = circle_y1,
          r = circle_radius,
          gp = grid::gpar(col = x$gp$col, fill = "white", lwd = x$gp$lwd)
        )
      )
    }
  }

  grid::setChildren(x, grob_list)
}

make_edges <- function(
  edges,
  coords,
  node_radii,
  edge_styles,
  edge_by_edge = list()
) {
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

      r_from <- node_radii[[from_idx]]
      r_to <- node_radii[[to_idx]]

      edge_type <- edges$edge[i]

      # Base style per edge type
      style <- switch(
        edge_type,
        "-->" = edge_styles$directed,
        "---" = edge_styles$undirected,
        "<->" = edge_styles$bidirected,
        "o->" = edge_styles$partial,
        "o-o" = edge_styles$partial,
        edge_styles$undirected
      )

      # ----- Apply nested by_edge overrides -----
      override <- list()

      # Specific edge override: from → to
      if (
        !is.null(edge_by_edge[[edges$from[i]]]) &&
          !is.null(edge_by_edge[[edges$from[i]]][[edges$to[i]]])
      ) {
        override <- utils::modifyList(
          override,
          edge_by_edge[[edges$from[i]]][[edges$to[i]]]
        )
      } else if (
        !is.null(edge_by_edge[[edges$to[i]]]) &&
          !is.null(edge_by_edge[[edges$to[i]]][[edges$from[i]]])
      ) {
        # Specific edge override: to → from
        override <- utils::modifyList(
          override,
          edge_by_edge[[edges$to[i]]][[edges$from[i]]]
        )
      }

      # Node-wide override for 'from'
      if (!is.null(edge_by_edge[[edges$from[i]]])) {
        node_wide <- edge_by_edge[[edges$from[i]]]
        # Only keep top-level non-list entries (styles, not nested edges)
        node_wide <- node_wide[!sapply(node_wide, is.list)]
        if (length(node_wide) > 0) {
          override <- utils::modifyList(node_wide, override)
          # node-wide entries are merged before specific edges, so specific edge takes precedence
        }
      }

      # Node-wide override for 'to'
      if (!is.null(edge_by_edge[[edges$to[i]]])) {
        node_wide <- edge_by_edge[[edges$to[i]]]
        node_wide <- node_wide[!sapply(node_wide, is.list)]
        if (length(node_wide) > 0) {
          override <- utils::modifyList(node_wide, override)
        }
      }

      if (length(override) > 0) {
        style <- utils::modifyList(style, override)
      }

      # ------------------------------------------

      # Arrow
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
        "o->" = grid::arrow(
          length = grid::unit(style$arrow_size, "mm"),
          type = "closed"
        ),
        "o-o" = NULL,
        NULL
      )

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
        name = paste0("edge.", i),
        edge_type = edge_type,
        circle_size = style$circle_size
      )
    }
  }

  edge_grobs
}
