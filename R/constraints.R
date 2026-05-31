# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────── caugi constraints (skeleton) ──────────────────────
# ──────────────────────────────────────────────────────────────────────────────
#
# Experimental, unexported skeleton for the constraint system described in
# `extras/design/constraints-plan.md`. The constructor uses NSE: it captures
# every supplied expression verbatim and walks it to produce a tagged AST.
# Operator surface, evaluator, and solver integration land in subsequent
# commits on `feat/constraints`.
#
# Atom surface:
#   - edge atoms via `%-->%`, `%---%`, `%<->%`, `%o->%`, `%--o%`, `%o-o%`
#     (each pinned to a specific edge type)
#   - set-membership atoms via R's `%in%` and caugi's existing query
#     functions: `A %in% parents(Y)`, `A %in% ancestors(Y)`, `B %in% mb(A)`
#   - topological precedence via `L %<<% R` — sugar that desugars to a
#     conjunction of `!(r %in% ancestors(l))` over `(l ∈ L, r ∈ R)`
#   - standalone predicates `acyclic()`, `collider(A, B, C)`,
#     `v_structure(A, B, C)`, `dsep(...)`
#   - quantifiers `forall(X, body)`, `exists(Z, body)` with bare symbol or
#     `c(...)` bound-variable specs
#   - boolean structure via `!`, `&` / `&&`, `|` / `||`, `xor()` and
#     `implies()`
#   - cardinality via `at_most(k, set)`, `at_least(k, set)`, `exactly(k,
#     set)` where `set` is either `c(formula, ...)` or a whitelisted
#     query call
#
# Atom tier policy (locked in for the AST):
#   - tier A : boolean combinations of edge atoms (edge operators,
#              `collider`, `v_structure`, and membership atoms whose
#              query is tier-A: `parents`, `children`, `neighbors`,
#              `spouses`, `markov_blanket`, `districts`)
#   - tier B : global structural atoms requiring transitive-closure aux
#              variables (`acyclic()`, and membership atoms whose query
#              is tier-B: `ancestors`, `descendants`, `anteriors`,
#              `posteriors`)
#   - tier C : path-enumeration atoms that don't decompose into a finite
#              boolean combination of edge atoms (`dsep()`)
#
# AST node shape (R side):
#   list(kind = "atom",     atom = <atom node>)
#   list(kind = "not",      body = <node>)
#   list(kind = "and"|"or", args = list(<node>, <node>, ...))
#
# Atom node shape:
#   list(kind = "edge", from = <chr>, to = <chr>, etype = <chr>)
#
# This commit covers tier-A edge atoms plus `!`, `&` / `&&`, `|` / `||`.
# Further atoms (adjacency, ancestrality, quantifiers, cardinality,
# user-defined predicates) follow in later commits.

#' Build a constraint set.
#'
#' @description
#' Experimental constructor for the `caugi_constraints` system. Captures
#' the supplied expressions via non-standard evaluation, classifies each
#' into a tagged AST node, and wraps both in a `caugi_constraints` S7
#' object.
#'
#' See `extras/design/constraints-plan.md` for the full design and the
#' currently recognised surface vocabulary.
#'
#' @param ... Unevaluated constraint expressions. Recognised:
#'   edge atoms (e.g. `A %-->% B`), set-membership atoms
#'   (`A %in% ancestors(Y)`), topological precedence (`L %<<% R`),
#'   standalone predicates (`acyclic()`, `collider()`, …), quantifiers
#'   (`forall(X, …)`, `exists(Z, …)`), cardinality (`at_most(k, set)` …),
#'   and boolean combinators (`!`, `&` / `&&`, `|` / `||`, `xor(…)`,
#'   `implies(…)`).
#'
#' @returns A `caugi_constraints` S7 object with three properties:
#'   `expressions` (the captured `language` objects), `formulas` (the
#'   classified AST nodes, parallel to `expressions`), and
#'   `schema_version` (currently `1L`).
#'
#' @examples
#' ctr <- caugi_constraints(
#'   A %-->% B,
#'   !(D %in% ancestors(A)),
#'   c("A") %<<% c("B", "C") %<<% c("D")
#' )
#'
#' @family constraints
#' @concept constraints
#' @export
caugi_constraints <- function(...) {
  exprs <- as.list(substitute(list(...)))[-1L]
  caller_env <- parent.frame()
  formulas <- lapply(
    exprs,
    function(e) .classify_constraint_expr(e, caller_env)
  )
  caugi_constraints_class(
    expressions = exprs,
    formulas = formulas,
    schema_version = 1L
  )
}

# ── AST classifier ───────────────────────────────────────────────────────────

