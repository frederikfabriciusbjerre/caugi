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
#' **Circle**
#'
#' Places nodes evenly along the perimeter of a circle. The first node is at
#' the top and subsequent nodes proceed counter-clockwise. Useful for small
#' graphs, cycle visualization, and as a deterministic fallback. Works with
#' all edge types and ignores edge structure.
#'
#' **Bipartite**
#'
#' Places nodes in two parallel rows or columns, one per side of a
#' `partition`.
#'
#' **Tiered**
#'
#' Places nodes in parallel rows or columns, one per tier of `tiers`.
#'
#' @param cg A `caugi` object. Must contain only directed edges for Sugiyama
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
#'   * `"circle"`: Place nodes evenly along a circle
#' @param packing_ratio Aspect ratio for packing disconnected components
#'   (width/height). Default is the golden ratio (1.618) which works well with
#'   widescreen displays. Use `1.0` for square grid, `2.0` for wider layouts,
#'   `0.5` for taller layouts, `Inf` for single row, or `0.0` for single column.
#' @param ... Arguments of the `"bipartite"` and `"tiered"` methods:
#'   * `partition` (bipartite): Optional logical vector with one value per
#'     node. Nodes with `TRUE` are placed in one partition and nodes with
#'     `FALSE` in the other; both must be non-empty. If `NULL` (default), the
#'     nodes without incoming edges form one partition and the rest the other.
#'   * `tiers` (tiered): The tier of each node, as a list of character vectors
#'     of node names, one per tier in order (element names are ignored); a
#'     numeric vector of tier indices named by node; or a data.frame with
#'     columns `name` and `tier`. Every node must be in a tier, no tier may be
#'     empty, and tier indices must be consecutive from 0 or 1.
#'   * `orientation`: `"columns"` (default) or `"rows"`. With `"columns"`, the
#'     first partition is the right column (x = 1) and the first tier the left
#'     column (x = 0). With `"rows"`, the first partition or tier is the top
#'     row (y = 1).
#'
#' @returns A `data.frame` with columns `name`, `x`, and `y` containing node
#'   names and their coordinates. The `"tiered"` method adds a `tier` column
#'   (0-indexed) and an `orientation` attribute, which `plot()` reads, so the
#'   tiers need not be passed again.
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
#' # Place nodes on a circle
#' layout_circle <- caugi_layout(cg, method = "circle")
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
  cg,
  method = c(
    "auto",
    "sugiyama",
    "fruchterman-reingold",
    "kamada-kawai",
    "bipartite",
    "tiered",
    "circle"
  ),
  packing_ratio = 1.618034,
  ...
) {
  is_caugi(cg, throw_error = TRUE)

  method <- match.arg(method)

  # Dispatch to specific layout function
  layout_fn <- switch(
    method,
    "auto" = {
      # Check for special layout parameters in ...
      dots <- list(...)

      # If tiers provided, use tiered layout
      if (!is.null(dots$tiers)) {
        .layout_tiered
      } else if (!is.null(dots$partition)) {
        # If partition provided, use bipartite layout
        .layout_bipartite
      } else {
        # Otherwise, choose based on edge types
        edge_types <- unique(edges(cg)[["edge"]])
        non_directed <- setdiff(edge_types, "-->")
        if (length(non_directed) == 0) {
          .layout_sugiyama
        } else {
          .layout_fruchterman_reingold
        }
      }
    },
    "sugiyama" = .layout_sugiyama,
    "fruchterman-reingold" = .layout_fruchterman_reingold,
    "kamada-kawai" = .layout_kamada_kawai,
    "bipartite" = .layout_bipartite,
    "tiered" = .layout_tiered,
    "circle" = .layout_circle
  )

  # Call the layout function with appropriate parameters
  # Bipartite and tiered layouts don't use packing_ratio
  if (
    identical(layout_fn, .layout_bipartite) ||
      identical(layout_fn, .layout_tiered)
  ) {
    layout_fn(cg, ...)
  } else {
    layout_fn(cg, packing_ratio = packing_ratio, ...)
  }
}

#' Bipartite layout for [caugi_layout()].
#' @keywords internal
#' @noRd
.layout_bipartite <- function(
  x,
  partition = NULL,
  orientation = c("columns", "rows")
) {
  is_caugi(x, throw_error = TRUE)

  orientation <- match.arg(orientation)

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

  coords <- rs_compute_bipartite_layout(x@session, partition, orientation)

  data.frame(
    name = nodes(x)[["name"]],
    x = coords[["x"]],
    y = coords[["y"]],
    stringsAsFactors = FALSE
  )
}

