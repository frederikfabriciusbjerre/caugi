test_that("bipartite layout with rows orientation works", {
  cg <- caugi(A %-->% X, A %-->% Y, B %-->% X, B %-->% Y)
  partition <- c(TRUE, TRUE, FALSE, FALSE)

  layout <- caugi_layout_bipartite(cg, partition, orientation = "rows")

  expect_equal(nrow(layout), 4)
  expect_equal(layout$name, c("A", "B", "X", "Y"))

  # A and B should be at y=1 (top row)
  expect_equal(layout$y[layout$name %in% c("A", "B")], c(1, 1))

  # X and Y should be at y=0 (bottom row)
  expect_equal(layout$y[layout$name %in% c("X", "Y")], c(0, 0))
})

test_that("bipartite layout with columns orientation works", {
  cg <- caugi(A %-->% X, A %-->% Y, B %-->% X, B %-->% Y)
  partition <- c(TRUE, TRUE, FALSE, FALSE)

  layout <- caugi_layout_bipartite(cg, partition, orientation = "columns")

  expect_equal(nrow(layout), 4)
  expect_equal(layout$name, c("A", "B", "X", "Y"))

  # A and B should be at x=1 (right column)
  expect_equal(layout$x[layout$name %in% c("A", "B")], c(1, 1))

  # X and Y should be at x=0 (left column)
  expect_equal(layout$x[layout$name %in% c("X", "Y")], c(0, 0))
})

test_that("bipartite layout via caugi_layout with rows", {
  cg <- caugi(A %-->% X, A %-->% Y, B %-->% X, B %-->% Y)
  partition <- c(TRUE, TRUE, FALSE, FALSE)

  layout <- caugi_layout(
    cg,
    method = "bipartite",
    partition = partition,
    orientation = "rows"
  )

  expect_equal(nrow(layout), 4)
  # A and B should be at y=1 (top row)
  expect_equal(layout$y[layout$name %in% c("A", "B")], c(1, 1))
  # X and Y should be at y=0 (bottom row)
  expect_equal(layout$y[layout$name %in% c("X", "Y")], c(0, 0))
})

test_that("bipartite layout via caugi_layout with columns", {
  cg <- caugi(A %-->% X, A %-->% Y, B %-->% X, B %-->% Y)
  partition <- c(TRUE, TRUE, FALSE, FALSE)

  layout <- caugi_layout(
    cg,
    method = "bipartite",
    partition = partition,
    orientation = "columns"
  )

  expect_equal(nrow(layout), 4)
  # A and B should be at x=1 (right column)
  expect_equal(layout$x[layout$name %in% c("A", "B")], c(1, 1))
  # X and Y should be at x=0 (left column)
  expect_equal(layout$x[layout$name %in% c("X", "Y")], c(0, 0))
})

test_that("bipartite layout auto-detects partition", {
  cg <- caugi(A %-->% X, B %-->% X, C %-->% Y)

  # Should auto-detect: A, B, C have no incoming edges (partition = TRUE)
  # X, Y have incoming edges (partition = FALSE)
  layout <- caugi_layout_bipartite(cg, orientation = "rows")

  expect_equal(nrow(layout), 5)
  # A, B, C should be in top row (y=1)
  expect_equal(layout$y[layout$name %in% c("A", "B", "C")], c(1, 1, 1))
  # X, Y should be in bottom row (y=0)
  expect_equal(layout$y[layout$name %in% c("X", "Y")], c(0, 0))
})

test_that("bipartite layout works on chain graph with auto-detection", {
  cg <- caugi(A %-->% B, B %-->% C, C %-->% D)

  # A has no incoming edges (partition = TRUE), others do (partition = FALSE)
  layout <- caugi_layout_bipartite(cg, orientation = "rows")

  expect_equal(nrow(layout), 4)
  expect_equal(layout$y[layout$name == "A"], 1) # Top row
  # Bottom row
  expect_equal(layout$y[layout$name %in% c("B", "C", "D")], c(0, 0, 0))
})

test_that("partition must be logical", {
  cg <- caugi(A %-->% B)

  expect_error(
    caugi_layout_bipartite(cg, partition = c(1, 0)),
    "partition must be a logical vector"
  )
})

test_that("partition length must match node count", {
  cg <- caugi(A %-->% B, B %-->% C)

  expect_error(
    caugi_layout_bipartite(cg, partition = c(TRUE, FALSE)),
    "partition length.*does not match number of nodes"
  )
})

test_that("both partitions must be non-empty", {
  cg <- caugi(A %-->% B, B %-->% C)

  expect_error(
    caugi_layout(
      cg,
      method = "bipartite",
      partition = c(TRUE, TRUE, TRUE),
      orientation = "rows"
    ),
    "Both partitions must be non-empty"
  )
})

test_that("bipartite layout works with single node per partition", {
  cg <- caugi(A %-->% B)
  partition <- c(TRUE, FALSE)

  layout <- caugi_layout_bipartite(cg, partition, orientation = "rows")

  # Both nodes should be centered horizontally
  expect_equal(layout$x, c(0.5, 0.5))
  expect_equal(layout$y, c(1, 0))
})

test_that("bipartite layout handles uneven partitions", {
  cg <- caugi(A %-->% X, B %-->% X, C %-->% X)
  partition <- c(TRUE, TRUE, TRUE, FALSE)

  layout <- caugi_layout_bipartite(cg, partition, orientation = "rows")

  # Three nodes in top row
  expect_equal(sum(layout$y == 1), 3)
  # One node in bottom row
  expect_equal(sum(layout$y == 0), 1)
})

