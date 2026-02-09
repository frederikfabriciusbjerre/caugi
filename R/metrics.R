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
#' @param cg1 A `caugi` object.
#' @param cg2 A `caugi` object.
#' @param normalized Logical; if `TRUE`, returns the normalized SHD.
#'
#' @returns An integer representing the Hamming Distance between the two graphs,
#' if `normalized = FALSE`, or a numeric between 0 and 1 if `normalized = TRUE`.
#'
#' @examples
#' cg1 <- caugi(A %-->% B %-->% C, D %-->% C, class = "DAG")
#' cg2 <- caugi(A %-->% B %-->% C, D %---% C, class = "PDAG")
#' shd(cg1, cg2) # 1
#'
#' @family metrics
#' @concept metrics
#'
#' @export
shd <- function(cg1, cg2, normalized = FALSE) {
  is_caugi(cg1, throw_error = TRUE)
  is_caugi(cg2, throw_error = TRUE)
  same_nodes(cg1, cg2, throw_error = TRUE)
  out_lst <- rs_shd(cg1@session, cg2@session)
  out <- if (normalized) out_lst$normalized else out_lst$count
  out
}

#' @title Hamming Distance
#'
#' @description Compute the Hamming Distance between two graphs.
#'
#' @param cg1 A `caugi` object.
#' @param cg2 A `caugi` object.
#' @param normalized Logical; if `TRUE`, returns the normalized Hamming
#' Distance.
#'
#' @returns An integer representing the Hamming Distance between the two graphs,
#' if `normalized = FALSE`, or a numeric between 0 and 1 if `normalized = TRUE`.
#'
#' @examples
#' cg1 <- caugi(A %-->% B %-->% C, D %-->% C, class = "DAG")
#' cg2 <- caugi(A %-->% B %-->% C, D %---% C, class = "PDAG")
#' hd(cg1, cg2) # 0
#'
#' @family metrics
#' @concept metrics
#'
#' @export
hd <- function(cg1, cg2, normalized = FALSE) {
  is_caugi(cg1, throw_error = TRUE)
  is_caugi(cg2, throw_error = TRUE)
  same_nodes(cg1, cg2, throw_error = TRUE)
  out_lst <- rs_hd(cg1@session, cg2@session)
  out <- if (normalized) out_lst$normalized else out_lst$count
  out
}

#' @title Adjustment Identification Distance
#'
#' @description Compute the Adjustment Identification Distance (AID) between two
#' graphs using the `gadjid` Rust package.
#'
#' @param truth A `caugi` object.
#' @param guess A `caugi` object.
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
#' aid(truth, guess) # 0.0187
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
