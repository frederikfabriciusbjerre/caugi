# Snapshots of the text exporters, so any change to their output shows up in
# review. Update with `testthat::snapshot_accept("export-snapshots")`.

# expect_snapshot() needs the 3rd edition; the rest of the suite uses the 2nd.
testthat::local_edition(3)

snapshot_graph <- caugi(
  A %-->% B,
  B %---% C,
  C %<->% D,
  "my var" %o->% A,
  E,
  class = "UNKNOWN"
)

test_that("to_dot() output", {
  expect_snapshot(cat(as.character(to_dot(snapshot_graph))))
})

test_that("to_mermaid() output", {
  expect_snapshot(cat(as.character(to_mermaid(snapshot_graph))))
})

test_that("to_graphml() output", {
  expect_snapshot(cat(as.character(to_graphml(snapshot_graph))))
})

test_that("caugi_serialize() output", {
  expect_snapshot(cat(caugi_serialize(
    snapshot_graph,
    comment = "c",
    tags = "t"
  )))
})
