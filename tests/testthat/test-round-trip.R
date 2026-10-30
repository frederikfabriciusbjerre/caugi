# caugi -> format -> caugi for every exporter with a matching importer. Each
# conversion gets 100 random graphs of every class it can hold, each with at
# least 100 edges, isolated nodes and awkward node names, and what comes back
# must be `==` to what went in.

.rt_glyphs <- c("-->", "---", "<->", "o->", "--o", "o-o")

.rt_names <- function(n) {
  stem <- sample(
    c("x", "a b", "x.y", "q'", "q\"", "<&>", "\u00e6\u00f8", "1"),
    n,
    TRUE
  )
  paste0(stem, "_", seq_len(n))
}

# `m` distinct pairs of `nm`, each ordered along one random order, so as
# directed edges they form a DAG.
.rt_pairs <- function(nm, m) {
  pairs <- utils::combn(length(nm), 2)
  pick <- pairs[, sample(ncol(pairs), m), drop = FALSE]
  ord <- sample(nm)
  list(from = ord[pick[1, ]], to = ord[pick[2, ]])
}

# A random graph of `class` with 25 connected nodes, at least 100 edges and
# seven more nodes: isolated, except that an AG joins four of them by `---`.
# "UNKNOWN+" is UNKNOWN with self-loops and parallel edges added.
.rt_graph <- function(class) {
  nm <- .rt_names(32)
  core <- nm[1:25]
  e <- .rt_pairs(core, sample(100:140, 1))
  edge <- rep("-->", length(e$from))
  build <- function(from, edge, to, cls) {
    caugi(from = from, edge = edge, to = to, nodes = nm, class = cls)
  }
  dag <- build(e$from, edge, e$to, "DAG")
  cpdag <- .session_to_caugi(
    rs_to_cpdag(dag@session),
    node_names = nodes(dag)$name
  )

  switch(
    class,
    DAG = dag,
    CPDAG = cpdag,
    PDAG = {
      edge[stats::runif(length(edge)) < 0.3] <- "---"
      build(e$from, edge, e$to, "PDAG")
    },
    MPDAG = {
      # The CPDAG plus some of the DAG's own orientations, closed under Meek.
      ce <- edges(cpdag)
      orient <- ce$edge == "---" & stats::runif(nrow(ce)) < 0.5
      back <- !paste(ce$from, ce$to) %in% paste(e$from, e$to)
      from <- ifelse(orient & back, ce$to, ce$from)
      to <- ifelse(orient & back, ce$from, ce$to)
      ed <- ifelse(orient, "-->", ce$edge)
      mutate_caugi(meek_closure(build(from, ed, to, "PDAG")), "MPDAG")
    },
    UG = build(e$from, rep("---", length(edge)), e$to, "UG"),
    ADMG = {
      # Bidirected edges anywhere, so some pairs get a bow.
      b <- .rt_pairs(core, 30)
      build(
        c(e$from, b$from),
        c(edge, rep("<->", 30)),
        c(e$to, b$to),
        "ADMG"
      )
    },
    AG = {
      # `<->` only between non-adjacent pairs where neither is an ancestor of
      # the other, and `---` only among nodes with no parents or spouses.
      anc <- ancestors(dag, core)
      p <- .rt_pairs(core, choose(25, 2))
      adjacent <- paste(p$from, p$to) %in%
        c(
          paste(e$from, e$to),
          paste(e$to, e$from)
        )
      related <- mapply(
        function(a, b) a %in% anc[[b]] || b %in% anc[[a]],
        p$from,
        p$to
      )
      keep <- utils::head(which(!adjacent & !related), 20)
      sel <- nm[26:29]
      s <- utils::combn(sel, 2)
      kids <- sample(core, 8)
      build(
        c(e$from, p$from[keep], s[1, ], rep(sel, 2)),
        c(edge, rep("<->", length(keep)), rep("---", ncol(s)), rep("-->", 8)),
        c(e$to, p$to[keep], s[2, ], kids),
        "AG"
      )
    },
    UNKNOWN = build(
      e$from,
      sample(.rt_glyphs, length(edge), TRUE),
      e$to,
      "UNKNOWN"
    ),
    "UNKNOWN+" = {
      # Five self-loops, and a second edge with another glyph on five pairs.
      g <- sample(.rt_glyphs, length(edge), TRUE)
      loops <- sample(core, 5)
      twice <- 1:5
      build(
        c(e$from, loops, e$from[twice]),
        c(
          g,
          sample(.rt_glyphs, 5, TRUE),
          ifelse(g[twice] == "-->", "<->", "-->")
        ),
        c(e$to, loops, e$to[twice]),
        "UNKNOWN"
      )
    }
  )
}

# 100 graphs per class, drawn once and shared by every conversion.
.rt_graphs <- local({
  cache <- list()
  function(class) {
    if (is.null(cache[[class]])) {
      cache[[class]] <<- withr::with_seed(
        sum(utf8ToInt(class)),
        lapply(1:100, function(i) .rt_graph(class))
      )
    }
    cache[[class]]
  }
})

.rt_check <- function(convert, classes) {
  for (class in classes) {
    graphs <- .rt_graphs(class)
    changed <- which(!vapply(graphs, function(cg) cg == convert(cg), TRUE))
    expect_identical(changed, integer(0), info = class)
  }
}

.rt_all <- c("DAG", "PDAG", "CPDAG", "MPDAG", "UG", "ADMG", "AG", "UNKNOWN")
.rt_directed_undirected <- c("DAG", "PDAG", "CPDAG", "MPDAG", "UG")

test_that("random graphs round-trip through JSON", {
  skip_on_cran()
  .rt_check(
    function(cg) caugi_deserialize(caugi_serialize(cg)),
    c(.rt_all, "UNKNOWN+")
  )
})

test_that("random graphs round-trip through GraphML", {
  skip_on_cran()
  f <- withr::local_tempfile(fileext = ".graphml")
  .rt_check(
    function(cg) {
      write_graphml(cg, f)
      read_graphml(f)
    },
    c(.rt_all, "UNKNOWN+")
  )
})

test_that("random graphs round-trip through a data.frame", {
  skip_on_cran()
  .rt_check(function(cg) as_caugi(as.data.frame(cg)), c(.rt_all, "UNKNOWN+"))
})

test_that("random graphs round-trip through dagitty", {
  skip_on_cran()
  skip_if_not_installed("dagitty")
  .rt_check(
    function(cg) as_caugi(as_dagitty(cg), class = cg@graph_class),
    .rt_all
  )
})

# igraph and the 0/1 adjacency matrix write `---` as two directed edges, so
# only graphs of `-->` and `---` come back, via `collapse`.
test_that("random graphs round-trip through igraph", {
  skip_on_cran()
  skip_if_not_installed("igraph")
  .rt_check(
    function(cg) {
      as_caugi(as_igraph(cg), class = cg@graph_class, collapse = TRUE)
    },
    .rt_directed_undirected
  )
})

test_that("random graphs round-trip through an adjacency matrix", {
  skip_on_cran()
  .rt_check(
    function(cg) {
      as_caugi(as_adjacency(cg), class = cg@graph_class, collapse = TRUE)
    },
    .rt_directed_undirected
  )
})

test_that("random DAGs round-trip through bnlearn", {
  skip_on_cran()
  skip_if_not_installed("bnlearn")
  .rt_check(function(cg) as_caugi(as_bnlearn(cg), class = "DAG"), "DAG")
})
