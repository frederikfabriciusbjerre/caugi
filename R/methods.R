# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Methods ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' Length of a `caugi`
#'
#' @description Returns the number of nodes in the graph.
#'
#' @param x A `caugi` object.
#'
#' @name length.caugi
#' @aliases length
#' @usage \method{length}{caugi}(x)
#'
#' @returns An integer representing the number of nodes.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   class = "DAG"
#' )
#' length(cg) # 2
#'
#' cg2 <- caugi(
#'   A %-->% B + C,
#'   nodes = LETTERS[1:5],
#'   class = "DAG"
#' )
#' length(cg2) # 5
#'
#' @family caugi methods
#' @concept methods
#'
#' @export
#' @rawNamespace export(length)
length.caugi <- function(x) {
  nrow(x@nodes)
}
S7::method(length, caugi) <- length.caugi

#' Print a `caugi`
#'
#' @param x A `caugi` object.
#' @param max_nodes Optional numeric; maximum number of node names to consider.
#'   If `NULL`, the method automatically prints as many as fit on one console
#'   line (plus a separate truncation line if needed).
#' @param max_edges Optional numeric; maximum number of edges to consider.
#'   If `NULL`, the method automatically prints as many edges as fit on two
#'   console lines (plus a separate truncation line if needed).
#' @param ... Not used.
#'
#' @returns The input `caugi` object, invisibly.
#'
#' @name print.caugi
#' @aliases print
#' @usage \method{print}{caugi}(x, max_nodes = getOption("caugi.max_nodes"),
#'   max_edges = getOption("caugi.max_edges"), ...)
#'
#' @examples
#' cg <- caugi(A %-->% B, class = "DAG")
#' print(cg)
#'
#' @family caugi methods
#' @concept methods
#'
#' @export
print.caugi <- function(
  x,
  max_nodes = getOption("caugi.max_nodes"),
  max_edges = getOption("caugi.max_edges"),
  ...
) {
  session <- x@session
  if (is.null(session)) {
    # Defensive fallback for malformed objects without a session.
    nodes_tbl <- data.table::data.table(name = character())
    edges_tbl <- data.table::data.table(
      from = character(),
      edge = character(),
      to = character()
    )
  } else {
    nodes_tbl <- x@nodes
    edges_tbl <- x@edges
  }

  n_nodes <- nrow(nodes_tbl)
  n_edges <- nrow(edges_tbl)

  if (is.null(session)) {
    graph_class <- NA_character_
    simple <- NA
  } else {
    graph_class <- x@graph_class
    simple <- x@simple
  }

  session_str <- if (is.null(session)) {
    "NULL"
  } else {
    session_chr <- format(session)
    if (grepl("0x[0-9a-fA-F]+", session_chr)) {
      sub(".*(0x[0-9a-fA-F]+).*", "\\1", session_chr)
    } else {
      session_chr
    }
  }

  # header split across two lines: main summary + graph_class line
  header <- sprintf(
    "<caugi object; %d nodes, %d edges; simple: %s; session=%s>",
    n_nodes,
    n_edges,
    simple,
    session_str
  )
  header_class <- sprintf("  graph_class: %s", graph_class)

  cat(header, "\n", sep = "")
  cat(header_class, "\n", sep = "")

  width <- getOption("width", 80L)

  # ── nodes: names on one line, truncation on its own line ────────────────────
  node_prefix <- "  nodes: "
  node_indent <- nchar(node_prefix, type = "width")

  if (n_nodes == 0L) {
    cat(node_prefix, "(none)\n", sep = "")
  } else {
    node_names <- nodes_tbl$name

    # cap by user-supplied max_nodes if finite
    if (!is.null(max_nodes) && is.finite(max_nodes)) {
      max_nodes <- as.integer(max_nodes)
      if (max_nodes < n_nodes) {
        node_names <- node_names[seq_len(max_nodes)]
      }
    }

    # how many of these names can fit on one line?
    n_fit <- .caugi_fit_on_line(node_names, width = width, indent = node_indent)
    if (n_fit < 1L) {
      n_fit <- 1L
    }

    shown_nodes <- min(n_fit, length(node_names))
    shown_names <- node_names[seq_len(shown_nodes)]

    first_line <- paste(shown_names, collapse = ", ")
    cat(node_prefix, first_line, "\n", sep = "")

    extra_nodes <- n_nodes - shown_nodes
    if (extra_nodes > 0L) {
      suffix <- paste0("... (", extra_nodes, " nodes more)")
      cat(strrep(" ", node_indent), suffix, "\n", sep = "")
    }
  }

  # ── edges: up to two lines of edges, truncation on its own line ─────────────
  edge_prefix <- "  edges: "
  edge_indent <- nchar(edge_prefix, type = "width")

  if (n_edges == 0L) {
    cat(edge_prefix, "(none)\n", sep = "")
    return(invisible(x))
  }

  edge_labels_all <- paste0(edges_tbl$from, edges_tbl$edge, edges_tbl$to)
  total_edges <- length(edge_labels_all)

  # apply max_edges cap if user supplied a finite value
  if (!is.null(max_edges) && is.finite(max_edges)) {
    max_edges <- as.integer(max_edges)
    edge_labels <- edge_labels_all[seq_len(min(max_edges, total_edges))]
    max_lines <- Inf
  } else {
    edge_labels <- edge_labels_all
    max_lines <- 2L
  }

  # wrap edges into lines
  lines <- character()
  used_edges <- 0L
  remaining <- edge_labels

  line_idx <- 1L
  while (length(remaining) > 0L && line_idx <= max_lines) {
    n_fit <- .caugi_fit_on_line(remaining, width = width, indent = edge_indent)
    if (n_fit < 1L) {
      n_fit <- 1L
    }
    take <- seq_len(min(n_fit, length(remaining)))

    line_labels <- remaining[take]
    lines <- c(lines, paste(line_labels, collapse = ", "))

    used_edges <- used_edges + length(take)
    remaining <- remaining[-take]
    line_idx <- line_idx + 1L
  }

  # print edge lines
  if (length(lines) == 0L) {
    cat(edge_prefix, "(none)\n", sep = "")
  } else {
    cat(edge_prefix, lines[[1L]], "\n", sep = "")
    if (length(lines) > 1L) {
      for (ln in lines[-1L]) {
        cat(strrep(" ", edge_indent), ln, "\n", sep = "")
      }
    }
  }

  # truncation line for edges
  extra_edges <- total_edges - used_edges
  if (extra_edges > 0L) {
    suffix <- paste0("... (", extra_edges, " edges more)")
    cat(strrep(" ", edge_indent), suffix, "\n", sep = "")
  }

  invisible(x)
}
S7::method(print, caugi) <- print.caugi

