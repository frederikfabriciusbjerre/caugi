# Marginalizing latents must preserve every conditional independence.
#
# The construction is from `IntelLabs/causality-lab`'s
# `test_partial_ancestral_graph.py::test_is_m_separated`: a DAG over eight
# observed and five latent variables, whose ancestral graph over the observed
# ones must encode exactly the same independences as the DAG itself.
#
# So for every pair of observed nodes and every conditioning set drawn from the
# rest, d-separation in the DAG and m-separation in the marginalized graph must
# agree. That pins `condition_marginalize()` and `m_separated()` against each
# other with no external package involved: the DAG's own d-separation is the
# oracle.

test_that("m-separation in the marginalized MAG matches d-separation in the DAG", {
  skip_on_cran()

  latent <- c("A", "B", "C", "D", "E")
  observed <- c("Sun", "W", "T", "Z", "V", "X", "U", "Y")

  parents <- list(
    X = c("A", "B", "T", "V"),
    Y = c("E", "U"),
    U = c("B", "Z"),
    V = c("E", "D"),
    Z = c("Sun", "C", "D"),
    T = c("W", "C"),
    Sun = c("W", "A")
  )
  from <- unlist(parents, use.names = FALSE)
  to <- rep(names(parents), vapply(parents, length, integer(1)))

  dag <- caugi(
    from = from,
    edge = rep("-->", length(from)),
    to = to,
    nodes = c(latent, observed),
    class = "DAG"
  )

  # Richardson and Spirtes (2002) Def. 4.2.1: the ancestral graph over the
  # observed variables.
  mag <- condition_marginalize(mutate_caugi(dag, "AG"), marg_vars = latent)
  expect_true(is_mag(mag))
  expect_setequal(nodes(mag)$name, observed)

  subsets_of <- function(s) {
    if (!length(s)) {
      return(list(character(0)))
    }
    do.call(
      c,
      lapply(0:length(s), function(k) combn(s, k, simplify = FALSE))
    )
  }

  mismatches <- character(0)
  compared <- 0L

  for (pair in combn(observed, 2, simplify = FALSE)) {
    rest <- setdiff(observed, pair)
    for (S in subsets_of(rest)) {
      z <- if (length(S)) S else NULL
      in_dag <- d_separated(dag, pair[1], pair[2], z)
      in_mag <- m_separated(mag, pair[1], pair[2], z)
      compared <- compared + 1L
      if (!isTRUE(in_dag == in_mag)) {
        mismatches <- c(
          mismatches,
          sprintf(
            "%s vs %s | {%s}: DAG %s, MAG %s",
            pair[1],
            pair[2],
            paste(S, collapse = ", "),
            in_dag,
            in_mag
          )
        )
      }
    }
  }

  # 28 pairs x 64 subsets of the remaining six.
  expect_equal(compared, 28L * 64L)
  expect_equal(
    length(mismatches),
    0L,
    info = paste0(
      length(mismatches),
      " of ",
      compared,
      " separations disagree between the DAG and its marginalization. First:\n",
      paste(utils::head(mismatches, 10L), collapse = "\n")
    )
  )
})
