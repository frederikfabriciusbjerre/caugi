#' Caugi Native Format Serialization
#'
#' Functions for converting caugi graphs to and from the native caugi JSON format.
#' This format provides efficient, reproducible serialization for saving and sharing
#' caugi graphs.
#'
#' @name format-caugi
#' @family export
#' @concept export
NULL

#' Write caugi Graph to File
#'
#' Writes a caugi graph to a file in the native caugi JSON format.
#' This format is designed for reproducibility, caching, and sharing
#' caugi graphs across R sessions.
#'
#' @param x A `caugi` object or an object coercible to `caugi`.
#' @param path Character string specifying the file path.
#' @param comment Optional character string with a comment about the graph.
#' @param tags Optional character vector of tags for categorizing the graph.
#'
#' @returns Invisibly returns the input `x`.
#'
#' @details
#' The caugi format is a versioned JSON schema that captures:
#' * Graph structure (nodes and edges with their types)
#' * Graph class (DAG, PDAG, ADMG, UG, etc.)
#' * Optional metadata (comments and tags)
#'
#' Edge types are encoded using their DSL operators (e.g., `"-->"`, `"<->"`, `"--"`).
#'
#' For a complete guide to the format, see `vignette("serialization", package = "caugi")`.
#' The formal JSON Schema is available at:
#' <https://caugi.org/schemas/caugi-v1.schema.json>
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B + C,
#'   B %-->% D,
#'   C %-->% D,
#'   class = "DAG"
#' )
#'
#' # Write to file
#' tmp <- tempfile(fileext = ".caugi.json")
#' write_caugi(cg, tmp, comment = "Example DAG")
#'
#' # Read back
#' cg2 <- read_caugi(tmp)
#' identical(edges(cg), edges(cg2))
#'
#' # Clean up
#' unlink(tmp)
#'
#' @family export
#' @concept export
#'
#' @export
write_caugi <- function(x, path, comment = NULL, tags = NULL) {
  is_caugi(x, throw_error = TRUE)

  # Build the graph if needed
  x <- build(x)

  # Validate arguments
  if (!is.character(path) || length(path) != 1L) {
    stop("`path` must be a single character string", call. = FALSE)
  }
  if (!is.null(comment) && (!is.character(comment) || length(comment) != 1L)) {
    stop("`comment` must be NULL or a single character string", call. = FALSE)
  }
  if (!is.null(tags) && !is.character(tags)) {
    stop("`tags` must be NULL or a character vector", call. = FALSE)
  }

  write_caugi_file_ptr(
    x@ptr,
    caugi_registry(),
    x@graph_class,
    x@nodes$name,
    path,
    comment,
    tags
  )

  invisible(x)
}

#' Read caugi Graph from File
#'
#' Reads a caugi graph from a file in the native caugi JSON format.
#'
#' @param path Character string specifying the file path.
#' @param lazy Logical; if `FALSE` (default), the graph is built immediately.
#'   If `TRUE`, graph building is deferred until needed.
#'
#' @returns A `caugi` object.
#'
#' @details
#' The function validates the file format and version, ensuring compatibility
#' with the current version of the caugi package.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B + C,
#'   class = "DAG"
#' )
#'
#' # Write and read
#' tmp <- tempfile(fileext = ".caugi.json")
#' write_caugi(cg, tmp)
#' cg2 <- read_caugi(tmp)
#'
#' # Clean up
#' unlink(tmp)
#'
#' @family export
#' @concept export
#'
#' @export
read_caugi <- function(path, lazy = FALSE) {
  if (!is.character(path) || length(path) != 1L) {
    stop("`path` must be a single character string", call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("File not found: ", path, call. = FALSE)
  }
  if (!is.logical(lazy) || length(lazy) != 1L) {
    stop("`lazy` must be a single logical value", call. = FALSE)
  }

  # Get the global registry
  reg <- caugi_registry()

  # Read from file
  result <- read_caugi_file_ptr(path, reg)

  # Create caugi object using the standard constructor
  if (length(result$edges_from) == 0L) {
    cg <- caugi(
      nodes = result$nodes,
      class = result$graph_class,
      build = !lazy
    )
  } else {
    cg <- caugi(
      from = result$edges_from,
      edge = result$edges_type,
      to = result$edges_to,
      nodes = result$nodes,
      class = result$graph_class,
      build = !lazy
    )
  }

  cg
}

#' Serialize caugi Graph to JSON String
#'
#' Converts a caugi graph to a JSON string in the native caugi format.
#' This is a lower-level function; consider using `write_caugi()` for
#' writing to files.
#'
#' @param x A `caugi` object or an object coercible to `caugi`.
#' @param comment Optional character string with a comment about the graph.
#' @param tags Optional character vector of tags for categorizing the graph.
#'
#' @returns A character string containing the JSON representation.
#'
#' @examples
#' cg <- caugi(A %-->% B, class = "DAG")
#' json <- caugi_serialize(cg)
#' cat(json)
#'
#' @family export
#' @concept export
#'
#' @export
caugi_serialize <- function(x, comment = NULL, tags = NULL) {
  is_caugi(x, throw_error = TRUE)

  # Build the graph if needed
  x <- build(x)

  # Validate arguments
  if (!is.null(comment) && (!is.character(comment) || length(comment) != 1L)) {
    stop("`comment` must be NULL or a single character string", call. = FALSE)
  }
  if (!is.null(tags) && !is.character(tags)) {
    stop("`tags` must be NULL or a character vector", call. = FALSE)
  }

  serialize_caugi_ptr(
    x@ptr,
    caugi_registry(),
    x@graph_class,
    x@nodes$name,
    comment,
    tags
  )
}

#' Deserialize caugi Graph from JSON String
#'
#' Converts a JSON string in the native caugi format back to a caugi graph.
#' This is a lower-level function; consider using `read_caugi()` for
#' reading from files.
#'
#' @param json Character string containing the JSON representation.
#' @param lazy Logical; if `FALSE` (default), the graph is built immediately.
#'   If `TRUE`, graph building is deferred until needed.
#'
#' @returns A `caugi` object.
#'
#' @examples
#' cg <- caugi(A %-->% B, class = "DAG")
#' json <- caugi_serialize(cg)
#' cg2 <- caugi_deserialize(json)
#'
#' @family export
#' @concept export
#'
#' @export
caugi_deserialize <- function(json, lazy = FALSE) {
  if (!is.character(json) || length(json) != 1L) {
    stop("`json` must be a single character string", call. = FALSE)
  }
  if (!is.logical(lazy) || length(lazy) != 1L) {
    stop("`lazy` must be a single logical value", call. = FALSE)
  }

  # Get the global registry
  reg <- caugi_registry()

  # Deserialize
  result <- deserialize_caugi_ptr(json, reg)

  # Create caugi object using the standard constructor
  if (length(result$edges_from) == 0L) {
    cg <- caugi(
      nodes = result$nodes,
      class = result$graph_class,
      build = !lazy
    )
  } else {
    cg <- caugi(
      from = result$edges_from,
      edge = result$edges_type,
      to = result$edges_to,
      nodes = result$nodes,
      class = result$graph_class,
      build = !lazy
    )
  }

  cg
}
