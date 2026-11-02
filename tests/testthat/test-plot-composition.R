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

  caugi_options(plot = list(spacing = 1))
  expect_error(
    p1 + p2,
    "`caugi_options\\(\\)\\$plot\\$spacing` must be a grid::unit\\(\\)"
  )
})

test_that("same-direction compositions allocate equal space to every plot", {
  plots <- lapply(seq_len(4), function(i) {
    caugi_plot(grob = grid::textGrob(as.character(i)))
  })
  for (op in list(`+`, `|`, `/`)) {
    left <- Reduce(op, plots)
    right <- op(plots[[1]], op(plots[[2]], op(plots[[3]], plots[[4]])))
    balanced <- op(op(plots[[1]], plots[[2]]), op(plots[[3]], plots[[4]]))
    for (p in list(left, right, balanced)) {
      layout <- p@grob$vp$layout
      horizontal <- layout$nrow == 1L
      sizes <- if (horizontal) layout$widths else layout$heights
      expect_length(p@grob$children, 4)
      expect_equal(as.numeric(sizes[c(1, 3, 5, 7)]), rep(1, 4))
      expect_equal(grid::unitType(sizes[c(1, 3, 5, 7)]), rep("null", 4))
      expect_equal(
        as.numeric(sizes[c(2, 4, 6)]),
        rep(as.numeric(caugi_options()$plot$spacing), 3)
      )
      expect_equal(
        grid::unitType(sizes[c(2, 4, 6)]),
        rep(grid::unitType(caugi_options()$plot$spacing), 3)
      )
      for (i in seq_along(plots)) {
        expect_equal(p@grob$children[[i]]$children[[1]], plots[[i]]@grob)
      }
    }
  }
})

test_that("flattening preserves mixed-direction groups", {
  p <- caugi_plot(grob = grid::textGrob("plot"))
  for (composition in list((p + p) / p / p, (p / p) + p + p)) {
    expect_length(composition@grob$children, 3)
    group <- composition@grob$children[[1]]$children[[1]]
    expect_length(group$children, 2)
    expect_false(identical(
      group$caugi_composition_direction,
      composition@grob$caugi_composition_direction
    ))
  }
  expect_length(((p | p) + p)@grob$children, 3)
})
