// SPDX-License-Identifier: MIT
//! Graph layout algorithms.

use crate::graph::CaugiGraph;

#[derive(Debug, Clone, Copy)]
pub enum LayoutMethod {
    Sugiyama,
    ForceDirected,
}

impl std::str::FromStr for LayoutMethod {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "sugiyama" => Ok(Self::Sugiyama),
            "force" => Ok(Self::ForceDirected),
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
}
