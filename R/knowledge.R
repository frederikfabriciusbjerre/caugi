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
#' Background knowledge about a causal graph: required and forbidden edges,
#' tiers and exogenous nodes.
#'
#' @details
#' Statements:
#' * `A %-->% B`: the edge `A --> B` is required.
#' * `!(A %-->% B)`: the edge `A --> B` is forbidden. The parentheses are
#'   required, and `!` applies to each edge inside them.
#' * `tier(t1 = A + B, t2 = C, max_lag = NULL)`: edges between tiers point from
#'   the earlier tier to the later one, and nodes in tiers more than `max_lag`
#'   apart are not adjacent. Nodes without a tier are not constrained by it.
#' * `exogenous(A, B)`: no edge points into A or B.
#'
#' Edges are written as in [caugi()], so `A + B %-->% C` and
#' `A %-->% B %-->% C` work too.
#'
#' @param ... Statements, as above, or bare node names.
#' @param nodes Character vector of node names. If given, the knowledge is about
#'   exactly these nodes: no statement, and no later edit, may name another.
#'
#' @returns A `caugi_knowledge` object.
#'
#' @examples
#' bk <- knowledge(
#'   tier(baseline = A + B, followup = C + D),
#'   A %-->% C,
#'   !(B %-->% D),
#'   exogenous(A)
#' )
#' bk
#' edges(bk, expand = TRUE)
#' plot(bk)
#'
#' @family knowledge
#' @concept knowledge
#'
#' @export
knowledge <- function(..., nodes = NULL) {
  calls <- as.list(substitute(list(...)))[-1L]
  tier <- .kn_is(calls, "tier")
  exo <- .kn_is(calls, "exogenous")
  if (sum(tier) > 1L) {
    stop("Use one `tier()`.", call. = FALSE)
  }
  tiers <- if (any(tier)) {
    .kn_tiers(as.list(calls[tier][[1L]])[-1L], parent.frame())
  }
  args <- lapply(calls[exo], function(ex) as.list(ex)[-1L])
  exogenous <- .get_nodes(NULL, unlist(args, recursive = FALSE))$name
  s <- .kn_parse(calls[!tier & !exo])
  closed <- !is.null(nodes)
  if (!closed) {
    nodes <- c(s$declared, unlist(tiers$tiers), exogenous, s$from, s$to)
  } else if (length(setdiff(s$declared, nodes))) {
    stop(
      "Unknown node(s): ",
      toString(setdiff(s$declared, nodes)),
      call. = FALSE
    )
  }
  .kn_new(rs_kn_new(
    unique(as.character(nodes)),
    s$from,
    s$to,
    s$status,
    as.character(names(tiers$tiers)),
    as.list(unname(tiers$tiers)),
    tiers$max_lag,
    exogenous,
    closed
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
#' @returns A named list of node names per tier, earliest tier first.
#'
#' @examples
#' tiers(knowledge(tier(baseline = A + B, followup = C)))
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

#' @title Required and forbidden edges of background knowledge
#'
#' @description
#' The edges `bk` requires or forbids, as written, as a `caugi` of class
#' `"UNKNOWN"` on its nodes.
#'
#' @param bk Background knowledge, made by [knowledge()].
#'
#' @returns A `caugi`.
#'
#' @examples
#' bk <- knowledge(A %-->% B, !(B %-->% C), !(C %-->% B))
#' required(bk)
#' forbidden(bk)
#'
#' @family knowledge
#' @concept knowledge
#'
#' @export
required <- function(bk) {
  .kn_edges_graph(bk, "required", "UNKNOWN")
}

#' @rdname required
#' @export
forbidden <- function(bk) {
  .kn_edges_graph(bk, "forbidden", "UNKNOWN")
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
  edge <- paste0(code(e$from), " %-->% ", code(e$to), recycle0 = TRUE)
  cat("<knowledge; nodes: ", toString(n$name), ">\n", sep = "")
  lines <- c(
    if (length(t)) {
      members <- vapply(t, function(v) paste(code(v), collapse = " + "), "")
      paste0(
        "tier(",
        toString(paste(code(names(t)), "=", members)),
        if (!is.null(lag)) paste0(", max_lag = ", lag),
        ")"
      )
    },
    if (any(n$exogenous)) {
      paste0("exogenous(", toString(code(n$name[n$exogenous])), ")")
    },
    ifelse(e$status == "required", edge, paste0("!(", edge, ")"))
  )
  cat(paste0("  ", lines, "\n", recycle0 = TRUE), sep = "")
  invisible(x)
}

#' @title Set the tiers or exogenous nodes of background knowledge
#'
#' @description
#' `set_tiers()` replaces the tiers, written as in `tier()` of [knowledge()].
#' `set_exogenous()` replaces the exogenous nodes. Both add nodes they name.
#'
#' @param bk Background knowledge, made by [knowledge()].
#' @param ... Tiers, earliest first, such as `baseline = A + B`, or exogenous
#'   nodes.
#' @param tiers A list of character vectors, one per tier, instead of `...`.
#' @param max_lag Nodes in tiers more than `max_lag` apart are not adjacent.
#'   If missing, the current `max_lag` is kept. `NULL` removes it.
#' @param name A character vector of node names, instead of `...`.
#'
#' @returns The updated knowledge.
#'
#' @examples
#' bk <- knowledge(A %-->% B)
#' bk <- set_tiers(bk, baseline = A, followup = B + C)
#' set_exogenous(bk, A)
#'
#' @family knowledge
#' @concept knowledge
#'
#' @export
set_tiers <- function(bk, ..., tiers = NULL, max_lag) {
  is_knowledge(bk, throw_error = TRUE)
  calls <- as.list(substitute(list(...)))[-1L]
  if (length(calls) && !is.null(tiers)) {
    stop("Provide tiers via `...` or `tiers`, not both.", call. = FALSE)
  }
  t <- if (length(calls)) {
    .kn_tiers(calls, parent.frame())$tiers
  } else {
    .kn_tier_names(lapply(tiers, as.character))
  }
  if (missing(max_lag)) {
    max_lag <- rs_kn_tiers(bk@ptr)$max_lag
  }
  .kn_new(rs_kn_set_tiers(
    bk@ptr,
    as.character(names(t)),
    as.list(unname(t)),
    max_lag
  ))
}

#' @rdname set_tiers
#' @export
set_exogenous <- function(bk, ..., name = NULL) {
  is_knowledge(bk, throw_error = TRUE)
  calls <- as.list(substitute(list(...)))[-1L]
  .kn_new(rs_kn_set_exogenous(bk@ptr, .get_nodes(name, calls)$name))
}

#' @title Apply and check background knowledge
#'
#' @description
#' `orient()` returns the tightest graph that agrees with both `cg` and `bk`:
#' an MPDAG, or a DAG if every edge is directed. It errors with class
#' `caugi_inconsistent` if no DAG agrees with both.
#'
#' `holds()` checks each statement of `edges(bk, expand = TRUE)`: `TRUE` if it
#' holds in every DAG `cg` stands for, `FALSE` if in none, and `NA` otherwise.
#'
#' @param cg A `caugi` with only `-->` and `---` edges, such as a DAG, PDAG,
#'   CPDAG or MPDAG.
#' @param bk Background knowledge, made by [knowledge()].
#'
#' @returns `orient()`: a `caugi`. `holds()`: `edges(bk, expand = TRUE)` with
#'   a logical column `holds`.
#'
#' @examples
#' cpdag <- caugi(A %---% B, B %---% C, class = "CPDAG")
#' bk <- knowledge(A %-->% B)
#' holds(cpdag, bk) # NA: some DAGs have A --> B, some B --> A
#' orient(cpdag, bk) # A --> B --> C
#'
#' @references
#' E. Perkovic, M. Kalisch and M. H. Maathuis (2017). Interpreting and using
#' CPDAGs with background knowledge. In \emph{Proceedings of the 33rd
#' Conference on Uncertainty in Artificial Intelligence (UAI-17)}.
#'
#' @family knowledge
#' @concept knowledge
#'
#' @export
orient <- function(cg, bk) {
  is_caugi(cg, throw_error = TRUE)
  is_knowledge(bk, throw_error = TRUE)
  session <- .kn_rust(rs_kn_orient(bk@ptr, cg@session))
  out <- .session_to_caugi(session, node_names = cg@nodes$name)
  if (is_dag(out)) mutate_caugi(out, "DAG") else out
}

#' @rdname orient
#' @export
holds <- function(cg, bk) {
  is_caugi(cg, throw_error = TRUE)
  is_knowledge(bk, throw_error = TRUE)
  .kn_table(.kn_rust(rs_kn_holds(bk@ptr, cg@session)))
}

# Drawn as a graph: forbidden edges dashed red, laid out by tier when every
# node has one.
S7::method(plot, caugi_knowledge) <- function(x, edge_style = list(), ...) {
  e <- edges(x)
  by_edge <- list()
  for (i in which(e$status == "forbidden")) {
    by_edge[[e$from[i]]][[e$to[i]]] <- list(col = "red", lty = "dashed")
  }
  edge_style <- utils::modifyList(list(by_edge = by_edge), edge_style)
  cg <- .kn_edges_graph(x, c("required", "forbidden"), "UNKNOWN")
  if (anyNA(nodes(x)$tier)) {
    plot(cg, edge_style = edge_style, ...)
  } else {
    plot(cg, layout = "tiered", tiers = tiers(x), edge_style = edge_style, ...)
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Internal helpers ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

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

# Which of `calls` are calls to `f`.
.kn_is <- function(calls, f) {
  vapply(
    calls,
    function(ex) is.call(ex) && identical(ex[[1L]], as.name(f)),
    logical(1)
  )
}

# Statements from Rust as caugi's edge table, plus `status` (and `holds`).
.kn_table <- function(x) {
  out <- data.table::data.table(
    from = x$from,
    edge = rep("-->", length(x$from)),
    to = x$to,
    status = x$status,
    holds = x$holds
  )
  data.table::setorderv(out, c("from", "to", "status"))
}

# `kind`, not `status`: data.table would read `status` as the column.
.kn_edges_graph <- function(bk, kind, class) {
  is_knowledge(bk, throw_error = TRUE)
  e <- edges(bk)
  e <- e[e$status %in% kind]
  caugi(
    from = e$from,
    edge = e$edge,
    to = e$to,
    nodes = nodes(bk)$name,
    class = class
  )
}

# `A %-->% B` is required and `!(A %-->% B)` forbidden, each parsed by caugi's
# DSL parser. Bare nodes come back as `declared`.
.kn_parse <- function(calls) {
  negated <- .kn_is(calls, "!")
  inner <- lapply(calls[negated], `[[`, 2L)
  bare <- !.kn_is(inner, "(")
  if (any(bare)) {
    ex <- deparse1(inner[[which(bare)[1L]]])
    stop("Negate a whole statement in parentheses: !(", ex, ")", call. = FALSE)
  }
  pos <- .collect_edges_nodes(calls[!negated])
  neg <- .collect_edges_nodes(inner)
  if (length(neg$declared)) {
    stop("Negate statements, not nodes.", call. = FALSE)
  }
  e <- rbind(pos$edges, neg$edges)
  bad <- setdiff(e$edge, "-->")
  if (length(bad)) {
    stop(
      "Knowledge statements are written with `%-->%`, not `%",
      bad[1L],
      "%`.",
      call. = FALSE
    )
  }
  list(
    from = e$from,
    to = e$to,
    status = rep(
      c("required", "forbidden"),
      c(nrow(pos$edges), nrow(neg$edges))
    ),
    declared = pos$declared
  )
}

# The edge verbs on knowledge. Rust reads `status`.
.kn_edit_edges <- function(bk, action, calls, from, edge, to, status) {
  is_knowledge(bk, throw_error = TRUE)
  if (length(calls)) {
    if (!is.null(status)) {
      stop(
        "`status` goes with `from` and `to`. In expressions, write a ",
        "forbidden edge as !(A %-->% B).",
        call. = FALSE
      )
    }
    s <- .kn_parse(calls)
    if (length(s$declared)) {
      stop(
        "Expected statements, not node(s): ",
        toString(s$declared),
        call. = FALSE
      )
    }
    from <- s$from
    to <- s$to
    status <- s$status
  } else if (!all(edge %in% "-->")) {
    stop("Knowledge statements are written with `-->`.", call. = FALSE)
  }
  .kn_new(rs_kn_edit(
    bk@ptr,
    action,
    as.character(from),
    as.character(to),
    as.character(status)
  ))
}

# Tiers named by position where they have no name.
.kn_tier_names <- function(tiers) {
  if (length(tiers)) {
    nm <- if (is.null(names(tiers))) character(length(tiers)) else names(tiers)
    names(tiers) <- ifelse(nm == "", seq_along(tiers), nm)
  }
  tiers
}

.kn_tiers <- function(args, env) {
  max_lag <- args[["max_lag"]]
  args[["max_lag"]] <- NULL
  list(
    tiers = .kn_tier_names(lapply(args, .expand_nodes)),
    max_lag = if (!is.null(max_lag)) eval(max_lag, env)
  )
}
