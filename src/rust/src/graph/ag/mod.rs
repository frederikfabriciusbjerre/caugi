// SPDX-License-Identifier: MIT
//! Ancestral Graph (AG) wrapper with O(1) slice queries via packed neighborhoods.
//!
//! An ancestral graph contains:
//! - Directed edges (-->) representing direct causal effects
//! - Bidirected edges (<->) representing latent confounding
//! - Undirected edges (---) representing selection or uncertain orientation
//!
//! An ancestral graph must satisfy three constraints:
//! 1. No directed cycles
//! 2. If there is an arrowhead at v from u, then v is not an anterior of u
//! 3. If v is an endpoint of an undirected edge, v has no edge with arrowhead at v

mod msep;

use super::error::AgError;
use super::packed::{PackedBuckets, PackedBucketsBuilder};
use super::CaugiGraph;
use crate::edges::EdgeClass;
use crate::graph::alg::bitset;
use crate::graph::alg::directed_part_is_acyclic;
use crate::graph::alg::traversal;
use std::sync::Arc;

#[derive(Debug, Clone)]
pub struct Ag {
    core: Arc<CaugiGraph>,
    /// packed as [parents | undirected | spouses | children] for each node
    packed: PackedBuckets<4>,
}

impl Ag {
    /// Builds an `Ag` view over a class-agnostic CSR graph.
    ///
    /// Validates that:
    /// 1. The directed part is acyclic
    /// 2. Only directed, bidirected, and undirected edges are present
    /// 3. Anterior constraint: if arrowhead at v from u, v is not anterior of u
    /// 4. Undirected constraint: if v has undirected edge, v has no arrowhead edges
    ///
    /// Parents, undirected neighbors, spouses, and children for each node are stored
    /// contiguously and sorted.
    ///
    /// Returns a `String` error for FFI compatibility. Use `try_new` for typed errors.
    pub fn new(core: Arc<CaugiGraph>) -> Result<Self, String> {
        Self::try_new(core).map_err(|e| e.to_string())
    }

    /// Builds an `Ag` view with typed error handling.
    ///
    /// See [`new`](Self::new) for details.
    pub fn try_new(core: Arc<CaugiGraph>) -> Result<Self, AgError> {
        let n = core.n() as usize;

        // Check acyclicity of directed part
        if !directed_part_is_acyclic(&core) {
            return Err(AgError::DirectedCycle);
        }

        let mut packed_builder: PackedBucketsBuilder<4> = PackedBucketsBuilder::new(n);

        // Count (parents, undirected, spouses, children) per node using mark helpers.
        // is_incoming_arrow(k) = Arrow points INTO me = neighbor is parent
        // Track which nodes have undirected edges and which have arrowhead edges
        let mut has_undirected = vec![false; n];
        let mut has_arrowhead = vec![false; n];

        for i in 0..n {
            for k in core.row_range(i as u32) {
                let spec = core.spec(k);
                match spec.class {
                    EdgeClass::Directed => {
                        if core.is_incoming_arrow(k) {
                            packed_builder.inc_degree(i, 0);
                            has_arrowhead[i] = true;
                        } else {
                            packed_builder.inc_degree(i, 3);
                        }
                    }
                    EdgeClass::Undirected => {
                        packed_builder.inc_degree(i, 1);
                        has_undirected[i] = true;
                    }
                    EdgeClass::Bidirected => {
                        packed_builder.inc_degree(i, 2);
                        has_arrowhead[i] = true;
                    }
                    _ => {
                        return Err(AgError::InvalidEdgeType {
                            found: spec.glyph.clone(),
                        });
                    }
                }
            }
        }

        // Check undirected constraint: if node has undirected edge, it can't have arrowhead
        for i in 0..n {
            if has_undirected[i] && has_arrowhead[i] {
                return Err(AgError::UndirectedConstraintViolation { node: i as u32 });
            }
        }

        packed_builder.finalize_degrees();

        // Scatter pass using mark helpers
        for i in 0..n {
            for k in core.row_range(i as u32) {
                let spec = core.spec(k);
                match spec.class {
                    EdgeClass::Directed => {
                        if core.is_incoming_arrow(k) {
                            packed_builder.scatter(i, 0, core.col_index[k]);
                        } else {
                            packed_builder.scatter(i, 3, core.col_index[k]);
                        }
                    }
                    EdgeClass::Undirected => {
                        packed_builder.scatter(i, 1, core.col_index[k]);
                    }
                    EdgeClass::Bidirected => {
                        packed_builder.scatter(i, 2, core.col_index[k]);
                    }
                    _ => unreachable!("Should have errored on invalid edges earlier"),
                }
            }
        }

        packed_builder.sort_all();
        let packed = packed_builder.build();

        let ag = Self { core, packed };

        // Check anterior constraint: for each edge with arrowhead at v from u,
        // v must not be an anterior of u
        ag.validate_anterior_constraint()?;

        Ok(ag)
    }

