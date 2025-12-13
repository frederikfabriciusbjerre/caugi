# example seen in Elements of Causal Inference, Figure 6.5, p. 115
adjustment_set_cg <- caugi(
  C %-->% X,
  X %-->% F,
  X %-->% D,
  A %-->% X,
  A %-->% K,
  K %-->% Y,
  D %-->% Y,
  D %-->% G,
  Y %-->% H,
  class = "DAG"
)

test_that("d-separation checks", {
  expect_false(d_separated(adjustment_set_cg, "X", "Y")) # backdoor via A-->K-->Y and causal X-->D-->Y
  expect_false(d_separated(adjustment_set_cg, "X", "Y", Z = "A")) # causal path still open
  expect_false(d_separated(adjustment_set_cg, "X", "Y", Z = "K")) # causal path still open
  expect_false(d_separated(adjustment_set_cg, "X", "Y", Z = "D")) # backdoor still open
  expect_true(d_separated(adjustment_set_cg, "X", "Y", Z = c("A", "D"))) # backdoor and causal both blocked
  expect_true(d_separated(adjustment_set_cg, "X", "Y", Z = c("K", "D"))) # backdoor and causal both blocked

  # now with indexes
  expect_false(d_separated(adjustment_set_cg, X_index = 2L, Y_index = 6L)) # backdoor via A-->K-->Y and causal X-->D-->Y
  expect_false(d_separated(
    adjustment_set_cg,
    X_index = 2L,
    Y_index = 6L,
    Z_index = 3L
  )) # causal path still open
  expect_false(d_separated(
    adjustment_set_cg,
    X_index = 2L,
    Y_index = 6L,
    Z_index = 4L
  )) # causal path still open
  expect_false(d_separated(
    adjustment_set_cg,
    X_index = 2L,
    Y_index = 6L,
    Z_index = 5L
  )) # backdoor still open
  expect_true(d_separated(
    adjustment_set_cg,
    X_index = 2L,
    Y_index = 6L,
    Z_index = c(3L, 5L)
  ))
  expect_true(d_separated(
    adjustment_set_cg,
    X_index = 2L,
    Y_index = 6L,
    Z_index = c(4L, 5L)
  ))
})

test_that("adjustment_set(type = 'parents') returns Pa(X) \\ {X,Y}", {
  got <- adjustment_set(adjustment_set_cg, "X", "Y", type = "parents")
  expect_setequal(got, c("A", "C"))
})

test_that("adjustment_set(type = 'backdoor') returns a valid backdoor set", {
  Z <- adjustment_set(adjustment_set_cg, "X", "Y", type = "backdoor")
  expect_true(is_valid_backdoor(adjustment_set_cg, X = "X", Y = "Y", Z = Z))
  expect_false("D" %in% Z) # descendant of X should not appear
})

test_that("adjustment_set(type = 'optimal') is valid and minimal here", {
  Z <- adjustment_set(adjustment_set_cg, "X", "Y", type = "optimal")
  expect_true(is_valid_backdoor(adjustment_set_cg, X = "X", Y = "Y", Z = Z))
  expect_true(setequal(Z, "A") || setequal(Z, "K")) # minimal sets in this DAG
})

test_that("is_valid_backdoor works on canonical choices", {
  expect_true(is_valid_backdoor(adjustment_set_cg, X = "X", Y = "Y", Z = "A"))
  expect_true(is_valid_backdoor(adjustment_set_cg, X = "X", Y = "Y", Z = "K"))
  expect_false(is_valid_backdoor(adjustment_set_cg, X = "X", Y = "Y", Z = "D"))
  expect_false(is_valid_backdoor(
    adjustment_set_cg,
    X = "X",
    Y = "Y",
    Z = c("A", "D")
  ))
  expect_false(is_valid_backdoor(adjustment_set_cg, X = "X", Y = "Y", Z = NULL))
})

test_that("all_backdoor_sets enumerates minimal sets", {
  sets <- all_backdoor_sets(adjustment_set_cg, X = "X", Y = "Y")
  norm <- lapply(sets, sort)
  expect_equal(length(norm), 2L)
  expect_true(any(setequal(norm[[1]], "A") | setequal(norm[[2]], "A")))
  expect_true(any(setequal(norm[[1]], "K") | setequal(norm[[2]], "K")))
})

test_that("all_backdoor_sets respects max_size and minimal", {
  sets <- all_backdoor_sets(adjustment_set_cg, X = "X", Y = "Y", minimal = TRUE)
  expect_equal(length(sets), 2L)
  expect_setequal(sets, c("A", "K"))
  sets2 <- all_backdoor_sets(
    adjustment_set_cg,
    X = "X",
    Y = "Y",
    minimal = FALSE,
    max_size = 2
  )
  expect_equal(length(sets2), 5L)
  expect_setequal(sets2, list("A", "K", c("A", "K"), c("C", "A"), c("C", "K")))
})

test_that("all_backdoor_sets includes empty set, if valid", {
  adjustment_set_cg <- caugi(
    C %-->% X,
    X %-->% F,
    X %-->% D,
    A %-->% X,
    A %-->% L, # add v structure, now empty set is valid
    K %-->% L,
    K %-->% Y,
    D %-->% Y,
    D %-->% G,
    Y %-->% H,
    class = "DAG"
  )
  # check if empty set is valid
  expect_true(is_valid_backdoor(adjustment_set_cg, X = "X", Y = "Y", Z = NULL))

  sets <- all_backdoor_sets(
    adjustment_set_cg,
    X = "X",
    Y = "Y",
    minimal = FALSE,
    max_size = 2
  )
  valid_sets <- list(
    character(0),
    "C",
    "A",
    "K",
    c("A", "K"),
    c("C", "A"),
    c("C", "K"),
    c("A", "L"),
    c("K", "L")
  )
  expect_setequal(sets, valid_sets)
})

test_that("adjustment functions cannot take multiple inputs", {
  expect_error(
    adjustment_set(
      adjustment_set_cg,
      X = c("X", "A"),
      Y = "Y",
      type = "parents"
    ),
    "Provide exactly one X and one Y."
  )
  expect_error(
    is_valid_backdoor(adjustment_set_cg, X = "X", Y = c("Y", "D"), Z = "A"),
    "Provide exactly one X and one Y."
  )
  expect_error(
    all_backdoor_sets(adjustment_set_cg, X = "X", Y = c("Y", "D")),
    "Provide exactly one X and one Y."
  )
  expect_error(
    d_separated(adjustment_set_cg, X_index = c(1L, 2L), Y = "Y", Z = "A"),
    "Provide exactly one X and one Y."
  )
})

test_that("adjust functions fails with faulty input", {
  expect_error(
    adjustment_set(adjustment_set_cg, X = "X", Y = NULL, type = "parents"),
    "Either the node name or the node index must be provided"
  )
  expect_error(
    adjustment_set(
      adjustment_set_cg,
      X = "X",
      Y = "Y",
      Y_index = 6L,
      type = "parent"
    ),
    "Provide either a node name or node index"
  )
  expect_error(
    d_separated(adjustment_set_cg, X = "X", Y = "Y", Z = "A", Z_index = 3L),
    "Provide either a node name or node index"
  )
})
