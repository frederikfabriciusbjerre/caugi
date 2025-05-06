#include <iostream>  // For std::cout
#include <cpp11.hpp>  // cpp11 library
#include <vector>
#include <cpp11.hpp>
#include <unordered_set>
#include <utility>

// Custom hash function for std::pair<int, int>
struct pair_hash {
  size_t operator()(const std::pair<int, int>& p) const {
    // A simple hash combine for two ints
    return std::hash<int>{}(p.first) ^ (std::hash<int>{}(p.second) << 1);
  }
};

// Normalize edge direction: (min, max)
inline std::pair<int, int> undirected_edge(int a, int b) {
  return std::make_pair(std::min(a, b), std::max(a, b));
}

[[cpp11::register]]
int caugi_distance_hd(const std::vector<int>& row_ptr1, const std::vector<int>& col_ids1,
                                  const std::vector<int>& row_ptr2, const std::vector<int>& col_ids2) {
  int n = row_ptr1.size() - 1;
  if (row_ptr1.size() - 1 != row_ptr2.size() - 1) {
    throw std::invalid_argument("Graphs must have the same number of nodes");
  }

  // Step 1: Build neighbor sets
  std::vector<std::unordered_set<int>> neighbors1(n), neighbors2(n);

  for (int v = 0; v < n; ++v) {
    for (int i = row_ptr1[v]; i < row_ptr1[v + 1]; ++i) {
      int from = std::min(v, col_ids1[i] - 1);
      int to = std::max(v, col_ids1[i] - 1);
      neighbors1[from].insert(to);
    }
    for (int i = row_ptr2[v]; i < row_ptr2[v + 1]; ++i) {
      int from = std::min(v, col_ids2[i] - 1);
      int to = std::max(v, col_ids2[i] - 1);
      neighbors2[from].insert(to);
    }
  }

  // Step 2: Compare and log
  int dist = 0;
  for (int v = 0; v < n; ++v) {
    const auto& n1 = neighbors1[v];
    const auto& n2 = neighbors2[v];

    std::cout << "Node " << v << ":\n";
    std::cout << "  Graph 1 neighbors: { ";
    for (int w : n1) std::cout << w << " ";
    std::cout << "}\n";

    std::cout << "  Graph 2 neighbors: { ";
    for (int w : n2) std::cout << w << " ";
    std::cout << "}\n";

    for (int w : n1) {
      if (n2.count(w) == 0) {
        std::cout << "    Missing in Graph 2: " << v << " → " << w << "\n";
        dist++;
      }
    }
    for (int w : n2) {
      if (n1.count(w) == 0) {
        std::cout << "    Missing in Graph 1: " << v << " → " << w << "\n";
        dist++;
      }
    }
  }

  std::cout << "Total Hamming distance: " << dist << "\n";
  return dist;
}