    /// Validate the anterior constraint for all edges.
    fn validate_anterior_constraint(&self) -> Result<(), AgError> {
        let n = self.n();
        for v in 0..n {
            // Check directed edges pointing into v (v's parents)
            for &u in self.parents_of(v) {
                // v has arrowhead from u, check that v is not anterior of u
                if self.is_anterior_of(v, u) {
                    return Err(AgError::AnteriorConstraintViolation {
                        source: u,
                        target: v,
                    });
                }
            }
            // Check bidirected edges (spouses) - both ends have arrowheads
            for &u in self.spouses_of(v) {
                // Only check once (when v < u to avoid duplicate checks)
                if v < u {
                    // Check both directions
                    if self.is_anterior_of(v, u) {
                        return Err(AgError::AnteriorConstraintViolation {
                            source: u,
                            target: v,
                        });
                    }
                    if self.is_anterior_of(u, v) {
                        return Err(AgError::AnteriorConstraintViolation {
                            source: v,
                            target: u,
                        });
                    }
                }
            }
        }
        Ok(())
    }

    /// Check if `v` is an anterior of `u`.
    /// Anteriors are reachable via undirected edges or directed edges pointing toward.
    fn is_anterior_of(&self, v: u32, u: u32) -> bool {
        if v == u {
            return true;
        }
        let anteriors = self.anteriors_of(u);
        anteriors.binary_search(&v).is_ok()
    }

    /// Number of nodes.
    #[inline]
    pub fn n(&self) -> u32 {
        self.core.n()
    }

    /// Sorted slice of parents of `i` (nodes with directed edge into `i`).
    #[inline]
    pub fn parents_of(&self, i: u32) -> &[u32] {
        self.packed.bucket_slice(i, 0)
    }

    /// Sorted slice of children of `i` (nodes with directed edge from `i`).
    #[inline]
    pub fn children_of(&self, i: u32) -> &[u32] {
        self.packed.bucket_slice(i, 3)
    }

    /// Sorted slice of undirected neighbors of `i`.
    #[inline]
    pub fn undirected_of(&self, i: u32) -> &[u32] {
        self.packed.bucket_slice(i, 1)
    }

    /// Sorted slice of spouses of `i` (nodes connected via bidirected edge).
    #[inline]
    pub fn spouses_of(&self, i: u32) -> &[u32] {
        self.packed.bucket_slice(i, 2)
    }

    /// All neighbors of `i`: [parents | undirected | spouses | children].
    #[inline]
    pub fn neighbors_of(&self, i: u32) -> &[u32] {
        self.packed.all_neighbors(i)
    }

    /// All ancestors of `i` via directed edges, returned in ascending order.
    #[inline]
    pub fn ancestors_of(&self, i: u32) -> Vec<u32> {
        traversal::ancestors_of(self.n(), i, |u| self.parents_of(u))
    }

    /// All descendants of `i` via directed edges, returned in ascending order.
    #[inline]
    pub fn descendants_of(&self, i: u32) -> Vec<u32> {
        traversal::descendants_of(self.n(), i, |u| self.children_of(u))
    }

    /// All anteriors of `i` (reachable via undirected or directed-into edges).
    #[inline]
    pub fn anteriors_of(&self, i: u32) -> Vec<u32> {
        traversal::anteriors_of(
            self.n(),
            i,
            |u| self.parents_of(u),
            |u| self.undirected_of(u),
        )
    }

    /// All posteriors of `i` (reachable via undirected or directed-out edges).
    #[inline]
    pub fn posteriors_of(&self, i: u32) -> Vec<u32> {
        traversal::posteriors_of(
            self.n(),
            i,
            |u| self.children_of(u),
            |u| self.undirected_of(u),
        )
    }

