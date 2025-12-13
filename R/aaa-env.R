# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── caugi environment ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# caugi package environment for edge registry
.caugi_env <- new.env(parent = emptyenv())

# Default caugi edge operators
.caugi_defaults_edge_ops <- c(
  "%-->%",
  "%---%",
  "%<->%",
  "%--o%",
  "%o->%",
  "%o-o%"
)

# Default caugi edge operator glyph map
.caugi_defaults_glyph_map <- c(
  "%-->%" = "-->",
  "%---%" = "---",
  "%<->%" = "<->",
  "%--o%" = "--o",
  "%o->%" = "o->",
  "%o-o%" = "o-o"
)

utils::globalVariables(c(
  "from",
  "to",
  "edge",
  ".",
  "..keys"
))

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────── caugi environemnt getters ───────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Get edge operators
#'
#' @description This function gets the default caugi edge operators
#'
#' @returns The current edge operators of the caugi environment
#'
#' @keywords internal
.edge_ops_get <- function() {
  get0("edge_ops", .caugi_env, ifnotfound = .caugi_defaults_edge_ops)
}

#' @title Get edge operators
#'
#' @description This function gets the default caugi edge glyphs
#'
#' @returns The current edge glyphs of the caugi environment
#'
#' @keywords internal
.glyph_map_get <- function() {
  get0("glyph_map", .caugi_env, ifnotfound = .caugi_defaults_glyph_map)
}
