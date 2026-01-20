// SPDX-License-Identifier: MIT
//! Topological sorting for graphs with directed edges.

use crate::edges::{EdgeClass, Mark};
use crate::graph::CaugiGraph;

/// Returns a topological ordering of the directed part of the graph using Kahn's algorithm.
///
/// Only considers directed edges; undirected/bidirected edges are ignored.
/// If the directed part contains a cycle, the returned vector will have fewer
/// than `n` elements (where `n` is the number of nodes).
///
/// # Returns
/// A vector of node indices in topological order. If the graph is acyclic,
/// the vector contains all `n` nodes. If there is a cycle, the vector contains
/// only the nodes that could be processed before the cycle was detected.
pub fn topological_sort(core: &CaugiGraph) -> Vec<u32> {
    let n = core.n() as usize;
    if n == 0 {
        return Vec::new();
    }

    let mut indeg = vec![0usize; n];

    // Compute in-degree: count incoming directed edges.
    // side[k] stores position: 0 = tail position, 1 = head position.
    // An edge is incoming if my mark is Arrow (arrow points INTO me).
    for i in 0..n {
        for k in core.row_range(i as u32) {
            let spec = &core.registry.specs[core.etype[k] as usize];
            if matches!(spec.class, EdgeClass::Directed) {
                let my_mark = if core.side[k] == 0 {
                    spec.tail
                } else {
                    spec.head
                };
                if my_mark == Mark::Arrow {
                    indeg[i] += 1;
                }
            }
        }
    }

    // Initialize with nodes having no incoming directed edges
    let mut queue: Vec<usize> = (0..n).filter(|&i| indeg[i] == 0).collect();
    let mut result: Vec<u32> = Vec::with_capacity(n);

    while let Some(u) = queue.pop() {
        result.push(u as u32);

        // Process outgoing directed edges from u.
        // An edge is outgoing if neighbor's mark is Arrow (arrow points INTO neighbor).
        for k in core.row_range(u as u32) {
            let spec = &core.registry.specs[core.etype[k] as usize];
            if matches!(spec.class, EdgeClass::Directed) {
                let neighbor_mark = if core.side[k] == 0 {
                    spec.head
                } else {
                    spec.tail
                };
                if neighbor_mark == Mark::Arrow {
                    // u -> v (outgoing edge)
                    let v = core.col_index[k] as usize;
                    indeg[v] -= 1;
                    if indeg[v] == 0 {
                        queue.push(v);
                    }
                }
            }
        }
    }

    result
}

#[cfg(test)]
mod tests {
    use super::topological_sort;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    #[test]
    fn empty_graph() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();

        let b = GraphBuilder::new(0, true, &reg);
        let g = b.finalize().unwrap();

