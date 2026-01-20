test_that("tiered layout with rows orientation works", {
  cg <- caugi(
    X1 %-->% M1 + M2,
    X2 %-->% M1 + M2,
    M1 %-->% Y,
    M2 %-->% Y
  )

  # Named list format
  tiers <- list(
    exposures = c("X1", "X2"),
    mediators = c("M1", "M2"),
    outcome = "Y"
  )

  layout <- caugi_layout_tiered(cg, tiers, orientation = "rows")

  expect_equal(nrow(layout), 5)
  expect_equal(layout$name, c("X1", "X2", "M1", "M2", "Y"))

  # X1 and X2 should be at y=1 (top tier)
  expect_equal(layout$y[layout$name %in% c("X1", "X2")], c(1, 1))

  # M1 and M2 should be at y=0.5 (middle tier)
  expect_equal(layout$y[layout$name %in% c("M1", "M2")], c(0.5, 0.5))

  # Y should be at y=0 (bottom tier)
  expect_equal(layout$y[layout$name == "Y"], 0)
})

test_that("tiered layout with columns orientation works", {
  cg <- caugi(
    X1 %-->% M1 + M2,
    X2 %-->% M1 + M2,
    M1 %-->% Y,
    M2 %-->% Y
  )

  tiers <- list(c("X1", "X2"), c("M1", "M2"), "Y")

  layout <- caugi_layout_tiered(cg, tiers, orientation = "columns")

  expect_equal(nrow(layout), 5)
  expect_equal(layout$name, c("X1", "X2", "M1", "M2", "Y"))

  # X1 and X2 should be at x=0 (left tier)
  expect_equal(layout$x[layout$name %in% c("X1", "X2")], c(0, 0))

  # M1 and M2 should be at x=0.5 (middle tier)
  expect_equal(layout$x[layout$name %in% c("M1", "M2")], c(0.5, 0.5))

  # Y should be at x=1 (right tier)
  expect_equal(layout$x[layout$name == "Y"], 1)
})

test_that("tiered layout with named numeric vector works", {
  cg <- caugi(A %-->% B, B %-->% C, C %-->% D)

  # 0-indexed
  tiers <- c(A = 0, B = 1, C = 2, D = 3)
  layout <- caugi_layout_tiered(cg, tiers, orientation = "rows")

  expect_equal(nrow(layout), 4)
  expect_equal(layout$y[layout$name == "A"], 1)
  expect_equal(layout$y[layout$name == "D"], 0)

  # 1-indexed (should be normalized to 0-indexed)
  tiers <- c(A = 1, B = 2, C = 3, D = 4)
  layout <- caugi_layout_tiered(cg, tiers, orientation = "rows")

  expect_equal(nrow(layout), 4)
  expect_equal(layout$y[layout$name == "A"], 1)
  expect_equal(layout$y[layout$name == "D"], 0)
})

test_that("tiered layout with data.frame works", {
  cg <- caugi(A %-->% B, B %-->% C)

  tiers <- data.frame(
    name = c("A", "B", "C"),
    tier = c(0, 1, 2)
  )

  layout <- caugi_layout_tiered(cg, tiers, orientation = "rows")

  expect_equal(nrow(layout), 3)
  expect_equal(layout$y[layout$name == "A"], 1)
  expect_equal(layout$y[layout$name == "B"], 0.5)
  expect_equal(layout$y[layout$name == "C"], 0)
})

test_that("tiered layout via caugi_layout with rows", {
  cg <- caugi(A %-->% B, B %-->% C)
  tiers <- list(c("A"), c("B"), c("C"))

  layout <- caugi_layout(
    cg,
    method = "tiered",
    tiers = tiers,
    orientation = "rows"
  )

  expect_equal(nrow(layout), 3)
  expect_equal(layout$y[layout$name == "A"], 1)
  expect_equal(layout$y[layout$name == "C"], 0)
})

