# ───────────────────────── Rust backend FFI tests ─────────────────────────────

test_that("graph builder works for directed edge in reverse direction", {
  reg <- edge_registry_new()
  edge_registry_register_builtins(reg)
  expect_equal(edge_registry_len(reg), 6L)

  # Custom directed edge in reverse direction
  code_und <- edge_registry_register(
    reg,
    glyph = "<--",
    tail_mark = "arrow",
    head_mark = "tail",
    class = "directed",
    symmetric = FALSE
  )
  expect_true(is.integer(code_und) || is.double(code_und))

  b <- graph_builder_new(reg, n = 3L, simple = TRUE)

  # test if reverse directed edge works
  graph_builder_add_edges(
    b,
    from = c(0L),
    to = c(1L),
    etype = c(code_und) # undirected edge in the middle
  )

  # Build the class to verify it works
  class_label <- graph_builder_resolve_class(b, class = "PDAG")
  expect_equal(class_label, "PDAG")

  reset_caugi_registry()
})

test_that("queries work for DAGs and PDAGs via session", {
  # DAG EXAMPLE
  cg <- caugi(A %-->% B, class = "DAG")

  expect_identical(
    rs_parents_of(cg@session, 0L),
    list(integer(0))
  )
  expect_identical(
    rs_children_of(cg@session, 0L),
    list(1L)
  )
  expect_identical(
    rs_parents_of(cg@session, 1L),
    list(0L)
  )
  expect_identical(
    rs_children_of(cg@session, 1L),
    list(integer(0))
  )

  cg <- add_edges(cg, B %-->% C)
  # Session syncs automatically

  expect_identical(
    rs_parents_of(cg@session, 0L),
    list(integer(0))
  )
  expect_identical(
    rs_children_of(cg@session, 0L),
    list(1L)
  )
  expect_identical(
    rs_parents_of(cg@session, 1L),
    list(0L)
  )
  expect_identical(
    rs_children_of(cg@session, 1L),
    list(2L)
  )
  expect_identical(
    rs_parents_of(cg@session, 2L),
    list(1L)
  )
  expect_identical(
    rs_children_of(cg@session, 2L),
    list(integer(0))
  )

  # PDAG EXAMPLE
  cg <- caugi(A %-->% B, class = "PDAG")
  expect_identical(
    rs_parents_of(cg@session, 0L),
    list(integer(0))
  )
  expect_identical(
    rs_children_of(cg@session, 0L),
    list(1L)
  )
  expect_identical(
    rs_parents_of(cg@session, 1L),
    list(0L)
  )
  expect_identical(
    rs_children_of(cg@session, 1L),
    list(integer(0))
  )

  cg <- add_edges(cg, B %---% C)
  # Session syncs automatically

  expect_identical(
    rs_parents_of(cg@session, 0L),
    list(integer(0))
  )
  expect_identical(
    rs_children_of(cg@session, 0L),
    list(1L)
  )
  expect_identical(
    rs_undirected_of(cg@session, 1L),
    list(2L)
  )
})

test_that("rs_build compiles core and view lazily", {
  cg <- caugi(A %-->% B, class = "DAG")
  state_before <- rs_is_valid(cg@session)
  expect_true(state_before$core_valid)
  expect_false(state_before$view_valid)

  rs_build(cg@session)
  state_after <- rs_is_valid(cg@session)
  expect_true(state_after$core_valid)
  expect_true(state_after$view_valid)

  # idempotent call
  rs_build(cg@session)
  state_after2 <- rs_is_valid(cg@session)
  expect_true(state_after2$core_valid)
  expect_true(state_after2$view_valid)

  # mutation invalidates build
  cg <- add_edges(cg, B %-->% C)
  state_after_update <- rs_is_valid(cg@session)
  expect_true(state_after_update$core_valid)
  expect_false(state_after_update$view_valid)

  rs_build(cg@session)
  state_rebuilt <- rs_is_valid(cg@session)
  expect_true(state_rebuilt$core_valid)
  expect_true(state_rebuilt$view_valid)
})

test_that("edge registry seal works", {
  reg <- edge_registry_new()
  edge_registry_register_builtins(reg)
  expect_equal(edge_registry_len(reg), 6L)

  code_und <- edge_registry_register(
    reg,
    glyph = "x-x",
    tail_mark = "other",
    head_mark = "other",
    class = "undirected",
    symmetric = TRUE
  )
  expect_true(is.integer(code_und) || is.double(code_und))
  expect_equal(edge_registry_len(reg), 7L)

  edge_registry_seal(reg)

  expect_error(edge_registry_register(
    reg,
    glyph = "o-O",
    tail_mark = "other",
    head_mark = "other",
    class = "undirected",
    symmetric = TRUE
  ))

  expect_equal(edge_registry_code_of(reg, "x-x"), as.integer(code_und))
  expect_error(edge_registry_code_of(reg, "unknown"))
})
