library(testthat)

test_that("Identical graphs have Hamming distance 0", {
  g1 <- caugi_graph(
    "A" %-->% "B",
    "B" %<->% "C"
  )
  g2 <- caugi_graph(
    "A" %-->% "B",
    "B" %<->% "C"
  )

  # Hamming distance between identical graphs should be 0
  expect_equal(hd(g1, g2), 0)
})

test_that("Graphs differ in one edge", {
  g1 <- caugi_graph(
    "A" %-->% "B",
    "B" %<->% "C",
    "C" %<->% "C"
  )
  g2 <- caugi_graph(
    "A" %-->% "B",
    "C" %<->% "C"
  )

  # Hamming distance between graphs differing by one edge should be 1
  expect_equal(hd(g1, g2), 1)
})


test_that("Graphs differ in two edge", {
  g1 <- caugi_graph(
    "A" %-->% "B",
    "B" %<->% "C"
  )
  g2 <- caugi_graph(
    "A" %-->% "B",
    "C" %<->% "A"
  )

  # Hamming distance between graphs differing by one edge should be 2
  expect_equal(hd(g1, g2), 2)
})


test_that("Graphs differ in four edges", {
  g1 <- caugi_graph(
    "A" %-->% "D",
    "B" %<->% "C"
  )
  g2 <- caugi_graph(
    "A" %-->% "B",
    "C" %<->% "D"
  )
  # Hamming distance between graphs differing by two edges should be 4
  expect_equal(hd(g1, g2), 4)
})

test_that("Directed edges and undirected edges are handled correctly", {
  g1 <- caugi_graph(
    "A" %-->% "B",
    "B" %<->% "C"
  )
  g2 <- caugi_graph(
    "B" %-->% "A",
    "C" %<->% "B"
  )
  print(g1)
  print(g2)

  expect_equal(hd(g1, g2), 0)
})
