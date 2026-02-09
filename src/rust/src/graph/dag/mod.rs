// SPDX-License-Identifier: MIT
//! DAG wrapper with O(1) slice queries via packed neighborhoods.

mod adjustment;
mod transforms;

use super::error::DagError;
use super::packed::{PackedBuckets, PackedBucketsBuilder};
use super::CaugiGraph;
use crate::edges::EdgeClass;
use crate::graph::alg::bitset;
use crate::graph::alg::csr;
use crate::graph::alg::directed_part_is_acyclic;
use crate::graph::alg::moral;
use crate::graph::alg::topological_sort;
use crate::graph::alg::traversal;
use std::sync::Arc;

#[derive(Debug, Clone)]
pub struct Dag {
    core: Arc<CaugiGraph>,
    packed: PackedBuckets<2>, // [parents | children]
}

impl Dag {
    /// Builds a `Dag` view over a class-agnostic CSR graph.
    ///
    /// Validates that the directed part is acyclic and that every edge is directed.
    /// Parents and children for each node are stored contiguously and are sorted.
    ///
    /// Returns a `String` error for FFI compatibility. Use `try_new` for typed errors.
    pub fn new(core: Arc<CaugiGraph>) -> Result<Self, String> {
        Self::try_new(core).map_err(|e| e.to_string())
    }

    /// Builds a `Dag` view with typed error handling.
    ///
    /// See [`new`](Self::new) for details.
    pub fn try_new(core: Arc<CaugiGraph>) -> Result<Self, DagError> {
        let n = core.n() as usize;

        if !directed_part_is_acyclic(&core) {
            return Err(DagError::DirectedCycle);
        }

        let mut packed_builder: PackedBucketsBuilder<2> = PackedBucketsBuilder::new(n);

        // Count `(parents, children)` per row using mark helpers.
        // is_incoming_arrow(k) = Arrow points INTO me = neighbor is parent
        // is_outgoing_arrow(k) = Arrow points FROM me = neighbor is child
        for i in 0..n {
            for k in core.row_range(i as u32) {
                let spec = core.spec(k);
                match spec.class {
                    EdgeClass::Directed => {
                        if core.is_incoming_arrow(k) {
                            packed_builder.inc_degree(i, 0);
                        } else {
                            packed_builder.inc_degree(i, 1);
                        }
                    }
                    _ => {
                        return Err(DagError::InvalidEdgeType {
                            found: spec.glyph.clone(),
                        });
                    }
                }
            }
        }

        packed_builder.finalize_degrees();

        // Scatter pass.
        for i in 0..n {
            for k in core.row_range(i as u32) {
                let v = core.col_index[k];
                if core.is_incoming_arrow(k) {
                    packed_builder.scatter(i, 0, v);
                } else {
                    packed_builder.scatter(i, 1, v);
                }
            }
        }

        packed_builder.sort_all();
        let packed = packed_builder.build();

        Ok(Self { core, packed })
    }

    /// Number of nodes.
    #[inline]
    pub fn n(&self) -> u32 {
        self.core.n()
    }

    /// Sorted slice of parents of `i` (borrowed view into packed storage).
    #[inline]
    pub fn parents_of(&self, i: u32) -> &[u32] {
        self.packed.bucket_slice(i, 0)
    }

    /// Sorted slice of children of `i` (borrowed view into packed storage).
    #[inline]
    pub fn children_of(&self, i: u32) -> &[u32] {
        self.packed.bucket_slice(i, 1)
    }

    /// Concatenated neighbors `[parents..., children...]` of `i`.
    #[inline]
    pub fn neighbors_of(&self, i: u32) -> &[u32] {
        self.packed.all_neighbors(i)
    }

    /// All ancestors of `i`, returned in ascending order.
    #[inline]
    pub fn ancestors_of(&self, i: u32) -> Vec<u32> {
        traversal::ancestors_of(self.n(), i, |u| self.parents_of(u))
    }

    /// All descendants of `i`, returned in ascending order.
    #[inline]
    pub fn descendants_of(&self, i: u32) -> Vec<u32> {
        traversal::descendants_of(self.n(), i, |u| self.children_of(u))
    }

    /// All anteriors of `i`, returned in ascending order.
    ///
    /// For DAGs, the anterior set equals the ancestor set (no undirected edges).
    #[inline]
    pub fn anteriors_of(&self, i: u32) -> Vec<u32> {
        self.ancestors_of(i)
    }

    /// Markov blanket of `i`: `Pa(i) ∪ Ch(i) ∪ (⋃ Pa(c) \ {i : c∈Ch(i)})`.
    #[inline]
    pub fn markov_blanket_of(&self, i: u32) -> Vec<u32> {
        traversal::markov_blanket_dag(self.n(), i, |u| self.parents_of(u), |u| self.children_of(u))
    }

    /// Nodes with no parents.
    #[inline]
    pub fn exogenous_nodes(&self) -> Vec<u32> {
        (0..self.n())
            .filter(|&i| self.parents_of(i).is_empty())
            .collect()
    }

    /// Returns a topological ordering of the nodes.
    ///
    /// Since this is a valid DAG, all nodes will be included in the ordering.
    /// For every edge u -> v, u will appear before v in the returned vector.
    #[inline]
    pub fn topological_sort(&self) -> Vec<u32> {
        topological_sort(&self.core)
    }

    /// Access the underlying CSR.
    pub fn core_ref(&self) -> &CaugiGraph {
        &self.core
    }
}

// -------- Internal helpers for masks and graph operations --------
impl Dag {
    /// Ancestors mask of a seed set. `a[v] == true` iff `v ∈ An(seeds) ∪ seeds`.
    pub(crate) fn ancestors_mask(&self, seeds: &[u32]) -> Vec<bool> {
        bitset::ancestors_mask(seeds, |u| self.parents_of(u), self.n())
    }

