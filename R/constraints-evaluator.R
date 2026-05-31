# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────── caugi_constraints — R-side evaluator ──────────────────
# ──────────────────────────────────────────────────────────────────────────────
#
# Given a `caugi` and a `caugi_constraints`, walk the AST in R and check
# each formula against the graph using the existing caugi query API.
# This is the v1 implementation: it's correct, debuggable, and ships
# fast. Performance-critical evaluation (for the solver) will live on
# the Rust side later.
#
# Coverage:
#   - tier A atoms : edge, membership (parents/children/neighbors/
#                    spouses/mb/districts), collider, v_structure
#   - tier B atoms : acyclic, membership (ancestors/descendants/
#                    anteriors/posteriors)
#   - tier C atoms : dsep (single X, single Y; multi-element X/Y is
#                    deferred)
#   - boolean      : not, and, or, xor, implies
#   - top-level set: the implicit conjunction over `ctr@formulas`
#
# Not yet implemented (will error with a clear message):
#   - quantifiers (forall, exists)
#   - cardinality (at_most, at_least, exactly)
#   (everything else in the constraint surface is supported)

#' Check whether a graph satisfies a constraint set.
#'
#' @description
#' Returns `TRUE` if every formula in `ctr` holds on `cg`, `FALSE`
#' otherwise. An empty constraint set is vacuously satisfied. The walk
#' is short-circuit at the formula list level — once a formula fails the
#' rest are not evaluated.
#'
#' @param cg A `caugi` object.
#' @param ctr A `caugi_constraints` object.
#'
#' @returns `TRUE` or `FALSE`.
#'
#' @family constraints
#' @concept constraints
#' @export
satisfies <- function(cg, ctr) {
  .check_evaluator_inputs(cg, ctr)
  if (length(ctr@formulas) == 0L) {
    return(TRUE)
  }
  for (f in ctr@formulas) {
    if (!.evaluate_formula(cg, f)) {
      return(FALSE)
    }
  }
  TRUE
}

