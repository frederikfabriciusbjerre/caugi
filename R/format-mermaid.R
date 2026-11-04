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
#' A node name Mermaid reads as an ID, such as `A`, `Sepal.Length`,
#' `age-group` or `2.5`, is written as it is. Any other name, such as `my var`
#' or the keyword `end`, is written as `nK["name"]` with a generated ID `nK`.
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

  # A name Mermaid reads as an ID is written as it is. Any other name gets a
  # generated ID `nK` with the name as its label, `"` written as `#quot;`. The
  # rule below was checked against the parser of Mermaid 11.4.1 and 11.17.2.
  nm <- nodes(x)$name
  e <- edges(x)
  keywords <- c(
    "call",
    "class",
    "classDef",
    "click",
    "end",
    "flowchart",
    "graph",
    "href",
    "interpolate",
    "linkStyle",
    "style",
    "subgraph"
  )
  # Mermaid reads ASCII letters, digits and the symbols listed below, and
  # Latin, Greek and Cyrillic letters except U+037F. `--`, `-.` and `.-` start
  # a link, `:::` a class and a leading `%%` a comment, and `direction` and a
  # keyword that is not part of a longer word, as in `end` or `1class`, break
  # the parse.
  bare <- grepl(
    "(*UTF)^(?:[A-Za-z0-9!#$%&'*+,./:?\\\\_`-]|(?!\\x{37F})(?=\\p{L})[\\x{C0}-\\x{4FF}])+$",
    enc2utf8(nm),
    perl = TRUE
  ) &
    !grepl("--|-\\.|\\.-|:::|^%%|direction", nm) &
    !grepl(
      paste0(
        "(^|[^A-Za-z_])(",
        paste(keywords, collapse = "|"),
        ")([^A-Za-z0-9_]|$)"
      ),
      nm
    )
  id <- nm
  id[!bare] <- make.unique(c(nm[bare], paste0("n", which(!bare))), "_")[
    sum(bare) + seq_len(sum(!bare))
  ]
  # A node is declared on its own line if it needs a label or has no edges.
  decl <- !bare | !nm %in% c(e$from, e$to)
  label <- ifelse(
    bare,
    "",
    paste0('["', gsub('"', "#quot;", nm, fixed = TRUE), '"]')
  )

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
  lines <- c(
    paste0("flowchart ", direction),
    paste0("  ", id[decl], label[decl], recycle0 = TRUE),
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
