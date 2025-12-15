// SPDX-License-Identifier: MIT
//! Sugiyama hierarchical layout algorithm.

use crate::graph::CaugiGraph;

pub fn sugiyama_layout(graph: &CaugiGraph) -> Result<Vec<(f64, f64)>, String> {
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use std::sync::Arc;

    #[test]
    fn test_sugiyama_empty_graph() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(0, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = sugiyama_layout(&core);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), vec![]);
    }

    #[test]
    fn test_sugiyama_single_node() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(1, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = sugiyama_layout(&core);
        assert!(result.is_ok());
        let coords = result.unwrap();
        assert_eq!(coords.len(), 1);
        assert!(coords[0].0.is_finite());
        assert!(coords[0].1.is_finite());
    }

    #[test]
    fn test_sugiyama_simple_dag() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        // Create A --> B --> C
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        let result = sugiyama_layout(&core);
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
    fn test_sugiyama_diamond_dag() {
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

        let result = sugiyama_layout(&core);
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
    fn test_sugiyama_with_undirected_edges() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();
        let cund = reg.code_of("---").unwrap();

        // Create A --> B --- C (undirected edges should be ignored)
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cund).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        let result = sugiyama_layout(&core);
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
