// SPDX-License-Identifier: MIT
//! Graph layout algorithms.

use crate::graph::CaugiGraph;

#[derive(Debug, Clone, Copy)]
pub enum LayoutMethod {
    Sugiyama,
    ForceDirected,
    KamadaKawai,
}

impl std::str::FromStr for LayoutMethod {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "sugiyama" => Ok(Self::Sugiyama),
            "force" => Ok(Self::ForceDirected),
            "kamada_kawai" | "kamada-kawai" | "kk" => Ok(Self::KamadaKawai),
            _ => Err(format!("Unknown layout method: '{}'", s)),
        }
    }
}

/// Compute node layout coordinates.
/// Returns a vector of (x, y) pairs, one for each node in order.
pub fn compute_layout(graph: &CaugiGraph, method: LayoutMethod) -> Result<Vec<(f64, f64)>, String> {
    match method {
        LayoutMethod::Sugiyama => sugiyama_layout(graph),
        LayoutMethod::ForceDirected => force_directed_layout(graph),
        LayoutMethod::KamadaKawai => kamada_kawai_layout(graph),
    }
}

fn sugiyama_layout(graph: &CaugiGraph) -> Result<Vec<(f64, f64)>, String> {
    let n = graph.n() as usize;

    if n == 0 {
        return Ok(Vec::new());
    }

    // Build edge list for rust-sugiyama
    let mut edges = Vec::new();
    for i in 0..n {
        let range = graph.row_range(i as u32);
        for idx in range {
            let j = graph.col_index[idx] as usize;
            let etype = graph.etype[idx];
            let side = graph.side[idx];

            // Only include directed edges (tail->head)
            let spec = &graph.registry.specs[etype as usize];
            if spec.class == crate::edges::EdgeClass::Directed && side == 0 {
                edges.push((i as u32, j as u32));
            }
        }
    }

    // Compute layout using rust-sugiyama
    let config = rust_sugiyama::configure::Config::default();
    let subgraphs = rust_sugiyama::from_edges(&edges, &config);

    // Extract coordinates in node order
    // rust-sugiyama returns Vec<(Vec<(usize, (f64, f64))>, width, height)>
    // where each element is a disconnected subgraph
    let mut coords = vec![(0.0, 0.0); n];

    for (subgraph_layout, _width, _height) in subgraphs {
        for (node_id, (x, y)) in subgraph_layout {
            if node_id < n {
                coords[node_id] = (x, y);
            }
        }
    }

    Ok(coords)
}

fn force_directed_layout(graph: &CaugiGraph) -> Result<Vec<(f64, f64)>, String> {
    use fdg_sim::{ForceGraph, ForceGraphHelper, Simulation, SimulationParameters};

    let n = graph.n() as usize;

    if n == 0 {
        return Ok(Vec::new());
    }

    let mut force_graph: ForceGraph<(), ()> = ForceGraph::default();

    // Add nodes (positions will be set after simulation creation)
    let mut node_indices = Vec::with_capacity(n);
    for i in 0..n {
        let idx = force_graph.add_force_node(i.to_string(), ());
        node_indices.push(idx);
    }

    // Add edges to force graph
    for i in 0..n {
        let range = graph.row_range(i as u32);
        for idx in range {
            let j = graph.col_index[idx] as usize;
            let etype = graph.etype[idx];
            let side = graph.side[idx];

            // For force-directed layout, we consider all edge types
            // Skip duplicates for symmetric edges
            let spec = &graph.registry.specs[etype as usize];
            if spec.symmetric && i > j {
                continue;
            }

            // Only add edge once per pair (use side == 0 for directed edges)
            if !spec.symmetric && side != 0 {
                continue;
            }

            force_graph.add_edge(node_indices[i], node_indices[j], ());
        }
    }

    let parameters = SimulationParameters::default();
    let mut simulation = Simulation::from_graph(force_graph, parameters);

    // Set deterministic circular initialization after creation
    let radius = 100.0;
    for (i, &node_idx) in node_indices.iter().enumerate() {
        let angle = 2.0 * std::f32::consts::PI * (i as f32) / (n as f32);
        let node = &mut simulation.get_graph_mut()[node_idx];
        node.location = fdg_sim::glam::Vec3::new(radius * angle.cos(), radius * angle.sin(), 0.0);
        node.old_location = node.location;
        node.velocity = fdg_sim::glam::Vec3::ZERO;
    }

    // Run simulation
    // TODO: Figure out a better criteria than just a fixed number of iterations
    for _ in 0..500 {
        // TODO: Is 0.035 a reasonable time step? This just comes from package examples.
        simulation.update(0.035);
    }

    // Extract coordinates from simulation
    let sim_graph = simulation.get_graph();
    let mut coords = vec![(0.0, 0.0); n];

    for i in 0..n {
        let node_idx = node_indices[i];
        let node = &sim_graph[node_idx];
        coords[i] = (node.location.x as f64, node.location.y as f64);
    }

    Ok(coords)
}

