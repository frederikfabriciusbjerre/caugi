#' @title Compute the Simple Hamming Distance Between Two Graphs
#'
#' @description Calculate the simple Hamming distance (number of differing edges) between two graphs.
#'
#' @param g1 A `caugi_graph` object representing the first graph.
#' @param g2 A `caugi_graph` object representing the second graph.
#' @return The Hamming distance between the two graphs (number of differing edges).
#' @export
hd <- function(g1, g2) {
  # Extract CSR data from both graphs
  csr1 <- g1$csr
  csr2 <- g2$csr

  # Extract row_ptr, col_ids, and type_codes from CSR data
  row_ptr1 <- csr1$row_ptr
  col_ids1 <- csr1$col_ids
  type_codes1 <- csr1$type_codes

  row_ptr2 <- csr2$row_ptr
  col_ids2 <- csr2$col_ids
  type_codes2 <- csr2$type_codes

  # Print CSR data for debugging (optional)
  print("Graph 1 CSR:")
  print(csr1)
  print("Graph 2 CSR:")
  print(csr2)

  # Call the C++ function to compute Hamming Distance (with type_codes included)
  distance <- caugi_distance_hd(
    row_ptr1, col_ids1, type_codes1,
    row_ptr2, col_ids2, type_codes2
  )

  # Return the calculated distance
  return(distance)
}
