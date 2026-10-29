test_that("Sugiyama layouts place parents above children in DAGs", {
  graphs <- list(
    caugi(A %-->% B %-->% C, class = "DAG"),
    caugi(A %-->% B + C, B %-->% D, C %-->% D, class = "DAG")
  )

  for (cg in graphs) {
    edge_df <- edges(cg)
    layouts <- list(
      caugi_layout_sugiyama(cg),
      caugi_layout(cg, method = "sugiyama"),
      caugi_layout(cg)
    )

    for (layout in layouts) {
      y <- stats::setNames(layout$y, layout$name)
      expect_true(all(y[edge_df$from] > y[edge_df$to]))
    }
  }
})

test_that("Sugiyama component packing preserves top-to-bottom flow", {
  cg <- caugi(
    A %-->% B %-->% C,
    D %-->% E,
    F,
    class = "DAG"
  )
  edge_df <- edges(cg)

  for (packing_ratio in c(0, 1.618034, Inf)) {
    layout <- caugi_layout_sugiyama(cg, packing_ratio = packing_ratio)
    y <- stats::setNames(layout$y, layout$name)

    expect_equal(layout$name, nodes(cg)[["name"]])
    expect_true(all(y[edge_df$from] > y[edge_df$to]))
    expect_true(all(is.finite(layout$x)))
    expect_true(all(is.finite(layout$y)))
    expect_true(all(layout$x >= 0 & layout$x <= 1))
    expect_true(all(layout$y >= 0 & layout$y <= 1))
  }
})

test_that("Sugiyama layout handles empty graphs and isolated nodes", {
  empty <- caugi_layout_sugiyama(caugi(class = "DAG"))
  expect_equal(nrow(empty), 0L)
  expect_named(empty, c("name", "x", "y"))

  singleton <- caugi_layout_sugiyama(caugi(A, class = "DAG"))
  expect_equal(singleton$name, "A")
  expect_equal(singleton$x, 0.5)
  expect_equal(singleton$y, 0.5)

  isolated <- caugi_layout_sugiyama(caugi(A, B, C, class = "DAG"))
  expect_equal(isolated$name, c("A", "B", "C"))
  expect_true(all(is.finite(isolated$x)))
  expect_true(all(is.finite(isolated$y)))
})
