test_that("+ operator creates horizontal composition", {
  cg1 <- caugi(A %-->% B)
  cg2 <- caugi(X %-->% Y)

  p1 <- plot(cg1, main = "Graph 1")
  p2 <- plot(cg2, main = "Graph 2")

  pdf(NULL)
  on.exit(dev.off())

  p3 <- p1 + p2

  expect_s7_class(p3, caugi_plot)
  expect_s3_class(p3@grob, "gTree")
  expect_equal(p3@grob$name, "caugi.composed")
})

test_that("| operator creates horizontal composition", {
  cg1 <- caugi(A %-->% B)
  cg2 <- caugi(X %-->% Y)

  p1 <- plot(cg1, main = "Graph 1")
  p2 <- plot(cg2, main = "Graph 2")

  pdf(NULL)
  on.exit(dev.off())

  p3 <- p1 | p2

  expect_s7_class(p3, caugi_plot)
  expect_s3_class(p3@grob, "gTree")
  expect_equal(p3@grob$name, "caugi.composed")
})

test_that("/ operator creates vertical composition", {
  cg1 <- caugi(A %-->% B)
  cg2 <- caugi(X %-->% Y)

  p1 <- plot(cg1, main = "Graph 1")
  p2 <- plot(cg2, main = "Graph 2")

  pdf(NULL)
  on.exit(dev.off())

  p3 <- p1 / p2

  expect_s7_class(p3, caugi_plot)
  expect_s3_class(p3@grob, "gTree")
  expect_equal(p3@grob$name, "caugi.composed")
})

test_that("compositions can be nested horizontally", {
  cg1 <- caugi(A %-->% B)
  cg2 <- caugi(X %-->% Y)

  p1 <- plot(cg1)
  p2 <- plot(cg2)

  pdf(NULL)
  on.exit(dev.off())

  p3 <- p1 + p2
  p4 <- p3 + p1

  expect_s7_class(p4, caugi_plot)
  expect_s3_class(p4@grob, "gTree")

  # Verify it can be drawn without error
  expect_silent(grid::grid.draw(p4@grob))
})

test_that("compositions can be nested vertically", {
  cg1 <- caugi(A %-->% B)
  cg2 <- caugi(X %-->% Y)

  p1 <- plot(cg1)
  p2 <- plot(cg2)

  pdf(NULL)
  on.exit(dev.off())

  p3 <- p1 / p2
  p4 <- p3 / p1

  expect_s7_class(p4, caugi_plot)
  expect_s3_class(p4@grob, "gTree")

  # Verify it can be drawn without error
  expect_silent(grid::grid.draw(p4@grob))
})

test_that("compositions can mix horizontal and vertical", {
  cg1 <- caugi(A %-->% B)
  cg2 <- caugi(X %-->% Y)

  p1 <- plot(cg1)
  p2 <- plot(cg2)

  pdf(NULL)
  on.exit(dev.off())

  p3 <- (p1 + p2) / p1

  expect_s7_class(p3, caugi_plot)
  expect_s3_class(p3@grob, "gTree")

  # Verify it can be drawn without error
  expect_silent(grid::grid.draw(p3@grob))
})

test_that("composition respects global spacing option", {
  old_opts <- caugi_options()
  on.exit(caugi_options(old_opts))

  cg1 <- caugi(A %-->% B)
  cg2 <- caugi(X %-->% Y)

  p1 <- plot(cg1)
  p2 <- plot(cg2)

  pdf(NULL)
  on.exit(dev.off(), add = TRUE)

  # Set custom spacing
  caugi_options(plot = list(spacing = grid::unit(3, "lines")))

  p3 <- p1 + p2

  expect_s7_class(p3, caugi_plot)

  # Verify it can be drawn without error
  expect_silent(grid::grid.draw(p3@grob))
})

test_that("composed plots can be printed", {
  cg1 <- caugi(A %-->% B)
  cg2 <- caugi(X %-->% Y)

  p1 <- plot(cg1)
  p2 <- plot(cg2)

  pdf(NULL)
  on.exit(dev.off())

  p3 <- p1 + p2

  # print should call plot method
  expect_silent(print(p3))
})

test_that("composition works with empty graphs", {
  cg1 <- caugi(A)
  cg2 <- caugi(X)

  p1 <- plot(cg1)
  p2 <- plot(cg2)

  pdf(NULL)
  on.exit(dev.off())

  p3 <- p1 + p2

  expect_s7_class(p3, caugi_plot)
  expect_silent(grid::grid.draw(p3@grob))
})

test_that("composition works with different graph sizes", {
  cg1 <- caugi(A %-->% B)
  cg2 <- caugi(
    X %-->% Y,
    Y %-->% Z,
    Z %-->% W,
    X %-->% Z
  )

  p1 <- plot(cg1)
  p2 <- plot(cg2)

  pdf(NULL)
  on.exit(dev.off())

  p3 <- p1 + p2
  p4 <- p1 / p2

  expect_s7_class(p3, caugi_plot)
  expect_s7_class(p4, caugi_plot)
  expect_silent(grid::grid.draw(p3@grob))
  expect_silent(grid::grid.draw(p4@grob))
})

test_that("plot composition branches are covered", {
  old_opts <- caugi_options()
  on.exit(caugi_options(old_opts), add = TRUE)

  p1 <- plot(caugi(A %-->% B))
  p2 <- plot(caugi(X %-->% Y))

  caugi_options(plot = list(spacing = NULL))
  expect_s7_class(p1 + p2, caugi_plot)
  expect_s7_class(p1 | p2, caugi_plot)
  expect_s7_class(p1 / p2, caugi_plot)

  add_method <- S7::method(S7:::as_generic(`+`), list(caugi_plot, caugi_plot))
  pipe_method <- S7::method(S7:::as_generic(`|`), list(caugi_plot, caugi_plot))
  divide_method <- S7::method(
    S7:::as_generic(`/`),
    list(caugi_plot, caugi_plot)
  )
  expect_s7_class(add_method(p1, p2), caugi_plot)
  expect_s7_class(pipe_method(p1, p2), caugi_plot)
  expect_s7_class(divide_method(p1, p2), caugi_plot)

  caugi_options(plot = list(spacing = 1))
  expect_error(
    p1 + p2,
    "`caugi_options\\(\\)\\$plot\\$spacing` must be a grid::unit\\(\\)"
  )
})
