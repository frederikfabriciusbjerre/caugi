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
#' @returns A `caugi_mermaid` S7 object wrapping the Mermaid string.
#'
#' @family export
#' @concept export
#'
#' @export
caugi_mermaid <- S7::new_class(
  "caugi_mermaid",
  parent = caugi_export,
  constructor = function(content) {
    S7::new_object(caugi_export(), content = content, format = "mermaid")
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
#' * Partial edges (`o->`) use `o-->` in Mermaid (circle tail)
#' * Partial edges (`--o`) use `--o` in Mermaid (circle head)
#' * Partial edges (`o-o`) use `o--o` in Mermaid (circle both ends)
#'
#' Edges with a custom glyph from [register_caugi_edge()] are an error.
#'
#' Each node is written as `nK["name"]` with a generated ID `nK`, so any
#' name works, including Mermaid keywords such as `end`.
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
  .stop_if_custom_glyphs(x, "to_mermaid()")

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

  # Every node gets a generated ID, so names never meet Mermaid's syntax or
  # reserved words such as `end`; the name is the label, with `"` as `#quot;`.
  nm <- nodes(x)$name
  id <- paste0("n", seq_along(nm))
  label <- gsub('"', "#quot;", nm, fixed = TRUE)

  # Mermaid parses the start (`o`/`<`) and end (`o`/`>`) markers of a link
  # independently, so `o-->` is a circle tail with an arrow head, matching
  # caugi's `o->`. See destructStartLink()/destructEndLink() in Mermaid.
  operator <- c(
    "-->" = "-->",
    "---" = "---",
    "<->" = "<-->",
    "o->" = "o-->",
    "--o" = "--o",
    "o-o" = "o--o"
  )
  e <- edges(x)
  lines <- c(
    paste0("flowchart ", direction),
    paste0("  ", id, '["', label, '"]'),
    paste0(
      "  ",
      id[match(e$from, nm)],
      " ",
      operator[e$edge],
      " ",
      id[match(e$to, nm)],
      recycle0 = TRUE
    )
  )
  caugi_mermaid(content = paste(lines, collapse = "\n"))
}

#' Write caugi Graph to Mermaid File
#'
#' Writes a caugi graph to a file in Mermaid format, as UTF-8 in every locale.
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
  writeLines(enc2utf8(mmd_obj@content), file, useBytes = TRUE)
  invisible(file)
}
