# `dag_to_pag()` against `pcalg::dag2pag`.
#
# pcalg derives the PAG of a DAG-with-latents by running FCI against a perfect
# conditional-independence oracle. caugi gets there structurally instead:
# marginalize the latents to a MAG, then apply Zhang's orientation rules. The
# two routes share no code, so agreement exercises the whole pipeline --
# `condition_marginalize()`, `mag_to_pag()`, and R1-R10 -- against an
# independent implementation, over graphs far larger and denser than the
# four-node ground-truth fixture reaches.

test_that("dag_to_pag matches pcalg::dag2pag on random DAGs with a latent", {
  skip_on_cran()
  skip_if_not_installed("pcalg")

  set.seed(11)
  compared <- 0L
  mismatches <- character(0)

  for (trial in seq_len(40L)) {
    p <- sample(4:6, 1L)
    g <- pcalg::randomDAG(p, prob = 0.5)
    latent <- sample(seq_len(p), 1L)
    nms <- paste0("N", seq_len(p))

    # pcalg: FCI against a d-separation oracle, via a perfect covariance.
    expected <- tryCatch(
      {
        suff <- list(C = stats::cov2cor(pcalg::trueCov(g)), n = 10^9)
        pcalg::dag2pag(
          suff,
          pcalg::gaussCItest,
          g,
          latent,
          alpha = 0.9999
        )@amat
      },
      error = function(cnd) NULL
    )
    if (is.null(expected)) {
      next
    }

    ix <- which(methods::as(g, "matrix") != 0, arr.ind = TRUE)
    dag <- caugi(
      from = nms[ix[, 1]],
      edge = rep("-->", nrow(ix)),
      to = nms[ix[, 2]],
      nodes = nms,
      class = "DAG"
    )

    actual <- tryCatch(
      as_adjacency(dag_to_pag(dag, latents = nms[latent]), coding = "marks"),
      error = function(cnd) cnd
    )
    if (inherits(actual, "condition")) {
      mismatches <- c(
        mismatches,
        sprintf(
          "trial %d: dag_to_pag errored: %s",
          trial,
          conditionMessage(actual)
        )
      )
      next
    }

    compared <- compared + 1L
    # pcalg renumbers the observed nodes; caugi keeps their names. Both drop
    # the latent and preserve the original order, so positions correspond.
    # Compare by value, not identity: pcalg returns doubles.
    if (
      !identical(dim(actual), dim(expected)) ||
        !all(unname(actual) == unname(expected))
    ) {
      mismatches <- c(mismatches, sprintf("trial %d: PAG differs", trial))
    }
  }

  expect_gt(compared, 30L)
  expect_equal(
    length(mismatches),
    0L,
    info = paste0(
      length(mismatches),
      " of ",
      compared,
      " DAGs give a different PAG than pcalg. First:\n",
      paste(utils::head(mismatches, 5L), collapse = "\n")
    )
  )
})

test_that("m-separation in dag_to_pag() matches d-separation in the DAG", {
  dag <- caugi(
    U %-->% X + Y,
    X %-->% M,
    M %-->% Y,
    W %-->% X,
    class = "DAG"
  )
  pag <- dag_to_pag(dag, latents = "U")
  expect_identical(pag@graph_class, "PAG")
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

test_that("dag_to_pag handles selection, no latents, and bad input", {
  sel <- dag_to_pag(caugi(X %-->% S, Y %-->% S, class = "DAG"), selection = "S")
  expect_identical(edges(sel)$edge, "o-o") # X --- Y is not invariant alone
  chain <- dag_to_pag(caugi(A %-->% B, B %-->% C, class = "DAG"))
  expect_true(all(edges(chain)$edge == "o-o"))
  expect_error(dag_to_pag(caugi(A %---% B, class = "UG")), "'DAG' or 'AG'")
})
