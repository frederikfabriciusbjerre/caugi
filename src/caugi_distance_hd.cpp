#include <cpp11.hpp>
#include <vector>
#include <set>
#include <algorithm>
#include <tuple>

// Define the Edge structure for comparison (ignoring direction and type)
struct Edge {
  int from;
  int to;

  bool operator<(const Edge& other) const {
    return std::tie(from, to) < std::tie(other.from, other.to);
  }
};

// Helper function to extract normalized edges from CSR format
std::set<Edge> extract_edges(const std::vector<int>& row_ptr, const std::vector<int>& col_ids) {
  std::set<Edge> edges;
  int n_nodes = row_ptr.size() - 1;

  for (int i = 0; i < n_nodes; ++i) {
    for (int j = row_ptr[i]; j < row_ptr[i + 1]; ++j) {
      int neighbor = col_ids[j];
      edges.insert(Edge{std::min(i, neighbor), std::max(i, neighbor)});
    }
  }

  return edges;
}

// Hamming distance: count of differing unordered edges
[[cpp11::register]]
int caugi_distance_hd(const std::vector<int>& row_ptr1, const std::vector<int>& col_ids1,
                      const std::vector<int>& row_ptr2, const std::vector<int>& col_ids2) {

  std::set<Edge> edges1 = extract_edges(row_ptr1, col_ids1);
  std::set<Edge> edges2 = extract_edges(row_ptr2, col_ids2);

  std::set<Edge> sym_diff;
  std::set_symmetric_difference(
    edges1.begin(), edges1.end(),
    edges2.begin(), edges2.end(),
    std::inserter(sym_diff, sym_diff.begin())
  );

  return static_cast<int>(sym_diff.size());
}
