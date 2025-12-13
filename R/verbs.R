# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────── Build a caugi graph ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Build the graph now
#'
#' @description If a `caugi` has been modified (nodes or edges added or
#' removed), it is marked as _not built_, i.e `cg@built = FALSE`.
#' This function builds the graph using the Rust backend and updates the
#' internal pointer to the graph. If the graph is already built, it is returned.
#'
#' @param cg A `caugi` object.
#' @param ... Not used.
#'
#' @returns The built `caugi` object.
#'
#' @examples
#' # initialize empty graph and build slowly
#' cg <- caugi(class = "PDAG")
#'
#' cg <- cg |>
#'   add_nodes(c("A", "B", "C", "D", "E")) |> # A, B, C, D, E
#'   add_edges(A %-->% B %-->% C) |> # A --> B --> C, D, E
#'   set_edges(B %---% C) # A --> B --- C, D, E
#'
#' cg <- remove_edges(cg, B %---% C) |> # A --> B, C, D, E
#'   remove_nodes(c("C", "D", "E")) # A --> B
#'
#' # verbs do not build the Rust backend
#' cg@built # FALSE
#' build(cg)
#' cg@built # TRUE
#'
#' @family verbs
#' @concept verbs
#'
#' @export
build <- S7::new_generic("build", "cg")

#' @name build
#' @export
S7::method(build, caugi) <- function(cg, ...) {
  if (length(list(...)) > 0L) {
    stop(
      "`build()` does not take any arguments other than `cg`.",
      call. = FALSE
    )
  }
  if (is_empty_caugi(cg)) {
    return(cg)
  }
  if (cg@built) {
    return(cg)
  }

  s <- cg@`.state`

  n <- nrow(s$nodes)
  id <- seq_len(n) - 1L
  names(id) <- s$nodes$name

  reg <- caugi_registry()
  b <- graph_builder_new(reg, n = n, simple = cg@simple)

  if (nrow(s$edges)) {
    # batched glyph->code lookup
    codes <- edge_registry_code_of(reg, s$edges$edge)
    graph_builder_add_edges(
      b,
      as.integer(unname(id[s$edges$from])),
      as.integer(unname(id[s$edges$to])),
      as.integer(codes)
    )
  }

  p <- graph_builder_build_view(b, s$class)

  # normalize edge order
  s$edges <- .edge_constructor(
    from = s$edges$from,
    edge = s$edges$edge,
    to = s$edges$to
  )

  s$ptr <- p
  s$built <- TRUE
  cg
}

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── Edge verbs ──────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' Caugi graph verbs
#'
#' @title Manipulate nodes and edges of a `caugi`
#' @name caugi_verbs
#' @description Add, remove, or and set nodes or edges to / from a `caugi`
#' object. Edges can be specified using expressions with the infix operators.
#' Alternatively, the edges to be added are specified using the
#' `from`, `edge`, and `to` arguments.
#'
#' @param cg A `caugi` object.
#' @param ... Expressions specifying edges to add using the infix operators,
#' or nodes to add using unquoted names, vectors via `c()`, or `+` composition.
#' @param from Character vector of source node names. Default is `NULL`.
#' @param edge Character vector of edge types. Default is `NULL`.
#' @param to Character vector of target node names. Default is `NULL`.
#' @param name Character vector of node names. Default is `NULL`.
#' @param inplace Logical, whether to modify the graph inplace or not.
#' If `FALSE` (default), a copy of the `caugi` is made and modified.
#'
#' @returns The updated `caugi`.
#'
#' @examples
#' # initialize empty graph and build slowly
#' cg <- caugi(class = "PDAG")
#'
#' cg <- cg |>
#'   add_nodes(c("A", "B", "C", "D", "E")) |> # A, B, C, D, E
#'   add_edges(A %-->% B %-->% C) |> # A --> B --> C, D, E
#'   set_edges(B %---% C) # A --> B --- C, D, E
#'
#' cg <- remove_edges(cg, B %---% C) |> # A --> B, C, D, E
#'   remove_nodes(c("C", "D", "E")) # A --> B
#'
#' # verbs do not build the Rust backend
#' cg@built # FALSE
#' build(cg)
#' cg@built # TRUE
#'
#' @family verbs
#' @concept verbs
NULL

#' @describeIn caugi_verbs Add edges.
#' @export
add_edges <- function(
  cg,
  ...,
  from = NULL,
  edge = NULL,
  to = NULL,
  inplace = FALSE
) {
  calls <- as.list(substitute(list(...)))[-1L]
  has_expr <- length(calls) > 0L
  has_vec <- !(is.null(from) && is.null(edge) && is.null(to))
  if (has_expr && has_vec) {
    stop(
      "Provide expressions via the infix operators (`A --> B`) ",
      "or vectors via the `from`, `edge`, and `to` arguments, ",
      "but not both."
    )
  }
  if (!has_expr && !has_vec) {
    return(cg)
  }

  # build edges
  edges <- .get_edges(from, edge, to, calls)

  # update via helper and return
  .update_caugi(cg, edges = edges, action = "add", inplace = inplace)
}

