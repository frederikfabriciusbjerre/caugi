# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── DSL parser tests ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────────── Checks ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that(".is_edge_call identifies edge calls", {
  edge_call <- quote(A %-->% B) # parsing only; no eval
  non_edge <- quote(A + B)

  expect_true(.is_edge_call(edge_call))
  expect_false(.is_edge_call(non_edge))
  expect_false(.is_edge_call(quote(A)))
})

test_that(".is_node_expr validates allowed node expressions", {
  expect_true(.is_node_expr(quote(A)))
  expect_true(.is_node_expr("A"))
  expect_true(.is_node_expr(quote((A))))
  expect_true(.is_node_expr(quote(c(A, "B", (C)))))
  expect_true(.is_node_expr(quote(A + (B + C))))
  # Edge calls are not node expressions
  expect_false(.is_node_expr(quote(A %-->% B)))
})

test_that(".is_node_expr rejects unsupported calls", {
  expect_false(.is_node_expr(quote(A:B)))
  expect_false(.is_node_expr(quote(paste(A, B))))
})

test_that(".contains_edge handles parentheses and returns FALSE otherwise", {
  expect_true(.contains_edge(quote((A %-->% B))))
  expect_false(.contains_edge(quote(A + B)))
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── glyph of ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that(".glyph_of returns correct glyph", {
  reset_caugi_registry()
  expect_equal(.glyph_of(as.symbol("%-->%")), "-->")
  expect_equal(.glyph_of(as.symbol("%---%")), "---")
  expect_equal(.glyph_of(as.symbol("%<->%")), "<->")
  expect_equal(.glyph_of(as.symbol("%--o%")), "--o")
  expect_equal(.glyph_of(as.symbol("%o-o%")), "o-o")
  expect_equal(.glyph_of(as.symbol("%o->%")), "o->")

  # new registered edge
  register_caugi_edge(
    glyph = "<--",
    tail_mark = "arrow",
    head_mark = "tail",
    class = "directed",
    symmetric = FALSE
  )
  expect_equal(.glyph_of(as.symbol("%<--%")), "<--")
  reset_caugi_registry()
})

test_that(".glyph_of returns NULL for unknown operator", {
  expect_null(.glyph_of(TRUE))
  expect_null(.glyph_of(NULL))
  expect_null(.glyph_of(as.symbol("A")))
  expect_null(.glyph_of(as.symbol("%unknown%")))
})

test_that(".glyph_of handles NULL and unnamed glyph maps in case everything goes south", {
  old <- get0("glyph_map", .caugi_env, ifnotfound = quote(MISSING))
  on.exit(
    {
      if (identical(old, quote(MISSING))) {
        rm("glyph_map", envir = .caugi_env)
      } else {
        assign("glyph_map", old, envir = .caugi_env)
      }
    },
    add = TRUE
  )

  assign("glyph_map", NULL, envir = .caugi_env)
  expect_null(.glyph_of(as.symbol("%-->%")))

  assign("glyph_map", c("x", "y"), envir = .caugi_env) # no names
  expect_null(.glyph_of(as.symbol("%-->%")))
})


# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────── Expand, split, collect ────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that(".expand_nodes expands symbols, strings, numerics, +, c(), and ()", {
  expect_equal(.expand_nodes(quote(A)), "A")
  expect_equal(.expand_nodes("B"), "B")
  expect_equal(.expand_nodes(1), "1")
  expect_equal(.expand_nodes(quote((A))), "A")
  expect_equal(
    .expand_nodes(quote(A + B + (C))),
    c("A", "B", "C")
  )
  expect_equal(
    .expand_nodes(quote(c(A, "B", (C), 3))),
    c("A", "B", "C", "3")
  )
  expect_error(.expand_nodes(quote(A:B)))
})

test_that(".split_plus and .combine_plus are consistent", {
  expr <- quote(A + (B + C) + D)
  parts <- .split_plus(expr)

  # note: middle stays nested
  expect_length(parts, 4)
  expect_equal(lapply(parts, deparse1), list("A", "B", "C", "D"))

  # Recombine flattened parts explicitly
  recombined <- .combine_plus(list(quote(A), quote(B), quote(C), quote(D)))
  expect_equal(deparse1(recombined), "A + B + C + D")
})

