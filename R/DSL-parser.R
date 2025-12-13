# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── DSL parser helpers ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Is it an edge call / expression?
#'
#' @description This function checks if the expression is an edge call
#'
#' @param expr An expression to check
#'
#' @returns TRUE if the expression is an edge call, FALSE otherwise
#'
#' @keywords internal
.is_edge_call <- function(expr) {
  is.call(expr) && as.character(expr[[1L]]) %in% .edge_ops_get()
}

#' @title Is it a node expr?
#'
#' @description Check if the expression is a valid node expression:
#' symbol, string, number, c(...), +, (...)
#'
#' @param expr An expression to check
#'
#' @returns TRUE if the expression is a valid node expression, FALSE otherwise
#'
#' @keywords internal
.is_node_expr <- function(expr) {
  # symbol or "A"
  if (is.symbol(expr) || (is.character(expr) && length(expr) == 1L)) {
    return(TRUE)
  }

  if (is.call(expr)) {
    fn <- as.character(expr[[1L]])

    # parentheses
    if (fn == "(") {
      return(.is_node_expr(expr[[2L]]))
    }

    # c(A, B + C, (D))
    if (fn == "c") {
      args <- as.list(expr)[-1L]
      return(all(vapply(args, .is_node_expr, logical(1))))
    }

    # A + B + (C + D) — only nodes on both sides
    if (fn == "+") {
      return(.is_node_expr(expr[[2L]]) && .is_node_expr(expr[[3L]]))
    }
  }
  FALSE
}

#' @title Does the expression contain an edge call?
#'
#' @description Recursively check if the expression contains any edge call.
#'
#' @param expr An expression to check
#'
#' @returns TRUE if the expression contains an edge call, FALSE otherwise
#'
#' @keywords internal
.contains_edge <- function(expr) {
  if (.is_edge_call(expr)) {
    return(TRUE)
  }
  if (is.call(expr)) {
    fn <- as.character(expr[[1L]])
    if (fn == "(") {
      return(.contains_edge(expr[[2L]]))
    }
    if (fn == "+") {
      return(.contains_edge(expr[[2L]]) || .contains_edge(expr[[3L]]))
    }
  }
  FALSE
}

#' @title Get glyph for an operator
#'
#' @description Get the glyph string for a given edge operator symbol.
#'
#' @param op_sym A symbol representing the edge operator (e.g., `%-->%`).
#'
#' @returns A string representing the edge glyph (e.g., `"-->"`).
#'
#' @keywords internal
.glyph_of <- function(op_sym) {
  if (is.null(op_sym)) {
    return(NULL)
  }
  key <- as.character(op_sym)
  m <- .glyph_map_get()
  if (is.null(m)) {
    return(NULL)
  }
  nms <- names(m)
  if (is.null(nms) || !(key %in% nms)) {
    return(NULL)
  }
  m[[key]]
}

#' @title Expand node expressions
#'
#' @description Expand node expressions: symbol, "B", c(...), +, (...)
#'
#' @param expr An expression representing nodes.
#'
#' @returns A character vector of node names.
#'
#' @keywords internal
.expand_nodes <- function(expr, env = parent.frame()) {
  if (is.symbol(expr)) {
    return(deparse1(expr))
  }
  if (is.character(expr) && length(expr) == 1L) {
    return(expr)
  }
  if (is.numeric(expr) && length(expr) == 1L) {
    return(as.character(expr))
  }
  if (is.call(expr)) {
    fn <- as.character(expr[[1L]])
    if (fn == "(") {
      return(.expand_nodes(expr[[2L]], env))
    }
    if (fn == "+") {
      return(c(.expand_nodes(expr[[2L]], env), .expand_nodes(expr[[3L]], env)))
    }
    if (fn == "c") {
      return(unlist(
        lapply(as.list(expr)[-1L], .expand_nodes, env = env),
        use.names = FALSE
      ))
    }
  }
  stop("Unsupported node expression: ", deparse1(expr), call. = FALSE)
}


#' @title Expand target expressions with `=`
#'
#' @description Split any expression into top-level '+' terms (fully flattened).
#'
#' @param expr An expression representing nodes.
#'
#' @returns A character vector of node names.
#'
#' @keywords internal
.split_plus <- function(expr) {
  if (is.call(expr)) {
    fn <- as.character(expr[[1L]])
    if (fn == "+") {
      return(c(.split_plus(expr[[2L]]), .split_plus(expr[[3L]])))
    }
    if (fn == "(") {
      return(.split_plus(expr[[2L]]))
    }
  }
  list(expr)
}

