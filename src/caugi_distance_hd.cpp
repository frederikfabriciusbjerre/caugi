#include <iostream>
#include <ostream>  // For std::endl
#include <set>
#include <vector>   // For std::vector
#include <algorithm> // For std::min and std::max
#include <cpp11.hpp>  // Ensure cpp11 is included


[[cpp11::register]]
int caugi_distance_hd(const std::vector<int>& row_ptr1, const std::vector<int>& col_ids1, const std::vector<int>& type_codes1,
                      const std::vector<int>& row_ptr2, const std::vector<int>& col_ids2, const std::vector<int>& type_codes2) {

  const int n = row_ptr1.size() - 1;

  // Fix the size comparison: cast size to int
  if (static_cast<int>(row_ptr2.size()) != n + 1) cpp11::stop("Graphs have different #vertices");

  int dist = 0;

  // Iterate over each vertex
  for (int v = 0; v < n; ++v) {
    auto it1  = col_ids1.begin() + row_ptr1[v];
    auto end1 = col_ids1.begin() + row_ptr1[v + 1];
    auto it2  = col_ids2.begin() + row_ptr2[v];
    auto end2 = col_ids2.begin() + row_ptr2[v + 1];

    while (it1 != end1 && it2 != end2) {
      // Compare edges
      if (*it1 == *it2) {
        // Same edge, no difference
        ++it1; ++it2;
      }
      else if (*it1 < *it2) {
        // Edge only in the first graph
        ++dist;
        ++it1;
      }
      else {
        // Edge only in the second graph
        ++dist;
        ++it2;
      }
    }

    // Count remaining edges in either graph
    dist += (end1 - it1) + (end2 - it2);
  }

  return dist;
}

