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
