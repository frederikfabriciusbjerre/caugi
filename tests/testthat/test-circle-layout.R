test_that("circle layout places nodes on a unit-radius circle around (0.5, 0.5)", {
  cg <- caugi(A %-->% B, B %-->% C, C %-->% D, D %-->% A)
  layout <- caugi_layout_circle(cg)

  expect_equal(nrow(layout), 4)
  expect_setequal(layout$name, c("A", "B", "C", "D"))

  radii <- sqrt((layout$x - 0.5)^2 + (layout$y - 0.5)^2)
  expect_equal(radii, rep(0.5, 4), tolerance = 1e-9)
})

test_that("circle layout first node is at the top", {
  cg <- caugi(A %-->% B, B %-->% C, C %-->% A)
  layout <- caugi_layout_circle(cg)

  expect_equal(layout$x[1], 0.5, tolerance = 1e-9)
  expect_equal(layout$y[1], 1.0, tolerance = 1e-9)
})

test_that("circle layout via caugi_layout dispatches to circle method", {
  cg <- caugi(A %-->% B, B %-->% C, C %-->% D)
  layout <- caugi_layout(cg, method = "circle")

  expect_equal(nrow(layout), 4)
  radii <- sqrt((layout$x - 0.5)^2 + (layout$y - 0.5)^2)
  expect_equal(radii, rep(0.5, 4), tolerance = 1e-9)
})

test_that("circle layout works with mixed edge types", {
  cg <- caugi(A %-->% B, B %<->% C, C %---% D)
  layout <- caugi_layout_circle(cg)

  expect_equal(nrow(layout), 4)
  expect_true(all(layout$x >= 0 & layout$x <= 1))
  expect_true(all(layout$y >= 0 & layout$y <= 1))
})

test_that("circle layout is deterministic", {
  cg <- caugi(A %-->% B, B %-->% C, C %-->% D, D %-->% A)
  l1 <- caugi_layout_circle(cg)
  l2 <- caugi_layout_circle(cg)
  expect_equal(l1, l2)
})

test_that("circle layout single node is centered", {
  cg <- caugi(A, class = "DAG")
  layout <- caugi_layout_circle(cg)

  expect_equal(nrow(layout), 1)
  expect_equal(layout$x, 0.5)
  expect_equal(layout$y, 0.5)
})