test_that("tiered layout via caugi_layout with columns", {
  cg <- caugi(A %-->% B, B %-->% C)
  tiers <- c(A = 0, B = 1, C = 2)

  layout <- caugi_layout(
    cg,
    method = "tiered",
    tiers = tiers,
    orientation = "columns"
  )

  expect_equal(nrow(layout), 3)
  expect_equal(layout$x[layout$name == "A"], 0)
  expect_equal(layout$x[layout$name == "C"], 1)
})

test_that("tiered layout works with two tiers", {
  cg <- caugi(A %-->% X, B %-->% X, C %-->% Y)

  tiers <- list(c("A", "B", "C"), c("X", "Y"))

  layout <- caugi_layout_tiered(cg, tiers, orientation = "rows")

  expect_equal(nrow(layout), 5)
  # First tier should be at y=1
  expect_equal(layout$y[layout$name %in% c("A", "B", "C")], c(1, 1, 1))
  # Second tier should be at y=0
  expect_equal(layout$y[layout$name %in% c("X", "Y")], c(0, 0))
})

test_that("tiered layout works with single node per tier", {
  cg <- caugi(A %-->% B, B %-->% C)
  tiers <- list("A", "B", "C")

  layout <- caugi_layout_tiered(cg, tiers, orientation = "rows")

  # All nodes should be centered horizontally
  expect_equal(layout$x, c(0.5, 0.5, 0.5))
  expect_equal(layout$y, c(1, 0.5, 0))
})

test_that("tiered layout handles uneven tier sizes", {
  cg <- caugi(A %-->% X, B %-->% X, C %-->% X)
  tiers <- list(c("A", "B", "C"), "X")

  layout <- caugi_layout_tiered(cg, tiers, orientation = "rows")

  # Three nodes in top tier should be evenly spaced
  top_tier <- layout[layout$name %in% c("A", "B", "C"), ]
  expect_equal(sort(top_tier$x), c(0, 0.5, 1))
  expect_equal(unique(top_tier$y), 1)

  # One node in bottom tier should be centered
  bottom_tier <- layout[layout$name == "X", ]
  expect_equal(bottom_tier$x, 0.5)
  expect_equal(bottom_tier$y, 0)
})

test_that("tiers must be provided", {
  cg <- caugi(A %-->% B)

  expect_error(
    caugi_layout_tiered(cg),
    "argument \"tiers\" is missing"
  )
})

test_that("tiers must be correct format", {
  cg <- caugi(A %-->% B)

  expect_error(
    caugi_layout_tiered(cg, tiers = "invalid"),
    "tiers must be a named list, named numeric vector, or data.frame"
  )

  expect_error(
    caugi_layout_tiered(cg, tiers = c(1, 2)),
    "tiers must be a named list, named numeric vector, or data.frame"
  )
})

test_that("tier assignments must cover all nodes", {
  cg <- caugi(A %-->% B, B %-->% C)

  # Missing node C
  tiers <- c(A = 0, B = 1)

  expect_error(
    caugi_layout_tiered(cg, tiers),
    "Missing tier assignments for nodes: C"
  )
})

test_that("nodes in tiers must exist in graph", {
  cg <- caugi(A %-->% B)

  # Node Z doesn't exist
  tiers <- list(c("A", "Z"), "B")

  expect_error(
    caugi_layout_tiered(cg, tiers),
    "Node 'Z' in tier 1 is not in the graph"
  )
})

test_that("tier indices must be non-negative", {
  cg <- caugi(A %-->% B)

  tiers <- c(A = -1, B = 0)

  expect_error(
    caugi_layout_tiered(cg, tiers),
    "Tier indices must be non-negative"
  )
})

test_that("tier indices must be consecutive", {
  cg <- caugi(A %-->% B, B %-->% C)

  # Gap: tiers 0, 1, 3 (missing 2)
  tiers <- c(A = 0, B = 1, C = 3)

  expect_error(
    caugi_layout_tiered(cg, tiers),
    "Tier indices must be consecutive"
  )
})

test_that("data.frame must have correct columns", {
  cg <- caugi(A %-->% B)

  # Missing 'tier' column
  tiers <- data.frame(name = c("A", "B"), x = c(0, 1))

  expect_error(
    caugi_layout_tiered(cg, tiers),
    "Data.frame must have columns 'name' and 'tier'"
  )
})

