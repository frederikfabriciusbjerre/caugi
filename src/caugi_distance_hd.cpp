#include <iostream>
#include <ostream>  // For std::endl
#include <set>
#include <vector>   // For std::vector
#include <algorithm> // For std::min and std::max

struct Edge {
  int from;
  int to;

  // Comparison operator for the set
  bool operator<(const Edge& other) const {
    // Normalize edges: always store (min, max) pair for both directed and undirected edges
    return std::tie(from, to) < std::tie(other.from, other.to);
  }

  // Equality operator for set comparisons
  bool operator==(const Edge& other) const {
    // Check if both edges are the same, treating (A, B) and (B, A) as equal
    return (from == other.from && to == other.to) || (from == other.to && to == other.from);
  }
};

// Helper function to extract normalized edges from CSR format
std::set<Edge> extract_edges(const std::vector<int>& row_ptr, const std::vector<int>& col_ids, const std::vector<int>& type_codes) {
  std::set<Edge> edges;
  int n_nodes = row_ptr.size() - 1;

  std::cout << "Extracting edges: \n";

  for (int i = 0; i < n_nodes; ++i) {
    for (int j = row_ptr[i]; j < row_ptr[i + 1]; ++j) {
      int neighbor = col_ids[j];

      // Normalize the edge for undirected graphs (treat as the same regardless of direction)
      Edge edge{std::min(i, neighbor), std::max(i, neighbor)};

      // Print each edge for debugging
      std::cout << "  Node " << i << " to Node " << neighbor << std::endl;

      // Insert the normalized edge into the set
      edges.insert(edge);
    }
  }

  std::cout << "Total edges extracted: " << edges.size() << std::endl;

  return edges;
}


// Hamming distance: count of differing unordered edges
[[cpp11::register]]
int caugi_distance_hd(const std::vector<int>& row_ptr1, const std::vector<int>& col_ids1, const std::vector<int>& type_codes1,
                      const std::vector<int>& row_ptr2, const std::vector<int>& col_ids2, const std::vector<int>& type_codes2) {

  std::cout << "Extracting edges for graph 1:\n";
  std::set<Edge> edges1 = extract_edges(row_ptr1, col_ids1, type_codes1);

  std::cout << "Extracting edges for graph 2:\n";
  std::set<Edge> edges2 = extract_edges(row_ptr2, col_ids2, type_codes2);

  std::cout << "Calculating symmetric difference between edges:\n";

  std::set<Edge> sym_diff;
  std::set_symmetric_difference(
    edges1.begin(), edges1.end(),
    edges2.begin(), edges2.end(),
    std::inserter(sym_diff, sym_diff.begin())
  );

  int hamming_distance = static_cast<int>(sym_diff.size());
  std::cout << "Hamming distance: " << hamming_distance << std::endl;

  return hamming_distance;
}
