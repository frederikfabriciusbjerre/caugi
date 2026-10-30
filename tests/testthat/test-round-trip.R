# caugi -> format -> caugi for every exporter with a matching importer, using
# every built-in glyph the format can hold.

# Edges as sorted "from edge to" strings, symmetric edges in node order.
edge_key <- function(cg) {
  e <- as.data.frame(edges(cg))
  sym <- e$edge %in% c("---", "<->", "o-o")
  from <- ifelse(sym, pmin(e$from, e$to), e$from)
  to <- ifelse(sym, pmax(e$from, e$to), e$to)
  sort(paste(from, e$edge, to))
}

expect_round_trip <- function(cg, back) {
  expect_setequal(nodes(back)$name, nodes(cg)$name)
  expect_identical(edge_key(back), edge_key(cg))
}

all_glyphs <- caugi(
  A %-->% B,
  B %---% C,
  C %<->% D,
  D %o->% E,
  E %--o% F,
  F %o-o% G,
  H,
  class = "UNKNOWN"
)
pdag <- caugi(A %-->% B, B %---% C, D, class = "PDAG")
dag <- caugi(A %-->% B, B %-->% C, D, class = "DAG")

test_that("JSON round-trips every built-in glyph", {
  expect_round_trip(all_glyphs, caugi_deserialize(caugi_serialize(all_glyphs)))
})

test_that("GraphML round-trips every built-in glyph", {
  f <- withr::local_tempfile(fileext = ".graphml")
  write_graphml(all_glyphs, f)
  expect_round_trip(all_glyphs, read_graphml(f))
})

test_that("data.frame round-trips every built-in glyph", {
  expect_round_trip(all_glyphs, as_caugi(as.data.frame(all_glyphs)))
})

test_that("dagitty round-trips every built-in glyph", {
  skip_if_not_installed("dagitty")
  back <- as_caugi(as_dagitty(all_glyphs), class = "UNKNOWN")
  expect_round_trip(all_glyphs, back)
})

# igraph writes both `---` and `<->` as two directed edges, so only one
# symmetric glyph can come back, via `collapse`.
test_that("igraph round-trips --> and ---", {
  skip_if_not_installed("igraph")
  back <- as_caugi(as_igraph(pdag), class = "PDAG", collapse = TRUE)
  expect_round_trip(pdag, back)
})

test_that("adjacency matrix round-trips --> and ---", {
  back <- as_caugi(as_adjacency(pdag), class = "PDAG", collapse = TRUE)
  expect_round_trip(pdag, back)
})

test_that("bnlearn round-trips a DAG", {
  skip_if_not_installed("bnlearn")
  expect_round_trip(dag, as_caugi(as_bnlearn(dag), class = "DAG"))
})