test_that("each tier element must be character vector", {
  cg <- caugi(A %-->% B)

  # Tier element is numeric
  tiers <- list(c(1, 2), "B")

  expect_error(
    caugi_layout_tiered(cg, tiers),
    "Each tier in the list must be a character vector"
  )
})

test_that("plot method accepts tiered layout as string", {
  cg <- caugi(A %-->% B, B %-->% C)
  tiers <- list("A", "B", "C")

  expect_no_error({
    p <- plot(
      cg,
      layout = "tiered",
      tiers = tiers,
      orientation = "rows"
    )
  })
})

test_that("plot method accepts tiered layout as function", {
  cg <- caugi(A %-->% B, B %-->% C)
  tiers <- c(A = 0, B = 1, C = 2)

  expect_no_error({
    p <- plot(
      cg,
      layout = caugi_layout_tiered,
      tiers = tiers,
      orientation = "columns"
    )
  })
})

test_that("tiered layout returns correct structure", {
  cg <- caugi(A %-->% B)
  tiers <- list("A", "B")

  layout <- caugi_layout_tiered(cg, tiers)

  # Check structure
  expect_s3_class(layout, "data.frame")
  expect_named(layout, c("name", "x", "y", "tier"))
  expect_type(layout$name, "character")
  expect_type(layout$x, "double")
  expect_type(layout$y, "double")
  expect_type(layout$tier, "integer")

  # Check coordinates are in [0, 1]
  expect_true(all(layout$x >= 0 & layout$x <= 1))
  expect_true(all(layout$y >= 0 & layout$y <= 1))

  # Check at least one coordinate is 1.0
  expect_true(any(abs(c(layout$x, layout$y) - 1.0) < 1e-10))

  # Check orientation attribute
  expect_equal(attr(layout, "orientation"), "columns")
})

test_that("tiered layout is deterministic", {
  cg <- caugi(A %-->% B, B %-->% C)
  tiers <- list(c("A"), c("B"), c("C"))

  layout1 <- caugi_layout_tiered(cg, tiers, orientation = "rows")
  layout2 <- caugi_layout_tiered(cg, tiers, orientation = "rows")

  expect_equal(layout1, layout2)
})

test_that("tiered layout works with complex graph", {
  cg <- caugi(
    A %-->% D + E,
    B %-->% D + E + F,
    C %-->% E + F,
    D %-->% G,
    E %-->% G + H,
    F %-->% H
  )

  tiers <- list(
    tier1 = c("A", "B", "C"),
    tier2 = c("D", "E", "F"),
    tier3 = c("G", "H")
  )

  layout <- caugi_layout_tiered(cg, tiers, orientation = "rows")

  expect_equal(nrow(layout), 8)

  # Check tier positions
  tier1_nodes <- layout[layout$name %in% c("A", "B", "C"), ]
  tier2_nodes <- layout[layout$name %in% c("D", "E", "F"), ]
  tier3_nodes <- layout[layout$name %in% c("G", "H"), ]

  expect_equal(unique(tier1_nodes$y), 1)
  expect_equal(unique(tier2_nodes$y), 0.5)
  expect_equal(unique(tier3_nodes$y), 0)

  # Check nodes are evenly spaced within tiers
  expect_equal(sort(tier1_nodes$x), c(0, 0.5, 1))
  expect_equal(sort(tier2_nodes$x), c(0, 0.5, 1))
  expect_equal(sort(tier3_nodes$x), c(0, 1))
})

test_that("tiered layout works with four tiers", {
  cg <- caugi(A %-->% B, B %-->% C, C %-->% D, D %-->% E)
  tiers <- list("A", "B", "C", "D", "E")

  layout <- caugi_layout_tiered(cg, tiers, orientation = "rows")

  expect_equal(nrow(layout), 5)

  # Check y coordinates are evenly distributed
  expect_equal(layout$y[layout$name == "A"], 1)
  expect_equal(layout$y[layout$name == "B"], 0.75)
  expect_equal(layout$y[layout$name == "C"], 0.5)
  expect_equal(layout$y[layout$name == "D"], 0.25)
  expect_equal(layout$y[layout$name == "E"], 0)
})

