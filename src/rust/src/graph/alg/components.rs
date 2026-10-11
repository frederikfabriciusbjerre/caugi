// SPDX-License-Identifier: MIT
//! Weak connectivity and strong connectivity of the directed part.

use crate::edges::EdgeClass;
use crate::graph::CaugiGraph;

/// Select connectivity across all edges or mutual directed reachability.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ComponentMode {
    Weak,
    Strong,
}

/// Partition nodes in O(V + E) time and O(V) auxiliary space.
///
/// Weak connectivity ignores all endpoint marks. Strong connectivity uses only
/// fully directed edges. Nodes and components follow the original node order.
/// The CSR core stores both half-edges, so reverse traversal needs no new index.
pub fn components(core: &CaugiGraph, mode: ComponentMode) -> Vec<Vec<u32>> {
    let n = core.n() as usize;
    let mut labels = vec![usize::MAX; n];
    let mut count = 0;

    match mode {
        ComponentMode::Weak => {
            let mut stack = Vec::new();
            for start in 0..n {
                if labels[start] != usize::MAX {
                    continue;
                }
                labels[start] = count;
                stack.push(start as u32);
                while let Some(u) = stack.pop() {
                    for k in core.row_range(u) {
                        let v = core.col_index[k] as usize;
                        if labels[v] == usize::MAX {
                            labels[v] = count;
                            stack.push(v as u32);
                        }
                    }
                }
                count += 1;
            }
        }
        ComponentMode::Strong => {
            let mut seen = vec![false; n];
            let mut finish = Vec::with_capacity(n);
            let mut dfs = Vec::new();

            // Explicit DFS frames avoid overflowing the call stack on long paths.
            for start in 0..n {
                if seen[start] {
                    continue;
                }
                seen[start] = true;
                dfs.push((start as u32, core.row_range(start as u32).start));
                while let Some((u, next)) = dfs.last_mut() {
                    if *next == core.row_range(*u).end {
                        finish.push(*u);
                        dfs.pop();
                        continue;
                    }
                    let k = *next;
                    *next += 1;
                    if is_directed(core, k) && core.is_outgoing_arrow(k) {
                        let v = core.col_index[k];
                        if !seen[v as usize] {
                            seen[v as usize] = true;
                            dfs.push((v, core.row_range(v).start));
                        }
                    }
                }
            }

            let mut stack = Vec::new();
            for &start in finish.iter().rev() {
                if labels[start as usize] != usize::MAX {
                    continue;
                }
                labels[start as usize] = count;
                stack.push(start);
                while let Some(u) = stack.pop() {
                    for k in core.row_range(u) {
                        if is_directed(core, k) && core.is_incoming_arrow(k) {
                            let v = core.col_index[k] as usize;
                            if labels[v] == usize::MAX {
                                labels[v] = count;
                                stack.push(v as u32);
                            }
                        }
                    }
                }
                count += 1;
            }
        }
    }

    // Scanning node IDs normalizes the result without a comparison sort.
    let mut groups: Vec<Vec<u32>> = Vec::with_capacity(count);
    let mut normalized = vec![usize::MAX; count];
    for (node, label) in labels.into_iter().enumerate() {
        if normalized[label] == usize::MAX {
            normalized[label] = groups.len();
            groups.push(Vec::new());
        }
        groups[normalized[label]].push(node as u32);
    }
    groups
}

fn is_directed(core: &CaugiGraph, k: usize) -> bool {
    matches!(core.spec(k).class, EdgeClass::Directed)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::{EdgeRegistry, EdgeSpec, Mark};
    use crate::graph::builder::GraphBuilder;

    fn graph(n: u32, edges: &[(u32, u32, &str)]) -> CaugiGraph {
        let mut registry = EdgeRegistry::new();
        registry.register_builtins().unwrap();
        registry
            .register(EdgeSpec {
                glyph: "<--".into(),
                tail: Mark::Arrow,
                head: Mark::Tail,
                symmetric: false,
                class: EdgeClass::Directed,
            })
            .unwrap();
        let mut builder = GraphBuilder::new(n, false, &registry);
        for &(u, v, glyph) in edges {
            builder
                .add_edge(u, v, registry.code_of(glyph).unwrap())
                .unwrap();
        }
        builder.finalize().unwrap()
    }

    #[test]
    fn empty_and_isolated_nodes() {
        for mode in [ComponentMode::Weak, ComponentMode::Strong] {
            assert!(components(&graph(0, &[]), mode).is_empty());
            assert_eq!(
                components(&graph(3, &[]), mode),
                vec![vec![0], vec![1], vec![2]]
            );
        }
    }

    #[test]
    fn cycles_with_one_way_bridge_and_reverse_glyph() {
        let core = graph(
            7,
            &[
                (0, 2, "-->"),
                (2, 4, "-->"),
                (0, 4, "<--"),
                (4, 1, "-->"),
                (1, 3, "-->"),
                (3, 5, "-->"),
                (5, 1, "-->"),
            ],
        );
        assert_eq!(
            components(&core, ComponentMode::Weak),
            vec![vec![0, 1, 2, 3, 4, 5], vec![6]]
        );
        assert_eq!(
            components(&core, ComponentMode::Strong),
            vec![vec![0, 2, 4], vec![1, 3, 5], vec![6]]
        );
    }

    #[test]
    fn mixed_edges_only_connect_weakly() {
        let core = graph(
            7,
            &[
                (0, 1, "-->"),
                (2, 1, "-->"),
                (2, 3, "---"),
                (3, 4, "<->"),
                (4, 5, "o->"),
                (5, 6, "--o"),
                (6, 0, "o-o"),
            ],
        );
        assert_eq!(
            components(&core, ComponentMode::Weak),
            vec![(0..7).collect::<Vec<u32>>()]
        );
        assert_eq!(
            components(&core, ComponentMode::Strong),
            (0..7).map(|i| vec![i]).collect::<Vec<_>>()
        );
    }

    #[test]
    fn self_loops_and_parallel_edges() {
        let core = graph(
            3,
            &[(0, 0, "-->"), (0, 1, "-->"), (0, 1, "<->"), (1, 0, "-->")],
        );
        for mode in [ComponentMode::Weak, ComponentMode::Strong] {
            assert_eq!(components(&core, mode), vec![vec![0, 1], vec![2]]);
        }
    }

    #[test]
    fn long_path_does_not_recurse() {
        let n = 20_000;
        let edges: Vec<_> = (1..n).map(|i| (i - 1, i, "-->")).collect();
        let core = graph(n, &edges);
        assert_eq!(
            components(&core, ComponentMode::Weak),
            vec![(0..n).collect::<Vec<_>>()]
        );
        assert_eq!(components(&core, ComponentMode::Strong).len(), n as usize);
    }
}