    /// Markov blanket of `i`: nodes joined to it by a collider path.
    #[inline]
    pub fn markov_blanket_of(&self, i: u32) -> Vec<u32> {
        traversal::collider_connected(
            self.n(),
            i,
            |u| self.parents_of(u),
            |u| self.children_of(u),
            |u| self.spouses_of(u),
            |u| self.undirected_of(u),
        )
    }

    /// District (c-component) containing node `i`.
    /// The district is the set of nodes reachable via bidirected edges.
    pub fn district_of(&self, i: u32) -> Vec<u32> {
        let n = self.n() as usize;
        let mut seen = vec![false; n];
        let mut stack = vec![i];
        while let Some(u) = stack.pop() {
            let ui = u as usize;
            if std::mem::replace(&mut seen[ui], true) {
                continue;
            }
            for &s in self.spouses_of(u) {
                if !seen[s as usize] {
                    stack.push(s);
                }
            }
        }
        bitset::collect_from_mask(&seen)
    }

    /// All districts (c-components) in the graph.
    pub fn districts(&self) -> Vec<Vec<u32>> {
        let n = self.n() as usize;
        let mut seen = vec![false; n];
        let mut result = Vec::new();

        for start in 0..n {
            if seen[start] {
                continue;
            }
            let district = self.district_of(start as u32);
            for &node in &district {
                seen[node as usize] = true;
            }
            result.push(district);
        }
        result
    }

    /// Number of districts (c-components).
    pub fn num_districts(&self) -> usize {
        self.districts().len()
    }

    /// Nodes with no parents (exogenous in directed sense).
    #[inline]
    pub fn exogenous_nodes(&self) -> Vec<u32> {
        (0..self.n())
            .filter(|&i| self.parents_of(i).is_empty())
            .collect()
    }

    /// Access the underlying CSR.
    pub fn core_ref(&self) -> &CaugiGraph {
        &self.core
    }

    /// Check if this graph is a valid ancestral graph.
    /// Since construction validates all constraints, this always returns true for a constructed Ag.
    pub fn is_ag(&self) -> bool {
        true
    }

    /// Check if two nodes are adjacent (connected by any edge).
    pub fn adjacent(&self, a: u32, b: u32) -> bool {
        // `neighbors_of` concatenates four individually-sorted buckets, so the
        // combined slice is not globally sorted and cannot be binary-searched.
        // Search each sorted bucket separately instead.
        self.parents_of(a).binary_search(&b).is_ok()
            || self.children_of(a).binary_search(&b).is_ok()
            || self.spouses_of(a).binary_search(&b).is_ok()
            || self.undirected_of(a).binary_search(&b).is_ok()
    }

    /// Check if this ancestral graph is maximal (MAG).
    ///
    /// A maximal ancestral graph (MAG) is an ancestral graph where no additional
    /// edge can be added without either:
    /// 1. Violating the ancestral graph constraints, OR
    /// 2. Changing the encoded independence model
    ///
    /// For each non-adjacent pair (u, v), if they are not m-separated given any
    /// subset of the remaining nodes, then an edge could be added, making the
    /// graph non-maximal. One m-separation test per pair decides this, so the
    /// check is polynomial.
    pub fn is_mag(&self) -> bool {
        // A pair with no separating set has an inducing path (Richardson and
        // Spirtes 2002, Corollary 4.3), and every interior vertex of one is a
        // collider. So the interior lies in one district D (consecutive
        // colliders are joined by `<->`), and both ends point into it: they
        // are in D or pa(D). Only such pairs need a test.
        let mut tested = std::collections::HashSet::new();
        for district in self.districts() {
            let mut ends: Vec<u32> = district
                .iter()
                .flat_map(|&d| self.parents_of(d).iter().copied())
                .chain(district.iter().copied())
                .collect();
            ends.sort_unstable();
            ends.dedup();
            for (k, &u) in ends.iter().enumerate() {
                for &v in &ends[k + 1..] {
                    if !self.adjacent(u, v)
                        && tested.insert((u, v))
                        && !self.has_separating_set(u, v)
                    {
                        return false;
                    }
                }
            }
        }
        true
    }