#' @describeIn caugi_verbs Remove edges.
#' @export
remove_edges <- function(
  cg,
  ...,
  from = NULL,
  edge = NULL,
  to = NULL,
  inplace = FALSE
) {
  calls <- as.list(substitute(list(...)))[-1L]
  has_expr <- length(calls) > 0L
  has_vec <- !(is.null(from) && is.null(edge) && is.null(to))
  if (has_expr && has_vec) {
    stop(
      "Provide expressions via the infix operators (`A --> B`) ",
      "or vectors via the `from`, `edge`, and `to` arguments, ",
      "but not both."
    )
  }
  if (!has_expr && !has_vec) {
    return(cg)
  }

  # build edges
  edges <- .get_edges(from, edge, to, calls)

  # update via helper and return
  .update_caugi(cg, edges = edges, action = "remove", inplace = inplace)
}

#' @describeIn caugi_verbs Set edge type for given pair(s).
#' @export
set_edges <- function(
  cg,
  ...,
  from = NULL,
  edge = NULL,
  to = NULL,
  inplace = FALSE
) {
  calls <- as.list(substitute(list(...)))[-1L]
  has_expr <- length(calls) > 0L
  has_vec <- !(is.null(from) && is.null(edge) && is.null(to))
  if (has_expr && has_vec) {
    stop(
      "Provide expressions via the infix operators (`A --> B`) ",
      "or vectors via the `from`, `edge`, and `to` arguments, ",
      "but not both."
    )
  }
  if (!has_expr && !has_vec) {
    return(cg)
  }

  edges <- .get_edges(from, edge, to, calls)

  pairs <- unique(edges[, .(from, to)])
  cg_mod <- .update_caugi(
    cg,
    edges = pairs,
    action = "remove",
    inplace = inplace
  )
  cg_mod <- .update_caugi(cg_mod, edges = edges, action = "add", inplace = TRUE)
  cg_mod
}

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── Node verbs ──────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @describeIn caugi_verbs Add nodes.
#' @export
add_nodes <- function(cg, ..., name = NULL, inplace = FALSE) {
  calls <- as.list(substitute(list(...)))[-1L]
  nodes <- .get_nodes(name, calls)
  if (!nrow(nodes)) {
    return(cg)
  }
  .update_caugi(cg, nodes = nodes, action = "add", inplace = inplace)
}

