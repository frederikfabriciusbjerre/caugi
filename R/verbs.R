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
#' # Graphs are now built lazily when needed
#' parents(cg, "B") # triggers compilation
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
      "but not both.",
      call. = FALSE
    )
  }
  if (!has_expr && !has_vec) {
    return(cg)
  }

  if (has_vec && is.null(edge)) {
    if (!cg@simple) {
      stop(
        "When removing edges without specifying `edge`, `cg` must be simple.",
        call. = FALSE
      )
    }
    if (is.null(from) || is.null(to)) {
      stop(
        "`from` and `to` must be supplied when `edge` is omitted.",
        call. = FALSE
      )
    }
    if (length(from) != length(to)) {
      stop("`from` and `to` must be equal length.", call. = FALSE)
    }

    pairs <- data.table::data.table(
      from = as.character(from),
      to = as.character(to)
    )

    # Remove both directions of the edge
    pairs <- unique(data.table::rbindlist(list(
      pairs,
      pairs[, .(from = to, to = from)]
    )))

    return(.update_caugi(
      cg,
      edges = pairs,
      action = "remove",
      inplace = inplace
    ))
  }

  edges <- .get_edges(from, edge, to, calls, simple = cg@simple)
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
#' @param simple Logical, whether the graph is simple or not.
#'
#' @returns A `data.table` with columns `from`, `edge`, and `to`.
#'
#' @keywords internal
.get_edges <- function(from, edge, to, calls, simple = TRUE) {
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

#' @title Sync session with R state
#'
#' @description Internal helper to synchronize the GraphSession with the
#' current R-side node/edge state. The session automatically invalidates
#' its cached computations when edges change.
#'
#' @param cg A `caugi` object.
#'
#' @returns The same `caugi` object with session synced.
#'
#' @keywords internal
.sync_session <- function(cg) {
  s <- cg@`.state`
  n <- nrow(s$nodes)

  if (n == 0L) {
    s$session <- NULL
    return(cg)
  }

  reg <- caugi_registry()
  id <- seq_len(n) - 1L
  names(id) <- s$nodes$name

  # Resolve AUTO class if needed (before creating session)
  resolved_class <- s$class
  if (s$class == "AUTO" && nrow(s$edges) > 0L) {
    # Use builder to determine class from edges
    b <- graph_builder_new(reg, n = n, simple = s$simple)
    codes <- edge_registry_code_of(reg, s$edges$edge)
    graph_builder_add_edges(
      b,
      as.integer(unname(id[s$edges$from])),
      as.integer(unname(id[s$edges$to])),
      as.integer(codes)
    )
    resolved_class <- graph_builder_resolve_class(b, "AUTO")
    s$class <- resolved_class
  } else if (s$class == "AUTO") {
    # No edges yet, default to DAG
    resolved_class <- "DAG"
    s$class <- resolved_class
  }

  # Clone session for copy-on-write semantics or create new
  if (!is.null(s$session)) {
    s$session <- graph_session_clone(s$session)
    # Update cloned session with new state
    graph_session_set_n(s$session, n)
    graph_session_set_names(s$session, s$nodes$name)
    graph_session_set_class(s$session, resolved_class)
  } else {
    s$session <- graph_session_new(reg, n, s$simple, resolved_class)
    graph_session_set_names(s$session, s$nodes$name)
  }

  # Sync edges to session
  if (nrow(s$edges) > 0L) {
    codes <- edge_registry_code_of(reg, s$edges$edge)
    graph_session_set_edges(
      s$session,
      as.integer(unname(id[s$edges$from])),
      as.integer(unname(id[s$edges$to])),
      as.integer(codes)
    )
  } else {
    # Clear edges in session
    graph_session_set_edges(s$session, integer(0), integer(0), integer(0))
  }

  cg
}

#' @title Update nodes and edges of a `caugi`
#'
#' @description Internal helper to add or remove nodes/edges. The session
#' is automatically synced after modifications.
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

    # clone state safely (session will be cloned in .sync_session)
    state_copy <- .cg_state(
      nodes = data.table::copy(s$nodes),
      edges = data.table::copy(s$edges),
      simple = s$simple,
      class = s$class,
      name_index_map = s$name_index_map$clone(),
      session = s$session # Will be cloned in .sync_session
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
    if (!is.null(nodes)) {
      drop_ids <- intersect(nodes$name, s$name_index_map$keys())
      if (length(drop_ids) > 0L) {
        s$name_index_map$remove(keys = drop_ids)
        for (i in seq_len(nrow(s$nodes))) {
          s$name_index_map$set(s$nodes$name[i], i - 1L)
        }
      }
    }
  }

  # Sync session with updated R state (auto-invalidates cached computations)
  .sync_session(cg)
}
