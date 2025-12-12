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
  cg <- caugi(A %-->% B)

  layout <- caugi_layout(cg)

  expect_s3_class(layout, "data.frame")
  expect_equal(nrow(layout), 2L)
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