test_that(".combine_plus covers len 0 and len 1", {
  expect_null(.combine_plus(list()))
  one <- .combine_plus(list(quote(A)))
  expect_identical(deparse1(one), "A")
})

test_that(".collect_edges_nodes returns empty data frame when no units", {
  out <- .collect_edges_nodes(list())
  expect_equal(nrow(out$edges), 0)
  expect_named(out$edges, c("from", "edge", "to"))
  expect_length(out$declared, 0)
})

test_that(".collect_edges_nodes errors on invalid top-level expression", {
  expect_error(.collect_edges_nodes(list(quote(A:B))), "Expected an edge")
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── Parse edge ──────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that(".parse_edge_arg extracts context correctly", {
  # Build A + (B %-->% C) + D using calls to avoid precedence concerns
  edge_core <- call("%-->%", quote(B), quote(C))
  expr <- call("+", quote(A), call("+", edge_core, quote(D)))

  units <- .parse_edge_arg(expr)
  expect_length(units, 1)

  u <- units[[1]]
  # LHS should be A + B; RHS should be C + D
  expect_equal(.expand_nodes(u$lhs), c("A", "B"))
  expect_equal(.expand_nodes(u$rhs), c("C", "D"))
  expect_equal(u$glyph, "-->")
})

test_that(".edge_units_to_dt produces cartesian edges", {
  edge_unit <- list(
    lhs = quote(A + B),
    rhs = quote(C + D),
    glyph = "-->"
  )
  df <- .edge_units_to_dt(list(edge_unit))
  expect_s3_class(df, "data.table")
  expect_equal(nrow(df), 4)
  expect_equal(df$from, c("A", "A", "B", "B"))
  expect_equal(df$to, c("C", "D", "C", "D"))
  expect_true(all(df$edge == "-->"))
})

test_that(".collect_edges_nodes gathers edges and declared nodes", {
  # Expressions:
  #   1) A + B %-->% C + D
  #   2) c(E, "F", (G))        # declared nodes
  #   3) Duplicate edge to test distinct
  ex1 <- quote(A + B %-->% C + D)
  ex_decl <- call("c", quote(E), "F", quote((G)))
  ex_dup <- quote(B %-->% C)

  out <- .collect_edges_nodes(list(ex1, ex_decl, ex_dup))

  # Declared nodes unique
  expect_setequal(out$declared, c("E", "F", "G"))

  # Edges distinct and complete cartesian from {A,B} to {C,D}
  # plus B->C duplicate removed
  df <- out$edges
  expect_true(all(c("from", "edge", "to") %in% names(df)))
  expect_equal(nrow(df), 4) # A->C, A->D, B->C, B->D
  expect_true(any(df$from == "A" & df$to == "C"))
  expect_true(any(df$from == "A" & df$to == "D"))
  expect_true(any(df$from == "B" & df$to == "C"))
  expect_true(any(df$from == "B" & df$to == "D"))
  expect_true(all(df$edge == "-->"))
})


test_that(".parse_edge_arg errors when no edge present", {
  expect_error(.parse_edge_arg(quote(A + B + C)), "Expected an edge expression")
})

test_that(".parse_edge_arg handles multiple edge units with context", {
  reset_caugi_registry()
  register_caugi_edge(
    glyph = "<--",
    tail_mark = "arrow",
    head_mark = "tail",
    class = "directed",
    symmetric = FALSE
  )
  # Build: X + (A %-->% B) + Y + (C %<--% D) + Z
  e1 <- call("%-->%", quote(A), quote(B))
  e2 <- call("%<--%", quote(C), quote(D))
  expr <- call(
    "+",
    quote(X),
    call(
      "+",
      call("+", e1, quote(Y)),
      call("+", e2, quote(Z))
    )
  )
  units <- .parse_edge_arg(expr)
  expect_length(units, 2)

  # First unit context: LHS X + A ; RHS B + Y
  u1 <- units[[1]]
  expect_equal(.expand_nodes(u1$lhs), c("X", "A"))
  expect_equal(.expand_nodes(u1$rhs), c("B", "Y"))
  expect_equal(u1$glyph, "-->")

  # Second unit context: LHS Y + C ; RHS D + Z  (X consumed before first edge)
  u2 <- units[[2]]
  expect_equal(.expand_nodes(u2$lhs), c("Y", "C"))
  expect_equal(.expand_nodes(u2$rhs), c("D", "Z"))
  expect_equal(u2$glyph, "<--")

  reset_caugi_registry()
})

# ----
test_that("simple chain expands pairwise", {
  cg <- caugi(A %-->% B %-->% C)
  expect_equal(sort(cg@edges$from), c("A", "B"))
  expect_equal(sort(cg@edges$to), c("B", "C"))
  expect_setequal(cg@edges$edge, c("-->"))
})

test_that("mixed operators chain left-to-right", {
  cg <- caugi(A %-->% B %---% C %<->% D)
  expect_true(
    any(
      cg@edges$from == "A" &
        cg@edges$edge == "-->" &
        cg@edges$to == "B"
    )
  )
  expect_true(
    any(
      cg@edges$from == "B" &
        cg@edges$edge == "---" &
        cg@edges$to == "C"
    )
  )
  expect_true(
    any(
      cg@edges$from == "C" &
        cg@edges$edge == "<->" &
        cg@edges$to == "D"
    )
  )
  expect_equal(nrow(cg@edges), 3)
})

test_that("set terms in chain expand to cartesian per segment", {
  cg <- caugi((A + B) %o->% (C + D) %--o% E)
  # segment 1: {A,B} o-> {C,D}
  expect_true(
    any(
      cg@edges$from == "A" &
        cg@edges$edge == "o->" &
        cg@edges$to == "C"
    )
  )
  expect_true(
    any(
      cg@edges$from == "B" &
        cg@edges$edge == "o->" &
        cg@edges$to == "D"
    )
  )
  # segment 2: {C,D} --o E
  expect_true(
    any(
      cg@edges$from == "C" &
        cg@edges$edge == "--o" &
        cg@edges$to == "E"
    )
  )
  expect_true(
    any(
      cg@edges$from == "D" &
        cg@edges$edge == "--o" &
        cg@edges$to == "E"
    )
  )
  expect_equal(nrow(cg@edges), 6)
})

test_that("extra + nodes around a chain attach to the ends", {
  cg <- caugi(X + A %-->% B %-->% C + Y)
  # first segment: {X,A} --> B
  expect_true(
    any(
      cg@edges$from == "X" &
        cg@edges$edge == "-->" &
        cg@edges$to == "B"
    )
  )
  expect_true(
    any(
      cg@edges$from == "A" &
        cg@edges$edge == "-->" &
        cg@edges$to == "B"
    )
  )
  # last segment: B --> {C,Y}
  expect_true(
    any(
      cg@edges$from == "B" &
        cg@edges$edge == "-->" &
        cg@edges$to == "C"
    )
  )
  expect_true(
    any(
      cg@edges$from == "B" &
        cg@edges$edge == "-->" &
        cg@edges$to == "Y"
    )
  )
  # no A --> C directly
  expect_false(any(cg@edges$from == "A" & cg@edges$to == "C"))
})

test_that("parentheses isolate terms inside chain", {
  cg <- caugi(A %-->% (B + C) %<->% D)
  # segment 1
  expect_true(
    any(
      cg@edges$from == "A" &
        cg@edges$edge == "-->" &
        cg@edges$to == "B"
    )
  )
  expect_true(
    any(
      cg@edges$from == "A" &
        cg@edges$edge == "-->" &
        cg@edges$to == "C"
    )
  )
  # segment 2
  expect_true(
    any(
      cg@edges$from == "B" &
        cg@edges$edge == "<->" &
        cg@edges$to == "D"
    )
  )
  expect_true(
    any(
      cg@edges$from == "C" &
        cg@edges$edge == "<->" &
        cg@edges$to == "D"
    )
  )
  expect_equal(nrow(cg@edges), 4)
})

test_that("self-loop is caugt by chained edges", {
  expect_error(caugi(A %-->% B %-->% B), "Self-loops not allowed")
})

test_that("chains respect class constraints", {
  expect_error(caugi(A %---% B %-->% C, class = "DAG"))
  expect_error(caugi(A %o->% B %o-o% C, class = "PDAG"))
})
