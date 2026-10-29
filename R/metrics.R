# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Metrics ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── Structural metrics ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Structural Hamming Distance
#'
#' @description Compute the Structural Hamming Distance (SHD) between two
#' graphs.
#'
#' For graphs with at most one edge between any two nodes, the SHD is
#' symmetric: swapping `truth` and `guess` gives the same value, normalized or
#' not. The argument names only mark the usual roles of the true and the
#' estimated graph, as in [aid()].
#'
#' @param truth A `caugi` object.
#' @param guess A `caugi` object.
#' @param normalized Logical; if `TRUE`, returns the normalized SHD.
#'
#' @returns An integer representing the Hamming Distance between the two graphs,
#' if `normalized = FALSE`, or a numeric between 0 and 1 if `normalized = TRUE`.
#'
#' @examples
#' truth <- caugi(A %-->% B %-->% C, D %-->% C, class = "DAG")
#' guess <- caugi(A %-->% B %-->% C, D %---% C, class = "PDAG")
#' shd(truth, guess) # 1
#'
#' @family metrics
#' @concept metrics
#'
#' @export
shd <- function(truth, guess, normalized = FALSE) {
  is_caugi(truth, throw_error = TRUE)
  is_caugi(guess, throw_error = TRUE)
  same_nodes(truth, guess, throw_error = TRUE)
  out_lst <- rs_shd(truth@session, guess@session)
  out <- if (normalized) out_lst$normalized else out_lst$count
  out
}

#' @title Hamming Distance
#'
#' @description Compute the Hamming Distance between two graphs.
#'
#' The Hamming Distance is symmetric: swapping `truth` and `guess` gives the
#' same value, normalized or not. The argument names only mark the usual roles
#' of the true and the estimated graph, as in [aid()].
#'
#' @param truth A `caugi` object.
#' @param guess A `caugi` object.
#' @param normalized Logical; if `TRUE`, returns the normalized Hamming
#' Distance.
#'
#' @returns An integer representing the Hamming Distance between the two graphs,
#' if `normalized = FALSE`, or a numeric between 0 and 1 if `normalized = TRUE`.
#'
#' @examples
#' truth <- caugi(A %-->% B %-->% C, D %-->% C, class = "DAG")
#' guess <- caugi(A %-->% B %-->% C, D %---% C, class = "PDAG")
#' hd(truth, guess) # 0
#'
#' @family metrics
#' @concept metrics
#'
#' @export
hd <- function(truth, guess, normalized = FALSE) {
  is_caugi(truth, throw_error = TRUE)
  is_caugi(guess, throw_error = TRUE)
  same_nodes(truth, guess, throw_error = TRUE)
  out_lst <- rs_hd(truth@session, guess@session)
  out <- if (normalized) out_lst$normalized else out_lst$count
  out
}

#' @title Adjustment Identification Distance
#'
#' @description Compute the Adjustment Identification Distance (AID) between two
#' graphs. AID counts how often the adjustment-identification strategy applied
#' to `guess` yields a causal inference that is incorrect relative to `truth`,
#' so unlike [shd()] and [hd()], swapping the two graphs generally changes the
#' value. Implemented in caugi's Rust backend following Henckel, Würtzen &
#' Weichwald (2024), <doi:10.48550/arXiv.2402.08616>.
#'
#' @param truth A `caugi` object of class `"DAG"` or `"CPDAG"`.
#' @param guess A `caugi` object of class `"DAG"` or `"CPDAG"`.
#' @param type A character string specifying the type of AID to compute.
#' Options are `"oset"` (default), `"ancestor"`, and `"parent"`.
#' @param normalized Logical; if `TRUE`, returns the normalized AID. If `FALSE`,
#' returns the count.
#'
#' @returns A numeric representing the AID between the two graphs, if
#' `normalized = TRUE`, or an integer count if `normalized = FALSE`.
#'
#' @examples
#' set.seed(1)
#' truth <- generate_graph(n = 100, m = 200, class = "DAG")
#' guess <- generate_graph(n = 100, m = 200, class = "DAG")
#' aid(truth, guess) # 0.109
#'
#' @family metrics
#' @concept metrics
#'
#' @export
aid <- function(
  truth,
  guess,
  type = c("oset", "ancestor", "parent"),
  normalized = TRUE
) {
  type <- match.arg(type)
  is_caugi(truth, throw_error = TRUE)
  is_caugi(guess, throw_error = TRUE)
  same_nodes(truth, guess, throw_error = TRUE)

  res <- switch(
    type,
    oset = rs_oset_aid(truth@session, guess@session),
    ancestor = rs_ancestor_aid(truth@session, guess@session),
    parent = rs_parent_aid(truth@session, guess@session)
  )
  if (normalized) {
    res$score
  } else {
    res$count
  }
}
