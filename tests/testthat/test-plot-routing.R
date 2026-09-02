# Tests for the pure edge-routing geometry helpers in R/plot-routing.R.
# These operate on plain mm doubles and need no graphics device.

test_that(".point_segment_dist measures perpendicular foot inside segment", {
  res <- .point_segment_dist(5, 3, 0, 0, 10, 0)
  expect_equal(res$dist, 3)
  expect_equal(res$t, 0.5)
})

test_that(".point_segment_dist clamps past the endpoints", {
  before_a <- .point_segment_dist(-4, 0, 0, 0, 10, 0)
  expect_equal(before_a$t, 0)
  expect_equal(before_a$dist, 4)

  past_b <- .point_segment_dist(13, 0, 0, 0, 10, 0)
  expect_equal(past_b$t, 1)
  expect_equal(past_b$dist, 3)
})

test_that(".point_segment_dist handles a zero-length segment", {
  res <- .point_segment_dist(4, 5, 1, 1, 1, 1)
  expect_equal(res$t, 0)
  expect_equal(res$dist, 5)
})

test_that("route_edge_path returns NULL when the obstacle is far away", {
  path <- route_edge_path(
    0,
    0,
    10,
    0,
    r_from = 0,
    r_to = 0,
    ox = 5,
    oy = 50,
    or = 1,
    clearance = 1
  )
  expect_null(path)
})

test_that("route_edge_path returns NULL when there are no obstacles", {
  path <- route_edge_path(
    0,
    0,
    10,
    0,
    r_from = 0,
    r_to = 0,
    ox = numeric(0),
    oy = numeric(0),
    or = numeric(0),
    clearance = 1
  )
  expect_null(path)
})

test_that("route_edge_path bends the curve clear of an on-segment obstacle", {
  ox <- 5
  oy <- 0
  or <- 1
  clearance <- 1
  path <- route_edge_path(
    0,
    0,
    10,
    0,
    r_from = 0,
    r_to = 0,
    ox = ox,
    oy = oy,
    or = or,
    clearance = clearance
  )

  expect_type(path, "list")
  expect_named(path, c("x", "y"))

  # The closest approach of the sampled curve to the obstacle center must
  # respect the required clearance.
  dists <- sqrt((path$x - ox)^2 + (path$y - oy)^2)
  expect_gte(min(dists), or + clearance)
})

test_that("route_edge_path bends to the side opposite the obstacle", {
  # Obstacle above the chord -> curve apex should dip below it (negative y).
  above <- route_edge_path(
    0,
    0,
    10,
    0,
    r_from = 0,
    r_to = 0,
    ox = 5,
    oy = 0.5,
    or = 1,
    clearance = 1
  )
  expect_lt(min(above$y), 0)

  # Obstacle below the chord -> curve apex should rise above it (positive y).
  below <- route_edge_path(
    0,
    0,
    10,
    0,
    r_from = 0,
    r_to = 0,
    ox = 5,
    oy = -0.5,
    or = 1,
    clearance = 1
  )
  expect_gt(max(below$y), 0)
})

test_that("route_edge_path keeps the curve endpoints at the node centers", {
  # With zero radii there is no clipping, so the curve spans center to center.
  path <- route_edge_path(
    2,
    3,
    12,
    9,
    r_from = 0,
    r_to = 0,
    ox = 7,
    oy = 6,
    or = 1,
    clearance = 1
  )
  expect_equal(path$x[1], 2)
  expect_equal(path$y[1], 3)
  expect_equal(path$x[length(path$x)], 12)
  expect_equal(path$y[length(path$y)], 9)
})

test_that("route_edge_path clips the curve to the node borders", {
  # Non-zero radii: the endpoints should sit on each node's border, i.e. at
  # distance r_from / r_to from the respective center.
  p0 <- c(0, 0)
  p2 <- c(10, 0)
  path <- route_edge_path(
    p0[1],
    p0[2],
    p2[1],
    p2[2],
    r_from = 1.5,
    r_to = 2,
    ox = 5,
    oy = 0,
    or = 1,
    clearance = 1
  )

  d_start <- sqrt((path$x[1] - p0[1])^2 + (path$y[1] - p0[2])^2)
  m <- length(path$x)
  d_end <- sqrt((path$x[m] - p2[1])^2 + (path$y[m] - p2[2])^2)
  expect_equal(d_start, 1.5, tolerance = 1e-3)
  expect_equal(d_end, 2, tolerance = 1e-3)
})

test_that("route_edge_path samples the requested number of points", {
  path <- route_edge_path(
    0,
    0,
    10,
    0,
    r_from = 0,
    r_to = 0,
    ox = 5,
    oy = 0,
    or = 1,
    clearance = 1,
    n = 25L
  )
  expect_length(path$x, 25L)
  expect_length(path$y, 25L)
})

test_that("makeContent curves an edge around an on-path obstacle", {
  pdf(NULL)
  on.exit(dev.off())
  grid::pushViewport(grid::viewport(xscale = c(0, 1), yscale = c(0, 1)))

  obstacle <- list(
    obstacle_x = 0.5,
    obstacle_y = 0.5,
    obstacle_r = list(grid::unit(4, "mm"))
  )

  routed <- make_edge_grob(
    x0 = 0,
    y0 = 0.5,
    x1 = 1,
    y1 = 0.5,
    r_from = grid::unit(3, "mm"),
    r_to = grid::unit(3, "mm"),
    gp = grid::gpar(col = "black", lwd = 1),
    edge_type = "-->",
    obstacle_x = obstacle$obstacle_x,
    obstacle_y = obstacle$obstacle_y,
    obstacle_r = obstacle$obstacle_r,
    route = TRUE
  )
  routed_line <- grid::makeContent(routed)$children[[1]]
  expect_gt(length(routed_line$x), 2)

  straight <- make_edge_grob(
    x0 = 0,
    y0 = 0.5,
    x1 = 1,
    y1 = 0.5,
    r_from = grid::unit(3, "mm"),
    r_to = grid::unit(3, "mm"),
    gp = grid::gpar(col = "black", lwd = 1),
    edge_type = "-->",
    obstacle_x = obstacle$obstacle_x,
    obstacle_y = obstacle$obstacle_y,
    obstacle_r = obstacle$obstacle_r,
    route = FALSE
  )
  straight_line <- grid::makeContent(straight)$children[[1]]
  expect_length(straight_line$x, 2)
})