#' Summarize a `caugi`
#'
#' @description Summarizes a graph by its class, size and the number of edges
#' of each type.
#'
#' @param object A `caugi` object.
#' @param x A `caugi_summary` object.
#' @param ... Not used.
#'
#' @returns `summary()` returns a `caugi_summary` object: a list with
#'   `graph_class`, `n_nodes`, `n_edges` and `edge_types` (a table of edge
#'   counts by glyph). `print()` returns its input invisibly.
#'
#' @examples
#' cg <- caugi(A %-->% B + C, B %---% C, class = "PDAG")
#' summary(cg)
#'
#' @family caugi methods
#' @concept methods
#'
#' @export
summary.caugi <- function(object, ...) {
  edges <- object@edges
  structure(
    list(
      graph_class = object@graph_class,
      n_nodes = length(object),
      n_edges = nrow(edges),
      edge_types = table(edges$edge, dnn = NULL)
    ),
    class = "caugi_summary"
  )
}
S7::method(summary, caugi) <- summary.caugi

#' Convert a `caugi` to a data.frame
#'
#' @description Returns the graph as a plain `data.frame` with columns `from`,
#' `edge` and `to`: one row per edge, then one row per isolated node with the
#' node in `from` and `NA` in `edge` and `to`. [caugi()] reads such rows back
#' as isolated nodes, so `caugi(edges_df = as.data.frame(cg))` keeps every
#' node. Use [edges()] for the edges alone.
#'
#' @param x A `caugi` object.
#' @param row.names,optional Passed to [base::as.data.frame()].
#' @param ... Passed to [base::as.data.frame()].
#'
#' @returns A `data.frame` with columns `from`, `edge` and `to`.
#'
#' @examples
#' cg <- caugi(A %-->% B + C, B %---% C, D, class = "PDAG")
#' df <- as.data.frame(cg) # D has a row with edge = NA
#' caugi(edges_df = df, class = "PDAG") == cg # TRUE
#'
#' @family caugi methods
#' @concept methods
#'
#' @export
as.data.frame.caugi <- function(x, row.names = NULL, optional = FALSE, ...) {
  e <- x@edges
  iso <- setdiff(x@nodes$name, c(e$from, e$to))
  na <- rep(NA_character_, length(iso))
  as.data.frame(
    list(from = c(e$from, iso), edge = c(e$edge, na), to = c(e$to, na)),
    row.names = row.names,
    optional = optional,
    stringsAsFactors = FALSE,
    ...
  )
}
S7::method(as.data.frame, caugi) <- as.data.frame.caugi

#' @rdname summary.caugi
#' @export
print.caugi_summary <- function(x, ...) {
  cat(sprintf(
    "<caugi %s: %d nodes, %d edges>\n",
    x$graph_class,
    x$n_nodes,
    x$n_edges
  ))
  for (glyph in names(x$edge_types)) {
    cat(sprintf("  %s  %d\n", glyph, x$edge_types[[glyph]]))
  }
  invisible(x)
}

#' @title Fit items on a line
#'
#' @description Helper function to determine how many items can fit on a line
#' of given width, considering an indent.
#'
#' @param items A character vector of item labels.
#' @param width An integer specifying the total line width.
#' @param indent An integer specifying the indent width.
#'
#' @returns An integer indicating how many items fit on the line.
#'
#' @keywords internal
.caugi_fit_on_line <- function(items, width, indent) {
  if (length(items) == 0L) {
    return(0L)
  }

  used <- 0L
  current_len <- 0L

  for (lab in items) {
    lab_len <- nchar(lab, type = "width")

    if (used == 0L) {
      candidate_len <- lab_len
    } else {
      candidate_len <- current_len + 2L + lab_len # ", "
    }

    if (indent + candidate_len <= width || used == 0L) {
      used <- used + 1L
      current_len <- candidate_len
    } else {
      break
    }
  }

  used
}

