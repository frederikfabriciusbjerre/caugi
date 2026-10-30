#' Compute Graph Layout
#'
#' Computes node coordinates for graph visualization using
#' specified layout algorithm. If the graph has not been built yet, it will
#' be built automatically before computing the layout.
#'
#' `caugi_layout_sugiyama()`, `caugi_layout_fruchterman_reingold()`,
#' `caugi_layout_kamada_kawai()`, `caugi_layout_bipartite()`,
#' `caugi_layout_tiered()` and `caugi_layout_circle()` are deprecated. Call
#' `caugi_layout()` with the matching `method` instead, e.g.
#' `caugi_layout(cg, method = "tiered", tiers = tiers)`.
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
#' **Bipartite**
#'
#' Places nodes in two parallel rows or columns based on a `partition`, e.g.
#' causes and effects. Without a `partition`, nodes without incoming edges
#' form one group and all other nodes the other.
#'
#' **Tiered**
#'
#' Places nodes in several parallel rows or columns based on `tiers`, e.g.
#' exposures, mediators and outcomes. Nodes within a tier are spaced evenly.
#'
#' **Circle**
#'
#' Places nodes evenly along the perimeter of a circle. The first node is at
#' the top and subsequent nodes proceed counter-clockwise. Useful for small
#' graphs, cycle visualization, and as a deterministic fallback. Works with
#' all edge types and ignores edge structure.
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
#'   * `"bipartite"`: Bipartite layout (optional `partition` and `orientation`)
#'   * `"tiered"`: Multi-tier layout (requires `tiers`, optional `orientation`)
#'   * `"circle"`: Place nodes evenly along a circle
#' @param packing_ratio Aspect ratio for packing disconnected components
#'   (width/height) in the `"sugiyama"`, `"fruchterman-reingold"` and
#'   `"kamada-kawai"` layouts. Default is the golden ratio (1.618) which works
#'   well with widescreen displays. Use `1.0` for square grid, `2.0` for wider
#'   layouts, `0.5` for taller layouts, `Inf` for single row, or `0.0` for
#'   single column.
#' @param ... Options of the chosen layout: `partition` and `orientation` for
#'   `"bipartite"`, and `tiers` and `orientation` for `"tiered"`. The other
#'   layouts take none. Options a layout ignores give a warning: anything in
#'   `...` for layouts other than `"bipartite"` and `"tiered"`, and
#'   `packing_ratio` for `"bipartite"`, `"tiered"` and `"circle"`.
#' @param partition For `"bipartite"`: optional logical vector indicating node
#'   partitions. Nodes with `TRUE` are placed in one partition and nodes with
#'   `FALSE` in the other. Length must equal the number of nodes. Both
#'   partitions must be non-empty. If `NULL` (default), attempts to detect
#'   bipartite structure automatically by assigning nodes without incoming
#'   edges to one partition and others to the second partition.
#' @param tiers For `"tiered"`: tier assignments specifying which tier each
#'   node belongs to. Can be provided in multiple formats:
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
#' @param orientation For `"bipartite"` and `"tiered"`: character string
#'   specifying the layout orientation:
#'   * `"columns"` (default): Vertical lines of nodes. The bipartite layout
#'     puts the `TRUE` partition on the right (x=1) and the `FALSE` partition
#'     on the left (x=0). The tiered layout puts the first tier at the left
#'     (x=0) and the last tier at the right (x=1).
#'   * `"rows"`: Horizontal lines of nodes. The bipartite layout puts the
#'     `TRUE` partition on top (y=1) and the `FALSE` partition at the bottom
#'     (y=0). The tiered layout puts the first tier at the top (y=1) and the
#'     last tier at the bottom (y=0).
#' @param x Deprecated; use `cg` instead. Supplying it gives a deprecation
#'   warning.
#'
#' @returns A `data.frame` with columns `name`, `x`, and `y` containing node
#'   names and their coordinates. The tiered layout adds a `tier` column with
#'   the (0-indexed) tier of each node and stores the orientation in an
#'   `orientation` attribute. When passed to `plot()`, tier information is
#'   automatically extracted, so you don't need to specify `tiers` again.
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
#' # Tiered layout with three tiers, given as a named list
#' cg_tiered <- caugi(
#'   X1 %-->% M1 + M2,
#'   X2 %-->% M1 + M2,
#'   M1 %-->% Y,
#'   M2 %-->% Y
#' )
#' tiers <- list(
#'   exposures = c("X1", "X2"),
#'   mediators = c("M1", "M2"),
#'   outcome = "Y"
#' )
#' layout_tiered <- caugi_layout(
#'   cg_tiered,
#'   method = "tiered",
#'   tiers = tiers,
#'   orientation = "rows"
#' )
#'
#' # The same tiers as a named numeric vector or a data.frame
#' tiers_vec <- c(X1 = 1, X2 = 1, M1 = 2, M2 = 2, Y = 3)
#' tiers_df <- data.frame(name = names(tiers_vec), tier = tiers_vec)
#' layout_tiered <- caugi_layout(cg_tiered, method = "tiered", tiers = tiers_df)
#'
#' # The layout includes tier information, so plot() works without passing tiers
#' plot(cg_tiered, layout = layout_tiered)
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
  ...,
  x
) {
  if (!missing(x)) {
    cg <- .layout_x_deprecated(x, missing(cg), "caugi_layout")
  }
  is_caugi(cg, throw_error = TRUE)

  method <- match.arg(method)
  dots <- list(...)

  if (method == "auto") {
    if (!is.null(dots$tiers)) {
      method <- "tiered"
    } else if (!is.null(dots$partition)) {
      method <- "bipartite"
    } else {
      # Otherwise, choose based on edge types
      edge_types <- unique(edges(cg)[["edge"]])
      non_directed <- setdiff(edge_types, "-->")
      method <- if (length(non_directed) == 0) {
        "sugiyama"
      } else {
        "fruchterman-reingold"
      }
    }
  }

  # Warn about options the chosen layout ignores, so that a misspelled or
  # misplaced option does not go unnoticed. The bipartite and tiered layouts
  # take their options from `...` and reject unknown ones themselves.
  ignored <- character(0)
  if (!method %in% c("bipartite", "tiered")) {
    ignored <- names(dots)[nzchar(names(dots))]
  }
  packs <- method %in% c("sugiyama", "fruchterman-reingold", "kamada-kawai")
  if (!packs && !missing(packing_ratio)) {
    ignored <- c("packing_ratio", ignored)
  }
  if (length(ignored) > 0L) {
    warning(
      "The \"",
      method,
      "\" layout ignores ",
      paste0("`", ignored, "`", collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  switch(
    method,
    "sugiyama" = .layout_sugiyama(cg, packing_ratio),
    "fruchterman-reingold" = .layout_fruchterman_reingold(cg, packing_ratio),
    "kamada-kawai" = .layout_kamada_kawai(cg, packing_ratio),
    "bipartite" = .layout_bipartite(cg, ...),
    "tiered" = .layout_tiered(cg, ...),
    "circle" = .layout_circle(cg)
  )
}

#' @title Handle the deprecated `x` argument of the layout functions
#'
#' @description Signals a warning of class `caugi_deprecated_layout_x` (and
#' `deprecatedWarning`) and returns `x` as the graph. Errors if `cg` was
#' supplied too.
#'
#' @param x The deprecated `x` argument.
#' @param cg_missing Logical; whether `cg` was missing.
#' @param fn Name of the calling layout function.
#'
#' @returns `x`.
#'
#' @keywords internal
#' @noRd
.layout_x_deprecated <- function(x, cg_missing, fn) {
  if (!cg_missing) {
    stop(
      "Supply the graph as `cg` only; `x` is a deprecated name for it.",
      call. = FALSE
    )
  }
  warning(structure(
    class = c(
      "caugi_deprecated_layout_x",
      "deprecatedWarning",
      "warning",
      "condition"
    ),
    list(
      message = paste0(
        "The `x` argument of `",
        fn,
        "()` is deprecated; use `cg` instead."
      ),
      call = NULL
    )
  ))
  x
}

#' @rdname caugi_layout
#' @export
caugi_layout_sugiyama <- function(cg, packing_ratio = 1.618034, ..., x) {
  .Deprecated("caugi_layout")
  if (!missing(x)) {
    cg <- .layout_x_deprecated(x, missing(cg), "caugi_layout_sugiyama")
  }
  caugi_layout(cg, method = "sugiyama", packing_ratio = packing_ratio)
}

#' @rdname caugi_layout
#' @export
caugi_layout_fruchterman_reingold <- function(
  cg,
  packing_ratio = 1.618034,
  ...,
  x
) {
  .Deprecated("caugi_layout")
  if (!missing(x)) {
    cg <- .layout_x_deprecated(
      x,
      missing(cg),
      "caugi_layout_fruchterman_reingold"
    )
  }
  caugi_layout(
    cg,
    method = "fruchterman-reingold",
    packing_ratio = packing_ratio
  )
}

#' @rdname caugi_layout
#' @export
caugi_layout_kamada_kawai <- function(cg, packing_ratio = 1.618034, ..., x) {
  .Deprecated("caugi_layout")
  if (!missing(x)) {
    cg <- .layout_x_deprecated(x, missing(cg), "caugi_layout_kamada_kawai")
  }
  caugi_layout(cg, method = "kamada-kawai", packing_ratio = packing_ratio)
}

#' @rdname caugi_layout
#' @export
caugi_layout_bipartite <- function(
  cg,
  partition = NULL,
  orientation = c("columns", "rows"),
  x
) {
  .Deprecated("caugi_layout")
  if (!missing(x)) {
    cg <- .layout_x_deprecated(x, missing(cg), "caugi_layout_bipartite")
  }
  caugi_layout(
    cg,
    method = "bipartite",
    partition = partition,
    orientation = orientation
  )
}

#' @rdname caugi_layout
#' @export
caugi_layout_tiered <- function(
  cg,
  tiers,
  orientation = c("columns", "rows"),
  x
) {
  .Deprecated("caugi_layout")
  if (!missing(x)) {
    cg <- .layout_x_deprecated(x, missing(cg), "caugi_layout_tiered")
  }
  caugi_layout(cg, method = "tiered", tiers = tiers, orientation = orientation)
}

#' @rdname caugi_layout
#' @export
caugi_layout_circle <- function(cg, ..., x) {
  .Deprecated("caugi_layout")
  if (!missing(x)) {
    cg <- .layout_x_deprecated(x, missing(cg), "caugi_layout_circle")
  }
  caugi_layout(cg, method = "circle")
}

#' @title Bipartite layout
#'
#' @description Places nodes in two parallel rows or columns based on a
#' partition. Called by `caugi_layout(method = "bipartite")`.
#'
#' @inheritParams caugi_layout
#'
#' @returns A `data.frame` with columns `name`, `x`, and `y`.
#'
#' @keywords internal
#' @noRd
.layout_bipartite <- function(
  cg,
  partition = NULL,
  orientation = c("columns", "rows")
) {
  orientation <- match.arg(orientation)

  # Auto-detect partition if not provided
  if (is.null(partition)) {
    # Simple heuristic: nodes with no incoming edges vs nodes with
    # incoming edges
    edges_df <- edges(cg)
    node_names <- nodes(cg)[["name"]]

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

    if (length(partition) != nrow(nodes(cg))) {
      stop(
        "partition length (",
        length(partition),
        ") ",
        "does not match number of nodes (",
        nrow(nodes(cg)),
        ")",
        call. = FALSE
      )
    }
  }

  coords <- rs_compute_bipartite_layout(cg@session, partition, orientation)

  data.frame(
    name = nodes(cg)[["name"]],
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

#' @title Tiered layout
#'
#' @description Places nodes in parallel rows or columns based on tier
#' assignments. Called by `caugi_layout(method = "tiered")`.
#'
#' @inheritParams caugi_layout
#'
#' @returns A `data.frame` with columns `name`, `x`, `y` and `tier`, and an
#'   `orientation` attribute.
#'
#' @keywords internal
#' @noRd
.layout_tiered <- function(
  cg,
  tiers,
  orientation = c("columns", "rows")
) {
  orientation <- match.arg(orientation)

  node_names <- nodes(cg)[["name"]]

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
    cg@session,
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

#' @title Sugiyama hierarchical layout
#'
#' @description Places nodes in layers, parents above children. Errors on
#' graphs with non-directed edges. Called by
#' `caugi_layout(method = "sugiyama")`.
#'
#' @inheritParams caugi_layout
#'
#' @returns A `data.frame` with columns `name`, `x`, and `y`.
#'
#' @keywords internal
#' @noRd
.layout_sugiyama <- function(cg, packing_ratio) {
  edge_types <- unique(edges(cg)[["edge"]])
  non_directed <- setdiff(edge_types, "-->")

  if (length(non_directed) > 0) {
    stop(
      "Sugiyama layout only supports graphs with directed edges. ",
      "Found edge type(s): ",
      paste(non_directed, collapse = ", "),
      ". ",
      "Consider using method = \"fruchterman-reingold\" or ",
      "method = \"kamada-kawai\" for graphs with mixed edge types.",
      call. = FALSE
    )
  }

  coords <- rs_compute_layout(cg@session, "sugiyama", packing_ratio)

  data.frame(
    name = nodes(cg)[["name"]],
    x = coords[["x"]],
    y = coords[["y"]],
    stringsAsFactors = FALSE
  )
}

#' @title Fruchterman-Reingold force-directed layout
#'
#' @description Called by `caugi_layout(method = "fruchterman-reingold")`.
#'
#' @inheritParams caugi_layout
#'
#' @returns A `data.frame` with columns `name`, `x`, and `y`.
#'
#' @keywords internal
#' @noRd
.layout_fruchterman_reingold <- function(cg, packing_ratio) {
  coords <- rs_compute_layout(cg@session, "fruchterman-reingold", packing_ratio)

  data.frame(
    name = nodes(cg)[["name"]],
    x = coords[["x"]],
    y = coords[["y"]],
    stringsAsFactors = FALSE
  )
}

#' @title Kamada-Kawai stress minimization layout
#'
#' @description Called by `caugi_layout(method = "kamada-kawai")`.
#'
#' @inheritParams caugi_layout
#'
#' @returns A `data.frame` with columns `name`, `x`, and `y`.
#'
#' @keywords internal
#' @noRd
.layout_kamada_kawai <- function(cg, packing_ratio) {
  coords <- rs_compute_layout(cg@session, "kamada-kawai", packing_ratio)

  data.frame(
    name = nodes(cg)[["name"]],
    x = coords[["x"]],
    y = coords[["y"]],
    stringsAsFactors = FALSE
  )
}

#' @title Circle layout
#'
#' @description Places nodes evenly along a circle, the first at the top.
#' Called by `caugi_layout(method = "circle")`.
#'
#' @inheritParams caugi_layout
#'
#' @returns A `data.frame` with columns `name`, `x`, and `y`.
#'
#' @keywords internal
#' @noRd
.layout_circle <- function(cg) {
  coords <- rs_compute_layout(cg@session, "circle", 1.0)

  data.frame(
    name = nodes(cg)[["name"]],
    x = coords[["x"]],
    y = coords[["y"]],
    stringsAsFactors = FALSE
  )
}
