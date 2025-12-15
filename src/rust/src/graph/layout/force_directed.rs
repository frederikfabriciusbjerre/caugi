// SPDX-License-Identifier: MIT
//! Force-directed layout using Fruchterman-Reingold algorithm.

use crate::graph::CaugiGraph;

pub fn force_directed_layout(graph: &CaugiGraph) -> Result<Vec<(f64, f64)>, String> {
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

    // Create simulation with default parameters
    let parameters = SimulationParameters::default();
    let mut simulation = Simulation::from_graph(force_graph, parameters);

    // Set deterministic circular initialization after creation
    // This overwrites the random positions set by from_graph()
    let radius = 100.0;
    for (i, &node_idx) in node_indices.iter().enumerate() {
        let angle = 2.0 * std::f32::consts::PI * (i as f32) / (n as f32);
        let node = &mut simulation.get_graph_mut()[node_idx];
        node.location = fdg_sim::glam::Vec3::new(radius * angle.cos(), radius * angle.sin(), 0.0);
        node.old_location = node.location;
        node.velocity = fdg_sim::glam::Vec3::ZERO;
    }

    // Run simulation
    // Use reasonable iteration count for stable layout
    for _ in 0..500 {
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
    fn test_force_layout_empty_graph() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(0, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = force_directed_layout(&core);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), vec![]);
    }

    #[test]
    fn test_force_layout_single_node() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(1, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = force_directed_layout(&core);
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

        let result = force_directed_layout(&core);
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

        let result = force_directed_layout(&core);
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
    fn test_force_layout_deterministic() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        // Create A --> B --> C
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        // Run layout twice
        let result1 = force_directed_layout(&core);
        let result2 = force_directed_layout(&core);

        assert!(result1.is_ok());
        assert!(result2.is_ok());

        let coords1 = result1.unwrap();
        let coords2 = result2.unwrap();

        // Should be identical (deterministic)
        assert_eq!(coords1, coords2);
    }
}