    /// Descendants mask of a seed set. `d[v] == true` iff `v ∈ De(seeds) ∪ seeds`.
    pub(crate) fn descendants_mask(&self, seeds: &[u32]) -> Vec<bool> {
        bitset::descendants_mask(seeds, |u| self.children_of(u), self.n())
    }

    /// Moralized adjacency within mask. Undirected edges among ancestors.
    pub(crate) fn moral_adj(&self, mask: &[bool]) -> Vec<Vec<u32>> {
        moral::moral_adj(self.n(), |u| self.parents_of(u), mask)
    }

    /// Backward reachability through parents from every `y ∈ ys`.
    pub(crate) fn can_reach_any_y(&self, ys: &[u32]) -> Vec<bool> {
        let mut r = vec![false; self.n() as usize];
        let mut st = ys.to_vec();
        while let Some(v) = st.pop() {
            let vi = v as usize;
            if r[vi] {
                continue;
            }
            r[vi] = true;
            st.extend_from_slice(self.parents_of(v));
        }
        r
    }

    /// Drop predicate for removing the first edge on each proper causal path.
    /// Uses mark-based direction: is_outgoing_arrow means row_u -> v.
    pub(crate) fn drop_first_edge(
        &self,
        xs_mask: &[bool],
        reach_y: &[bool],
        row_u: u32,
        k: usize,
    ) -> bool {
        let c = self.core_ref();
        let v = c.col_index[k];
        if c.is_outgoing_arrow(k) {
            // edge row_u -> v (Arrow points FROM me toward neighbor)
            // Drop if row_u is in X and v can reach Y
            xs_mask[row_u as usize] && reach_y[v as usize]
        } else {
            // edge v -> row_u (Arrow points INTO me)
            // Drop if v is in X and row_u can reach Y
            xs_mask[v as usize] && reach_y[row_u as usize]
        }
    }

    /// Rebuild a filtered CSR by dropping edges selected by predicate `drop(u, k)`.
    pub(crate) fn rebuild_filtered<F: FnMut(u32, usize) -> bool>(
        &self,
        mut drop: F,
    ) -> Result<CaugiGraph, String> {
        csr::filter_edges(self.core_ref(), |u, k, _c| !drop(u, k))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    #[test]
    fn dag_relations() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(0, 2, cdir).unwrap();
        b.add_edge(3, 0, cdir).unwrap();

        let core = std::sync::Arc::new(b.finalize().unwrap());
        let dag = Dag::new(core).expect("Dag construction failed");
        assert_eq!(dag.children_of(0), vec![1, 2]);
        assert_eq!(dag.parents_of(0), vec![3]);
        assert_eq!(dag.parents_of(1), vec![0]);
        assert!(dag.children_of(1).is_empty());
        assert_eq!(dag.children_of(3), vec![0]);
        assert_eq!(dag.neighbors_of(0), vec![3, 1, 2]);
        assert_eq!(dag.neighbors_of(1), vec![0]);
        assert_eq!(dag.neighbors_of(2), vec![0]);
        assert_eq!(dag.neighbors_of(3), vec![0]);
        assert_eq!(dag.n(), 4);

        let core = dag.core_ref();
        assert_eq!(core.n(), 4);
    }

    #[test]
    fn dag_an_de() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let c = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(3, 0, c).unwrap();
        b.add_edge(0, 1, c).unwrap();
        b.add_edge(0, 2, c).unwrap();
        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(g.ancestors_of(0), vec![3]);
        assert_eq!(g.descendants_of(0), vec![1, 2]);
        assert_eq!(g.ancestors_of(2), vec![0, 3]);
        assert_eq!(g.descendants_of(3), vec![0, 1, 2]);
    }

    #[test]
    fn dag_mb() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(4, true, &r);
        b.add_edge(2, 1, d).unwrap();
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(0, 3, d).unwrap();
        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(g.markov_blanket_of(0), vec![1, 2, 3]);
    }

    #[test]
    fn dag_cycle_rejected() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cdir).unwrap();
        b.add_edge(2, 0, cdir).unwrap();
        let core = std::sync::Arc::new(b.finalize().unwrap());
        let dag = Dag::new(core);
        assert!(dag.is_err());
    }

    #[test]
    fn dag_non_directed_rejected() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();
        let cund = reg.code_of("<->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cund).unwrap();
        let core = std::sync::Arc::new(b.finalize().unwrap());
        let dag = Dag::new(core);
        assert!(dag.is_err());
    }

    #[test]
    fn dag_exogenous() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(4, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(0, 2, d).unwrap();
        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(g.exogenous_nodes(), vec![0, 3]);
    }

    #[test]
    fn dag_descendants_seen_continue_path() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(1, 3, d).unwrap();
        b.add_edge(2, 3, d).unwrap();

        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(g.descendants_of(0), vec![1, 2, 3]);
    }

    #[test]
    fn dag_topological_sort() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // Diamond: 0 -> 1, 0 -> 2, 1 -> 3, 2 -> 3
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(1, 3, d).unwrap();
        b.add_edge(2, 3, d).unwrap();

        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        let order = g.topological_sort();

        // All 4 nodes should be in the order
        assert_eq!(order.len(), 4);

        // Check ordering constraints
        let pos: std::collections::HashMap<u32, usize> =
            order.iter().enumerate().map(|(i, &v)| (v, i)).collect();
        assert!(pos[&0] < pos[&1]); // 0 -> 1
        assert!(pos[&0] < pos[&2]); // 0 -> 2
        assert!(pos[&1] < pos[&3]); // 1 -> 3
        assert!(pos[&2] < pos[&3]); // 2 -> 3
    }
}