fn kamada_kawai_layout(graph: &CaugiGraph) -> Result<Vec<(f64, f64)>, String> {
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

    // Optimize using conjugate gradient
    conjugate_gradient_optimize(
        &mut positions,
        &distances,
        k_constant,
        ideal_length,
        n,
        100, // max iterations
        1e-4, // tolerance
    );

    // Convert to output format
    let mut coords = vec![(0.0, 0.0); n];
    for i in 0..n {
        coords[i] = (positions[2 * i], positions[2 * i + 1]);
    }

    Ok(coords)
}

/// Compute all-pairs shortest path distances using BFS
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

/// Compute Kamada-Kawai stress (objective function)
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

/// Compute gradient of Kamada-Kawai stress
fn compute_gradient(
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

/// Conjugate gradient optimization
fn conjugate_gradient_optimize(
    positions: &mut [f64],
    distances: &[f64],
    k_constant: f64,
    ideal_length: f64,
    n: usize,
    max_iter: usize,
    tolerance: f64,
) {
    let dim = n * 2;
    let mut gradient = vec![0.0; dim];
    let mut direction = vec![0.0; dim];
    let mut old_gradient = vec![0.0; dim];

    // Initial gradient
    compute_gradient(positions, distances, k_constant, ideal_length, n, &mut gradient);
    
    // Initial direction = -gradient
    for i in 0..dim {
        direction[i] = -gradient[i];
    }

    for iter in 0..max_iter {
        // Check convergence
        let grad_norm: f64 = gradient.iter().map(|&g| g * g).sum::<f64>().sqrt();
        if grad_norm < tolerance {
            break;
        }

        // Line search to find step size
        let alpha = line_search(
            positions,
            &direction,
            distances,
            k_constant,
            ideal_length,
            n,
        );

        // Update positions
        for i in 0..dim {
            positions[i] += alpha * direction[i];
        }

        // Store old gradient
        old_gradient.copy_from_slice(&gradient);

        // Compute new gradient
        compute_gradient(positions, distances, k_constant, ideal_length, n, &mut gradient);

        // Fletcher-Reeves formula for beta
        let numerator: f64 = gradient.iter().map(|&g| g * g).sum();
        let denominator: f64 = old_gradient.iter().map(|&g| g * g).sum();
        let beta = if denominator > 1e-10 {
            numerator / denominator
        } else {
            0.0
        };

        // Update search direction
        for i in 0..dim {
            direction[i] = -gradient[i] + beta * direction[i];
        }

        // Restart CG periodically (every n iterations)
        if iter % n == 0 && iter > 0 {
            for i in 0..dim {
                direction[i] = -gradient[i];
            }
        }
    }
}

/// Simple line search using backtracking
fn line_search(
    positions: &[f64],
    direction: &[f64],
    distances: &[f64],
    k_constant: f64,
    ideal_length: f64,
    n: usize,
) -> f64 {
    let mut alpha = 1.0;
    let tau = 0.5; // reduction factor

    let f0 = compute_stress(positions, distances, k_constant, ideal_length, n);
    
    let mut test_positions = positions.to_vec();
    
    for _ in 0..20 {
        // Test positions with current alpha
        for i in 0..positions.len() {
            test_positions[i] = positions[i] + alpha * direction[i];
        }
        
        let f_new = compute_stress(&test_positions, distances, k_constant, ideal_length, n);
        
        // Armijo condition
        if f_new < f0 {
            return alpha;
        }
        
        alpha *= tau;
    }

    alpha
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use std::sync::Arc;

    #[test]
    fn test_from_str_valid() {
        use std::str::FromStr;
        let method = LayoutMethod::from_str("sugiyama");
        assert!(method.is_ok());
        assert!(matches!(method.unwrap(), LayoutMethod::Sugiyama));

        let method = LayoutMethod::from_str("force");
        assert!(method.is_ok());
        assert!(matches!(method.unwrap(), LayoutMethod::ForceDirected));
    }

    #[test]
    fn test_from_str_invalid() {
        use std::str::FromStr;
        let method = LayoutMethod::from_str("invalid");
        assert!(method.is_err());
        assert_eq!(method.unwrap_err(), "Unknown layout method: 'invalid'");
    }

    #[test]
    fn test_layout_empty_graph() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(0, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = compute_layout(&core, LayoutMethod::Sugiyama);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), vec![]);
    }

    #[test]
    fn test_layout_single_node() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(1, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = compute_layout(&core, LayoutMethod::Sugiyama);
        assert!(result.is_ok());
        let coords = result.unwrap();
        assert_eq!(coords.len(), 1);
        // Single node should have some coordinate
        assert!(coords[0].0.is_finite());
        assert!(coords[0].1.is_finite());
    }

    #[test]
    fn test_layout_simple_dag() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        // Create A --> B --> C
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        let result = compute_layout(&core, LayoutMethod::Sugiyama);
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
    fn test_layout_diamond_dag() {
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

        let result = compute_layout(&core, LayoutMethod::Sugiyama);
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
    fn test_layout_with_undirected_edges() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();
        let cund = reg.code_of("---").unwrap();

        // Create A --> B --- C (undirected edges should be ignored)
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cund).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        let result = compute_layout(&core, LayoutMethod::Sugiyama);
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
    fn test_force_layout_empty_graph() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(0, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = compute_layout(&core, LayoutMethod::ForceDirected);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), vec![]);
    }

    #[test]
    fn test_force_layout_single_node() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(1, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = compute_layout(&core, LayoutMethod::ForceDirected);
        assert!(result.is_ok());
        let coords = result.unwrap();
        assert_eq!(coords.len(), 1);
        assert!(coords[0].0.is_finite());
        assert!(coords[0].1.is_finite());
    }

    #[test]
    fn test_force_layout_simple_dag() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        // Create A --> B --> C
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        let result = compute_layout(&core, LayoutMethod::ForceDirected);
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
    fn test_force_layout_with_undirected_edges() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();
        let cund = reg.code_of("---").unwrap();

        // Create A --> B --- C (force layout handles mixed edge types)
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cund).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        let result = compute_layout(&core, LayoutMethod::ForceDirected);
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
    fn test_kamada_kawai_empty_graph() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(0, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = compute_layout(&core, LayoutMethod::KamadaKawai);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), vec![]);
    }

    #[test]
    fn test_kamada_kawai_single_node() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(1, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = compute_layout(&core, LayoutMethod::KamadaKawai);
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

        let result = compute_layout(&core, LayoutMethod::KamadaKawai);
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

        let result = compute_layout(&core, LayoutMethod::KamadaKawai);
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
        let result1 = compute_layout(&core, LayoutMethod::KamadaKawai);
        let result2 = compute_layout(&core, LayoutMethod::KamadaKawai);

        assert!(result1.is_ok());
        assert!(result2.is_ok());

        let coords1 = result1.unwrap();
        let coords2 = result2.unwrap();

        // Should be identical (deterministic)
        assert_eq!(coords1, coords2);
    }

    #[test]
    fn test_from_str_kamada_kawai() {
        use std::str::FromStr;
        
        assert!(matches!(
            LayoutMethod::from_str("kamada_kawai"),
            Ok(LayoutMethod::KamadaKawai)
        ));
        assert!(matches!(
            LayoutMethod::from_str("kamada-kawai"),
            Ok(LayoutMethod::KamadaKawai)
        ));
        assert!(matches!(
            LayoutMethod::from_str("kk"),
            Ok(LayoutMethod::KamadaKawai)
        ));
    }
}
