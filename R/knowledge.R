# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────── Background knowledge ─────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# The knowledge itself lives in Rust (`src/rust/src/knowledge.rs`); this class
# holds a pointer to it.
caugi_knowledge <- S7::new_class(
  "caugi_knowledge",
  properties = list(ptr = S7::class_any)
)

#' @title Background knowledge
#'
#' @description
#' What background knowledge do we have about a causal graph? This can be used
#' in causal discovery settings, to apply orientations on graphs, or to check
#' if some knowledge constraints apply to a graph.
#'
#' @details
#' Statements:
#' * `A %-->% B`: A and B are adjacent, and the edge is `A --> B`.
#' * `A %!-->% B`: there is no edge `A --> B`.
#' * `A %---% B`: A and B are adjacent.
#' * `A %!---% B`: A and B are not adjacent.
#' * `tier(t1 = A + B, t2 = C, max_lag = NULL)`: edges between tiers point from
#'   the earlier tier to the later one, and nodes in tiers more than `max_lag`
#'   apart are not adjacent. Every node must be in a tier.
#' * `exogenous(A, B)`: no edge points into A or B.
#'
#' Statements are written as edges in [caugi()]: `A + B %!-->% C`,
#' `A %-->% c(B, C)` and `A %-->% B %-->% C` all work.
#'
#' @param ... Statements, as above, or bare node names.
#' @param nodes Character vector of node names. If given, statements may only
#'   name these nodes.
#'
#' @returns A `caugi_knowledge` object.
#'
#' @examples
#' bk <- knowledge(
#'   tier(baseline = A + B, followup = C + D),
#'   A %-->% C,
#'   B %!-->% D,
#'   exogenous(A)
#' )
#' bk
#' nodes(bk)
#' edges(bk, expand = TRUE)
#'
#' @family knowledge
#' @concept knowledge
#'
#' @export
knowledge <- function(..., nodes = NULL) {
  calls <- as.list(substitute(list(...)))[-1L]
  env <- parent.frame()
  is_a <- function(f) {
    vapply(
      calls,
      function(ex) is.call(ex) && identical(ex[[1L]], as.name(f)),
      logical(1)
    )
  }
  tier <- is_a("tier")
  exo <- is_a("exogenous")
  if (sum(tier) > 1L) {
    stop("Use one `tier()`.", call. = FALSE)
  }
  tiers <- if (any(tier)) .kn_tiers(as.list(calls[tier][[1L]])[-1L], env)
  args <- lapply(calls[exo], function(ex) as.list(ex)[-1L])
  exogenous <- .get_nodes(NULL, unlist(args, recursive = FALSE))$name
  rest <- .collect_edges_nodes(calls[!tier & !exo], glyphs = .kn_glyphs)
  e <- rest$edges
  if (is.null(nodes)) {
    nodes <- c(rest$declared, unlist(tiers$tiers), exogenous, e$from, e$to)
  } else if (length(setdiff(rest$declared, nodes))) {
    stop(
      "Unknown node(s): ",
      toString(setdiff(rest$declared, nodes)),
      call. = FALSE
    )
  }
  .kn_new(rs_kn_new(
    unique(as.character(nodes)),
    e$from,
    e$edge,
    e$to,
    as.character(names(tiers$tiers)),
    as.list(unname(tiers$tiers)),
    tiers$max_lag,
    exogenous
  ))
}

#' @title Is it background knowledge?
#'
#' @param x An object.
#' @param throw_error Logical; if `TRUE`, error when `x` is not knowledge.
#'
#' @returns `TRUE` if `x` was made by [knowledge()], else `FALSE`.
#'
#' @examples
#' is_knowledge(knowledge(A %-->% B)) # TRUE
#' is_knowledge(caugi(A %-->% B)) # FALSE
#'
#' @family knowledge
#' @concept knowledge
#'
#' @export
is_knowledge <- function(x, throw_error = FALSE) {
  ok <- S7::S7_inherits(x, caugi_knowledge)
  if (!ok && throw_error) {
    stop("Input must be made by `knowledge()`.", call. = FALSE)
  }
  ok
}

#' @title Tiers of background knowledge
#'
#' @param bk Background knowledge, made by [knowledge()].
#'
#' @returns A named list of node names per tier, earliest tier first. Empty if
#'   `bk` has no tiers.
#'
#' @examples
#' bk <- knowledge(tier(baseline = A + B, followup = C))
#' tiers(bk)
#'
#' @family knowledge
#' @concept knowledge
#'
#' @export
tiers <- function(bk) {
  is_knowledge(bk, throw_error = TRUE)
  t <- rs_kn_tiers(bk@ptr)
  if (length(t$names)) stats::setNames(t$members, t$names) else list()
}

S7::method(print, caugi_knowledge) <- function(x, ...) {
  n <- nodes(x)
  e <- edges(x)
  t <- tiers(x)
  lag <- rs_kn_tiers(x@ptr)$max_lag
  # Names as R code, backticked where needed.
  code <- function(v) {
    vapply(
      v,
      function(s) deparse1(as.name(s), backtick = TRUE),
      "",
      USE.NAMES = FALSE
    )
  }
  cat("<knowledge; nodes: ", toString(n$name), ">\n", sep = "")
  lines <- c(
    if (length(t)) {
      members <- vapply(t, function(v) paste(code(v), collapse = " + "), "")
      paste0(
        "tier(",
        toString(paste(code(names(t)), "=", members)),
        if (!is.na(lag)) paste0(", max_lag = ", lag),
        ")"
      )
    },
    if (any(n$exogenous)) {
      paste0("exogenous(", toString(code(n$name[n$exogenous])), ")")
    },
    paste0(code(e$from), " %", e$edge, "% ", code(e$to), recycle0 = TRUE)
  )
  cat(paste0("  ", lines, "\n", recycle0 = TRUE), sep = "")
  invisible(x)
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Internal helpers ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# The operators knowledge statements are written with, for the DSL parser.
.kn_glyphs <- c(
  "%-->%" = "-->",
  "%!-->%" = "!-->",
  "%---%" = "---",
  "%!---%" = "!---"
)

# Rust returns an inconsistency as a condition of class `caugi_inconsistent`.
.kn_rust <- function(x) {
  if (inherits(x, "condition")) {
    stop(x)
  }
  x
}

.kn_new <- function(ptr) {
  caugi_knowledge(ptr = .kn_rust(ptr))
}

.kn_tiers <- function(args, env) {
  max_lag <- args[["max_lag"]]
  args[["max_lag"]] <- NULL
  tiers <- lapply(args, .expand_nodes)
  if (length(tiers)) {
    nm <- if (is.null(names(tiers))) character(length(tiers)) else names(tiers)
    names(tiers) <- ifelse(nm == "", seq_along(tiers), nm)
  }
  list(tiers = tiers, max_lag = if (!is.null(max_lag)) eval(max_lag, env))
}
