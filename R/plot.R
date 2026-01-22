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
#'   * `"auto"`: Automatically choose the best layout (default). Selection order:
#'     1. If `tiers` is provided, uses `"tiered"`
#'     2. If `partition` is provided, uses `"bipartite"`
#'     3. If graph has only directed edges, uses `"sugiyama"`
#'     4. Otherwise, uses `"fruchterman-reingold"`
#'   * `"sugiyama"`: Hierarchical layout for DAGs (requires only directed edges)
#'   * `"fruchterman-reingold"`: Fast spring-electrical layout (works with all
#'     edge types)
#'   * `"kamada-kawai"`: High-quality stress minimization (works with all edge
#'     types)
#'   * `"bipartite"`: Bipartite layout (requires `partition` parameter)
#'   * `"tiered"`: Multi-tier layout (requires `tiers` parameter)
#' @param packing_ratio Aspect ratio for packing disconnected components
#'   (width/height). Default is the golden ratio (1.618) which works well with
#'   widescreen displays. Use `1.0` for square grid, `2.0` for wider layouts,
#'   `0.5` for taller layouts, `Inf` for single row, or `0.0` for single column.
#' @param ... Additional arguments passed to the specific layout function.
#'   For bipartite layouts, use `partition` (logical vector) and `orientation`
#'   (`"columns"` or `"rows"`).
#'   For tiered layouts, use `tiers` (list, named vector, or data.frame) and
#'   `orientation` (`"rows"` or `"columns"`).
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
#' # Auto-selects tiered when tiers provided
#' cg_tiered <- caugi(X1 %-->% M1, X2 %-->% M2, M1 %-->% Y, M2 %-->% Y)
#' tiers <- list(c("X1", "X2"), c("M1", "M2"), "Y")
#' layout_auto <- caugi_layout(cg_tiered, tiers = tiers) # Uses "tiered"
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
#' # Tiered layout with three tiers
#' cg_tiered <- caugi(
#'   X1 %-->% M1 + M2,
#'   X2 %-->% M1 + M2,
#'   M1 %-->% Y,
#'   M2 %-->% Y
#' )
#' tiers <- list(c("X1", "X2"), c("M1", "M2"), "Y")
#' layout_tiered <- caugi_layout(
#'   cg_tiered,
#'   method = "tiered",
#'   tiers = tiers,
#'   orientation = "rows"
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
    "bipartite",
    "tiered"
  ),
  packing_ratio = 1.618034,
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
      # Check for special layout parameters in ...
      dots <- list(...)

      # If tiers provided, use tiered layout
      if (!is.null(dots$tiers)) {
        caugi_layout_tiered
      } else if (!is.null(dots$partition)) {
        # If partition provided, use bipartite layout
        caugi_layout_bipartite
      } else {
        # Otherwise, choose based on edge types
        edge_types <- unique(edges(x)[["edge"]])
        non_directed <- setdiff(edge_types, "-->")
        if (length(non_directed) == 0) {
          caugi_layout_sugiyama
        } else {
          caugi_layout_fruchterman_reingold
        }
      }
    },
    "sugiyama" = caugi_layout_sugiyama,
    "fruchterman-reingold" = caugi_layout_fruchterman_reingold,
    "kamada-kawai" = caugi_layout_kamada_kawai,
    "bipartite" = caugi_layout_bipartite,
    "tiered" = caugi_layout_tiered
  )

  # Call the layout function with appropriate parameters
  # Bipartite and tiered layouts don't use packing_ratio
  if (
    identical(layout_fn, caugi_layout_bipartite) ||
      identical(layout_fn, caugi_layout_tiered)
  ) {
    layout_fn(x, ...)
  } else {
    layout_fn(x, packing_ratio = packing_ratio, ...)
  }
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
#'   * `"columns"`: Two vertical columns. First partition on right (x=1),
#'     second partition on left (x=0).
#'   * `"rows"`: Two horizontal rows. First partition on top (y=1),
#'     second partition on bottom (y=0).
#'
#' @returns A `data.frame` with columns `name`, `x`, and `y` containing node
#'   names and their coordinates.
#'
#' @examples
#' # Create a bipartite graph (causes -> effects)
#' cg <- caugi(A %-->% X, A %-->% Y, B %-->% X, B %-->% Y)
#' partition <- c(TRUE, TRUE, FALSE, FALSE) # A, B = causes, X, Y = effects
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
  orientation = c("columns", "rows")
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

