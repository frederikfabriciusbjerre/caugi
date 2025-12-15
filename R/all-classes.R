#' Export Format Classes
#'
#' S7 classes for representing caugi graphs in various export formats.
#' These classes provide a common interface for serializing graphs to
#' different text formats like DOT, GraphML, JSON, etc.
#'
#' @section Base Class:
#' [`caugi_export`] is the base class for all export formats. It provides:
#' * `content` property: Character string containing the serialized graph
#' * `format` property: Character string indicating the format type
#' * Common methods: `print()`, `as.character()`, `knit_print()`
#'
#' @section Subclasses:
#' * [`caugi_dot`]: DOT format for Graphviz visualization
#'
#' @name export-classes
#' @family export
#' @concept export
NULL

#' S7 Base Class for Caugi Exports
#'
#' A base class for all caugi export formats. Provides common structure
#' and behavior for different export formats (DOT, GraphML, etc.).
#'
#' @param content A character string containing the exported graph.
#' @param format A character string indicating the export format.
#'
#' @family export
#' @concept export
#'
#' @export
caugi_export <- S7::new_class(
  "caugi_export",
  properties = list(
    content = S7::class_character,
    format = S7::class_character
  )
)

#' @export
S7::method(print, caugi_export) <- function(x, ...) {
  cat(x@content, "\n", sep = "")
  invisible(x)
}

#' @export
S7::method(as.character, caugi_export) <- function(x, ...) {
  x@content
}

knit_print <- S7::new_external_generic("knitr", "knit_print", "x")

# TODO: Roxygen + S7 does not work for documenting this method currently.
# Once https://github.com/RConsortium/S7/issues/562 is resolved, we should
# be able to add `#' @export` here.

#' Knit Print Method for caugi_export
#'
#' Renders caugi export objects as code blocks in Quarto/R Markdown documents.
#' This method is automatically invoked when an export object is the last
#' expression in a code chunk.
#'
#' @param x A `caugi_export` object.
#' @param ... Additional arguments (currently unused).
#'
#' @returns A `knit_asis` object for rendering by knitr.
#'
#' @details
#' This method enables seamless rendering of caugi graphs in Quarto and
#' R Markdown. The code block type is determined by the export format.
#' Simply use an export function (e.g., `to_dot(cg)`) as the last expression
#' in a chunk with `output: asis`:
#'
#' ```
#' #| output: asis
#' to_dot(cg)
#' ```
#' @name knit_print.caugi_export
#' @family export
#' @concept export
S7::method(
  knit_print,
  caugi_export
) <- function(
  x,
  ...
) {
  knitr::asis_output(paste0("```{", x@format, "}\n", x@content, "\n```\n"))
}
