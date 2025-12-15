test_that("caugi_layout works with simple DAG", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    C %-->% D,
    class = "DAG"
  )

  layout <- caugi_layout(cg)

  expect_s3_class(layout, "data.frame")
  expect_equal(nrow(layout), 4L)
  expect_named(layout, c("name", "x", "y"))
  expect_equal(layout$name, c("A", "B", "C", "D"))
  expect_type(layout$x, "double")
  expect_type(layout$y, "double")
})

test_that("caugi_layout builds graph if needed", {
  cg <- caugi(A %-->% B, build = FALSE)

  layout <- caugi_layout(cg)

  expect_s3_class(layout, "data.frame")
  expect_equal(nrow(layout), 2L)
  expect_true(cg@built)
})

test_that("caugi_layout works with single node", {
  cg <- caugi(A, class = "DAG")

  layout <- caugi_layout(cg)

  expect_s3_class(layout, "data.frame")
  expect_equal(nrow(layout), 1L)
  expect_equal(layout$name, "A")
})

test_that("plot.caugi runs without error", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    class = "DAG"
  )

  # Open a null graphics device to avoid opening windows during tests
  pdf(NULL)
  on.exit(dev.off())

  expect_s7_class(plot(cg), caugi_plot)
})

test_that("plot.caugi accepts node_style arguments", {
  cg <- caugi(A %-->% B)

  pdf(NULL)
  on.exit(dev.off())

  expect_s7_class(
    plot(
      cg,
      node_style = list(fill = "lightgreen", padding = 0.8)
    ),
    caugi_plot
  )
})

test_that("plot.caugi accepts edge_style arguments", {
  cg <- caugi(A %-->% B)

  pdf(NULL)
  on.exit(dev.off())

  expect_s7_class(
    plot(
      cg,
      edge_style = list(col = "blue", arrow_size = 4)
    ),
    caugi_plot
  )
})

test_that("plot.caugi works with single node", {
  cg <- caugi(A, class = "DAG")

  pdf(NULL)
  on.exit(dev.off())

  expect_s7_class(plot(cg), caugi_plot)
})

test_that("plot.caugi builds graph if needed", {
  cg <- caugi(A %-->% B)

  pdf(NULL)
  on.exit(dev.off())

  expect_s7_class(plot(cg), caugi_plot)
})

test_that("caugi_layout works with force method", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    C %-->% D,
    class = "DAG"
  )

  layout <- caugi_layout(cg, method = "force")

  expect_s3_class(layout, "data.frame")
  expect_equal(nrow(layout), 4L)
  expect_named(layout, c("name", "x", "y"))
  expect_equal(layout$name, c("A", "B", "C", "D"))
  expect_type(layout$x, "double")
  expect_type(layout$y, "double")
  expect_true(all(is.finite(layout$x)))
  expect_true(all(is.finite(layout$y)))
})

test_that("force layout works with mixed edge types", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %<->% D
  )

  layout <- caugi_layout(cg, method = "force")

  expect_s3_class(layout, "data.frame")
  expect_equal(nrow(layout), 4L)
  expect_true(all(is.finite(layout$x)))
  expect_true(all(is.finite(layout$y)))
})

test_that("sugiyama layout rejects mixed edge types", {
  cg <- caugi(
    A %-->% B,
    B %---% C
  )

  expect_error(caugi_layout(cg, method = "sugiyama"))
})

test_that("plot.caugi works with force layout", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    class = "DAG"
  )

  pdf(NULL)
  on.exit(dev.off())

  expect_s7_class(plot(cg, layout = "force"), caugi_plot)
})

test_that("auto method selects sugiyama for directed-only graphs", {
  cg <- caugi(
    A %-->% B %-->% C,
    class = "DAG"
  )

  layout_auto <- caugi_layout(cg, method = "auto")
  layout_sug <- caugi_layout(cg, method = "sugiyama")

  # Auto should produce same result as sugiyama for directed-only graphs
  expect_equal(layout_auto, layout_sug)
})

test_that("auto method selects force for mixed edge graphs", {
  cg <- caugi(
    A %-->% B,
    B %---% C
  )

  # Auto should work (selecting force internally)
  layout_auto <- caugi_layout(cg, method = "auto")
  expect_s3_class(layout_auto, "data.frame")
  expect_equal(nrow(layout_auto), 3L)

  # Sugiyama should fail
  expect_error(caugi_layout(cg, method = "sugiyama"))
})

test_that("plot with auto layout works", {
  # Test with directed-only
  cg_dir <- caugi(A %-->% B %-->% C, class = "DAG")

  pdf(NULL)
  on.exit(dev.off())

  expect_s7_class(plot(cg_dir, layout = "auto"), caugi_plot)

  # Test with mixed edges
  cg_mixed <- caugi(A %-->% B, B %---% C)
  expect_s7_class(plot(cg_mixed, layout = "auto"), caugi_plot)
})

test_that("auto is the default method", {
  cg <- caugi(A %-->% B, class = "DAG")

  # Default should work without specifying method
  layout_default <- caugi_layout(cg)
  expect_s3_class(layout_default, "data.frame")

  pdf(NULL)
  on.exit(dev.off())

  # Default should work for plot too
  expect_s7_class(plot(cg), caugi_plot)
})

test_that("kamada-kawai layout works with simple DAG", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    C %-->% D,
    class = "DAG"
  )

  layout <- caugi_layout(cg, method = "kamada-kawai")

  expect_s3_class(layout, "data.frame")
  expect_equal(nrow(layout), 4L)
  expect_named(layout, c("name", "x", "y"))
  expect_equal(layout$name, c("A", "B", "C", "D"))
  expect_type(layout$x, "double")
  expect_type(layout$y, "double")
  expect_true(all(is.finite(layout$x)))
  expect_true(all(is.finite(layout$y)))
})

test_that("kamada-kawai layout is deterministic", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    C %-->% D,
    class = "DAG"
  )

  layout1 <- caugi_layout(cg, method = "kamada-kawai")
  layout2 <- caugi_layout(cg, method = "kamada-kawai")
  layout3 <- caugi_layout(cg, method = "kamada-kawai")

  # All three should be identical
  expect_identical(layout1, layout2)
  expect_identical(layout2, layout3)
})
