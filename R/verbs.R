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

#' @title Build and update session from nodes and edges
#'
#' @description Internal helper to create or update a GraphSession with
#' the given nodes and edges. Rust is the source of truth.
#'
#' @param node_names Character vector of node names.
#' @param edges_dt A data.table with columns `from`, `edge`, `to`.
#' @param simple Logical; whether the graph is simple.
#' @param class Character; the graph class.
#' @param old_session Optional existing session for copy-on-write.
#'
#' @returns A list with `session` (GraphSession pointer) and `class` (resolved class string).
#'
#' @keywords internal
.build_session <- function(node_names, edges_dt, simple, class, old_session = NULL) {
  n <- length(node_names)
  reg <- caugi_registry()

  # Resolve AUTO class if needed
  resolved_class <- class
  if (n > 0L && nrow(edges_dt) > 0L) {
    id <- seq_len(n) - 1L
    names(id) <- node_names

    if (class == "AUTO") {
      b <- graph_builder_new(reg, n = n, simple = simple)
      codes <- edge_registry_code_of(reg, edges_dt$edge)
      graph_builder_add_edges(
        b,
        as.integer(unname(id[edges_dt$from])),
        as.integer(unname(id[edges_dt$to])),
        as.integer(codes)
      )
      resolved_class <- graph_builder_resolve_class(b, "AUTO")
    }
  } else if (class == "AUTO") {
    # For empty graphs with AUTO, default to DAG
    resolved_class <- "DAG"
  }

  # Always create a session (even for empty graphs)
  session <- graph_session_new(reg, n, simple, resolved_class)

  if (n > 0L) {
    id <- seq_len(n) - 1L
    names(id) <- node_names
    graph_session_set_names(session, node_names)

    if (nrow(edges_dt) > 0L) {
      codes <- edge_registry_code_of(reg, edges_dt$edge)
      graph_session_set_edges(
        session,
        as.integer(unname(id[edges_dt$from])),
        as.integer(unname(id[edges_dt$to])),
        as.integer(codes)
      )
    }
  }

  list(session = session, class = resolved_class)
}

#' @title Update nodes and edges of a `caugi`
#'
#' @description Internal helper to add or remove nodes/edges. Rust is the
#' source of truth - we get current state from Rust, modify it, and build
#' a new session.
#'
#' @param cg A `caugi` object.
#' @param nodes A `data.frame` with column `name` for node names to add/remove.
#' @param edges A `data.frame` with columns `from`, `edge`, `to` for edges to
#' add/remove.
#' @param action One of `"add"` or `"remove"`.
#' @param inplace Deprecated and ignored. Always returns a new caugi object.
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
  session <- cg@session

  # Get current state from Rust session (session is always present)
  current_nodes <- cg@nodes$name
  current_edges <- cg@edges
  current_simple <- graph_session_simple(session)
  current_class <- graph_session_class(session)

  # Apply modifications
  if (identical(action, "add")) {
    if (!is.null(nodes)) {
      current_nodes <- unique(c(current_nodes, nodes$name))
    }
    if (!is.null(edges)) {
      # Add nodes from edges
      current_nodes <- unique(c(current_nodes, edges$from, edges$to))
      # Add edges
      current_edges <- unique(
        data.table::rbindlist(list(current_edges, edges), use.names = TRUE),
        by = c("from", "edge", "to")
      )
    }
  } else {
    # remove action
    if (!is.null(edges)) {
      keys <- intersect(c("from", "edge", "to"), names(edges))
      if (!all(c("from", "to") %in% keys)) {
        stop("edges must include at least `from` and `to`.", call. = FALSE)
      }
      edges_key <- unique(edges[, ..keys])
      current_edges <- current_edges[!edges_key, on = keys]
    }
    if (!is.null(nodes)) {
      drop <- nodes$name
      current_nodes <- setdiff(current_nodes, drop)
      if (nrow(current_edges)) {
        current_edges <- current_edges[!(from %chin% drop | to %chin% drop)]
      }
    }
    current_nodes <- unique(current_nodes)
    current_edges <- unique(current_edges)
  }

  # Build new session with updated state
  # When adding edges, always re-resolve the class to allow automatic upgrade
  use_class <- if (identical(action, "add") && !is.null(edges)) {
    "AUTO"
  } else {
    current_class
  }
  result <- .build_session(
    node_names = current_nodes,
    edges_dt = current_edges,
    simple = current_simple,
    class = use_class,
    old_session = session
  )

  caugi(.session = result$session)
}