#' @title Normalize a `tiers` argument
#'
#' @description Turns a named list, named numeric vector or data.frame of
#' tiers into one integer tier per node, in node order. Errors on unknown
#' nodes, nodes in more than one tier, non-whole or `NA` tiers, and nodes
#' without a tier.
#'
#' @param tiers The `tiers` argument.
#' @param node_names Character vector of the graph's node names.
#'
#' @returns A named integer vector, named and ordered by `node_names`.
#'
#' @keywords internal
#' @noRd
.tier_assignments <- function(tiers, node_names) {
  if (is.list(tiers) && !is.data.frame(tiers)) {
    if (!all(vapply(tiers, is.character, logical(1)))) {
      stop(
        "Each tier in the list must be a character vector of node names",
        call. = FALSE
      )
    }
    nm <- unlist(tiers, use.names = FALSE)
    tier <- rep(seq_along(tiers) - 1, lengths(tiers))
    where <- paste("tier", tier + 1)
  } else if (is.numeric(tiers) && !is.null(names(tiers))) {
    nm <- names(tiers)
    tier <- unname(tiers)
    where <- rep("tiers", length(nm))
  } else if (is.data.frame(tiers)) {
    if (!all(c("name", "tier") %in% colnames(tiers))) {
      stop("Data.frame must have columns 'name' and 'tier'", call. = FALSE)
    }
    nm <- as.character(tiers$name)
    tier <- tiers$tier
    where <- rep("tiers data.frame", length(nm))
  } else {
    stop(
      "tiers must be a named list, named numeric vector, or data.frame ",
      "with 'name' and 'tier' columns",
      call. = FALSE
    )
  }

  unknown <- which(!nm %in% node_names)
  if (length(unknown) > 0L) {
    k <- unknown[1L]
    stop(
      "Node '",
      nm[k],
      "' in ",
      where[k],
      " is not in the graph",
      call. = FALSE
    )
  }
  dup <- unique(nm[duplicated(nm)])
  if (length(dup) > 0L) {
    stop(
      "Nodes assigned to more than one tier: ",
      paste(dup, collapse = ", "),
      call. = FALSE
    )
  }
  # An NA tier counts as unassigned.
  missing <- setdiff(node_names, nm[!is.na(tier)])
  if (length(missing) > 0L) {
    stop(
      "Missing tier assignments for nodes: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  if (any(tier != round(tier))) {
    stop("Tier indices must be whole numbers", call. = FALSE)
  }

  out <- as.integer(tier)[match(node_names, nm)]
  names(out) <- node_names
  out
}

#' Tiered layout for [caugi_layout()].
#' @keywords internal
#' @noRd
.layout_tiered <- function(
  x,
  tiers,
  orientation = c("columns", "rows")
) {
  is_caugi(x, throw_error = TRUE)

  orientation <- match.arg(orientation)

  node_names <- nodes(x)[["name"]]

  tier_assignments <- .tier_assignments(tiers, node_names)

  # Normalize tier indices to start from 0
  min_tier <- min(tier_assignments)
  if (min_tier < 0) {
    stop("Tier indices must be non-negative", call. = FALSE)
  }
  if (min_tier > 0) {
    tier_assignments <- as.integer(tier_assignments - min_tier)
  }

  # Validate: tiers are consecutive
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
  coords <- rs_compute_tiered_layout(
    x@session,
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

#' Sugiyama layout for [caugi_layout()].
#' @keywords internal
#' @noRd
.layout_sugiyama <- function(x, packing_ratio = 1.618034, ...) {
  is_caugi(x, throw_error = TRUE)

  edge_types <- unique(edges(x)[["edge"]])
  non_directed <- setdiff(edge_types, "-->")

  if (length(non_directed) > 0) {
    stop(
      "Sugiyama layout only supports graphs with directed edges. ",
      "Found edge type(s): ",
      paste(non_directed, collapse = ", "),
      ". ",
      "Consider `method = \"fruchterman-reingold\"` or ",
      "`method = \"kamada-kawai\"` for graphs with mixed edge types.",
      call. = FALSE
    )
  }

  coords <- rs_compute_layout(x@session, "sugiyama", packing_ratio)

  data.frame(
    name = nodes(x)[["name"]],
    x = coords[["x"]],
    y = coords[["y"]],
    stringsAsFactors = FALSE
  )
}

#' Fruchterman-Reingold layout for [caugi_layout()].
#' @keywords internal
#' @noRd
.layout_fruchterman_reingold <- function(
  x,
  packing_ratio = 1.618034,
  ...
) {
  is_caugi(x, throw_error = TRUE)

  coords <- rs_compute_layout(x@session, "fruchterman-reingold", packing_ratio)

  data.frame(
    name = nodes(x)[["name"]],
    x = coords[["x"]],
    y = coords[["y"]],
    stringsAsFactors = FALSE
  )
}

#' Kamada-Kawai layout for [caugi_layout()].
#' @keywords internal
#' @noRd
.layout_kamada_kawai <- function(x, packing_ratio = 1.618034, ...) {
  is_caugi(x, throw_error = TRUE)

  coords <- rs_compute_layout(x@session, "kamada-kawai", packing_ratio)

  data.frame(
    name = nodes(x)[["name"]],
    x = coords[["x"]],
    y = coords[["y"]],
    stringsAsFactors = FALSE
  )
}

#' Circle layout for [caugi_layout()].
#' @keywords internal
#' @noRd
.layout_circle <- function(x, ...) {
  is_caugi(x, throw_error = TRUE)

  coords <- rs_compute_layout(x@session, "circle", 1.0)

  data.frame(
    name = nodes(x)[["name"]],
    x = coords[["x"]],
    y = coords[["y"]],
    stringsAsFactors = FALSE
  )
}
