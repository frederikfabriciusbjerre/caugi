test_that("normalize_latent_structure exogenizes latents (Lemma 1)", {
  dag <- caugi(
    A %-->% U,
    U %-->% X + Y,
    class = "DAG"
  )

  norm <- normalize_latent_structure(dag, latents = "U")

  expect_null(parents(norm, "U"))
  expect_setequal(children(norm, "A"), c("X", "Y"))

  admg1 <- latent_project(dag, latents = "U")
  admg2 <- latent_project(norm, latents = "U")
  expect_equal(shd(admg1, admg2), 0)
})

test_that("normalize_latent_structure removes singleton latents (Lemma 2)", {
  dag <- caugi(
    U %-->% X,
    class = "DAG"
  )

  norm <- normalize_latent_structure(dag, latents = "U")

  expect_false("U" %in% nodes(norm)$name)
  expect_setequal(nodes(norm)$name, "X")

  admg1 <- latent_project(dag, latents = "U")
  admg2 <- latent_project(norm, latents = character(0))
  expect_equal(shd(admg1, admg2), 0)
})

test_that("normalize_latent_structure drops latent with one child even if it has descendants", {
  dag <- caugi(
    U %-->% X,
    X %-->% Y,
    class = "DAG"
  )

  norm <- normalize_latent_structure(dag, latents = "U")

  expect_false("U" %in% nodes(norm)$name)
  expect_setequal(nodes(norm)$name, c("X", "Y"))
  expect_equal(children(norm, "X"), "Y")

  admg1 <- latent_project(dag, latents = "U")
  admg2 <- latent_project(norm, latents = character(0))
  expect_equal(shd(admg1, admg2), 0)
})

test_that("normalize_latent_structure removes nested latents (Lemma 3.8)", {
  dag <- caugi(
    U %-->% X + Y + Z,
    W %-->% X + Y,
    class = "DAG"
  )

  norm <- normalize_latent_structure(dag, latents = c("U", "W"))

  expect_true("U" %in% nodes(norm)$name)
  expect_false("W" %in% nodes(norm)$name)

  admg1 <- latent_project(dag, latents = c("U", "W"))
  admg2 <- latent_project(norm, latents = "U")
  expect_equal(shd(admg1, admg2), 0)
})

test_that("normalize_latent_structure does not change overlapping but non-nested latents", {
  dag <- caugi(
    U1 %-->% A + B + C,
    U2 %-->% B + D,
    class = "DAG"
  )

  norm <- normalize_latent_structure(dag, latents = c("U1", "U2"))

  expect_equal(shd(dag, norm), 0)
  expect_setequal(nodes(norm)$name, c("U1", "U2", "A", "B", "C", "D"))
})

test_that("normalize_latent_structure is idempotent", {
  dag <- caugi(
    A %-->% U,
    U %-->% X + Y,
    V %-->% X + Y,
    class = "DAG"
  )

  norm1 <- normalize_latent_structure(dag, latents = c("U", "V"))
  norm2 <- normalize_latent_structure(norm1, latents = c("U", "V"))

  expect_setequal(nodes(norm1)$name, nodes(norm2)$name)
  expect_equal(shd(norm1, norm2), 0)
})

test_that("normalize_latent_structure validation and loop branches are covered", {
  cg_pdag <- caugi(A %---% B, class = "PDAG")
  expect_error(
    normalize_latent_structure(cg_pdag, latents = "A"),
    "normalize_latent_structure\\(\\) can only be applied to DAGs\\."
  )

  cg <- caugi(U, A %-->% B, class = "DAG")
  expect_error(
    normalize_latent_structure(cg, latents = 1),
    "`latents` must be a character vector of node names."
  )

  expect_identical(normalize_latent_structure(cg, latents = character(0)), cg)

  expect_error(
    normalize_latent_structure(cg, latents = "Z"),
    "Unknown latent node\\(s\\): Z"
  )

  # Latent with no children exercises the NULL->0 branch.
  out_no_children <- normalize_latent_structure(cg, latents = "U")
  expect_false("U" %in% out_no_children@nodes$name)

  # Nested child set branch (drop_one <- current_latents[i]).
  dag_nested <- caugi(
    U1 %-->% X + Y,
    U2 %-->% X + Y + Z,
    X %-->% W,
    class = "DAG"
  )
  out_nested <- normalize_latent_structure(dag_nested, latents = c("U1", "U2"))
  expect_false(
    "U1" %in% out_nested@nodes$name && "U2" %in% out_nested@nodes$name
  )

  # Force child_sets NULL branch in Lemma 2 (coverage for character(0) path).
  dag_mock <- caugi(
    U1 %-->% X + Y,
    U2 %-->% X + Y,
    class = "DAG"
  )
  normalize_for_null_children <- normalize_latent_structure
  environment(normalize_for_null_children) <- list2env(
    list(
      vapply = function(X, FUN, FUN.VALUE, ..., USE.NAMES = TRUE) {
        rep.int(2L, length(X))
      },
      children = function(cg, l) NULL
    ),
    parent = environment(normalize_latent_structure)
  )
  expect_silent(
    normalize_for_null_children(dag_mock, latents = c("U1", "U2"))
  )
})
