#' GraphML Format Export and Import
#'
#' Functions for converting caugi graphs to and from GraphML format.
#' GraphML is an XML-based file format for graphs supported by many
#' graph tools and libraries.
#'
#' @name format-graphml
#' @family export
NULL

#' S7 Class for GraphML Export
#'
#' An S7 object that wraps a GraphML format string for caugi graphs.
#'
#' @param content A character string containing the GraphML format graph.
#'
#' @family export
#'
#' @export
caugi_graphml <- S7::new_class(
  "caugi_graphml",
  parent = caugi_export,
  constructor = function(content) {
    S7::new_object(caugi_export, content = content, format = "graphml")
  }
)

#' Export caugi Graph to GraphML Format
#'
#' Converts a caugi graph to the GraphML XML format as a string.
#' GraphML is widely supported by graph analysis tools and libraries.
#'
#' @param x A `caugi` object.
#'
#' @returns A `caugi_graphml` object containing the GraphML representation.
#'
#' @details
#' The GraphML export includes:
#' * Node IDs and labels
#' * Edge types stored as a custom `edge_type` attribute
#' * Graph class stored as a graph-level attribute
#'
#' Edge types are encoded using the caugi DSL operators (e.g., "-->", "<->").
#' This allows for perfect round-trip conversion back to caugi.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B + C,
#'   B %-->% D,
#'   C %-->% D,
#'   class = "DAG"
#' )
#'
#' # Get GraphML string
#' graphml <- to_graphml(cg)
#' cat(graphml@content)
#'
#' # Write to file
#' \dontrun{
#' write_graphml(cg, "graph.graphml")
#' }
#'
#' @family export
#' @export
to_graphml <- function(x) {
  is_caugi(x, throw_error = TRUE)
  xml <- rs_serialize_graphml(
    x@session,
    caugi_registry(),
    x@graph_class
  )

  caugi_graphml(xml)
}

#' Write caugi Graph to GraphML File
#'
#' Exports a caugi graph to a GraphML file.
#'
#' @param x A `caugi` object.
#' @param path File path for the output GraphML file.
#'
#' @returns Invisibly returns `NULL`. Called for side effects.
#'
#' @examples
#' cg <- caugi(A %-->% B + C, class = "DAG")
#'
#' tmp <- tempfile(fileext = ".graphml")
#' write_graphml(cg, tmp)
#'
#' # Read it back
#' cg2 <- read_graphml(tmp)
#'
#' # Clean up
#' unlink(tmp)
#'
#' @family export
#' @export
write_graphml <- function(x, path) {
  graphml <- to_graphml(x)
  writeLines(graphml@content, path)
  invisible(NULL)
}

#' Read GraphML File to caugi Graph
#'
#' Imports a GraphML file as a caugi graph. Supports GraphML files
#' exported from caugi with full edge type information.
#'
#' @param path File path to the GraphML file.
#' @param class Graph class to assign. If `NULL` (default), attempts to
#'   read from the GraphML metadata. If not present, defaults to "UNKNOWN".
#'
#' @returns A `caugi` object.
#'
#' @details
#' This function provides basic GraphML import support. It reads:
#' * Nodes and their IDs
#' * Edges with source and target
#' * Edge types (if present in `edge_type` attribute)
#' * Graph class (if present in graph data)
#'
#' For GraphML files not created by caugi, edge types default to "-->"
#' for directed graphs and "---" for undirected graphs.
#'
#' @examples
#' # Create and export a graph
#' cg <- caugi(
#'   A %-->% B,
#'   B %-->% C,
#'   class = "DAG"
#' )
#'
#' tmp <- tempfile(fileext = ".graphml")
#' write_graphml(cg, tmp)
#'
#' # Read it back
#' cg2 <- read_graphml(tmp)
#'
#' # Clean up
#' unlink(tmp)
#'
#' @family export
#' @export
read_graphml <- function(path, class = NULL) {
  if (!file.exists(path)) {
    stop("File not found: ", path, call. = FALSE)
  }

  xml_content <- paste(readLines(path, warn = FALSE), collapse = "\n")
  reg <- caugi_registry()
  result <- deserialize_graphml(xml_content, reg)

  # Use provided class or fall back to metadata
  final_class <- class %||% result$graph_class %||% "UNKNOWN"

  if (length(result$edges_from) == 0) {
    # No edges - just nodes
    return(caugi(nodes = result$nodes, class = final_class))
  }

  caugi(
    from = result$edges_from,
    edge = result$edges_type,
    to = result$edges_to,
    nodes = result$nodes,
    class = final_class
  )
}
