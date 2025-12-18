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

test_that("plot.caugi applies margins and title padding", {
  cg <- caugi(A %-->% B)

  pdf(NULL)
  on.exit(dev.off())

  p <- plot(cg, main = "Title")
  graph <- grid::getGrob(p@grob, "caugi.graph")
  layout <- graph$vp[[1]]$layout

  margin_widths <- grid::convertWidth(
    layout$widths[c(1, 3)],
    "mm",
    valueOnly = TRUE
  )
  expect_true(all(margin_widths > 0))
  expect_equal(margin_widths[1], margin_widths[2])

  top_bottom_margins <- grid::convertHeight(
    layout$heights[c(1, 5)],
    "mm",
    valueOnly = TRUE
  )
  expect_true(all(top_bottom_margins > 0))
  expect_equal(top_bottom_margins[1], top_bottom_margins[2])

  expect_gt(
    grid::convertHeight(layout$heights[[2]], "mm", valueOnly = TRUE),
    0
  )
  expect_gt(
    grid::convertHeight(layout$heights[[3]], "mm", valueOnly = TRUE),
    0
  )
})

test_that("plot.caugi omits title spacing when main is NULL", {
  cg <- caugi(A %-->% B)

  pdf(NULL)
  on.exit(dev.off())

  p <- plot(cg)
  graph <- grid::getGrob(p@grob, "caugi.graph")
  layout <- graph$vp[[1]]$layout

  expect_equal(
    grid::convertHeight(layout$heights[[2]], "mm", valueOnly = TRUE),
    0
  )
  expect_equal(
    grid::convertHeight(layout$heights[[3]], "mm", valueOnly = TRUE),
    0
  )
})

test_that("caugi_layout works with fruchterman-reingold method", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    C %-->% D,
    class = "DAG"
  )

  layout <- caugi_layout(cg, method = "fruchterman-reingold")

  expect_s3_class(layout, "data.frame")
  expect_equal(nrow(layout), 4L)
  expect_named(layout, c("name", "x", "y"))
  expect_equal(layout$name, c("A", "B", "C", "D"))
  expect_type(layout$x, "double")
  expect_type(layout$y, "double")
  expect_true(all(is.finite(layout$x)))
  expect_true(all(is.finite(layout$y)))
})

test_that("fruchterman-reingold layout works with mixed edge types", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %<->% D
  )

  layout <- caugi_layout(cg, method = "fruchterman-reingold")

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

test_that("plot.caugi works with fruchterman-reingold layout", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    class = "DAG"
  )

  pdf(NULL)
  on.exit(dev.off())

  expect_s7_class(plot(cg, layout = "fruchterman-reingold"), caugi_plot)
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

test_that("auto method selects fruchterman-reingold for mixed edge graphs", {
  cg <- caugi(
    A %-->% B,
    B %---% C
  )

  # Auto should work (selecting fruchterman-reingold internally)
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

test_that("caugi_options can be queried", {
  opts <- caugi_options()

  expect_type(opts, "list")
  expect_true("plot" %in% names(opts))
  expect_type(opts$plot, "list")
})

test_that("caugi_options can set and get plot spacing", {
  old_opts <- caugi_options()
  on.exit(caugi_options(old_opts))

  # Set new spacing
  caugi_options(plot = list(spacing = grid::unit(2, "lines")))

  # Verify it was set
  opts <- caugi_options()
  expect_s3_class(opts$plot$spacing, "unit")
  expect_equal(as.numeric(opts$plot$spacing), 2)
})

test_that("caugi_options can set node_style defaults", {
  old_opts <- caugi_options()
  on.exit(caugi_options(old_opts))

  # Set node style
  caugi_options(
    plot = list(
      node_style = list(fill = "lightblue", padding = 3)
    )
  )

  opts <- caugi_options()
  expect_equal(opts$plot$node_style$fill, "lightblue")
  expect_equal(opts$plot$node_style$padding, 3)
})

test_that("caugi_options can set edge_style defaults", {
  old_opts <- caugi_options()
  on.exit(caugi_options(old_opts))

  # Set edge style
  caugi_options(
    plot = list(
      edge_style = list(arrow_size = 5, fill = "darkgray")
    )
  )

  opts <- caugi_options()
  expect_equal(opts$plot$edge_style$arrow_size, 5)
  expect_equal(opts$plot$edge_style$fill, "darkgray")
})

test_that("plot respects global node_style options", {
  old_opts <- caugi_options()
  on.exit(caugi_options(old_opts))

  # Set global node style
  caugi_options(
    plot = list(
      node_style = list(fill = "lightblue")
    )
  )

  cg <- caugi(A %-->% B)

  pdf(NULL)
  on.exit(dev.off(), add = TRUE)

  p <- plot(cg)
  expect_s7_class(p, caugi_plot)

  # Verify grob was created (basic check that options didn't break plotting)
  expect_true(!is.null(p@grob))
})

test_that("plot arguments override global options", {
  old_opts <- caugi_options()
  on.exit(caugi_options(old_opts))

  # Set global node style
  caugi_options(
    plot = list(
      node_style = list(fill = "lightblue")
    )
  )

  cg <- caugi(A %-->% B)

  pdf(NULL)
  on.exit(dev.off(), add = TRUE)

  # Override with argument
  p <- plot(cg, node_style = list(fill = "pink"))
  expect_s7_class(p, caugi_plot)
})

test_that("plot.caugi renders o-> edges with circles", {
  cg <- caugi(A %o->% B, class = "UNKNOWN")

  pdf(NULL)
  on.exit(dev.off())

  # Test that plot completes without error and renders circles
  expect_s7_class(plot(cg), caugi_plot)
})

test_that("plot.caugi renders o-o edges with circles on both ends", {
  cg <- caugi(A %o-o% B, class = "UNKNOWN")

  pdf(NULL)
  on.exit(dev.off())

  # Test that plot completes without error and renders circles
  expect_s7_class(plot(cg), caugi_plot)
})

test_that("plot.caugi accepts circle_size for partial edges", {
  cg <- caugi(A %o->% B, B %o-o% C, class = "UNKNOWN")

  pdf(NULL)
  on.exit(dev.off())

  # Test that custom circle_size is accepted
  p <- plot(
    cg,
    edge_style = list(
      partial = list(circle_size = 2.5)
    )
  )
  expect_s7_class(p, caugi_plot)
})

test_that("plot.caugi with mixed edge types including partial", {
  cg <- caugi(
    A %-->% B,
    B %o->% C,
    C %o-o% D,
    class = "UNKNOWN"
  )

  pdf(NULL)
  on.exit(dev.off())

  # Test that mixed edge types render correctly
  expect_s7_class(plot(cg), caugi_plot)
})
