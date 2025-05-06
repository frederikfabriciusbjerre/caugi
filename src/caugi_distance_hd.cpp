#include <iostream>  // For std::cout
#include <cpp11.hpp>  // cpp11 library
#include <vector>

[[cpp11::register]]
int caugi_distance_hd(const std::vector<int>& row_ptr1, const std::vector<int>& col_ids1, const std::vector<int>& type_codes1,
                      const std::vector<int>& row_ptr2, const std::vector<int>& col_ids2, const std::vector<int>& type_codes2) {

  const int n = row_ptr1.size() - 1;

  // Debug: Print sizes of row_ptrs
  std::cout << "Row_ptr1 size: " << row_ptr1.size() << std::endl;
  std::cout << "Row_ptr2 size: " << row_ptr2.size() << std::endl;

  if (row_ptr2.size() != n + 1) {
    std::cerr << "Error: Graphs have different #vertices!" << std::endl;
    cpp11::stop("Graphs have different #vertices");
  }

  int dist = 0;

  // Iterate over each vertex
  for (int v = 0; v < n; ++v) {
    auto it1  = col_ids1.begin() + row_ptr1[v];
    auto end1 = col_ids1.begin() + row_ptr1[v + 1];
    auto it2  = col_ids2.begin() + row_ptr2[v];
    auto end2 = col_ids2.begin() + row_ptr2[v + 1];

    // Debug: Print the edges for each vertex
    std::cout << "Edges for graph 1 (vertex " << v << "): ";
    for (auto it = it1; it != end1; ++it) {
      std::cout << *it << " ";
    }
    std::cout << std::endl;  // New line after the edges of graph 1

    std::cout << "Edges for graph 2 (vertex " << v << "): ";
    for (auto it = it2; it != end2; ++it) {
      std::cout << *it << " ";
    }
    std::cout << std::endl;  // New line after the edges of graph 2

    while (it1 != end1 && it2 != end2) {
      if (*it1 == *it2) {
        ++it1; ++it2;
      }
      else if (*it1 < *it2) {
        ++dist;
        ++it1;
      }
      else {
        ++dist;
        ++it2;
      }
    }

    // Count remaining edges in either graph
    dist += (end1 - it1) + (end2 - it2);
  }

  // Print final Hamming distance
  std::cout << "Hamming Distance: " << dist << std::endl;

  return dist;
}
