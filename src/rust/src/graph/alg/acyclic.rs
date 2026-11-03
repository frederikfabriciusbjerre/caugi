// SPDX-License-Identifier: MIT
//! Acyclicity testing for graphs.

use super::topo_sort::topological_sort;
use crate::edges::EdgeClass;
use crate::graph::CaugiGraph;

/// Returns true iff the directed part of the graph is acyclic.
/// Ignores undirected/partial/bidirected edges.
///
/// This is implemented by running topological sort and checking if all nodes
/// were processed. If the directed part contains a cycle, topological sort
/// will not be able to process all nodes.
pub fn directed_part_is_acyclic(core: &CaugiGraph) -> bool {
    let n = core.n() as usize;
    // Empty graphs are trivially acyclic
    if n == 0 {
        return true;
    }
    topological_sort(core).len() == n
}

/// A directed cycle `[v, ..., v]` in the directed part, starting at its lowest
/// node, or `None` if the directed part is acyclic.
pub fn find_directed_cycle(core: &CaugiGraph) -> Option<Vec<u32>> {
    let n = core.n() as usize;
    let mut left = vec![true; n];
    for v in topological_sort(core) {
        left[v as usize] = false;
    }
    // Every node the sort could not place has a parent it could not place
    // either, so walking to parents from one of them repeats a node.
    let mut v = (0..n).find(|&v| left[v])? as u32;
    let mut seen_at = vec![usize::MAX; n];
    let mut walk = Vec::new();
    while seen_at[v as usize] == usize::MAX {
        seen_at[v as usize] = walk.len();
        walk.push(v);
        v = core
            .row_range(v)
            .find(|&k| {
                core.spec(k).class == EdgeClass::Directed
                    && core.is_incoming_arrow(k)
                    && left[core.col_index[k] as usize]
            })
            .map(|k| core.col_index[k])
            .unwrap();
    }
    // The walk ran against the arrows.
    let mut cycle = walk.split_off(seen_at[v as usize]);
    cycle.reverse();
    let lowest = (0..cycle.len()).min_by_key(|&i| cycle[i]).unwrap();
    cycle.rotate_left(lowest);
    cycle.push(cycle[0]);
    Some(cycle)
}

#[cfg(test)]
mod tests {
    use super::{directed_part_is_acyclic, find_directed_cycle};
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    #[test]
    fn empty_stack_when_every_node_has_incoming_directed() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let code = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new(2, false, &reg);
        b.add_edge(0, 1, code).unwrap();
        b.add_edge(1, 0, code).unwrap();
        let g = b.finalize().unwrap();

        assert!(!directed_part_is_acyclic(&g));
        assert_eq!(find_directed_cycle(&g), Some(vec![0, 1, 0]));
    }

    #[test]
    fn find_directed_cycle_skips_acyclic_parts() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // 0 -> 1 -> 2 -> 3 -> 1, 3 -> 4: the cycle is 1 -> 2 -> 3 -> 1.
        let mut b = GraphBuilder::new(5, true, &reg);
        for (u, v) in [(0, 1), (1, 2), (2, 3), (3, 1), (3, 4)] {
            b.add_edge(u, v, d).unwrap();
        }
        let g = b.finalize().unwrap();
        assert_eq!(find_directed_cycle(&g), Some(vec![1, 2, 3, 1]));

        let mut b = GraphBuilder::new(2, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        assert_eq!(find_directed_cycle(&b.finalize().unwrap()), None);
    }

    #[test]
    fn directed_part_is_acyclic_ignores_undirected_and_bidirected() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let dir = reg.code_of("-->").unwrap();
        let und = reg.code_of("---").unwrap();
        let bi = reg.code_of("<->").unwrap();

        // Directed part is a DAG: 0 -> 1 -> 2
        let mut b = GraphBuilder::new(3, false, &reg);
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(1, 2, dir).unwrap();
        // Add an undirected 2-cycle and a bidirected edge; should be ignored by acyclicity
        b.add_edge(0, 2, und).unwrap();
        b.add_edge(2, 0, bi).unwrap();
        let g = b.finalize().unwrap();

        assert!(directed_part_is_acyclic(&g));
    }
}