#' @title Combine terms with '+'
#'
#' @description Combine a list of terms into a single left-associative '+' call.
#'
#' @param terms A list of expressions to combine.
#'
#' @returns A single expression combining the terms with '+'.
#'
#' @keywords internal
.combine_plus <- function(terms) {
  len <- length(terms)
  if (len == 0) {
    return(NULL)
  }
  if (len == 1) {
    return(terms[[1L]])
  }
  out <- terms[[1L]]
  for (i in 2:len) {
    out <- call("+", out, terms[[i]])
  }
  out
}

#' @title Parse one caugi(...) argument
#'
#' @description Parse one caugi(...) argument into edge units
#'
#' @param expr An expression representing an edge with nodes
#'
#' @returns A list of edge units, each with lhs, rhs, and glyph.
#'
#' @keywords internal
.parse_edge_arg <- function(expr) {
  terms <- .split_plus(expr)

  is_edge <- vapply(terms, .is_edge_call, TRUE)
  if (!any(is_edge)) {
    stop("Expected an edge expression; got: ", deparse(expr), call. = FALSE)
  }

  edge_idx <- which(is_edge)
  units <- list()

  keep_node <- function(x) !is.null(x) && !.is_edge_call(x)

  for (k in seq_along(edge_idx)) {
    i <- edge_idx[k]
    edge_term <- terms[[i]]

    # Identify contiguous non-edge nodes to the left/right of this edge term
    prev_idx <- if (k > 1L) {
      edge_idx[k - 1L]
    } else {
      0L
    }
    next_idx <- if (k < length(edge_idx)) {
      edge_idx[k + 1L]
    } else {
      length(terms) + 1L
    }
    left_idx <- if (prev_idx + 1L <= i - 1L) {
      seq.int(prev_idx + 1L, i - 1L)
    } else {
      integer(0)
    }
    right_idx <- if (i + 1L <= next_idx - 1L) {
      seq.int(i + 1L, next_idx - 1L)
    } else {
      integer(0)
    }
    left_nodes_terms <- Filter(keep_node, terms[left_idx])
    right_nodes_terms <- Filter(keep_node, terms[right_idx])

    # Case 1: single edge call (no chaining)
    if (!is.call(edge_term[[2L]]) || !.is_edge_call(edge_term[[2L]])) {
      lhs <- edge_term[[2L]]
      rhs <- edge_term[[3L]]
      if (length(left_nodes_terms)) {
        lhs <- call("+", .combine_plus(left_nodes_terms), lhs)
      }
      if (length(right_nodes_terms)) {
        rhs <- call("+", rhs, .combine_plus(right_nodes_terms))
      }
      units <- c(
        units,
        list(list(
          lhs = lhs,
          rhs = rhs,
          glyph = .glyph_of(edge_term[[1L]])
        ))
      )
      next
    }

    # Case 2: chained edge expression: lhs is itself an edge call
    chain <- .flatten_edge_chain(edge_term)
    chain_terms <- chain$terms # list of term-exprs
    chain_ops <- chain$ops # character(ops)

    # Attach external left nodes to the first term; right nodes to the last term
    if (length(left_nodes_terms)) {
      chain_terms[[1L]] <- call(
        "+",
        .combine_plus(left_nodes_terms),
        chain_terms[[1L]]
      )
    }
    if (length(right_nodes_terms)) {
      last <- length(chain_terms)
      chain_terms[[last]] <- call(
        "+",
        chain_terms[[last]],
        .combine_plus(right_nodes_terms)
      )
    }

    # Emit one unit per segment, left-to-right
    for (j in seq_along(chain_ops)) {
      units <- c(
        units,
        list(
          .segment_units(
            chain_terms[[j]],
            chain_ops[[j]],
            chain_terms[[j + 1L]]
          )
        )
      )
    }
  }
  units
}


#' @title Turn edge units into a `data.table` of edges
#'
#' @description Convert a list of edge units into a `data.table` with columns
#' `from`, `edge`, and `to`.
#'
#' @param units A list of edge units, each with `lhs`, `rhs`, and `glyph`.
#'
#' @returns A `data.table` with columns `from`, `edge`, and `to`.
#'
#' @keywords internal
.edge_units_to_dt <- function(units) {
  dfs <- lapply(units, function(u) {
    froms <- .expand_nodes(u$lhs)
    tos <- .expand_nodes(u$rhs)
    data.table::data.table(
      from = rep(froms, each = length(tos)),
      edge = u$glyph,
      to = rep(tos, times = length(froms))
    )
  })
  data.table::rbindlist(dfs, use.names = TRUE)
}