#' Tiered Graph Layout
#'
#' Computes node coordinates for graphs with multiple tiers (layers), placing
#' nodes in parallel rows or columns based on tier assignments. If the graph
#' has not been built yet, it will be built automatically before computing
#' the layout.
#'
#' @param x A `caugi` object.
#' @param tiers Tier assignments specifying which tier each node belongs to.
#'   Can be provided in multiple formats:
#'   * **Named list**: List where each element is a character vector of node
#'     names belonging to that tier. Element names are ignored; tier order is
#'     determined by list order (first element = tier 0, etc.).
#'   * **Named numeric vector**: Vector where names are node names and values
#'     are tier indices (starting from 0 or 1).
#'   * **Data.frame**: Must contain columns `name` (node names) and `tier`
#'     (tier indices).
#'
#'   All nodes must be assigned to a tier, all tiers must be non-empty, and
#'   tier indices must be consecutive starting from 0 or 1.
#' @param orientation Character string specifying the layout orientation:
#'   * `"columns"`: Vertical tiers. First tier at left (x=0),
#'     subsequent tiers to the right, last tier at right (x=1).
#'   * `"rows"`: Horizontal tiers. First tier at top (y=1),
#'     subsequent tiers below, last tier at bottom (y=0).
#'
#' @returns A `data.frame` with columns `name`, `x`, `y`, and `tier` containing
#'   node names, their coordinates, and tier assignments (0-indexed). The
#'   returned data.frame also has an `orientation` attribute storing the
#'   orientation used. When passed to `plot()`, tier information is
#'   automatically extracted, so you don't need to specify `tiers` again.
#'
#' @examples
#' # Create a three-tier causal graph (exposures -> mediators -> outcome)
#' cg <- caugi(
#'   X1 %-->% M1 + M2,
#'   X2 %-->% M1 + M2,
#'   M1 %-->% Y,
#'   M2 %-->% Y
#' )
#'
#' # Option 1: Named list (tier names are just labels)
#' tiers <- list(
#'   exposures = c("X1", "X2"),
#'   mediators = c("M1", "M2"),
#'   outcome = "Y"
#' )
#' layout_rows <- caugi_layout_tiered(cg, tiers, orientation = "rows")
#'
#' # Option 2: Named numeric vector (0-indexed or 1-indexed both work)
#' tiers <- c(X1 = 1, X2 = 1, M1 = 2, M2 = 2, Y = 3)
#' layout_cols <- caugi_layout_tiered(cg, tiers, orientation = "columns")
#'
#' # Option 3: Data.frame
#' tiers <- data.frame(
#'   name = c("X1", "X2", "M1", "M2", "Y"),
#'   tier = c(1, 1, 2, 2, 3)
#' )
#' layout <- caugi_layout_tiered(cg, tiers, orientation = "rows")
#'
#' # The layout includes tier information, so plot() works without passing tiers
#' plot(cg, layout = layout)
#'
#' @family plotting
#' @concept plotting
#'
#' @export
caugi_layout_tiered <- function(
  x,
  tiers,
  orientation = c("columns", "rows")
) {
  is_caugi(x, throw_error = TRUE)

  orientation <- match.arg(orientation)

  # Ensure graph is built
  if (!x@built) {
    x <- build(x)
  }

  node_names <- nodes(x)[["name"]]
  n_nodes <- length(node_names)

  # Normalize tiers to a named integer vector (node name -> tier index)
  tier_assignments <- NULL

  if (is.list(tiers) && !is.data.frame(tiers)) {
    # Named list format: list(tier1 = c("A", "B"), tier2 = c("C"))
    tier_assignments <- integer(n_nodes)
    names(tier_assignments) <- node_names

    for (tier_idx in seq_along(tiers)) {
      tier_nodes <- tiers[[tier_idx]]
      if (!is.character(tier_nodes)) {
        stop(
          "Each tier in the list must be a character vector of node names",
          call. = FALSE
        )
      }
      for (node_name in tier_nodes) {
        if (!(node_name %in% node_names)) {
          stop(
            "Node '",
            node_name,
            "' in tier ",
            tier_idx,
            " is not in the graph",
            call. = FALSE
          )
        }
        tier_assignments[node_name] <- tier_idx - 1 # 0-indexed
      }
    }
  } else if (is.numeric(tiers) && !is.null(names(tiers))) {
    # Named numeric vector format: c(A = 0, B = 0, C = 1)
    tier_assignments <- as.integer(tiers)
    names(tier_assignments) <- names(tiers)

    # Check all nodes are present
    if (!all(node_names %in% names(tier_assignments))) {
      missing <- setdiff(node_names, names(tier_assignments))
      stop(
        "Missing tier assignments for nodes: ",
        paste(missing, collapse = ", "),
        call. = FALSE
      )
    }

    # Reorder to match node order
    tier_assignments <- tier_assignments[node_names]
  } else if (is.data.frame(tiers)) {
    # Data.frame format with columns 'name' and 'tier'
    if (!all(c("name", "tier") %in% colnames(tiers))) {
      stop(
        "Data.frame must have columns 'name' and 'tier'",
        call. = FALSE
      )
    }

    tier_assignments <- integer(n_nodes)
    names(tier_assignments) <- node_names

    for (i in seq_len(nrow(tiers))) {
      node_name <- as.character(tiers$name[i])
      tier_idx <- as.integer(tiers$tier[i])

      if (!(node_name %in% node_names)) {
        stop(
          "Node '",
          node_name,
          "' in tiers data.frame is not in the graph",
          call. = FALSE
        )
      }

      tier_assignments[node_name] <- tier_idx
    }
  } else {
    stop(
      "tiers must be a named list, named numeric vector, or data.frame ",
      "with 'name' and 'tier' columns",
      call. = FALSE
    )
  }

  # Normalize tier indices to start from 0
  min_tier <- min(tier_assignments)
  if (min_tier < 0) {
    stop("Tier indices must be non-negative", call. = FALSE)
  }
  if (min_tier > 0) {
    tier_assignments <- as.integer(tier_assignments - min_tier)
  }

  # Validate: all nodes assigned, tiers are consecutive
  if (anyNA(tier_assignments)) {
    unassigned <- node_names[is.na(tier_assignments)]
    stop(
      "Nodes without tier assignments: ",
      paste(unassigned, collapse = ", "),
      call. = FALSE
    )
  }

  unique_tiers <- sort(unique(tier_assignments))
  num_tiers <- length(unique_tiers)
  expected_tiers <- seq(from = unique_tiers[1], length.out = num_tiers)

  if (!identical(unique_tiers, expected_tiers)) {
    stop(
      "Tier indices must be consecutive integers. ",
      "Found tiers: ",
      paste(sort(unique(tier_assignments + min_tier)), collapse = ", "),
      call. = FALSE
    )
  }

  # Check all tiers are non-empty (this should already be guaranteed by unique_tiers)
  tier_counts <- table(tier_assignments)
  if (any(tier_counts == 0)) {
    empty_tiers <- which(tier_counts == 0)
    stop(
      "Tiers cannot be empty. Empty tiers: ",
      paste(empty_tiers, collapse = ", "),
      call. = FALSE
    )
  }

  # Call Rust function
  coords <- compute_tiered_layout_ptr(
    x@ptr,
    as.integer(tier_assignments),
    as.integer(num_tiers),
    orientation
  )

  result <- data.frame(
    name = node_names,
    x = coords[["x"]],
    y = coords[["y"]],
    tier = as.integer(tier_assignments),
    stringsAsFactors = FALSE
  )

  # Store orientation as attribute for plot() to use
  attr(result, "orientation") <- orientation

  result
}