#' Classify a single unevaluated constraint expression into an AST node.
#'
#' Walks `expr` and dispatches on its shape. Currently recognises:
#'   * parenthesised forms — transparently unwrapped
#'   * edge-operator calls — `%...%` infix names of length ≥ 3
#'   * unary `!` — negation
#'   * binary `&` / `&&` — conjunction
#'   * binary `|` / `||` — disjunction
#'   * `<elem> %in% <query>(<args>)` — set-membership atoms over the
#'     whitelisted query functions (see `.constraint_query_whitelist`)
#'   * `<L> %<<% <R>` — topological-precedence sugar; desugars to a
#'     conjunction of `!(r %in% ancestors(l))` over the cartesian product
#'     of `(l ∈ L, r ∈ R)`. Chained `A %<<% B %<<% C` produces the union
#'     of adjacent-pair desugarings.
#'
#' Anything else triggers an error pointing at the design doc. The error
#' is intentionally strict: we'd rather fail loudly while the surface is
#' incomplete than silently accept partial classification.
#'
#' @param expr An unevaluated expression (language object).
#' @returns A tagged list — the AST node — see the file header for shape.
#'
#' @keywords internal
#' @noRd
.classify_constraint_expr <- function(expr, env = NULL) {
  if (is.call(expr)) {
    op <- expr[[1L]]
    if (is.name(op)) {
      nm <- as.character(op)
      if (nm == "(") {
        return(.classify_constraint_expr(expr[[2L]], env))
      }
      if (nm == "{") {
        if (length(expr) != 2L) {
          stop(
            "Constraint blocks `{ ... }` must contain exactly one ",
            "expression; got ",
            length(expr) - 1L,
            ".",
            call. = FALSE
          )
        }
        return(.classify_constraint_expr(expr[[2L]], env))
      }
      if (nm == "!") {
        return(list(
          kind = "not",
          body = .classify_constraint_expr(expr[[2L]], env)
        ))
      }
      if (nm == "&" || nm == "&&") {
        return(list(
          kind = "and",
          args = list(
            .classify_constraint_expr(expr[[2L]], env),
            .classify_constraint_expr(expr[[3L]], env)
          )
        ))
      }
      if (nm == "|" || nm == "||") {
        return(list(
          kind = "or",
          args = list(
            .classify_constraint_expr(expr[[2L]], env),
            .classify_constraint_expr(expr[[3L]], env)
          )
        ))
      }
      if (nm == "%in%") {
        return(.classify_membership(expr))
      }
      if (nm == "%<<%") {
        return(.classify_precedence(expr))
      }
      if (nm == "forall" || nm == "exists") {
        return(.classify_quantifier(nm, expr, env))
      }
      if (nm == "xor") {
        return(.classify_binary_combinator("xor", expr, env))
      }
      if (nm == "implies") {
        return(.classify_implies(expr, env))
      }
      if (nm == "at_most" || nm == "at_least" || nm == "exactly") {
        return(.classify_cardinality(nm, expr, env))
      }
      if (.is_edge_glyph_op(nm)) {
        return(list(
          kind = "atom",
          atom = list(
            kind = "edge",
            from = .constraint_node_name(expr[[2L]]),
            to = .constraint_node_name(expr[[3L]]),
            etype = .edge_glyph_from_op(nm)
          )
        ))
      }
      predicate <- .classify_predicate_call(nm, expr)
      if (!is.null(predicate)) {
        return(predicate)
      }
      user_predicate <- .classify_user_predicate_invocation(nm, expr, env)
      if (!is.null(user_predicate)) {
        return(user_predicate)
      }
    }
  }
  stop(
    "Unrecognized constraint expression: ",
    deparse1(expr),
    ".\nThis surface is still being built; see ",
    "`extras/design/constraints-plan.md` for the planned vocabulary.",
    call. = FALSE
  )
}

# ── set-membership and topological-precedence ────────────────────────────────

#' Whitelist of caugi query functions recognised inside `%in%` constraints.
#'
#' Mapped to their atom tier so the classifier records tier on each
#' produced membership AST node. Tier A queries decompose into a finite
#' boolean combination of edge atoms; tier B queries require
#' transitive-closure aux variables in the encoder.
#'
#' Kept as a function (not a literal constant) so the table can be
#' extended without touching `.classify_membership`.
#'
#' @keywords internal
#' @noRd
.constraint_query_whitelist <- function() {
  list(
    parents = "A",
    children = "A",
    neighbors = "A",
    spouses = "A",
    markov_blanket = "A",
    districts = "A",
    ancestors = "B",
    descendants = "B",
    anteriors = "B",
    posteriors = "B"
  )
}