        let order = topological_sort(&g);
        assert!(order.is_empty());
    }

    #[test]
    fn single_node() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();

        let b = GraphBuilder::new(1, true, &reg);
        let g = b.finalize().unwrap();

        let order = topological_sort(&g);
        assert_eq!(order, vec![0]);
    }

    #[test]
    fn simple_chain() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let code = reg.code_of("-->").unwrap();

        // 0 -> 1 -> 2
        let mut b = GraphBuilder::new(3, true, &reg);
        b.add_edge(0, 1, code).unwrap();
        b.add_edge(1, 2, code).unwrap();
        let g = b.finalize().unwrap();

        let order = topological_sort(&g);
        assert_eq!(order.len(), 3);
        // 0 must come before 1, 1 must come before 2
        let pos: std::collections::HashMap<u32, usize> =
            order.iter().enumerate().map(|(i, &v)| (v, i)).collect();
        assert!(pos[&0] < pos[&1]);
        assert!(pos[&1] < pos[&2]);
    }

    #[test]
    fn diamond_dag() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let code = reg.code_of("-->").unwrap();

        // Diamond: 0 -> 1, 0 -> 2, 1 -> 3, 2 -> 3
        let mut b = GraphBuilder::new(4, true, &reg);
        b.add_edge(0, 1, code).unwrap();
        b.add_edge(0, 2, code).unwrap();
        b.add_edge(1, 3, code).unwrap();
        b.add_edge(2, 3, code).unwrap();
        let g = b.finalize().unwrap();

        let order = topological_sort(&g);
        assert_eq!(order.len(), 4);
        let pos: std::collections::HashMap<u32, usize> =
            order.iter().enumerate().map(|(i, &v)| (v, i)).collect();
        // 0 must come before 1 and 2; 1 and 2 must come before 3
        assert!(pos[&0] < pos[&1]);
        assert!(pos[&0] < pos[&2]);
        assert!(pos[&1] < pos[&3]);
        assert!(pos[&2] < pos[&3]);
    }

    #[test]
    fn cycle_returns_partial() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let code = reg.code_of("-->").unwrap();

        // Cycle: 0 -> 1 -> 2 -> 0
        let mut b = GraphBuilder::new(3, false, &reg);
        b.add_edge(0, 1, code).unwrap();
        b.add_edge(1, 2, code).unwrap();
        b.add_edge(2, 0, code).unwrap();
        let g = b.finalize().unwrap();

        let order = topological_sort(&g);
        // All nodes have in-degree > 0, so nothing can be processed
        assert!(order.is_empty());
    }

    #[test]
    fn partial_cycle() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let code = reg.code_of("-->").unwrap();

        // 0 -> 1 -> 2 -> 1 (cycle between 1 and 2), node 3 is separate
        let mut b = GraphBuilder::new(4, false, &reg);
        b.add_edge(0, 1, code).unwrap();
        b.add_edge(1, 2, code).unwrap();
        b.add_edge(2, 1, code).unwrap();
        b.add_edge(0, 3, code).unwrap();
        let g = b.finalize().unwrap();

        let order = topological_sort(&g);
        // Only nodes 0 and 3 can be processed (no incoming edges initially)
        assert_eq!(order.len(), 2);
        assert!(order.contains(&0));
        assert!(order.contains(&3));
    }

    #[test]
    fn ignores_undirected_edges() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let dir = reg.code_of("-->").unwrap();
        let und = reg.code_of("---").unwrap();

        // 0 -> 1, 1 --- 2 (undirected), 2 -> 3
        let mut b = GraphBuilder::new(4, true, &reg);
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(1, 2, und).unwrap();
        b.add_edge(2, 3, dir).unwrap();
        let g = b.finalize().unwrap();

        let order = topological_sort(&g);
        assert_eq!(order.len(), 4);
        let pos: std::collections::HashMap<u32, usize> =
            order.iter().enumerate().map(|(i, &v)| (v, i)).collect();
        assert!(pos[&0] < pos[&1]);
        assert!(pos[&2] < pos[&3]);
    }

    #[test]
    fn ignores_bidirected_edges() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let dir = reg.code_of("-->").unwrap();
        let bi = reg.code_of("<->").unwrap();

        // 0 -> 1 -> 2, 0 <-> 2 (bidirected)
        let mut b = GraphBuilder::new(3, true, &reg);
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(1, 2, dir).unwrap();
        b.add_edge(0, 2, bi).unwrap();
        let g = b.finalize().unwrap();

        let order = topological_sort(&g);
        assert_eq!(order.len(), 3);
        let pos: std::collections::HashMap<u32, usize> =
            order.iter().enumerate().map(|(i, &v)| (v, i)).collect();
        assert!(pos[&0] < pos[&1]);
        assert!(pos[&1] < pos[&2]);
    }

    #[test]
    fn isolated_nodes() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let code = reg.code_of("-->").unwrap();

        // Nodes 0, 1, 2 with only edge 0 -> 1; node 2 is isolated
        let mut b = GraphBuilder::new(3, true, &reg);
        b.add_edge(0, 1, code).unwrap();
        let g = b.finalize().unwrap();

        let order = topological_sort(&g);
        assert_eq!(order.len(), 3);
        let pos: std::collections::HashMap<u32, usize> =
            order.iter().enumerate().map(|(i, &v)| (v, i)).collect();
        assert!(pos[&0] < pos[&1]);
        // Node 2 can appear anywhere
        assert!(pos.contains_key(&2));
    }
}