#' Sugiyama Hierarchical Layout
#'
#' Computes node coordinates using the Sugiyama hierarchical layout algorithm.
#' Optimized for directed acyclic graphs (DAGs), placing nodes in layers to
#' emphasize hierarchical structure and causal flow from top to bottom.
#'
#' @param x A `caugi` object. Must contain only directed edges.
#' @param ... Ignored. For future extensibility.
#' @inheritParams caugi_layout
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
caugi_layout_sugiyama <- function(x, packing_ratio = 1.618034, ...) {
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

  coords <- compute_layout_ptr(x@ptr, "sugiyama", packing_ratio)

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
#' @inheritParams caugi_layout
#' @param ... Ignored. For future extensibility.
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
caugi_layout_fruchterman_reingold <- function(
  x,
  packing_ratio = 1.618034,
  ...
) {
  is_caugi(x, throw_error = TRUE)

  # Ensure graph is built
  if (!x@built) {
    x <- build(x)
  }

  coords <- compute_layout_ptr(x@ptr, "fruchterman-reingold", packing_ratio)

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
#' @inheritParams caugi_layout
#' @param ... Ignored. For future extensibility.
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
caugi_layout_kamada_kawai <- function(x, packing_ratio = 1.618034, ...) {
  is_caugi(x, throw_error = TRUE)

  # Ensure graph is built
  if (!x@built) {
    x <- build(x)
  }

  coords <- compute_layout_ptr(x@ptr, "kamada-kawai", packing_ratio)

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
#'     or `by_tier = list(`1` = list(fill = "lightblue"))`
#' @param main Optional character string for plot title. If `NULL` (default),
#'   no title is displayed.
#' @param title_style List of title styling parameters. Supports:
#'   * Appearance (passed to `gpar()`): `col`, `fontsize`, `fontface`,
#'     `fontfamily`, `cex`
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
  outer_margin = grid::unit(2, "mm"),
  title_gap = grid::unit(1, "lines"),
  ...
) {
  is_caugi(x, throw_error = TRUE)

  # Ensure graph is built
  if (!x@built) {
    x <- build(x)
  }

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

    coords <- layout

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