    /// Is there any set that m-separates `u` and `v`?
    ///
    /// Richardson and Spirtes (2002), Theorem 4.2 (iv) <=> (v) with no
    /// selection or latent nodes: some set does iff `ant({u, v}) \ {u, v}` does.
    fn has_separating_set(&self, u: u32, v: u32) -> bool {
        let mut z = self.anteriors_of(u);
        z.extend(self.anteriors_of(v));
        z.sort_unstable();
        z.dedup();
        z.retain(|&w| w != u && w != v);
        self.m_separated(&[u], &[v], &z)
    }
}

impl crate::graph::traits::Acyclic for Ag {}
impl crate::graph::traits::DirectedNeighbors for Ag {
    #[inline]
    fn n(&self) -> u32 {
        Ag::n(self)
    }
    #[inline]
    fn parents_of(&self, i: u32) -> &[u32] {
        Ag::parents_of(self, i)
    }
    #[inline]
    fn children_of(&self, i: u32) -> &[u32] {
        Ag::children_of(self, i)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    fn setup() -> (EdgeRegistry, u8, u8, u8) {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let dir = reg.code_of("-->").unwrap();
        let bid = reg.code_of("<->").unwrap();
        let und = reg.code_of("---").unwrap();
        (reg, dir, bid, und)
    }

    #[test]
    fn ag_basic_construction_directed_only() {
        let (reg, dir, _bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        // Simple DAG: 0 -> 1 -> 2
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(1, 2, dir).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).expect("AG construction failed");
        assert_eq!(ag.n(), 3);
        assert_eq!(ag.parents_of(0), &[] as &[u32]);
        assert_eq!(ag.parents_of(1), &[0]);
        assert_eq!(ag.parents_of(2), &[1]);
        assert_eq!(ag.children_of(0), &[1]);
        assert_eq!(ag.children_of(1), &[2]);
    }

    #[test]
    fn ag_basic_construction_with_bidirected() {
        let (reg, dir, bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        // 0 -> 1, 0 -> 2, 1 <-> 2, 2 -> 3
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(0, 2, dir).unwrap();
        b.add_edge(1, 2, bid).unwrap();
        b.add_edge(2, 3, dir).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).expect("AG construction failed");
        assert_eq!(ag.n(), 4);
        assert_eq!(ag.spouses_of(1), &[2]);
        assert_eq!(ag.spouses_of(2), &[1]);
    }

    #[test]
    fn ag_basic_construction_with_undirected() {
        let (reg, _dir, _bid, und) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        // Pure undirected: 0 --- 1 --- 2
        b.add_edge(0, 1, und).unwrap();
        b.add_edge(1, 2, und).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).expect("AG construction failed");
        assert_eq!(ag.n(), 3);
        assert_eq!(ag.undirected_of(0), &[1]);
        assert_eq!(ag.undirected_of(1), &[0, 2]);
        assert_eq!(ag.undirected_of(2), &[1]);
    }

    #[test]
    fn ag_cycle_rejected() {
        let (reg, dir, _bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        // Directed cycle: 0 -> 1 -> 2 -> 0
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(1, 2, dir).unwrap();
        b.add_edge(2, 0, dir).unwrap();

        let result = Ag::new(Arc::new(b.finalize().unwrap()));
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("cycle"));
    }

    #[test]
    fn ag_undirected_constraint_violation() {
        let (reg, dir, _bid, und) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        // Node 1 has both undirected (from 0) and directed in (from 2)
        b.add_edge(0, 1, und).unwrap();
        b.add_edge(2, 1, dir).unwrap();

        let result = Ag::new(Arc::new(b.finalize().unwrap()));
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Undirected constraint"));
    }

    #[test]
    fn ag_undirected_constraint_violation_bidirected() {
        let (reg, _dir, bid, und) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        // Node 1 has both undirected and bidirected
        b.add_edge(0, 1, und).unwrap();
        b.add_edge(1, 2, bid).unwrap();

        let result = Ag::new(Arc::new(b.finalize().unwrap()));
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Undirected constraint"));
    }