test_that("plot method accepts bipartite layout as string", {
  cg <- caugi(A %-->% X, B %-->% X)
  partition <- c(TRUE, TRUE, FALSE)

  expect_no_error({
    p <- plot(
      cg,
      layout = "bipartite",
      partition = partition,
      orientation = "rows"
    )
  })
})

test_that("plot method accepts bipartite layout as function", {
  cg <- caugi(A %-->% X, B %-->% X)
  partition <- c(TRUE, TRUE, FALSE)

  expect_no_error({
    p <- plot(
      cg,
      layout = caugi_layout_bipartite,
      partition = partition,
      orientation = "rows"
    )
  })
})

test_that("plot method accepts pre-computed layout data.frame", {
  cg <- caugi(A %-->% B, B %-->% C)
  coords <- caugi_layout_sugiyama(cg)

  expect_no_error({
    p <- plot(cg, layout = coords)
  })
})

test_that("plot method errors on invalid layout type", {
  cg <- caugi(A %-->% B)

  expect_error(
    plot(cg, layout = 123),
    "layout must be a character string, function, or data.frame"
  )
})

test_that("plot method errors on layout data.frame missing columns", {
  cg <- caugi(A %-->% B)

  # Missing 'y' column
  bad_coords1 <- data.frame(name = c("A", "B"), x = c(0, 1))
  expect_error(
    plot(cg, layout = bad_coords1),
    "Layout data.frame is missing required column: y"
  )

  # Missing 'x' and 'y' columns
  bad_coords2 <- data.frame(name = c("A", "B"))
  expect_error(
    plot(cg, layout = bad_coords2),
    "Layout data.frame is missing required columns: x, y"
  )

  # Missing 'name' column
  bad_coords3 <- data.frame(x = c(0, 1), y = c(0, 1))
  expect_error(
    plot(cg, layout = bad_coords3),
    "Layout data.frame is missing required column: name"
  )
})

test_that("plot method errors on non-numeric layout coordinates", {
  cg <- caugi(A %-->% B)

  # Non-numeric x
  bad_coords1 <- data.frame(name = c("A", "B"), x = c("0", "1"), y = c(0, 1))
  expect_error(
    plot(cg, layout = bad_coords1),
    "Layout column 'x' must be numeric"
  )

  # Non-numeric y
  bad_coords2 <- data.frame(name = c("A", "B"), x = c(0, 1), y = c("0", "1"))
  expect_error(
    plot(cg, layout = bad_coords2),
    "Layout column 'y' must be numeric"
  )
})

test_that("plot method errors on layout with NA/NaN/Inf values", {
  cg <- caugi(A %-->% B)

  # NA in x
  bad_coords1 <- data.frame(name = c("A", "B"), x = c(NA, 1), y = c(0, 1))
  expect_error(
    plot(cg, layout = bad_coords1),
    "Layout column 'x' contains NA, NaN, or infinite values"
  )

  # Inf in y
  bad_coords2 <- data.frame(name = c("A", "B"), x = c(0, 1), y = c(0, Inf))
  expect_error(
    plot(cg, layout = bad_coords2),
    "Layout column 'y' contains NA, NaN, or infinite values"
  )

  # NaN in x
  bad_coords3 <- data.frame(name = c("A", "B"), x = c(NaN, 1), y = c(0, 1))
  expect_error(
    plot(cg, layout = bad_coords3),
    "Layout column 'x' contains NA, NaN, or infinite values"
  )
})

test_that("plot method errors on layout with wrong number of nodes", {
  cg <- caugi(A %-->% B, B %-->% C)

  # Too few nodes
  bad_coords <- data.frame(name = c("A", "B"), x = c(0, 1), y = c(0, 1))
  expect_error(
    plot(cg, layout = bad_coords),
    "Layout has 2 rows but graph has 3 nodes"
  )
})

test_that("plot method errors on layout with missing node names", {
  cg <- caugi(A %-->% B, B %-->% C)

  # Missing node C, but has correct row count (due to extra node D)
  bad_coords <- data.frame(
    name = c("A", "B", "D"),
    x = c(0, 1, 2),
    y = c(0, 1, 2)
  )
  expect_error(
    plot(cg, layout = bad_coords),
    "Layout is missing coordinate for node: C"
  )
})

test_that("plot method errors on layout with extra node names", {
  cg <- caugi(A %-->% B)

  # Extra node Z - this will be caught by row count check first
  bad_coords <- data.frame(
    name = c("A", "B", "Z"),
    x = c(0, 1, 2),
    y = c(0, 1, 2)
  )
  expect_error(
    plot(cg, layout = bad_coords),
    "Layout has 3 rows but graph has 2 nodes"
  )

  # Extra node Z with correct row count - should catch unknown node
  bad_coords2 <- data.frame(name = c("Z", "B"), x = c(0, 1), y = c(0, 1))
  expect_error(
    plot(cg, layout = bad_coords2),
    "Layout is missing coordinate for node: A"
  )
})

test_that("bipartite auto-detect fails when all nodes have incoming edges", {
  # Graph where all nodes have incoming edges (cycle)
  cg <- caugi(A %-->% B, B %-->% C, C %-->% A)

  expect_error(
    caugi_layout_bipartite(cg),
    "Could not automatically detect bipartite structure"
  )
})

test_that("bipartite auto-detect fails when no nodes have incoming edges", {
  # Graph with isolated nodes (no edges at all)
  cg <- caugi(A + B + C)

  expect_error(
    caugi_layout_bipartite(cg),
    "Could not automatically detect bipartite structure"
  )
})
