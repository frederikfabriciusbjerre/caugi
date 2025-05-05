#' @title Compute the Simple Hamming Distance Between Two Graphs
#'
#' @description Calculate the simple Hamming distance (number of differing edges) between two graphs.
#'
#' @param g1 A `caugi_graph` object representing the first graph.
#' @param g2 A `caugi_graph` object representing the second graph.
#' @return The Hamming distance between the two graphs (number of differing edges).
#' @export
hd <- function(g1, g2) {
  # Extract CSR data from both graphs (only row_ptr and col_ids are needed now)
  csr1 <- g1$csr
  csr2 <- g2$csr

  # Call the C++ function to compute Hamming Distance (ignoring edge types)
  distance <- caugi_distance_hd(
    csr1$row_ptr, csr1$col_ids,
    csr2$row_ptr, csr2$col_ids
  )

  return(distance)
}
