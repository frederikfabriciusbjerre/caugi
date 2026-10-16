test_that("m-separation in dag_to_pag() matches d-separation in the DAG", {
  dag <- caugi(
    U %-->% X + Y,
    X %-->% M,
    M %-->% Y,
    W %-->% X,
    class = "DAG"
  )
  pag <- dag_to_pag(dag, latents = "U")
  obs <- nodes(pag)$name

  for (x in obs) {
    for (y in setdiff(obs, x)) {
      rest <- setdiff(obs, c(x, y))
      for (k in 0:length(rest)) {
        for (z in utils::combn(rest, k, simplify = FALSE)) {
          expect_identical(
            m_separated(pag, x, y, z),
            d_separated(dag, x, y, z),
            label = paste(x, y, paste(z, collapse = ","))
          )
        }
      }
    }
  }
})

test_that("minimal_separator() on a PAG returns a minimal m-separator", {
  pag <- caugi(A %o->% B, C %o->% B, B %-->% D, class = "PAG")
  z <- minimal_separator(pag, "A", "D")
  expect_identical(z, "B")
  expect_true(m_separated(pag, "A", "D", z))
  expect_false(m_separated(pag, "A", "D"))
  expect_null(minimal_separator(pag, "A", "B"))
})
