# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Methods ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' Length of a `caugi`
#'
#' @description Returns the number of nodes in the graph.
#'
#' @param x A `caugi` object.
#'
#' @name length
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
S7::method(length, caugi) <- function(x) {
  nrow(x@nodes)
}

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
#' @name print
#'
#' @examples
#' cg <- caugi(A %-->% B, class = "DAG")
#' print(cg)
#'
#' @family caugi methods
#' @concept methods
#'
#' @export
S7::method(print, caugi) <- function(
  x,
  max_nodes = getOption("caugi.max_nodes"),
  max_edges = getOption("caugi.max_edges"),
  ...
) {
  nodes_tbl <- x@nodes
  edges_tbl <- x@edges

  n_nodes <- nrow(nodes_tbl)
  n_edges <- nrow(edges_tbl)

  graph_class <- x@graph_class
  simple <- x@simple
  built <- x@built
  ptr <- x@ptr

  ptr_str <- if (is.null(ptr)) {
    "NULL"
  } else {
    ptr_chr <- format(ptr)
    if (grepl("0x[0-9a-fA-F]+", ptr_chr)) {
      sub(".*(0x[0-9a-fA-F]+).*", "\\1", ptr_chr)
    } else {
      ptr_chr
    }
  }

  # header split across two lines: main summary + graph_class line
  header <- sprintf(
    "<caugi object; %d nodes, %d edges; simple: %s; built: %s; ptr=%s>",
    n_nodes,
    n_edges,
    simple,
    built,
    ptr_str
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

  for (line_idx in seq_len(max_lines)) {
    if (length(remaining) == 0L) {
      break
    }

    n_fit <- .caugi_fit_on_line(remaining, width = width, indent = edge_indent)
    if (n_fit < 1L) {
      n_fit <- 1L
    }
    take <- seq_len(min(n_fit, length(remaining)))

    line_labels <- remaining[take]
    lines <- c(lines, paste(line_labels, collapse = ", "))

    used_edges <- used_edges + length(take)
    remaining <- remaining[-take]
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