#' @title Collect edges and nodes
#'
#' @description Collect edges (via .parse_edge_arg) and explicitly declared
#' nodes (no edges).
#'
#' @param calls A list of expressions from caugi(...)
#'
#' @returns A list with two elements:
#' * edges: a `data.table` with columns `from`, `edge`, `to`
#' * declared: a character vector of explicitly declared nodes
#'
#' @keywords internal
.collect_edges_nodes <- function(calls) {
  units <- list()
  declared <- character()
  i <- 0
  for (ex in calls) {
    i <- i + 1L
    if (missing(ex)) {
      stop("Argument ", i, " is missing in `caugi`.", call. = FALSE)
    }
    if (.contains_edge(ex)) {
      units <- c(units, .parse_edge_arg(ex))
    } else if (.is_node_expr(ex)) {
      declared <- c(declared, .expand_nodes(ex))
    } else {
      stop(
        "Expected an edge (A %-->% B) ",
        "or a node expression (C, D, C+D, c(C,D)); got: ",
        deparse(ex),
        call. = FALSE
      )
    }
  }
  edges <- if (length(units)) {
    unique(.edge_units_to_dt(units), by = c("from", "edge", "to"))
  } else {
    .edge_constructor()
  }
  list(edges = edges, declared = unique(declared))
}

#' @title Flatten a chained edge expression
#'
#' @description Given a chained edge expression,
#' flatten it into its terms and operators.
#'
#' @param call_expr A call expression representing a chained edge.
#'
#' @returns A list with two elements, `terms` and `ops`.
#'
#' @keywords internal
.flatten_edge_chain <- function(call_expr) {
  stopifnot(is.call(call_expr))
  terms <- list()
  ops <- character()

  cur <- call_expr
  repeat {
    # If this node is an edge call, peel one layer and keep walking left
    if (.is_edge_call(cur)) {
      op_chr <- as.character(cur[[1L]])
      right <- cur[[3L]]
      ops <- c(op_chr, ops)
      terms <- c(list(right), terms)
      cur <- cur[[2L]] # continue with the left
    } else {
      # reached the leftmost term
      terms <- c(list(cur), terms)
      break
    }
  }
  list(terms = terms, ops = ops)
}

#' @title Create an edge unit from lhs, op, rhs
#'
#' @description Create an edge unit from lhs, op, rhs expressions.
#'
#' @param lhs_term An expression for the left-hand side nodes.
#' @param op_chr A string representing the edge operator glyph.
#' @param rhs_term An expression for the right-hand side nodes.
#'
#' @returns A list with elements `lhs`, `rhs`, and `glyph`.
#'
#' @keywords internal
.segment_units <- function(lhs_term, op_chr, rhs_term) {
  glyph <- .glyph_of(as.name(op_chr))
  froms <- .expand_nodes(lhs_term)
  tos <- .expand_nodes(rhs_term)
  list(lhs = lhs_term, rhs = rhs_term, glyph = glyph)
}


#' @title Edge constructor
#'
#' @description
#' Internal function to construct edges for `caugi` objects.
#'
#' @param from Character vector of source node names.
#' @param edge Character vector of edge glyphs.
#' @param to Character vector of target node names.
#'
#' @returns A `data.table` object with columns `from`, `edge`, and `to`.
#'
#' @keywords internal
.edge_constructor <- function(
  from = character(),
  edge = character(),
  to = character()
) {
  dt <- data.table::data.table(
    from = from,
    edge = edge,
    to = to
  )
  data.table::setorder(dt, "from", "to", "edge")
  return(dt)
}

#' @title Edge constructor using indices.
#'
#' @description
#' Internal function to construct edges for `caugi` objects using indices.
#'
#' @param from_idx Integer vector of source node indices.
#' @param edge Character vector of edge glyphs.
#' @param to_idx Integer vector of target node indices.
#' @param node_names Character vector of node names.
#'
#' @returns A `data.table` object with columns `from`, `edge`, and `to`.
#'
#' @keywords internal
.edge_constructor_idx <- function(from_idx, edge, to_idx, node_names) {
  dt <- data.table::data.table(
    from = node_names[from_idx],
    edge = edge,
    to = node_names[to_idx]
  )
  data.table::setorder(dt, "from", "to", "edge")
  return(dt)
}

#' @title Node constructor
#'
#' @description
#' A simple wrapper creating a `data.table` object with a single column `name`.
#'
#' @details
#' The reason this exists is so if changes should be made in the future, it is
#' easy to simply change this constructor, rather than changing the calls to
#' `data.table` all over the place.
#'
#' @param names Character vector of node names.
#' @param sort Logical indicating whether to sort the node names.
#'
#' @returns A `data.table` object with a single column `name`.
#'
#' @keywords internal
.node_constructor <- function(names = character(), sort = FALSE) {
  dt <- data.table::data.table(
    name = names
  )
  if (sort) {
    data.table::setorder(dt, "name") # sorts inplace
  }
  return(dt)
}