#' Report which constraints fail on a graph.
#'
#' @description
#' Returns a `data.frame` with one row per top-level formula in `ctr`
#' that does NOT hold on `cg`. Columns: `index` (position in the
#' constraint set), `formula` (rendered surface syntax).
#'
#' @param cg A `caugi` object.
#' @param ctr A `caugi_constraints` object.
#'
#' @returns A `data.frame` of failing formulas. Empty when `cg`
#'   satisfies `ctr`.
#'
#' @family constraints
#' @concept constraints
#' @export
violations <- function(cg, ctr) {
  .check_evaluator_inputs(cg, ctr)
  if (length(ctr@formulas) == 0L) {
    return(data.frame(
      index = integer(0L),
      formula = character(0L),
      stringsAsFactors = FALSE
    ))
  }
  ok <- vapply(
    ctr@formulas,
    function(f) .evaluate_formula(cg, f),
    logical(1L)
  )
  failed <- which(!ok)
  data.frame(
    index = failed,
    formula = vapply(
      ctr@formulas[failed],
      .format_formula,
      character(1L)
    ),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
#' @noRd
.check_evaluator_inputs <- function(cg, ctr) {
  is_caugi(cg, throw_error = TRUE)
  if (!S7::S7_inherits(ctr, caugi_constraints_class)) {
    stop(
      "`ctr` must be a `caugi_constraints` object, got: ",
      paste(class(ctr), collapse = "/"),
      ".",
      call. = FALSE
    )
  }
  invisible(NULL)
}

# ── formula dispatch ─────────────────────────────────────────────────────────

#' @keywords internal
#' @noRd
.evaluate_formula <- function(cg, node, env = NULL) {
  switch(
    node$kind,
    atom = .evaluate_atom(cg, .substitute_atom(node$atom, env)),
    not = !.evaluate_formula(cg, node$body, env),
    and = all(vapply(
      node$args,
      function(a) .evaluate_formula(cg, a, env),
      logical(1L)
    )),
    or = any(vapply(
      node$args,
      function(a) .evaluate_formula(cg, a, env),
      logical(1L)
    )),
    xor = xor(
      .evaluate_formula(cg, node$args[[1L]], env),
      .evaluate_formula(cg, node$args[[2L]], env)
    ),
    implies = (!.evaluate_formula(cg, node$antecedent, env)) ||
      .evaluate_formula(cg, node$consequent, env),
    forall = .evaluate_quantifier(cg, node, env, mode = "forall"),
    `exists` = .evaluate_quantifier(cg, node, env, mode = "exists"),
    cardinality = .evaluate_cardinality(cg, node, env),
    stop("Unknown formula kind in evaluator: `", node$kind, "`.", call. = FALSE)
  )
}

# ── cardinality ──────────────────────────────────────────────────────────────

#' Evaluate `at_most(k, set)` / `at_least(k, set)` / `exactly(k, set)`.
#'
#' For the `formulas` set kind: count how many listed formulas hold
#' under the current env. For the `query` set kind: count the size of
#' the query result on the substituted args.
#'
#' @keywords internal
#' @noRd
.evaluate_cardinality <- function(cg, node, env) {
  count <- .cardinality_count(cg, node$set, env)
  k <- node$k
  switch(
    node$card_kind,
    at_most = count <= k,
    at_least = count >= k,
    exactly = count == k,
    stop("Unknown cardinality kind: `", node$card_kind, "`.", call. = FALSE)
  )
}

#' @keywords internal
#' @noRd
.cardinality_count <- function(cg, set, env) {
  switch(
    set$kind,
    formulas = sum(vapply(
      set$formulas,
      function(f) .evaluate_formula(cg, f, env),
      logical(1L)
    )),
    query = .cardinality_query_count(cg, set, env),
    stop("Unknown cardinality set kind: `", set$kind, "`.", call. = FALSE)
  )
}

#' @keywords internal
#' @noRd
.cardinality_query_count <- function(cg, set, env) {
  if (length(set$args) != 1L) {
    stop(
      "Multi-set query arguments are not yet supported in cardinality.",
      call. = FALSE
    )
  }
  arg <- vapply(
    set$args[[1L]],
    function(n) .substitute_name(n, env),
    character(1L)
  )
  result <- .invoke_query(cg, set$query, arg)
  nodes <- if (is.list(result)) {
    unique(unlist(result, use.names = FALSE))
  } else {
    result
  }
  length(nodes)
}

# ── quantifiers ──────────────────────────────────────────────────────────────

#' Evaluate `forall` / `exists` by enumerating ordered tuples of
#' distinct nodes (the AllNodes scope) and short-circuiting on the first
#' decisive result.
#'
#' @keywords internal
#' @noRd
.evaluate_quantifier <- function(cg, node, env, mode) {
  scope_kind <- node$scope$kind
  if (!identical(scope_kind, "all_nodes")) {
    stop(
      "Quantifier scope `",
      scope_kind,
      "` is not yet supported by the evaluator.",
      call. = FALSE
    )
  }
  ns <- nodes(cg)[["name"]]
  if (length(node$vars) > length(ns)) {
    # No tuples of distinct nodes — `forall` is vacuously TRUE,
    # `exists` is FALSE.
    return(mode == "forall")
  }
  for (tup in .ordered_tuples(ns, length(node$vars))) {
    new_env <- env
    for (i in seq_along(node$vars)) {
      new_env[[node$vars[[i]]]] <- tup[[i]]
    }
    ok <- .evaluate_formula(cg, node$body, new_env)
    if (mode == "forall" && !ok) {
      return(FALSE)
    }
    if (mode == "exists" && ok) {
      return(TRUE)
    }
  }
  mode == "forall"
}

#' Enumerate ordered tuples of distinct nodes of arity `k` from `ns`.
#' Returns a list of length-`k` character vectors.
#'
#' @keywords internal
#' @noRd
.ordered_tuples <- function(ns, k) {
  if (k == 0L) {
    return(list(character(0L)))
  }
  if (k == 1L) {
    return(as.list(ns))
  }
  out <- list()
  for (i in seq_along(ns)) {
    sub <- .ordered_tuples(ns[-i], k - 1L)
    for (r in sub) {
      out[[length(out) + 1L]] <- c(ns[[i]], r)
    }
  }
  out
}

# ── leaf substitution ────────────────────────────────────────────────────────
#
# Quantifier-bound variables are recorded in `env` (a named list mapping
# var-names to substituted node names). When walking an atom we replace
# every leaf whose name appears in `env`. If `env` is `NULL` we skip the
# walk entirely — closed atoms pay no overhead.

#' @keywords internal
#' @noRd
.substitute_atom <- function(atom, env) {
  if (is.null(env) || length(env) == 0L) {
    return(atom)
  }
  switch(
    atom$kind,
    edge = {
      atom$from <- .substitute_name(atom$from, env)
      atom$to <- .substitute_name(atom$to, env)
      atom
    },
    membership = {
      atom$elem <- .substitute_name(atom$elem, env)
      atom$args <- lapply(atom$args, function(s) {
        vapply(s, function(n) .substitute_name(n, env), character(1L))
      })
      atom
    },
    acyclic = atom,
    collider = ,
    v_structure = {
      atom$a <- .substitute_name(atom$a, env)
      atom$mid <- .substitute_name(atom$mid, env)
      atom$c <- .substitute_name(atom$c, env)
      atom
    },
    dsep = {
      atom$x <- vapply(atom$x, function(n) .substitute_name(n, env), character(1L))
      atom$y <- vapply(atom$y, function(n) .substitute_name(n, env), character(1L))
      atom$given <- vapply(atom$given, function(n) .substitute_name(n, env), character(1L))
      atom
    },
    atom
  )
}

#' @keywords internal
#' @noRd
.substitute_name <- function(name, env) {
  if (!is.null(env) && !is.null(env[[name]])) {
    return(env[[name]])
  }
  name
}

#' @keywords internal
#' @noRd
.evaluator_unsupported <- function(kind) {
  stop(
    "`",
    kind,
    "` is not yet supported by the R-side evaluator. ",
    "See `extras/design/constraints-plan.md` for the roadmap.",
    call. = FALSE
  )
}

# ── atom dispatch ────────────────────────────────────────────────────────────

#' @keywords internal
#' @noRd
.evaluate_atom <- function(cg, atom) {
  switch(
    atom$kind,
    edge = .evaluate_edge(cg, atom),
    membership = .evaluate_membership(cg, atom),
    acyclic = is_acyclic(cg),
    collider = .evaluate_collider(cg, atom),
    v_structure = .evaluate_v_structure(cg, atom),
    dsep = .evaluate_dsep(cg, atom),
    stop("Unknown atom kind in evaluator: `", atom$kind, "`.", call. = FALSE)
  )
}

#' Edge atom: exact match against the graph's edge table.
#' @keywords internal
#' @noRd
.evaluate_edge <- function(cg, atom) {
  e <- edges(cg)
  any(
    e$from == atom$from &
      e$to == atom$to &
      e$edge == atom$etype
  )
}

#' Membership atom: dispatch on `query`, return whether `elem` is in
#' the resulting set.
#' @keywords internal
#' @noRd
.evaluate_membership <- function(cg, atom) {
  if (length(atom$args) != 1L) {
    stop(
      "Multi-set query arguments are not yet supported in the evaluator.",
      call. = FALSE
    )
  }
  result <- .invoke_query(cg, atom$query, atom$args[[1L]])
  nodes <- if (is.list(result)) {
    unique(unlist(result, use.names = FALSE))
  } else {
    result
  }
  atom$elem %in% nodes
}

#' Call a recognised caugi query function with the caugi and a single
#' node-set argument. The query name has already been whitelisted at
#' classify time, so this can assume the function exists.
#'
#' @keywords internal
#' @noRd
.invoke_query <- function(cg, query, arg) {
  fn <- get(query, envir = asNamespace("caugi"), mode = "function")
  fn(cg, arg)
}

#' Collider atom: arrowheads into `mid` from both `a` and `c`.
#'
#' A directed edge `a --> mid` or a bidirected edge `a <-> mid` both
#' qualify as "into mid"; same for `c`.
#'
#' @keywords internal
#' @noRd
.evaluate_collider <- function(cg, atom) {
  .has_arrowhead_into(cg, atom$a, atom$mid) &&
    .has_arrowhead_into(cg, atom$c, atom$mid)
}

#' V-structure atom: collider plus non-adjacency of the shoulders.
#' @keywords internal
#' @noRd
.evaluate_v_structure <- function(cg, atom) {
  .evaluate_collider(cg, atom) &&
    !.has_any_edge(cg, atom$a, atom$c)
}

#' @keywords internal
#' @noRd
.has_arrowhead_into <- function(cg, from, to) {
  e <- edges(cg)
  any(
    (e$from == from & e$to == to & e$edge %in% c("-->", "<->", "o->")) |
      (e$from == to & e$to == from & e$edge == "<->")
  )
}

#' Any edge of any direction or type between `u` and `v`.
#' @keywords internal
#' @noRd
.has_any_edge <- function(cg, u, v) {
  e <- edges(cg)
  any(
    (e$from == u & e$to == v) |
      (e$from == v & e$to == u)
  )
}

#' d-separation atom. Defers to `d_separated()`. Tier-C; the encoder
#' rejects this, but the R-side evaluator can answer it.
#'
#' @keywords internal
#' @noRd
.evaluate_dsep <- function(cg, atom) {
  if (length(atom$x) != 1L || length(atom$y) != 1L) {
    stop(
      "`dsep()` evaluator currently supports a single node on each side.",
      call. = FALSE
    )
  }
  d_separated(
    cg,
    X = atom$x,
    Y = atom$y,
    Z = if (length(atom$given) == 0L) NULL else atom$given
  )
}