test_that("auto layout selects tiered when tiers provided", {
  cg <- caugi(X1 %-->% M1, X2 %-->% M2, M1 %-->% Y, M2 %-->% Y)
  tiers <- list(c("X1", "X2"), c("M1", "M2"), "Y")

  # method = "auto" (default) should select tiered
  layout_auto <- caugi_layout(cg, tiers = tiers, orientation = "rows")
  layout_explicit <- caugi_layout(
    cg,
    method = "tiered",
    tiers = tiers,
    orientation = "rows"
  )

  # Should produce identical results
  expect_equal(layout_auto, layout_explicit)
})

test_that("auto layout selects bipartite when partition provided", {
  cg <- caugi(A %-->% X, B %-->% Y)
  partition <- c(TRUE, TRUE, FALSE, FALSE)

  # method = "auto" should select bipartite
  layout_auto <- caugi_layout(cg, partition = partition, orientation = "rows")
  layout_explicit <- caugi_layout(
    cg,
    method = "bipartite",
    partition = partition,
    orientation = "rows"
  )

  # Should produce identical results
  expect_equal(layout_auto, layout_explicit)
})

test_that("auto layout prefers tiers over partition if both provided", {
  cg <- caugi(A %-->% B, B %-->% C)
  tiers <- list("A", "B", "C")
  partition <- c(TRUE, FALSE, FALSE)

  # When both are provided, tiers should win
  # Note: partition will be passed to tiered layout but ignored (not an error)
  layout <- caugi_layout(cg, tiers = tiers, orientation = "rows")

  # Should use tiered layout (3 distinct y values)
  expect_equal(length(unique(layout$y)), 3)
  expect_equal(layout$y[layout$name == "A"], 1)
  expect_equal(layout$y[layout$name == "B"], 0.5)
  expect_equal(layout$y[layout$name == "C"], 0)
})

test_that("tier boxes can be drawn", {
  cg <- caugi(A %-->% B, B %-->% C)
  tiers <- list("A", "B", "C")

  expect_no_error({
    p <- plot(cg, tiers = tiers, tier_style = list(boxes = TRUE))
  })
})

test_that("tier boxes work with vector colors", {
  cg <- caugi(X1 %-->% M1, X2 %-->% M2, M1 %-->% Y, M2 %-->% Y)
  tiers <- list(c("X1", "X2"), c("M1", "M2"), "Y")

  expect_no_error({
    p <- plot(
      cg,
      tiers = tiers,
      tier_style = list(
        boxes = TRUE,
        fill = c("lightblue", "lightgreen", "lightyellow"),
        col = "gray50"
      )
    )
  })
})

test_that("tier boxes work with by_tier named overrides", {
  cg <- caugi(X1 %-->% M1 + M2, X2 %-->% M1 + M2, M1 %-->% Y, M2 %-->% Y)
  tiers <- list(
    exposures = c("X1", "X2"),
    mediators = c("M1", "M2"),
    outcome = "Y"
  )

  expect_no_error({
    p <- plot(
      cg,
      tiers = tiers,
      tier_style = list(
        boxes = TRUE,
        fill = "gray95",
        by_tier = list(
          exposures = list(fill = "lightblue"),
          outcome = list(fill = "lightyellow", lwd = 3)
        )
      )
    )
  })
})

test_that("tier boxes work with by_tier numeric indices", {
  cg <- caugi(A %-->% B, B %-->% C)
  tiers <- list("A", "B", "C")

  expect_no_error({
    p <- plot(
      cg,
      tiers = tiers,
      tier_style = list(
        boxes = TRUE,
        by_tier = list(
          `1` = list(fill = "lightblue"),
          `3` = list(fill = "lightyellow")
        )
      )
    )
  })
})

test_that("tier boxes default to FALSE", {
  cg <- caugi(A %-->% B, B %-->% C)
  tiers <- list("A", "B", "C")

  # Should not error even if tier_style provided but boxes = FALSE
  expect_no_error({
    p <- plot(cg, tiers = tiers, tier_style = list(fill = "red"))
  })
})