#' @describeIn caugi_verbs Remove nodes.
#' @export
remove_nodes <- function(cg, ..., name = NULL, inplace = FALSE) {
  calls <- as.list(substitute(list(...)))[-1L]
  nodes <- .get_nodes(name, calls)
  if (!nrow(nodes)) {
    return(cg)
  }
  .update_caugi(cg, nodes = nodes, action = "remove", inplace = inplace)
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Internal helpers ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Get nodes `data.table` from verb call.
#'
#' @description Internal helper to build nodes `data.table` from verb call.
#'
#' @param name Character vector of node names.
#' @param calls List of calls from `...`.
#'
#' @returns A `data.table` with column `name` for node names.
#'
#' @keywords internal
.get_nodes <- function(name, calls) {
  has_vec <- !is.null(name)
  has_expr <- length(calls) > 0L
  if (has_vec && has_expr) {
    stop("Provide nodes via `...` or `name`, not both.", call. = FALSE)
  }
  if (!has_vec && !has_expr) {
    return(.node_constructor())
  }
  name <- if (has_vec) {
    name
  } else {
    unlist(lapply(calls, .expand_nodes), use.names = FALSE)
  }
  .node_constructor(names = as.character(name))
}

#' @title Build edges `data.table` from verb call.
#'
#' @description Internal helper to build edges `data.table` from verb call.
#'
#' @param from Character vector of source node names.
#' @param edge Character vector of edge types.
#' @param to Character vector of target node names.
#' @param calls List of calls from `...`.
#'
#' @returns A `data.table` with columns `from`, `edge`, and `to`.
#'
#' @keywords internal
.get_edges <- function(from, edge, to, calls) {
  has_vec <- !(is.null(from) && is.null(edge) && is.null(to))
  edges <- if (has_vec) {
    if (is.null(from) || is.null(edge) || is.null(to)) {
      stop("`from`, `edge`, `to` must all be supplied.", call. = FALSE)
    }
    if (!(length(from) == length(to) && length(to) == length(edge))) {
      stop("`from`, `edge`, `to` must be equal length.", call. = FALSE)
    }
    .edge_constructor(
      from = as.character(from),
      edge = as.character(edge),
      to = as.character(to)
    )
  } else {
    if (length(calls) == 0L) {
      .edge_constructor()
    }
    units <- unlist(lapply(calls, .parse_edge_arg), recursive = FALSE)
    .edge_units_to_dt(units)
  }
  edges
}

#' @title Mark a `caugi` as _not built_.
#'
#' @description When a `caugi` is modified, it should be marked as not
#' built. This function sets the `built` attribute to `FALSE`. Thereby, the Rust
#' backend and the R frontend does not match, and at one point, the
#' `caugi` will need to be rebuild for it to be queried.
#'
#' @param cg A `caugi` object.
#'
#' @returns The same `caugi` object, but with the `built` attribute set to
#' `FALSE`.
#'
#' @keywords internal
.mark_not_built <- function(cg) {
  attr(cg, ".should_validate") <- FALSE
  on.exit(attr(cg, ".should_validate") <- NULL)

  s <- cg@`.state`
  s$built <- FALSE

  cg
}

#' @title Update nodes and edges of a `caugi`
#'
#' @description Internal helper to add or remove nodes/edges and mark graph as
#' not built.
#'
#' @param cg A `caugi` object.
#' @param nodes A `data.frame` with column `name` for node names to add/remove.
#' @param edges A `data.frame` with columns `from`, `edge`, `to` for edges to
#' add/remove.
#' @param action One of `"add"` or `"remove"`.
#' @param inplace Logical, whether to modify the graph inplace or not.
#'
#' @importFrom data.table `%chin%`
#'
#' @returns The updated `caugi` object.
#'
#' @keywords internal
.update_caugi <- function(
  cg,
  nodes = NULL,
  edges = NULL,
  action = c("add", "remove"),
  inplace = FALSE
) {
  action <- match.arg(action)

  # copy-on-write: default is NOT in-place
  if (!inplace) {
    s <- cg@`.state`

    # clone state
    state_copy <- .cg_state(
      nodes = s$nodes,
      edges = s$edges,
      ptr = NULL,
      built = FALSE,
      simple = s$simple,
      class = s$class,
      name_index_map = s$name_index_map
    )

    cg_copy <- caugi(state = state_copy)

    # reuse the in-place path on the copy
    return(.update_caugi(
      cg_copy,
      nodes = nodes,
      edges = edges,
      action = action,
      inplace = TRUE
    ))
  }

  s <- cg@`.state`

  if (identical(action, "add")) {
    if (!is.null(nodes)) {
      s$nodes <- .node_constructor(names = unique(c(s$nodes$name, nodes$name)))
    }
    if (!is.null(edges)) {
      s$nodes <- .node_constructor(
        names = unique(c(
          s$nodes$name,
          edges$from,
          edges$to
        ))
      )
      s$edges <- unique(
        data.table::rbindlist(list(s$edges, edges), use.names = TRUE),
        by = c("from", "edge", "to")
      )
    }
    # update fastmap
    new_ids <- setdiff(s$nodes$name, s$name_index_map$keys())
    if (length(new_ids) > 0L) {
      tmp <- nrow(s$nodes) - length(new_ids)
      new_id_values <- seq_len(length(new_ids)) - 1L + tmp
      do.call(
        s$name_index_map$mset,
        .set_names(as.list(new_id_values), new_ids)
      )
    }
  } else {
    if (!is.null(edges)) {
      keys <- intersect(c("from", "edge", "to"), names(edges))
      if (!all(c("from", "to") %in% keys)) {
        stop("edges must include at least `from` and `to`.", call. = FALSE)
      }
      edges_key <- unique(edges[, ..keys])
      s$edges <- s$edges[!edges_key, on = keys]
    }
    if (!is.null(nodes)) {
      drop <- nodes$name
      s$nodes <- .node_constructor(names = setdiff(s$nodes$name, drop))
      if (nrow(s$edges)) {
        s$edges <- s$edges[!(from %chin% drop | to %chin% drop)]
      }
    }
    s$nodes <- .node_constructor(names = unique(s$nodes$name))
    s$edges <- unique(s$edges)

    # update fastmap
    drop_ids <- intersect(nodes$name, s$name_index_map$keys())
    if (length(drop_ids) > 0L) {
      s$name_index_map$remove(keys = drop_ids)
      for (i in seq_len(nrow(s$nodes))) {
        s$name_index_map$set(s$nodes$name[i], i - 1L)
      }
    }
  }
  .mark_not_built(cg)
}
