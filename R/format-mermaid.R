#' Mermaid Format Export
#'
#' Functions for converting caugi graphs to Mermaid flowchart format.
#' Mermaid is a JavaScript-based diagramming tool that renders in web browsers
#' and is natively supported by Quarto, GitHub, and many other platforms.
#'
#' @name format-mermaid
#' @family export
#' @concept export
NULL

#' S7 Class for Mermaid Export
#'
#' An S7 object that wraps a Mermaid format string for displaying caugi graphs.
#' When printed interactively, displays the Mermaid string cleanly.
#'
#' @param content A character string containing the Mermaid format graph.
#'
#' @family export
#' @concept export
#'
#' @export
caugi_mermaid <- S7::new_class(
  "caugi_mermaid",
  parent = caugi_export,
  constructor = function(content) {
    S7::new_object(caugi_export, content = content, format = "mermaid")
  }
)

#' Export caugi Graph to Mermaid Format
#'
#' Converts a caugi graph to the Mermaid flowchart format as a string.
#' Mermaid diagrams can be rendered in Quarto, R Markdown, GitHub, and
#' many other platforms.
#'
#' @param x A `caugi` object.
#' @param direction Graph direction: "TB" (top-bottom), "TD" (top-down),
#'   "BT" (bottom-top), "LR" (left-right), or "RL" (right-left).
#'   Default is "TD".
#'
#' @returns A `caugi_mermaid` object containing the Mermaid representation.
#'
#' @details
#' The function handles different edge types:
#' * Directed edges (`-->`) use `-->` in Mermaid
#' * Undirected edges (`---`) use `---` in Mermaid
#' * Bidirected edges (`<->`) use `<-->` in Mermaid
#' * Partial edges (`o->`) use `o-->` in Mermaid (circle end)
#'
#' Node names are automatically escaped if they contain special characters.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B + C,
#'   B %-->% D,
#'   C %-->% D,
#'   class = "DAG"
#' )
#'
#' # Get Mermaid string
#' mmd <- to_mermaid(cg)
#' mmd@content
#'
#' # With custom direction
#' mmd <- to_mermaid(cg, direction = "LR")
#'
#' @family export
#' @concept export
#' @export
to_mermaid <- function(x, direction = "TD") {
  is_caugi(x, throw_error = TRUE)

  # Validate direction
  valid_directions <- c("TB", "TD", "BT", "LR", "RL")
  if (!direction %in% valid_directions) {
    stop(
      "Invalid direction '",
      direction,
      "'. ",
      "Must be one of: ",
      paste(valid_directions, collapse = ", "),
      call. = FALSE
    )
  }

  # Ensure graph is built
  if (!x@built) {
    x <- build(x)
  }

  nodes_df <- nodes(x)
  edges_df <- edges(x)

  # Start building Mermaid string
  lines <- character()
  lines <- c(lines, paste0("flowchart ", direction))

  # Add edges (nodes are defined implicitly through edges in Mermaid)
  if (nrow(edges_df) > 0) {
    for (i in seq_len(nrow(edges_df))) {
      from <- escape_mermaid_id(edges_df$from[i])
      to <- escape_mermaid_id(edges_df$to[i])
      edge_type <- edges_df$edge[i]

      # Determine edge operator
      if (edge_type == "-->") {
        operator <- "-->"
      } else if (edge_type == "---") {
        operator <- "---"
      } else if (edge_type == "<->") {
        operator <- "<-->"
      } else if (edge_type == "o->") {
        operator <- "o-->"
      } else {
        # Unknown edge type, default to directed
        operator <- "-->"
      }

      edge_line <- paste0("  ", from, " ", operator, " ", to)
      lines <- c(lines, edge_line)
    }
  } else {
    # If no edges, define nodes explicitly
    for (i in seq_len(nrow(nodes_df))) {
      node_name <- escape_mermaid_id(nodes_df$name[i])
      lines <- c(lines, paste0("  ", node_name))
    }
  }

  result <- paste(lines, collapse = "\n")
  caugi_mermaid(content = result)
}

#' Write caugi Graph to Mermaid File
#'
#' Writes a caugi graph to a file in Mermaid format.
#'
#' @param x A `caugi` object.
#' @param file Path to output file.
#' @param ... Additional arguments passed to [to_mermaid()], such as
#'   `direction`.
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
#' write_mermaid(cg, "graph.mmd")
#'
#' # With custom direction
#' write_mermaid(cg, "graph.mmd", direction = "LR")
#' }
#'
#' @family export
#' @concept export
#' @export
write_mermaid <- function(x, file, ...) {
  mmd_obj <- to_mermaid(x, ...)
  writeLines(mmd_obj@content, file)
  invisible(file)
}

# Helper function to escape Mermaid identifiers
escape_mermaid_id <- function(x) {
  # Mermaid requires quotes around IDs with special characters
  # Simple alphanumeric + underscore don't need quotes
  needs_quotes <- !grepl("^[a-zA-Z_][a-zA-Z0-9_]*$", x)

  if (needs_quotes) {
    # Escape quotes
    x <- gsub('"', '\\"', x, fixed = TRUE)
    paste0('"', x, '"')
  } else {
    x
  }
}
