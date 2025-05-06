#' @title Compute the Simple Hamming Distance Between Two Graphs
#'
#' @description Calculate the simple Hamming distance (number of differing edges) between two graphs.
#'
#' @param g1 A `caugi_graph` object representing the first graph.
#' @param g2 A `caugi_graph` object representing the second graph.
#' @return The Hamming distance between the two graphs (number of differing edges).
#' @export
hd <- function(g1, g2) {
  csr1 <- g1$csr
  csr2 <- g2$csr

  row_ptr1 <- csr1$row_ptr
  col_ids1 <- csr1$col_ids
  row_ptr2 <- csr2$row_ptr
  col_ids2 <- csr2$col_ids

  cat("=== CSR INPUT ===\n")
  cat("Graph 1:\n")
  cat("  row_ptr1:", paste(row_ptr1, collapse = ", "), "\n")
  cat("  col_ids1:", paste(col_ids1, collapse = ", "), "\n")

  cat("Graph 2:\n")
  cat("  row_ptr2:", paste(row_ptr2, collapse = ", "), "\n")
  cat("  col_ids2:", paste(col_ids2, collapse = ", "), "\n")

  distance <- caugi_distance_hd(row_ptr1, col_ids1, row_ptr2, col_ids2)
  return(distance)
}
