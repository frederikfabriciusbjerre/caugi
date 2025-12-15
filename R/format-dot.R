#' DOT Format Export and Import
#'
#' Functions for converting caugi graphs to and from Graphviz DOT format.
#' The DOT format is a plain text graph description language used by
#' Graphviz tools for visualization.
#'
#' @name format-dot
#' @family export
#' @concept export
NULL

#' S7 Class for DOT Export
#'
#' An S7 object that wraps a DOT format string for displaying caugi graphs.
#' When printed interactively, displays the DOT string cleanly.
#'
#' @param content A character string containing the DOT format graph.
#'
#' @family export
#' @concept export
#'
#' @export
caugi_dot <- S7::new_class(
  "caugi_dot",
  parent = caugi_export,
  constructor = function(content) {
    S7::new_object(caugi_export, content = content, format = "dot")
  }
)

#' Export caugi Graph to DOT Format
#'
#' Converts a caugi graph to the Graphviz DOT format as a string.
#' The DOT format can be used with Graphviz tools for visualization
#' and analysis.
#'
#' @param x A `caugi` object.
#' @param graph_attrs Named list of graph attributes (e.g.,
#'   `list(rankdir = "LR")`).
#' @param node_attrs Named list of default node attributes.
#' @param edge_attrs Named list of default edge attributes.
#'
#' @returns A `caugi_dot` object containing the DOT representation.
#'
#' @details
#' The function handles different edge types:
#' * Directed edges (`-->`) use `->` in DOT
#' * Undirected edges (`---`) use `--` in DOT (or `->` with `dir=none` in digraphs)
#' * Bidirected edges (`<->`) use `->` with `[dir=both]` attribute
#' * Partial edges (`o->`) use `->` with `[arrowtail=odot, dir=both]` attribute
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B + C,
#'   B %-->% D,
#'   C %-->% D,
#'   class = "DAG"
#' )
#'
#' # Get DOT string
#' dot <- to_dot(cg)
#' dot@content
#'
#' # With custom attributes
#' dot <- to_dot(
#'   cg,
#'   graph_attrs = list(rankdir = "LR"),
#'   node_attrs = list(shape = "box")
#' )
#'
#' @family export
#' @concept export
#' @export
to_dot <- function(
  x,
  graph_attrs = list(),
  node_attrs = list(),
  edge_attrs = list()
) {
  is_caugi(x, throw_error = TRUE)

  # Ensure graph is built
  if (!x@built) {
    x <- build(x)
  }

  nodes_df <- nodes(x)
  edges_df <- edges(x)

  # Start building DOT string
  lines <- character()

  # Determine graph type based on edge types
  has_directed <- any(edges_df$edge %in% c("-->", "o->", "<->"))

  # Use digraph if any directed edges, otherwise graph
  graph_type <- if (has_directed) "digraph" else "graph"
  lines <- c(lines, paste0(graph_type, " {"))

  # Add graph attributes
  if (length(graph_attrs) > 0) {
    for (name in names(graph_attrs)) {
      lines <- c(
        lines,
        paste0("  ", name, "=", format_dot_value(graph_attrs[[name]]), ";")
      )
    }
  }

  # Add default node attributes
  if (length(node_attrs) > 0) {
    attr_str <- paste(
      names(node_attrs),
      sapply(node_attrs, format_dot_value),
      sep = "=",
      collapse = ", "
    )
    lines <- c(lines, paste0("  node [", attr_str, "];"))
  }

  # Add default edge attributes
  if (length(edge_attrs) > 0) {
    attr_str <- paste(
      names(edge_attrs),
      sapply(edge_attrs, format_dot_value),
      sep = "=",
      collapse = ", "
    )
    lines <- c(lines, paste0("  edge [", attr_str, "];"))
  }

  # Add nodes
  lines <- c(lines, "")
  lines <- c(lines, "  // Nodes")
  for (i in seq_len(nrow(nodes_df))) {
    node_name <- nodes_df$name[i]
    lines <- c(lines, paste0("  ", escape_dot_id(node_name), ";"))
  }

  # Add edges
  if (nrow(edges_df) > 0) {
    lines <- c(lines, "")
    lines <- c(lines, "  // Edges")

    for (i in seq_len(nrow(edges_df))) {
      from <- escape_dot_id(edges_df$from[i])
      to <- escape_dot_id(edges_df$to[i])
      edge_type <- edges_df$edge[i]

      # Determine edge operator and attributes
      edge_attrs_list <- list()

      if (edge_type == "-->") {
        operator <- "->"
      } else if (edge_type == "---") {
        # In digraph, undirected edges must be represented as bidirectional
        if (graph_type == "digraph") {
          operator <- "->"
          edge_attrs_list$dir <- "none"
        } else {
          operator <- "--"
        }
      } else if (edge_type == "<->") {
        operator <- "->"
        edge_attrs_list$dir <- "both"
      } else if (edge_type == "o->") {
        operator <- "->"
        edge_attrs_list$dir <- "both"
        edge_attrs_list$arrowtail <- "odot"
      } else {
        # Unknown edge type, default to directed
        operator <- "->"
      }

      # Build edge line
      edge_line <- paste(from, operator, to)

      if (length(edge_attrs_list) > 0) {
        attr_str <- paste(
          names(edge_attrs_list),
          sapply(edge_attrs_list, format_dot_value),
          sep = "=",
          collapse = ", "
        )
        edge_line <- paste0(edge_line, " [", attr_str, "]")
      }

      lines <- c(lines, paste0("  ", edge_line, ";"))
    }
  }

  lines <- c(lines, "}")

  result <- paste(lines, collapse = "\n")
  caugi_dot(content = result)
}

#' Write caugi Graph to DOT File
#'
#' Writes a caugi graph to a file in Graphviz DOT format.
#'
#' @param x A `caugi` object.
#' @param file Path to output file.
#' @param ... Additional arguments passed to [to_dot()], such as `graph_attrs`,
#'   `node_attrs`, and `edge_attrs`.
#'
#' @returns Invisibly returns the path to the file.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B + C,
#'   B %-->% D,
#'   C %-->% D,
#'   class = "DAG"
#' )
#'
#' \dontrun{
#' # Write to file
#' write_dot(cg, "graph.dot")
#'
#' # With custom attributes
#' write_dot(
#'   cg,
#'   "graph.dot",
#'   graph_attrs = list(rankdir = "LR")
#' )
#' }
#'
#' @family export
#' @concept export
#' @export
write_dot <- function(x, file, ...) {
  dot_obj <- to_dot(x, ...)
  writeLines(dot_obj@content, file)
  invisible(file)
}

# Helper function to format DOT values
format_dot_value <- function(x) {
  if (is.character(x)) {
    paste0('"', x, '"')
  } else {
    as.character(x)
  }
}

# Helper function to escape DOT identifiers
escape_dot_id <- function(x) {
  # Check if identifier needs quotes
  # DOT identifiers can be alphanumeric + underscore, or must be quoted
  needs_quotes <- !grepl("^[a-zA-Z_][a-zA-Z0-9_]*$", x)

  if (needs_quotes) {
    # Escape quotes and backslashes
    x <- gsub("\\\\", "\\\\\\\\", x)
    x <- gsub('"', '\\\\"', x)
    paste0('"', x, '"')
  } else {
    x
  }
}