test_that("tier labels work with tier names", {
  cg <- caugi(X1 %-->% M1, X2 %-->% M2, M1 %-->% Y, M2 %-->% Y)
  tiers <- list(
    Exposures = c("X1", "X2"),
    Mediators = c("M1", "M2"),
    Outcome = "Y"
  )

  expect_no_error({
    p <- plot(
      cg,
      tiers = tiers,
      tier_style = list(
        boxes = TRUE,
        labels = TRUE
      )
    )
  })
})

test_that("tier labels work with custom labels", {
  cg <- caugi(A %-->% B, B %-->% C)
  tiers <- list("A", "B", "C")

  expect_no_error({
    p <- plot(
      cg,
      tiers = tiers,
      tier_style = list(
        boxes = TRUE,
        labels = c("First", "Second", "Third")
      )
    )
  })
})

test_that("tier labels work without labels", {
  cg <- caugi(A %-->% B, B %-->% C)
  tiers <- list("A", "B", "C")

  # Should work fine with labels = NULL or FALSE
  expect_no_error({
    p1 <- plot(cg, tiers = tiers, tier_style = list(boxes = TRUE))
    p2 <- plot(
      cg,
      tiers = tiers,
      tier_style = list(boxes = TRUE, labels = FALSE)
    )
  })
})

test_that("tier label styling works", {
  cg <- caugi(A %-->% B, B %-->% C)
  tiers <- list(First = "A", Second = "B", Third = "C")

  expect_no_error({
    p <- plot(
      cg,
      tiers = tiers,
      tier_style = list(
        boxes = TRUE,
        labels = TRUE,
        label_style = list(
          fontsize = 12,
          fontface = "italic",
          col = "blue"
        )
      )
    )
  })
})

test_that("plot extracts tier info from layout data.frame", {
  cg <- caugi(X1 %-->% M1 + M2, X2 %-->% M1 + M2, M1 %-->% Y, M2 %-->% Y)
  tiers <- list(
    exposures = c("X1", "X2"),
    mediators = c("M1", "M2"),
    outcome = "Y"
  )

  # Create layout with tier column
  layout_df <- caugi_layout_tiered(cg, tiers, orientation = "rows")

  # Should work without passing tiers again
  expect_no_error({
    p <- plot(
      cg,
      layout = layout_df,
      tier_style = list(boxes = TRUE, labels = TRUE)
    )
  })
})

test_that("explicit tiers override tier column in layout", {
  cg <- caugi(A %-->% B, B %-->% C)

  # Create layout with tier column
  tiers1 <- list("A", "B", "C")
  layout_df <- caugi_layout_tiered(cg, tiers1, orientation = "rows")

  # Pass different tiers to plot - should use the explicit ones
  tiers2 <- list(c("A", "B"), "C")

  expect_no_error({
    p <- plot(
      cg,
      layout = layout_df,
      tiers = tiers2,
      tier_style = list(boxes = TRUE)
    )
  })
})

test_that("boxes = FALSE does not draw boxes", {
  cg <- caugi(A %-->% B, B %-->% C)
  tiers <- list("A", "B", "C")

  # boxes = FALSE should not draw tier boxes
  expect_no_error({
    p <- plot(
      cg,
      tiers = tiers,
      tier_style = list(boxes = FALSE, labels = FALSE)
    )
  })

  # boxes = FALSE with labels = TRUE should only draw labels
  expect_no_error({
    p <- plot(
      cg,
      tiers = tiers,
      tier_style = list(boxes = FALSE, labels = TRUE)
    )
  })
})

test_that("labels = FALSE does not draw labels", {
  cg <- caugi(A %-->% B, B %-->% C)
  tiers <- list(First = "A", Second = "B", Third = "C")

  # labels = FALSE should not draw tier labels
  expect_no_error({
    p <- plot(
      cg,
      tiers = tiers,
      tier_style = list(boxes = TRUE, labels = FALSE)
    )
  })

  # Both FALSE should work
  expect_no_error({
    p <- plot(
      cg,
      tiers = tiers,
      tier_style = list(boxes = FALSE, labels = FALSE)
    )
  })
})
