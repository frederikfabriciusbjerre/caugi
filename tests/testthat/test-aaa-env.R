# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── environment tests ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that(".edge_ops_get returns defaults when unset", {
  old <- as.list(.caugi_env)
  on.exit(
    {
      rm(list = ls(.caugi_env), envir = .caugi_env)
      list2env(old, envir = .caugi_env)
    },
    add = TRUE
  )

  if (exists("edge_ops", envir = .caugi_env)) {
    rm("edge_ops", envir = .caugi_env)
  }
  expect_identical(.edge_ops_get(), .caugi_defaults_edge_ops)
})

test_that(".glyph_map_get returns defaults when unset", {
  old <- as.list(.caugi_env)
  on.exit(
    {
      rm(list = ls(.caugi_env), envir = .caugi_env)
      list2env(old, envir = .caugi_env)
    },
    add = TRUE
  )

  if (exists("glyph_map", envir = .caugi_env)) {
    rm("glyph_map", envir = .caugi_env)
  }
  expect_identical(.glyph_map_get(), .caugi_defaults_glyph_map)
})

test_that("getters return user-set values from .caugi_env", {
  old <- as.list(.caugi_env)
  on.exit(
    {
      rm(list = ls(.caugi_env), envir = .caugi_env)
      list2env(old, envir = .caugi_env)
    },
    add = TRUE
  )

  custom_ops <- c("%<--%", "%o--%")
  assign("edge_ops", custom_ops, envir = .caugi_env)
  expect_identical(.edge_ops_get(), custom_ops)

  custom_map <- c("%<--%" = "<--", "%b%" = "o--")
  assign("glyph_map", custom_map, envir = .caugi_env)
  expect_identical(.glyph_map_get(), custom_map)
})

test_that("glyph map and edge ops default shapes are consistent", {
  # same length and named map covering ops
  expect_length(.caugi_defaults_glyph_map, length(.caugi_defaults_edge_ops))
  expect_true(all(
    names(.caugi_defaults_glyph_map) %in% .caugi_defaults_edge_ops
  ))
})