#' Classify `<elem> %in% <query>(<args>)` into a `membership` atom.
#'
#' @keywords internal
#' @noRd
.classify_membership <- function(expr) {
  lhs <- expr[[2L]]
  rhs <- expr[[3L]]
  elem <- .constraint_node_name(lhs)

  if (!is.call(rhs) || !is.name(rhs[[1L]])) {
    stop(
      "Right-hand side of `%in%` in a constraint must be a query call ",
      "(e.g. `ancestors(Y)`), got: ",
      deparse1(rhs),
      call. = FALSE
    )
  }
  query <- as.character(rhs[[1L]])
  whitelist <- .constraint_query_whitelist()
  tier <- whitelist[[query]]
  if (is.null(tier)) {
    stop(
      "Unrecognized query function `",
      query,
      "()` on right-hand side of `%in%`. ",
      "Allowed: ",
      paste(names(whitelist), collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  args <- as.list(rhs)[-1L]
  if (length(args) == 0L) {
    stop(
      "Query `",
      query,
      "()` in a constraint requires at least one node argument.",
      call. = FALSE
    )
  }
  list(
    kind = "atom",
    atom = list(
      kind = "membership",
      elem = elem,
      query = query,
      args = lapply(args, .constraint_node_set),
      tier = tier
    )
  )
}

#' Classify `<L> %<<% <R>` (optionally chained) into a conjunction of
#' negated ancestral-membership atoms.
#'
#' For a single pair `L %<<% R` with `L = (l1, ..., lm)` and
#' `R = (r1, ..., rn)`, every cartesian pair `(li, rj)` produces an atom
#' `!(rj %in% ancestors(li))`. Chained applications `A %<<% B %<<% C`
#' parse left-associatively, so we recursively collect the chain into a
#' list of segments and emit adjacent-pair desugarings.
#'
#' @keywords internal
#' @noRd
.classify_precedence <- function(expr) {
  segments <- .collect_precedence_chain(expr)
  pair_constraints <- list()
  for (i in seq_len(length(segments) - 1L)) {
    left <- segments[[i]]
    right <- segments[[i + 1L]]
    for (l in left) {
      for (r in right) {
        pair_constraints[[length(pair_constraints) + 1L]] <- list(
          kind = "not",
          body = list(
            kind = "atom",
            atom = list(
              kind = "membership",
              elem = r,
              query = "ancestors",
              args = list(l),
              tier = "B"
            )
          )
        )
      }
    }
  }
  if (length(pair_constraints) == 1L) {
    return(pair_constraints[[1L]])
  }
  list(kind = "and", args = pair_constraints)
}

#' Walk a chain of `%<<%` calls and return its segments in order.
#'
#' `A %<<% B %<<% C` parses as `(A %<<% B) %<<% C`, so the leftmost
#' segment lives at the innermost depth.
#'
#' @keywords internal
#' @noRd
.collect_precedence_chain <- function(expr) {
  segs <- list()
  while (is.call(expr) &&
    is.name(expr[[1L]]) &&
    as.character(expr[[1L]]) == "%<<%") {
    segs <- c(list(.constraint_node_set(expr[[3L]])), segs)
    expr <- expr[[2L]]
  }
  segs <- c(list(.constraint_node_set(expr)), segs)
  segs
}

# ── xor / implies / cardinality ──────────────────────────────────────────────
#
# `xor(p, q)`, `implies(p, q)`, and the cardinality forms
# `at_most(k, set)`, `at_least(k, set)`, `exactly(k, set)` round out the
# boolean and counting surface. As with `exists`, we deliberately do not
# stub `xor` — it would mask `base::xor`. The classifier matches by name
# alone.
#
# Cardinality `set` can be either:
#   * a `c(...)` of constraint expressions — classic propositional
#     cardinality over a list of formulas, or
#   * a recognised query call (e.g. `parents(Y)`) — parametric cardinality
#     counting the size of a query result.
#
# Both shapes produce a `cardinality` AST node whose `set` slot carries a
# `kind` of `"formulas"` or `"query"`.

#' Classify a two-argument boolean combinator (currently only `xor`).
#'
#' @keywords internal
#' @noRd
.classify_binary_combinator <- function(kind, expr, env = NULL) {
  args <- as.list(expr)[-1L]
  if (length(args) != 2L) {
    stop(
      "`",
      kind,
      "()` expects exactly 2 arguments, got ",
      length(args),
      ".",
      call. = FALSE
    )
  }
  list(
    kind = kind,
    args = list(
      .classify_constraint_expr(args[[1L]], env),
      .classify_constraint_expr(args[[2L]], env)
    )
  )
}

#' Classify `implies(antecedent, consequent)`.
#'
#' @keywords internal
#' @noRd
.classify_implies <- function(expr, env = NULL) {
  args <- as.list(expr)[-1L]
  if (length(args) != 2L) {
    stop(
      "`implies()` expects exactly 2 arguments (antecedent, consequent), got ",
      length(args),
      ".",
      call. = FALSE
    )
  }
  list(
    kind = "implies",
    antecedent = .classify_constraint_expr(args[[1L]], env),
    consequent = .classify_constraint_expr(args[[2L]], env)
  )
}

#' Classify `at_most(k, set)` / `at_least(k, set)` / `exactly(k, set)`.
#'
#' `k` must be a non-negative integer literal. `set` is either a `c(...)`
#' of constraint expressions or a recognised query call.
#'
#' @keywords internal
#' @noRd
.classify_cardinality <- function(card_kind, expr, env = NULL) {
  args <- as.list(expr)[-1L]
  if (length(args) != 2L) {
    stop(
      "`",
      card_kind,
      "()` expects exactly 2 arguments (k, set), got ",
      length(args),
      ".",
      call. = FALSE
    )
  }
  k <- .cardinality_k(args[[1L]], card_kind)
  set <- .cardinality_set(args[[2L]], env)
  list(
    kind = "cardinality",
    card_kind = card_kind,
    k = k,
    set = set
  )
}

#' Parse and validate a cardinality `k` from a leaf expression.
#'
#' @keywords internal
#' @noRd
.cardinality_k <- function(expr, card_kind) {
  k <- tryCatch(eval(expr, envir = baseenv()), error = function(e) NULL)
  if (
    is.null(k) ||
      length(k) != 1L ||
      !is.numeric(k) ||
      !is.finite(k) ||
      k != as.integer(k) ||
      k < 0L
  ) {
    stop(
      "`",
      card_kind,
      "()` first argument must be a non-negative integer literal, got: ",
      deparse1(expr),
      ".",
      call. = FALSE
    )
  }
  as.integer(k)
}

#' Parse a cardinality `set` from an expression. Returns a tagged list.
#'
#' Two shapes:
#'   * `c(f1, f2, ...)` — classified as `kind = "formulas"`.
#'   * `query(args)` for any whitelisted query — classified as
#'     `kind = "query"`.
#'
#' @keywords internal
#' @noRd
.cardinality_set <- function(expr, env = NULL) {
  if (is.call(expr) && is.name(expr[[1L]])) {
    head <- as.character(expr[[1L]])
    if (head == "(") {
      return(.cardinality_set(expr[[2L]], env))
    }
    if (head == "c") {
      members <- as.list(expr)[-1L]
      if (length(members) == 0L) {
        stop(
          "Cardinality set `c(...)` must contain at least one expression.",
          call. = FALSE
        )
      }
      return(list(
        kind = "formulas",
        formulas = lapply(members, function(m) .classify_constraint_expr(m, env))
      ))
    }
    whitelist <- .constraint_query_whitelist()
    tier <- whitelist[[head]]
    if (!is.null(tier)) {
      query_args <- as.list(expr)[-1L]
      if (length(query_args) == 0L) {
        stop(
          "Query `",
          head,
          "()` in a cardinality set requires at least one node argument.",
          call. = FALSE
        )
      }
      return(list(
        kind = "query",
        query = head,
        args = lapply(query_args, .constraint_node_set),
        tier = tier
      ))
    }
  }
  stop(
    "Cardinality set must be `c(...)` of constraint expressions or a ",
    "recognised query call, got: ",
    deparse1(expr),
    ".",
    call. = FALSE
  )
}

# ── quantifiers ──────────────────────────────────────────────────────────────
#
# `forall(X, body)`, `forall(c(X, Y), body)`, and `exists(...)` follow the
# same shape: a leading bound-variable spec (a bare symbol or `c(...)`),
# then a body expression that may reference the bound names. The R-side
# classifier records the variable names verbatim and recursively
# classifies the body. Resolving leaf names that match a bound variable
# into Var refs (rather than Named refs) is the translator's job in the
# Rust pipeline — keeping the R AST purely syntactic.
#
# Stub functions: `forall` is stubbed so calling it outside a
# `caugi_constraints()` errors cleanly. `exists` is intentionally NOT
# stubbed because doing so would mask `base::exists`. The classifier
# matches it by name only — no binding lookup happens during NSE capture.

#' Classify a `forall(VARS, body)` or `exists(VARS, body)` call.
#'
#' @keywords internal
#' @noRd
.classify_quantifier <- function(kind, expr, env = NULL) {
  args <- as.list(expr)[-1L]
  if (length(args) != 2L) {
    stop(
      "`",
      kind,
      "()` expects exactly 2 arguments: bound variable(s) and body.",
      call. = FALSE
    )
  }
  vars <- .quantifier_var_names(args[[1L]])
  if (length(vars) == 0L) {
    stop("`", kind, "()` requires at least one bound variable.", call. = FALSE)
  }
  if (anyDuplicated(vars) > 0L) {
    stop(
      "`",
      kind,
      "()` bound variables must be unique, got: ",
      paste(vars, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  list(
    kind = kind,
    vars = vars,
    scope = list(kind = "all_nodes"),
    body = .classify_constraint_expr(args[[2L]], env)
  )
}

#' Parse the bound-variable position of a quantifier.
#'
#' Accepts a bare symbol (`X`) or a `c(...)` of bare symbols. Refuses
#' strings — bound variables should look syntactically like variables.
#'
#' @keywords internal
#' @noRd
.quantifier_var_names <- function(expr) {
  if (is.symbol(expr)) {
    return(as.character(expr))
  }
  if (
    is.call(expr) &&
      is.name(expr[[1L]]) &&
      as.character(expr[[1L]]) == "c"
  ) {
    args <- as.list(expr)[-1L]
    return(vapply(
      args,
      function(a) {
        if (!is.symbol(a)) {
          stop(
            "Bound variables in a quantifier must be bare symbols, got: ",
            deparse1(a),
            ".",
            call. = FALSE
          )
        }
        as.character(a)
      },
      character(1L)
    ))
  }
  stop(
    "Bound variables must be a bare symbol or `c(...)` of symbols, got: ",
    deparse1(expr),
    ".",
    call. = FALSE
  )
}

# ── standalone predicates ────────────────────────────────────────────────────

#' Whitelist of standalone predicate atoms recognised inside
#' `caugi_constraints()`. Each entry maps a predicate name to its
#' accepted arities and tier.
#'
#' @keywords internal
#' @noRd
.constraint_predicate_whitelist <- function() {
  list(
    acyclic = list(arity = 0L, tier = "B"),
    collider = list(arity = 3L, tier = "A"),
    v_structure = list(arity = 3L, tier = "A"),
    dsep = list(arity = c(2L, 3L), tier = "C")
  )
}

#' Dispatch a call expression onto a predicate atom if its head matches
#' the whitelist. Returns `NULL` for non-predicate calls so the caller can
#' fall through to its own error handling.
#'
#' Argument grammar:
#'   * `collider(A, B, C)` — three node names; `B` is the middle.
#'   * `v_structure(A, B, C)` — three node names; same convention.
#'   * `dsep(X, Y)` or `dsep(X, Y, Z)` — each slot may be a single name or
#'     a `c(...)` set. Named third argument (`given = Z`) is accepted by
#'     positional index — see the `dsep` branch below.
#'
#' @keywords internal
#' @noRd
.classify_predicate_call <- function(name, expr) {
  spec <- .constraint_predicate_whitelist()[[name]]
  if (is.null(spec)) {
    return(NULL)
  }
  args <- as.list(expr)[-1L]
  if (!(length(args) %in% spec$arity)) {
    stop(
      "`",
      name,
      "()` expects ",
      paste(spec$arity, collapse = " or "),
      " argument(s), got ",
      length(args),
      ".",
      call. = FALSE
    )
  }
  switch(
    name,
    acyclic = list(
      kind = "atom",
      atom = list(kind = "acyclic", tier = "B")
    ),
    collider = list(
      kind = "atom",
      atom = list(
        kind = "collider",
        a = .constraint_node_name(args[[1L]]),
        mid = .constraint_node_name(args[[2L]]),
        c = .constraint_node_name(args[[3L]]),
        tier = "A"
      )
    ),
    v_structure = list(
      kind = "atom",
      atom = list(
        kind = "v_structure",
        a = .constraint_node_name(args[[1L]]),
        mid = .constraint_node_name(args[[2L]]),
        c = .constraint_node_name(args[[3L]]),
        tier = "A"
      )
    ),
    dsep = {
      x <- .constraint_node_set(args[[1L]])
      y <- .constraint_node_set(args[[2L]])
      given <- if (length(args) >= 3L) {
        .constraint_node_set(args[[3L]])
      } else {
        character(0L)
      }
      list(
        kind = "atom",
        atom = list(
          kind = "dsep",
          x = x,
          y = y,
          given = given,
          tier = "C"
        )
      )
    }
  )
}

# ── user-defined predicates ──────────────────────────────────────────────────
#
# `caugi_predicate(fn)` wraps a function `fn(X, Y, …)` that defines a
# reusable constraint pattern. Inside `caugi_constraints(...)`, a call
# `my_pred("A", "B")` is detected by name lookup in the caller env,
# substituted with the arg expressions, and re-classified.
#
# This means predicate bodies are pure constraint expressions — they
# can use everything the surface offers: atoms, quantifiers,
# cardinality, other predicates, …

#' Define a reusable constraint predicate.
#'
#' @description
#' Wraps a function whose body is a constraint expression. The function
#' is recognised inside `caugi_constraints()` calls: a call to it is
#' inlined by substituting the parameter symbols with the supplied
#' argument expressions, then re-classified through the normal pipeline.
#'
#' Predicate bodies can use any form the constraint surface accepts.
#' Predicates can call other predicates (the substitution + re-classify
#' pass is recursive). Recursive predicates (a predicate that calls
#' itself, directly or transitively) are not supported and will produce
#' a stack-overflow-like error.
#'
#' @param fn A function. Its formal parameters are the predicate
#'   parameters; its body is the constraint expression. The function is
#'   never actually evaluated — the body is captured via
#'   `body(fn)` and substituted at classify time.
#'
#' @returns A function with class `"caugi_predicate"` that errors when
#'   called directly; useful only inside `caugi_constraints(...)`.
#'
#' @examples
#' has_path <- caugi_predicate(function(X, Y) X %in% ancestors(Y))
#' ctr <- caugi_constraints(has_path("A", "Y"))
#'
#' @family constraints
#' @concept constraints
#' @export
caugi_predicate <- function(fn) {
  if (!is.function(fn)) {
    stop("`caugi_predicate()` expects a function.", call. = FALSE)
  }
  params <- names(formals(fn))
  if (length(params) == 0L) {
    stop(
      "`caugi_predicate()` expects a function with at least one parameter.",
      call. = FALSE
    )
  }
  predicate_fn <- function(...) {
    stop(
      "`caugi_predicate` invocations are only meaningful inside ",
      "`caugi_constraints()`. See `extras/design/constraints-plan.md`.",
      call. = FALSE
    )
  }
  attr(predicate_fn, "caugi_predicate_params") <- params
  attr(predicate_fn, "caugi_predicate_body") <- body(fn)
  class(predicate_fn) <- c("caugi_predicate", "function")
  predicate_fn
}

#' Classify a user-defined predicate invocation.
#'
#' Looks up `name` in `env` (the caller of `caugi_constraints`). If it
#' resolves to a `caugi_predicate`, substitute its body and re-classify.
#'
#' @keywords internal
#' @noRd
.classify_user_predicate_invocation <- function(name, expr, env) {
  if (is.null(env)) {
    return(NULL)
  }
  if (!exists(name, envir = env, inherits = TRUE)) {
    return(NULL)
  }
  obj <- get(name, envir = env, inherits = TRUE)
  if (!inherits(obj, "caugi_predicate")) {
    return(NULL)
  }
  params <- attr(obj, "caugi_predicate_params", exact = TRUE)
  body_expr <- attr(obj, "caugi_predicate_body", exact = TRUE)
  call_args <- as.list(expr)[-1L]
  if (length(call_args) != length(params)) {
    stop(
      "Predicate `",
      name,
      "()` expects ",
      length(params),
      " argument(s), got ",
      length(call_args),
      ".",
      call. = FALSE
    )
  }
  bindings <- stats::setNames(call_args, params)
  substituted <- .substitute_expr(body_expr, bindings)
  .classify_constraint_expr(substituted, env)
}

#' Walk an expression tree, replacing every bare symbol whose name
#' appears in `bindings` with the corresponding argument expression.
#'
#' @keywords internal
#' @noRd
.substitute_expr <- function(expr, bindings) {
  if (is.symbol(expr)) {
    nm <- as.character(expr)
    if (nm %in% names(bindings)) {
      return(bindings[[nm]])
    }
    return(expr)
  }
  if (is.call(expr)) {
    head <- expr[[1L]]
    rest <- lapply(as.list(expr)[-1L], .substitute_expr, bindings = bindings)
    return(as.call(c(list(head), rest)))
  }
  expr
}

# ── operator stubs (outside-constraint UX) ───────────────────────────────────
#
# These functions exist solely to produce a clear error if a user calls
# them at top level instead of inside `caugi_constraints(...)`. Inside the
# constructor the expressions are captured unevaluated, so the stubs are
# never actually invoked.

#' Topological-precedence operator (constraint-only).
#'
#' Use only inside `caugi_constraints()`. Outside a constraint context,
#' calling this errors with a pointer to the design doc.
#'
#' @param lhs,rhs Sets of node names.
#' @keywords internal
`%<<%` <- function(lhs, rhs) {
  .constraint_only_stub("`%<<%`")
}

#' @keywords internal
#' @noRd
acyclic <- function() {
  .constraint_only_stub("`acyclic()`")
}

#' @keywords internal
#' @noRd
collider <- function(a, b, c) {
  .constraint_only_stub("`collider()`")
}

#' @keywords internal
#' @noRd
v_structure <- function(a, b, c) {
  .constraint_only_stub("`v_structure()`")
}

#' @keywords internal
#' @noRd
dsep <- function(x, y, given = character(0L)) {
  .constraint_only_stub("`dsep()`")
}

#' @keywords internal
#' @noRd
forall <- function(vars, body) {
  .constraint_only_stub("`forall()`")
}

#' @keywords internal
#' @noRd
implies <- function(antecedent, consequent) {
  .constraint_only_stub("`implies()`")
}

#' @keywords internal
#' @noRd
at_most <- function(k, set) {
  .constraint_only_stub("`at_most()`")
}

#' @keywords internal
#' @noRd
at_least <- function(k, set) {
  .constraint_only_stub("`at_least()`")
}

#' @keywords internal
#' @noRd
exactly <- function(k, set) {
  .constraint_only_stub("`exactly()`")
}

#' Shared error for constraint-only forms invoked at top level.
#' @keywords internal
#' @noRd
.constraint_only_stub <- function(label) {
  stop(
    label,
    " is only meaningful inside `caugi_constraints()`. ",
    "See `extras/design/constraints-plan.md`.",
    call. = FALSE
  )
}

# ── boolean algebra on caugi_constraints objects ─────────────────────────────
#
# A `caugi_constraints` value is interpreted as the conjunction of its
# `formulas` list. The boolean operators between two such values produce
# a new `caugi_constraints` whose interpretation matches the obvious
# semantics:
#
#   ctr1 & ctr2  →  conjunction-list concatenation
#   ctr1 | ctr2  →  one new formula: Or(And(ctr1), And(ctr2))
#   !ctr1        →  one new formula: Not(And(ctr1))
#
# Empty constraint sets are vacuously true; `And([])` is interpreted as
# True by the evaluator, `Or([])` as False. The wrappers carry that
# through transparently.

#' Wrap a list of formulas as a single AST node — a conjunction, or the
#' lone formula if the list has exactly one element, or `And([])` for an
#' empty list (vacuously true).
#'
#' @keywords internal
#' @noRd
.conjunction_of_formulas <- function(formulas) {
  if (length(formulas) == 0L) {
    return(list(kind = "and", args = list()))
  }
  if (length(formulas) == 1L) {
    return(formulas[[1L]])
  }
  list(kind = "and", args = formulas)
}

# ── pretty printing ──────────────────────────────────────────────────────────
#
# Constraint objects print as a numbered list of formulas, with each
# formula rendered back into the user-facing surface syntax via
# `.format_formula()`. Rendering walks the AST rather than reusing the
# stored `expressions` so synthesised constraints (boolean-algebra
# results, `negate()` outputs, future Rust-generated forms) print
# consistently with hand-written ones.

#' Render a single AST node back into surface syntax.
#'
#' Returns a character scalar. The rendering is structural and does not
#' attempt to round-trip every cosmetic choice — `&&` becomes `&`, `||`
#' becomes `|`, parentheses are inserted around any compound subterm
#' under `!` / `&` / `|` to keep precedence unambiguous.
#'
#' @keywords internal
#' @noRd
.format_formula <- function(node) {
  if (is.null(node)) {
    return("<null>")
  }
  kind <- node$kind
  switch(
    kind,
    atom = .format_atom(node$atom),
    not = paste0("!", .parens(.format_formula(node$body))),
    and = .format_join(node$args, " & "),
    or = .format_join(node$args, " | "),
    xor = paste0(
      "xor(",
      .format_formula(node$args[[1L]]),
      ", ",
      .format_formula(node$args[[2L]]),
      ")"
    ),
    implies = paste0(
      "implies(",
      .format_formula(node$antecedent),
      ", ",
      .format_formula(node$consequent),
      ")"
    ),
    forall = paste0(
      "forall(",
      .format_var_spec(node$vars),
      ", ",
      .format_formula(node$body),
      ")"
    ),
    exists = paste0(
      "exists(",
      .format_var_spec(node$vars),
      ", ",
      .format_formula(node$body),
      ")"
    ),
    cardinality = .format_cardinality(node),
    paste0("<", kind, ">")
  )
}

#' Render an atom node.
#' @keywords internal
#' @noRd
.format_atom <- function(atom) {
  kind <- atom$kind
  switch(
    kind,
    edge = paste0(atom$from, " %", atom$etype, "% ", atom$to),
    membership = paste0(
      atom$elem,
      " %in% ",
      atom$query,
      "(",
      paste(vapply(atom$args, .format_node_set, character(1L)), collapse = ", "),
      ")"
    ),
    acyclic = "acyclic()",
    collider = paste0("collider(", atom$a, ", ", atom$mid, ", ", atom$c, ")"),
    v_structure = paste0(
      "v_structure(",
      atom$a,
      ", ",
      atom$mid,
      ", ",
      atom$c,
      ")"
    ),
    dsep = paste0(
      "dsep(",
      .format_node_set(atom$x),
      ", ",
      .format_node_set(atom$y),
      if (length(atom$given) > 0L) paste0(", ", .format_node_set(atom$given)),
      ")"
    ),
    paste0("<atom:", kind, ">")
  )
}

#' Render a cardinality node.
#' @keywords internal
#' @noRd
.format_cardinality <- function(node) {
  set_str <- switch(
    node$set$kind,
    formulas = paste0(
      "c(",
      paste(
        vapply(node$set$formulas, .format_formula, character(1L)),
        collapse = ", "
      ),
      ")"
    ),
    query = paste0(
      node$set$query,
      "(",
      paste(
        vapply(node$set$args, .format_node_set, character(1L)),
        collapse = ", "
      ),
      ")"
    ),
    paste0("<set:", node$set$kind, ">")
  )
  paste0(node$card_kind, "(", node$k, ", ", set_str, ")")
}

#' Render a leaf set (character vector) as a node name or `c(...)`.
#' @keywords internal
#' @noRd
.format_node_set <- function(x) {
  if (length(x) == 1L) {
    return(x)
  }
  paste0("c(", paste(x, collapse = ", "), ")")
}

#' Render a quantifier var spec (character vector) — `X` if length 1,
#' `c(X, Y, ...)` otherwise.
#' @keywords internal
#' @noRd
.format_var_spec <- function(vars) {
  if (length(vars) == 1L) {
    return(vars)
  }
  paste0("c(", paste(vars, collapse = ", "), ")")
}

#' Join compound args with a separator, parenthesising each.
#' @keywords internal
#' @noRd
.format_join <- function(args, sep) {
  if (length(args) == 0L) {
    return(if (sep == " & ") "TRUE" else "FALSE")
  }
  paste(
    vapply(args, function(a) .parens(.format_formula(a)), character(1L)),
    collapse = sep
  )
}

#' Parenthesise a sub-expression unless it's already an atom.
#' @keywords internal
#' @noRd
.parens <- function(s) {
  if (
    nchar(s) <= 1L ||
      grepl("^[A-Za-z0-9_]+$", s) ||
      grepl("^[A-Za-z0-9_]+\\(.*\\)$", s) ||
      grepl("^!", s)
  ) {
    return(s)
  }
  paste0("(", s, ")")
}

# S3-style registration: defining the methods as plain functions and
# wiring them in `.onLoad` keeps `format` dispatch local to caugi and
# avoids the S7 generic wrapper, which would otherwise shadow
# `base::format` in the caugi namespace and break tests that mock it
# (see test-methods.R).

#' @keywords internal
#' @noRd
`format.caugi::caugi_constraints` <- function(x, ...) {
  if (length(x@formulas) == 0L) {
    return("<caugi_constraints: empty>")
  }
  header <- sprintf(
    "<caugi_constraints: %d formula%s>",
    length(x@formulas),
    if (length(x@formulas) == 1L) "" else "s"
  )
  lines <- vapply(
    seq_along(x@formulas),
    function(i) sprintf("  %d. %s", i, .format_formula(x@formulas[[i]])),
    character(1L)
  )
  paste(c(header, lines), collapse = "\n")
}

#' @keywords internal
#' @noRd
`print.caugi::caugi_constraints` <- function(x, ...) {
  cat(`format.caugi::caugi_constraints`(x, ...), "\n", sep = "")
  invisible(x)
}

# ── attaching constraints to a caugi ─────────────────────────────────────────
#
# Constraints are stored as an attribute on the `caugi` S7 object. caugi
# already uses `attr(self, ...)` internally (see the `session` setter),
# so this is consistent with the existing pattern and avoids churn in
# the class definition. Validation is intentionally minimal here —
# matching constraint node names against the graph's node set is
# deferred to evaluation time, matching caugi's lazy-build model.

#' Attach a constraint set to a caugi.
#'
#' @description
#' Returns a copy of `cg` with `ctr` recorded as its constraint set,
#' replacing any previously attached set. The constraints are stored as
#' an attribute on the caugi; soundness checks against the graph's node
#' set happen at evaluation time (`satisfies()` / `violations()`),
#' matching caugi's lazy-build model.
#'
#' @param cg A `caugi` object.
#' @param ctr A `caugi_constraints` object.
#'
#' @returns The input `cg`, with `ctr` attached.
#'
#' @examples
#' cg <- caugi(A %-->% B, class = "DAG")
#' ctr <- caugi_constraints(A %-->% B)
#' cg <- with_constraints(cg, ctr)
#' constraints(cg)
#'
#' @family constraints
#' @concept constraints
#' @export
with_constraints <- function(cg, ctr) {
  is_caugi(cg, throw_error = TRUE)
  if (!S7::S7_inherits(ctr, caugi_constraints_class)) {
    stop(
      "`ctr` must be a `caugi_constraints` object, got: ",
      paste(class(ctr), collapse = "/"),
      ".",
      call. = FALSE
    )
  }
  attr(cg, "caugi_constraints") <- ctr
  cg
}

# ── Rust round-trip (parser smoke test) ─────────────────────────────────────
#
# `parse_formula_in_rust(node)` ships a single R-side AST node across to
# Rust, parses it into the Rust `Formula` type, and returns the Rust
# `Debug` rendering. Pure smoke test for the parser layer — the
# evaluator and solver are not wired up yet.

#' Round-trip a single classified AST node through the Rust parser.
#'
#' @param node A list produced by `.classify_constraint_expr()` (or any
#'   element of a `caugi_constraints` object's `formulas` slot).
#' @returns The Rust `Debug` string of the parsed `Formula`.
#'
#' @keywords internal
#' @noRd
.constraints_parse_formula_rs <- function(node) {
  rs_constraints_parse_formula(node)
}

#' Retrieve the constraint set attached to a caugi, if any.
#'
#' @param cg A `caugi` object.
#' @returns The attached `caugi_constraints`, or `NULL` if none.
#'
#' @family constraints
#' @concept constraints
#' @export
constraints <- function(cg) {
  is_caugi(cg, throw_error = TRUE)
  attr(cg, "caugi_constraints", exact = TRUE)
}

S7::method(
  `&`,
  list(caugi_constraints_class, caugi_constraints_class)
) <- function(e1, e2) {
  caugi_constraints_class(
    expressions = c(e1@expressions, e2@expressions),
    formulas = c(e1@formulas, e2@formulas),
    schema_version = 1L
  )
}

S7::method(
  `|`,
  list(caugi_constraints_class, caugi_constraints_class)
) <- function(e1, e2) {
  caugi_constraints_class(
    expressions = list(),
    formulas = list(list(
      kind = "or",
      args = list(
        .conjunction_of_formulas(e1@formulas),
        .conjunction_of_formulas(e2@formulas)
      )
    )),
    schema_version = 1L
  )
}

#' Negate an entire constraint set.
#'
#' Returns a new `caugi_constraints` containing a single formula
#' `Not(And(<original formulas>))`. Provided as a function rather than as
#' an S7 `!` method because S7 does not currently expose dispatch on the
#' unary `!` primitive.
#'
#' @param ctr A `caugi_constraints` object.
#' @returns A new `caugi_constraints` whose single formula is the
#'   negation of the conjunction of `ctr`'s formulas.
#'
#' @keywords internal
#' @noRd
negate <- function(ctr) {
  if (!S7::S7_inherits(ctr, caugi_constraints_class)) {
    stop("`negate()` expects a `caugi_constraints` object.", call. = FALSE)
  }
  caugi_constraints_class(
    expressions = list(),
    formulas = list(list(
      kind = "not",
      body = .conjunction_of_formulas(ctr@formulas)
    )),
    schema_version = 1L
  )
}

# ── leaf grammar ─────────────────────────────────────────────────────────────

#' Is `nm` of the form `%glyph%` (an infix edge operator name)?
#'
#' @keywords internal
#' @noRd
.is_edge_glyph_op <- function(nm) {
  nchar(nm) > 2L &&
    substr(nm, 1L, 1L) == "%" &&
    substr(nm, nchar(nm), nchar(nm)) == "%"
}

#' Strip the surrounding `%` from an edge operator name.
#'
#' `"%-->%"` -> `"-->"`.
#'
#' @keywords internal
#' @noRd
.edge_glyph_from_op <- function(nm) {
  substr(nm, 2L, nchar(nm) - 1L)
}

#' Extract a node name from a leaf expression.
#'
#' Accepts a bare symbol or a single character literal. Refuses anything
#' else; the rest of the leaf grammar (numeric labels, programmatic
#' splicing) is deferred until the operator surface is fleshed out.
#'
#' @keywords internal
#' @noRd
.constraint_node_name <- function(expr) {
  if (is.symbol(expr)) {
    return(as.character(expr))
  }
  if (is.character(expr) && length(expr) == 1L) {
    return(expr)
  }
  stop(
    "Expected a node name (bare symbol or single string) in constraint atom, ",
    "got: ",
    deparse1(expr),
    call. = FALSE
  )
}

#' Extract a (possibly multi-element) set of node names from a leaf
#' expression.
#'
#' Accepts:
#'   * a bare symbol or single string  → length-1 character vector
#'   * a `c(...)` call of bare symbols / single strings → multi-element
#'     character vector
#'   * a parenthesised form, which is unwrapped transparently.
#'
#' @keywords internal
#' @noRd
.constraint_node_set <- function(expr) {
  if (is.call(expr) && is.name(expr[[1L]])) {
    head <- as.character(expr[[1L]])
    if (head == "(") {
      return(.constraint_node_set(expr[[2L]]))
    }
    if (head == "c") {
      args <- as.list(expr)[-1L]
      return(unlist(
        lapply(args, .constraint_node_name),
        use.names = FALSE
      ))
    }
  }
  .constraint_node_name(expr)
}