    #[test]
    fn ag_partial_edge_rejected() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let par = reg.code_of("o->").unwrap();

        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, par).unwrap();

        let result = Ag::new(Arc::new(b.finalize().unwrap()));
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .contains("directed, bidirected, and undirected"));
    }

    #[test]
    fn ag_ancestors_descendants() {
        let (reg, dir, bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        // Chain: 0 -> 1 -> 2 -> 3, with 1 <-> 4 (spouse, not ancestor/descendant)
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(1, 2, dir).unwrap();
        b.add_edge(2, 3, dir).unwrap();
        b.add_edge(1, 4, bid).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();

        // Ancestors of 3: {0, 1, 2}
        assert_eq!(ag.ancestors_of(3), vec![0, 1, 2]);

        // Descendants of 0: {1, 2, 3}
        assert_eq!(ag.descendants_of(0), vec![1, 2, 3]);

        // Node 4's ancestors/descendants should be empty (only bidirected to 1)
        assert!(ag.ancestors_of(4).is_empty());
        assert!(ag.descendants_of(4).is_empty());
    }

    #[test]
    fn ag_anteriors() {
        let (reg, dir, _bid, und) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        // 0 -> 1, 2 --- 3, no connection between directed and undirected parts
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(2, 3, und).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();

        // Anteriors of 1: {0}
        assert_eq!(ag.anteriors_of(1), vec![0]);

        // Anteriors of 3: {2} (via undirected)
        assert_eq!(ag.anteriors_of(3), vec![2]);

        // Anteriors of 2: {3} (via undirected)
        assert_eq!(ag.anteriors_of(2), vec![3]);
    }

    #[test]
    fn ag_districts() {
        let (reg, dir, bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(6, true, &reg);
        // District A: {0, 1} via 0 <-> 1
        // District B: {2, 3, 4} via 2 <-> 3, 3 <-> 4
        // District C: {5} (isolated)
        // Directed edges don't affect districts
        b.add_edge(0, 1, bid).unwrap();
        b.add_edge(2, 3, bid).unwrap();
        b.add_edge(3, 4, bid).unwrap();
        b.add_edge(0, 2, dir).unwrap(); // Directed doesn't connect districts

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let districts = ag.districts();
        assert_eq!(districts.len(), 3);
        assert_eq!(ag.num_districts(), 3);

        // Find district containing 0
        let d0 = ag.district_of(0);
        assert_eq!(d0, vec![0, 1]);

        // Find district containing 2
        let d2 = ag.district_of(2);
        assert_eq!(d2, vec![2, 3, 4]);

        // Find district containing 5
        let d5 = ag.district_of(5);
        assert_eq!(d5, vec![5]);
    }

    #[test]
    fn ag_exogenous() {
        let (reg, dir, bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        // 0 -> 1, 2 <-> 3
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(2, 3, bid).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();

        // Exogenous: nodes without parents = {0, 2, 3}
        assert_eq!(ag.exogenous_nodes(), vec![0, 2, 3]);
    }

    #[test]
    fn ag_empty_graph() {
        let (reg, _dir, _bid, _und) = setup();
        let b = GraphBuilder::new_with_registry(3, true, &reg);
        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(ag.n(), 3);
        for i in 0..3 {
            assert!(ag.parents_of(i).is_empty());
            assert!(ag.children_of(i).is_empty());
            assert!(ag.undirected_of(i).is_empty());
            assert!(ag.spouses_of(i).is_empty());
        }
    }

    #[test]
    fn ag_markov_blanket() {
        let (reg, dir, bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        // 0 -> 1, 2 -> 1, 1 -> 3, 1 <-> 4
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(2, 1, dir).unwrap();
        b.add_edge(1, 3, dir).unwrap();
        b.add_edge(1, 4, bid).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();

        // MB(1) = Pa(1) ∪ Ch(1) ∪ spouses(1) via district ∪ Pa(district)
        let mb = ag.markov_blanket_of(1);
        assert!(mb.contains(&0)); // parent
        assert!(mb.contains(&2)); // parent
        assert!(mb.contains(&3)); // child
        assert!(mb.contains(&4)); // spouse
    }

    #[test]
    fn ag_adjacent() {
        let (reg, dir, bid, und) = setup();
        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        // Build valid AG: mix of edges without constraint violations
        // - 0 -> 1: directed edge
        // - 1 <-> 2: bidirected edge (both nodes have arrowhead edges)
        // - 3 --- 4: undirected edge (separate from directed/bidirected part)
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(1, 2, bid).unwrap();
        b.add_edge(3, 4, und).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();

        assert!(ag.adjacent(0, 1));
        assert!(ag.adjacent(1, 0));
        assert!(ag.adjacent(1, 2));
        assert!(ag.adjacent(3, 4));
        assert!(!ag.adjacent(0, 2));
        assert!(!ag.adjacent(0, 3));
        assert!(!ag.adjacent(1, 4));
    }

    #[test]
    fn ag_is_mag_chain() {
        let (reg, dir, _bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        // Chain: 0 -> 1 -> 2 (0 and 2 are m-separated by {1})
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(1, 2, dir).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(ag.is_mag());
    }

    #[test]
    fn ag_is_mag_complete_graph_issue_309() {
        // Regression test for #309: a complete AG is trivially maximal (no
        // non-adjacent pairs), but a buggy `adjacent` using binary_search over
        // the unsorted concatenated neighborhood made `is_mag` return false.
        // Graph (figure 4b): nodes X=0, Z=1, Y=2, W=3.
        //   X <-> Z, X <-> Y, Z <-> W, Z --> Y, X --> W, Y <-> W
        let (reg, dir, bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, bid).unwrap(); // X <-> Z
        b.add_edge(0, 2, bid).unwrap(); // X <-> Y
        b.add_edge(1, 3, bid).unwrap(); // Z <-> W
        b.add_edge(1, 2, dir).unwrap(); // Z --> Y
        b.add_edge(0, 3, dir).unwrap(); // X --> W
        b.add_edge(2, 3, bid).unwrap(); // Y <-> W

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();

        // Every pair is adjacent (complete graph).
        for u in 0..4u32 {
            for v in (u + 1)..4u32 {
                assert!(ag.adjacent(u, v), "expected {u} and {v} to be adjacent");
            }
        }
        assert!(ag.is_mag());
    }

    #[test]
    fn ag_core_ref() {
        let (reg, dir, _bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, dir).unwrap();
        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(ag.core_ref().n(), 2);
    }

    #[test]
    fn ag_posteriors_markov_blanket_and_is_ag() {
        let (reg, dir, _bid, und) = setup();
        let mut b = GraphBuilder::new_with_registry(6, true, &reg);
        // Directed component with a co-parent:
        // 0 -> 2 <- 1, 2 -> 3
        b.add_edge(0, 2, dir).unwrap();
        b.add_edge(1, 2, dir).unwrap();
        b.add_edge(2, 3, dir).unwrap();
        // Separate undirected component to exercise undirected MB contribution.
        b.add_edge(4, 5, und).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(ag.is_ag());
        assert!(ag.is_anterior_of(2, 2));

        // Posteriors via directed and undirected traversal.
        assert_eq!(ag.posteriors_of(0), vec![2, 3]);
        assert_eq!(ag.posteriors_of(4), vec![5]);

        // MB(0) should include co-parent 1 via child 2.
        let mb0 = ag.markov_blanket_of(0);
        assert!(mb0.contains(&1));
        assert!(mb0.contains(&2));

        // MB(4) should include undirected neighbor 5.
        assert_eq!(ag.markov_blanket_of(4), vec![5]);
    }

    #[test]
    fn ag_district_of_handles_revisits() {
        let (reg, _dir, bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        // Triangle of spouses to force duplicate pushes/revisits in DFS stack.
        b.add_edge(0, 1, bid).unwrap();
        b.add_edge(1, 2, bid).unwrap();
        b.add_edge(0, 2, bid).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(ag.district_of(0), vec![0, 1, 2]);
    }

    #[test]
    fn ag_has_separating_set_uses_the_anterior_set() {
        let (reg, dir, _bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        // Chain 0 -> 1 -> 2, and an isolated 3.
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(1, 2, dir).unwrap();
        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(ag.has_separating_set(0, 2)); // by {1}
        assert!(ag.has_separating_set(0, 3)); // by {}
        assert!(!ag.has_separating_set(0, 1)); // adjacent
    }

    #[test]
    fn ag_is_mag_singleton_true() {
        let (reg, _dir, _bid, _und) = setup();
        let b = GraphBuilder::new_with_registry(1, true, &reg);
        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(ag.is_mag());
    }

    #[test]
    fn ag_anterior_constraint_violation_from_bidirected_when_left_is_anterior() {
        let (reg, dir, bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(2, false, &reg);
        // 0 -> 1 and 0 <-> 1 violates anterior constraint on the bidirected edge:
        // 0 is an anterior of 1.
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(0, 1, bid).unwrap();

        let err = Ag::try_new(Arc::new(b.finalize().unwrap())).unwrap_err();
        assert!(matches!(
            err,
            AgError::AnteriorConstraintViolation {
                source: 1,
                target: 0
            }
        ));
    }

    #[test]
    fn ag_anterior_constraint_violation_from_bidirected_when_right_is_anterior() {
        let (reg, dir, bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(2, false, &reg);
        // 1 -> 0 and 0 <-> 1 violates anterior constraint on the bidirected edge:
        // 1 is an anterior of 0.
        b.add_edge(1, 0, dir).unwrap();
        b.add_edge(0, 1, bid).unwrap();

        let err = Ag::try_new(Arc::new(b.finalize().unwrap())).unwrap_err();
        assert!(matches!(
            err,
            AgError::AnteriorConstraintViolation {
                source: 0,
                target: 1
            }
        ));
    }

    /// The definition: some subset of the other nodes m-separates `u` and `v`.
    fn separable_by_some_subset(ag: &Ag, u: u32, v: u32) -> bool {
        let others: Vec<u32> = (0..ag.n()).filter(|&w| w != u && w != v).collect();
        (0u32..1 << others.len()).any(|mask| {
            let z: Vec<u32> = others
                .iter()
                .enumerate()
                .filter(|(i, _)| mask >> i & 1 == 1)
                .map(|(_, &w)| w)
                .collect();
            ag.m_separated(&[u], &[v], &z)
        })
    }

    fn is_mag_by_subsets(ag: &Ag) -> bool {
        (0..ag.n()).all(|u| {
            (u + 1..ag.n()).all(|v| ag.adjacent(u, v) || separable_by_some_subset(ag, u, v))
        })
    }

    /// An AG on `n` nodes with one state per pair: 0 none, 1 a->b, 2 b->a,
    /// 3 a<->b, 4 a---b. `None` if the edges do not form an AG.
    fn ag_from_states(n: u32, states: &[usize]) -> Option<Ag> {
        let (reg, dir, bid, und) = setup();
        let mut b = GraphBuilder::new_with_registry(n, true, &reg);
        let mut k = 0;
        for a in 0..n {
            for c in (a + 1)..n {
                match states[k] {
                    1 => b.add_edge(a, c, dir).unwrap(),
                    2 => b.add_edge(c, a, dir).unwrap(),
                    3 => b.add_edge(a, c, bid).unwrap(),
                    4 => b.add_edge(a, c, und).unwrap(),
                    _ => {}
                }
                k += 1;
            }
        }
        Ag::new(Arc::new(b.finalize().unwrap())).ok()
    }

    #[test]
    fn is_mag_matches_the_subset_search_on_every_4_node_ag() {
        let (mut mags, mut non_mags) = (0, 0);
        for idx in 0..5usize.pow(6) {
            let states: Vec<usize> = (0..6).map(|k| idx / 5usize.pow(k) % 5).collect();
            let Some(ag) = ag_from_states(4, &states) else {
                continue;
            };
            assert_eq!(ag.is_mag(), is_mag_by_subsets(&ag), "states {:?}", states);
            if ag.is_mag() {
                mags += 1;
            } else {
                non_mags += 1;
            }
        }
        // Every 4-node MAG, as in the R ground truth; and some that are not.
        assert_eq!(mags, 3045);
        assert!(non_mags > 0);
    }

    #[test]
    fn is_mag_matches_the_subset_search_on_random_7_node_ags() {
        let mut seed: u64 = 398;
        let mut next = || {
            seed = seed
                .wrapping_mul(6364136223846793005)
                .wrapping_add(1442695040888963407);
            (seed >> 33) as usize
        };
        let (mut checked, mut non_mags) = (0, 0);
        while checked < 2000 {
            let states: Vec<usize> = (0..21)
                .map(|_| if next() % 10 < 4 { 1 + next() % 4 } else { 0 })
                .collect();
            let Some(ag) = ag_from_states(7, &states) else {
                continue;
            };
            assert_eq!(ag.is_mag(), is_mag_by_subsets(&ag), "states {:?}", states);
            checked += 1;
            non_mags += usize::from(!ag.is_mag());
        }
        assert!(non_mags > 0);
    }
}