#' Proxy for waldo comparison of caugi objects
#'
#' @description Provides a proxy representation for waldo comparison that
#' compares graph content (nodes, edges, simple, class) rather than session
#' identity.
#'
#' @param x A `caugi` object.
#' @param path The path to the object (for error messages).
#'
#' @returns A list with `object` (proxy) and `path`.
#'
#' @keywords internal
#' @export
`compare_proxy.caugi::caugi` <- function(x, path) {
  # Return a proxy with comparable properties (not the session pointer)
  list(
    object = list(
      simple = x@simple,
      graph_class = x@graph_class,
      nodes = sort(x@nodes$name),
      edges = rs_canonical_edges(x@session)
    ),
    path = path
  )
}

#' Compare caugi objects for equality
#'
#' @description S3 method for `all.equal` that compares caugi objects by their
#' graph content (nodes, edges, simple, class) rather than session identity.
#' This is used by testthat edition 2.
#'
#' @param target A `caugi` object.
#' @param current A `caugi` object.
#' @param ... Additional arguments (ignored).
#'
#' @returns `TRUE` if equal, or a character vector describing differences.
#'
#' @keywords internal
#' @export
`all.equal.caugi::caugi` <- function(target, current, ...) {
  if (!inherits(current, "caugi::caugi")) {
    return("current is not a caugi object")
  }

  diffs <- character(0)

  # Compare simple flag
  target_simple <- target@simple
  current_simple <- current@simple
  if (!identical(target_simple, current_simple)) {
    diffs <- c(
      diffs,
      sprintf(
        "simple: %s vs %s",
        target_simple,
        current_simple
      )
    )
  }

  # Compare graph_class
  target_class <- target@graph_class
  current_class <- current@graph_class
  if (!identical(target_class, current_class)) {
    diffs <- c(
      diffs,
      sprintf(
        "graph_class: %s vs %s",
        target_class,
        current_class
      )
    )
  }

  # Compare nodes
  target_nodes <- sort(target@nodes$name)
  current_nodes <- sort(current@nodes$name)
  if (!identical(target_nodes, current_nodes)) {
    diffs <- c(
      diffs,
      sprintf(
        "nodes differ: target has %d nodes, current has %d nodes",
        length(target_nodes),
        length(current_nodes)
      )
    )
  }

  # Compare edges in the canonical form Rust gives them
  target_edges <- rs_canonical_edges(target@session)
  current_edges <- rs_canonical_edges(current@session)
  if (length(target_edges$from) != length(current_edges$from)) {
    diffs <- c(
      diffs,
      sprintf(
        "edges differ: target has %d edges, current has %d edges",
        length(target_edges$from),
        length(current_edges$from)
      )
    )
  } else if (!identical(target_edges, current_edges)) {
    diffs <- c(diffs, "edges have different content")
  }

  if (length(diffs) == 0) {
    TRUE
  } else {
    diffs
  }
}

#' Equality operators for caugi objects
#'
#' @description S3 methods for `==` and `!=` that compare two caugi objects by
#' their graph content (nodes, edges, simple, class) rather than session
#' identity. Returns `FALSE` (resp. `TRUE`) when the other operand is not a
#' caugi object.
#'
#' @details
#' Row order is ignored, and an edge whose glyph is symmetric in the graph's
#' own edge registry is compared as an unordered pair, so `A --- B` and
#' `B --- A` are the same edge. Edges are also compared by their full
#' definition, so a glyph re-registered with a different meaning does not
#' match the original. Asymmetric glyphs are direction-sensitive, so
#' `A --> B` and `B --> A` are not.
#'
#' @param e1,e2 A `caugi` object (one or both sides).
#'
#' @returns A single logical.
#'
#' @examples
#' cg1 <- caugi(A %-->% B, class = "DAG")
#' cg2 <- caugi(A %-->% B, class = "DAG")
#' cg1 == cg2 # TRUE
#' cg1 != caugi(A %-->% C, class = "DAG") # TRUE
#'
#' # Symmetric edges are unordered, so these are the same graph.
#' caugi(A %---% B, class = "UG") == caugi(B %---% A, class = "UG") # TRUE
#'
#' # Directed edges are not.
#' caugi(A %-->% B, class = "DAG") == caugi(B %-->% A, class = "DAG") # FALSE
#'
#' @family caugi methods
#' @concept methods
#'
#' @name caugi-equality
#' @keywords internal
#' @export
`==.caugi::caugi` <- function(e1, e2) {
  if (!inherits(e1, "caugi::caugi") || !inherits(e2, "caugi::caugi")) {
    return(FALSE)
  }
  isTRUE(`all.equal.caugi::caugi`(e1, e2))
}

#' @rdname caugi-equality
#' @export
`!=.caugi::caugi` <- function(e1, e2) {
  !(e1 == e2)
}
