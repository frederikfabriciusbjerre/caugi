// SPDX-License-Identifier: MIT
//! Kamada-Kawai stress minimization layout algorithm.

use super::optimizer::conjugate_gradient_optimize;
use crate::graph::CaugiGraph;

pub fn kamada_kawai_layout(graph: &CaugiGraph) -> Result<Vec<(f64, f64)>, String> {
    let n = graph.n() as usize;

    if n == 0 {
        return Ok(Vec::new());
    }

    if n == 1 {
        return Ok(vec![(0.0, 0.0)]);
    }

    // Compute all-pairs shortest path distances using BFS
    let distances = compute_shortest_paths(graph, n);

    // Initialize positions in a circle
    let mut positions = vec![0.0; n * 2]; // [x0, y0, x1, y1, ...]
    let radius = 100.0;
    for i in 0..n {
        let angle = 2.0 * std::f64::consts::PI * (i as f64) / (n as f64);
        positions[2 * i] = radius * angle.cos();
        positions[2 * i + 1] = radius * angle.sin();
    }

    // Spring constants: k_ij = K / d_ij^2
    let k_constant = 1.0;
    let ideal_length = 100.0;

    // Create closures for gradient and objective
    let compute_gradient = |pos: &[f64], grad: &mut [f64]| {
        compute_stress_gradient(pos, &distances, k_constant, ideal_length, n, grad);
    };

    let compute_objective =
        |pos: &[f64]| compute_stress(pos, &distances, k_constant, ideal_length, n);

    // Optimize using conjugate gradient
    conjugate_gradient_optimize(
        &mut positions,
        compute_gradient,
        compute_objective,
        100,  // max iterations
        1e-4, // tolerance
    );

    // Convert to output format
    let mut coords = vec![(0.0, 0.0); n];
    for i in 0..n {
        coords[i] = (positions[2 * i], positions[2 * i + 1]);
    }

    Ok(coords)
}

/// Compute all-pairs shortest path distances using BFS.
fn compute_shortest_paths(graph: &CaugiGraph, n: usize) -> Vec<f64> {
    let mut distances = vec![f64::INFINITY; n * n];

    // Set diagonal to 0
    for i in 0..n {
        distances[i * n + i] = 0.0;
    }

    // BFS from each node
    for start in 0..n {
        let mut queue = std::collections::VecDeque::new();
        let mut visited = vec![false; n];

        queue.push_back(start);
        visited[start] = true;
        distances[start * n + start] = 0.0;

        while let Some(u) = queue.pop_front() {
            let range = graph.row_range(u as u32);
            for idx in range {
                let v = graph.col_index[idx] as usize;
                let etype = graph.etype[idx];

                // Consider all edges (treat as undirected for distance purposes)
                let spec = &graph.registry.specs[etype as usize];

                // Skip if already visited
                if visited[v] {
                    continue;
                }

                // For symmetric edges, only process once per pair
                if spec.symmetric && u > v {
                    continue;
                }

                visited[v] = true;
                let new_dist = distances[start * n + u] + 1.0;
                distances[start * n + v] = new_dist;
                distances[v * n + start] = new_dist; // symmetric
                queue.push_back(v);
            }
        }
    }

    // For disconnected components, use large distance
    for i in 0..n {
        for j in 0..n {
            if distances[i * n + j].is_infinite() {
                distances[i * n + j] = (n as f64) * 2.0;
            }
        }
    }

    distances
}

/// Compute Kamada-Kawai stress (objective function).
fn compute_stress(
    positions: &[f64],
    distances: &[f64],
    k_constant: f64,
    ideal_length: f64,
    n: usize,
) -> f64 {
    let mut stress = 0.0;

    for i in 0..n {
        for j in (i + 1)..n {
            let dx = positions[2 * i] - positions[2 * j];
            let dy = positions[2 * i + 1] - positions[2 * j + 1];
            let euclidean_dist = (dx * dx + dy * dy).sqrt();

            let graph_dist = distances[i * n + j];
            let ideal_dist = ideal_length * graph_dist;

            if graph_dist > 0.0 {
                let k_ij = k_constant / (graph_dist * graph_dist);
                let diff = euclidean_dist - ideal_dist;
                stress += k_ij * diff * diff;
            }
        }
    }

    stress
}

/// Compute gradient of Kamada-Kawai stress.
fn compute_stress_gradient(
    positions: &[f64],
    distances: &[f64],
    k_constant: f64,
    ideal_length: f64,
    n: usize,
    gradient: &mut [f64],
) {
    gradient.fill(0.0);

    for i in 0..n {
        for j in 0..n {
            if i == j {
                continue;
            }

            let dx = positions[2 * i] - positions[2 * j];
            let dy = positions[2 * i + 1] - positions[2 * j + 1];
            let euclidean_dist = (dx * dx + dy * dy).sqrt();

            if euclidean_dist < 1e-10 {
                continue;
            }

            let graph_dist = distances[i * n + j];
            let ideal_dist = ideal_length * graph_dist;

            if graph_dist > 0.0 {
                let k_ij = k_constant / (graph_dist * graph_dist);
                let factor = 2.0 * k_ij * (1.0 - ideal_dist / euclidean_dist);

                gradient[2 * i] += factor * dx;
                gradient[2 * i + 1] += factor * dy;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use std::sync::Arc;

    #[test]
    fn test_kamada_kawai_empty_graph() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(0, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = kamada_kawai_layout(&core);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), vec![]);
    }

    #[test]
    fn test_kamada_kawai_single_node() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(1, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = kamada_kawai_layout(&core);
        assert!(result.is_ok());
        let coords = result.unwrap();
        assert_eq!(coords.len(), 1);
        assert!(coords[0].0.is_finite());
        assert!(coords[0].1.is_finite());
    }

    #[test]
    fn test_kamada_kawai_simple_dag() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        // Create A --> B --> C
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        let result = kamada_kawai_layout(&core);
        assert!(result.is_ok());
        let coords = result.unwrap();
        assert_eq!(coords.len(), 3);

        // All coordinates should be finite
        for (x, y) in &coords {
            assert!(x.is_finite());
            assert!(y.is_finite());
        }
    }

    #[test]
    fn test_kamada_kawai_diamond_dag() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        // Create diamond: A --> B, A --> C, B --> D, C --> D
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(0, 2, cdir).unwrap();
        b.add_edge(1, 3, cdir).unwrap();
        b.add_edge(2, 3, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        let result = kamada_kawai_layout(&core);
        assert!(result.is_ok());
        let coords = result.unwrap();
        assert_eq!(coords.len(), 4);

        // All coordinates should be finite
        for (x, y) in &coords {
            assert!(x.is_finite());
            assert!(y.is_finite());
        }
    }

    #[test]
    fn test_kamada_kawai_deterministic() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        // Create A --> B --> C
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        // Run layout twice
        let result1 = kamada_kawai_layout(&core);
        let result2 = kamada_kawai_layout(&core);

        assert!(result1.is_ok());
        assert!(result2.is_ok());

        let coords1 = result1.unwrap();
        let coords2 = result2.unwrap();

        // Should be identical (deterministic)
        assert_eq!(coords1, coords2);
    }
}
