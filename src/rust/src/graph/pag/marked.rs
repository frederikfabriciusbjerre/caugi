// SPDX-License-Identifier: MIT
//! A simple mixed graph read and edited by endpoint mark.
//!
//! The skeleton is the CSR of a [`CaugiGraph`], shared rather than copied,
//! and never changes. Each edge slot carries the mark at its own row's node,
//! so the mark at `a` on the edge to `b` lives in `a`'s row, and `twin` links
//! each slot to the same edge in the other row. The MAG and PAG path
//! predicates read it.
//!
//! The path searches are depth-first with a path-local visited set, so they
//! find a path whenever one exists. The breadth-first searches with a global
//! visited set used by `pcalg` and causality-lab are cheaper but can miss a
//! path whose interior was consumed by an earlier branch.

use crate::edges::Mark;
use crate::graph::CaugiGraph;
use std::ops::Range;
use std::sync::Arc;

#[derive(Debug, Clone)]
pub(crate) struct MarkedGraph {
    row_index: Arc<[u32]>,
    col_index: Arc<[u32]>,
    /// `mark[k]`: the mark at slot `k`'s row node on its edge.
    mark: Vec<Mark>,
    /// `twin[k]`: the slot of the same edge in the other endpoint's row.
    twin: Vec<u32>,
}

impl MarkedGraph {
    /// The marks of `core`, sharing its skeleton. Self-loops and parallel
    /// edges cannot be read by mark, so they are an error.
    pub(crate) fn from_core(core: &CaugiGraph) -> Result<Self, String> {
        core.check_simple().map_err(|e| e.to_string())?;
        let mark = (0..core.col_index.len()).map(|k| core.my_mark(k)).collect();
        Ok(Self::new(
            Arc::clone(&core.row_index),
            Arc::clone(&core.col_index),
            mark,
        ))
    }

    fn new(row_index: Arc<[u32]>, col_index: Arc<[u32]>, mark: Vec<Mark>) -> Self {
        let mut g = Self {
            row_index,
            col_index,
            mark,
            twin: Vec::new(),
        };
        g.twin = (0..g.n())
            .flat_map(|i| g.slots(i).map(move |k| (i, k)))
            .map(|(i, k)| g.slot(g.col_index[k], i).expect("rows are symmetric") as u32)
            .collect();
        g
    }

    /// Number of nodes.
    #[inline]
    pub(crate) fn n(&self) -> u32 {
        (self.row_index.len() - 1) as u32
    }

    /// The slots of `i`'s row.
    #[inline]
    pub(super) fn slots(&self, i: u32) -> Range<usize> {
        self.row_index[i as usize] as usize..self.row_index[i as usize + 1] as usize
    }

    /// The node at the other end of slot `k`.
    #[inline]
    pub(super) fn col(&self, k: usize) -> u32 {
        self.col_index[k]
    }

    /// The mark at slot `k`'s row node.
    #[inline]
    pub(super) fn near(&self, k: usize) -> Mark {
        self.mark[k]
    }

    /// The mark at the other end of slot `k`.
    #[inline]
    pub(super) fn far(&self, k: usize) -> Mark {
        self.mark[self.twin[k] as usize]
    }

    /// Every node adjacent to `i`, in ascending order.
    #[inline]
    pub(crate) fn neighbors(&self, i: u32) -> &[u32] {
        &self.col_index[self.slots(i)]
    }

    /// The slot of the edge `{i, j}` in `i`'s row.
    #[inline]
    pub(super) fn slot(&self, i: u32, j: u32) -> Option<usize> {
        if i >= self.n() {
            return None;
        }
        let r = self.slots(i);
        self.col_index[r.clone()]
            .binary_search(&j)
            .ok()
            .map(|p| r.start + p)
    }

    /// The mark at `at` on the edge joining it to `from`, or `None` when the
    /// two are not adjacent.
    #[inline]
    pub(crate) fn mark_at(&self, at: u32, from: u32) -> Option<Mark> {
        self.slot(at, from).map(|k| self.mark[k])
    }

    /// Are `i` and `j` joined by an edge?
    #[inline]
    pub(crate) fn adjacent(&self, i: u32, j: u32) -> bool {
        self.slot(i, j).is_some()
    }

    // ── derived relations ────────────────────────────────────────────────

    /// Is `p --> c`?
    pub(crate) fn is_parent(&self, p: u32, c: u32) -> bool {
        self.slot(c, p)
            .is_some_and(|k| self.near(k) == Mark::Arrow && self.far(k) == Mark::Tail)
    }

    /// Is `a <-> b`?
    pub(crate) fn is_spouse(&self, a: u32, b: u32) -> bool {
        self.slot(a, b)
            .is_some_and(|k| self.near(k) == Mark::Arrow && self.far(k) == Mark::Arrow)
    }

    /// Neighbours joined to `i` by an edge with an arrowhead at `i`.
    pub(crate) fn arrowhead_neighbors(&self, i: u32) -> impl Iterator<Item = u32> + '_ {
        self.slots(i)
            .filter(move |&k| self.near(k) == Mark::Arrow)
            .map(move |k| self.col(k))
    }

    // ── path predicates ─────────────────────────────────────────────────

    /// Is the directed edge `a --> b` visible (Zhang 2008, Def. 8)?
    ///
    /// Visible iff some `c` not adjacent to `b` has (a) an edge into `a`, or
    /// (b) a collider path into `a` whose non-endpoints are all parents of
    /// `b`. Only `-->` can be visible.
    pub(crate) fn visible_edge(&self, a: u32, b: u32) -> bool {
        if a == b || a >= self.n() || b >= self.n() || !self.is_parent(a, b) {
            return false;
        }
        // (a): `c *-> a --> b` with `c` and `b` non-adjacent.
        if self
            .arrowhead_neighbors(a)
            .any(|c| c != b && !self.adjacent(c, b))
        {
            return true;
        }
        // (b): the last non-endpoint `d` of the collider path is a spouse of
        // `a` and a parent of `b`, and the rest of the path discriminates
        // `<d, a, b>`.
        self.neighbors(a).iter().any(|&d| {
            d != b
                && self.is_spouse(a, d)
                && self.is_parent(d, b)
                && self.discriminating_path(d, a, b).is_some()
        })
    }

    /// A discriminating path for the triple `<a, b, c>`, as `[d, ..., a, b, c]`.
    ///
    /// `d` is not adjacent to `c`, and every vertex strictly between `d` and
    /// `b` is a collider on the path and a parent of `c`. The triple is
    /// checked rather than assumed, so any triple may be passed.
    pub(crate) fn discriminating_path(&self, a: u32, b: u32, c: u32) -> Option<Vec<u32>> {
        let n = self.n();
        if a >= n || b >= n || c >= n || a == b || b == c || a == c {
            return None;
        }
        if !self.is_parent(a, c) || self.mark_at(a, b) != Some(Mark::Arrow) || !self.adjacent(b, c)
        {
            return None;
        }
        let mut on_path = vec![false; n as usize];
        for v in [a, b, c] {
            on_path[v as usize] = true;
        }
        // Built from `a` outward, then reversed so the source comes first.
        let mut chain = vec![a];
        if !self.extend_collider_chain(&mut chain, &mut on_path, c) {
            return None;
        }
        chain.reverse();
        chain.extend([b, c]);
        Some(chain)
    }

    /// Extend `chain` away from `c` until it reaches a source not adjacent
    /// to `c`. Every vertex added on the way must be a collider on the path
    /// and a parent of `c`.
    fn extend_collider_chain(&self, chain: &mut Vec<u32>, on_path: &mut [bool], c: u32) -> bool {
        let curr = *chain.last().expect("chain is never empty");
        for d in self.arrowhead_neighbors(curr) {
            if on_path[d as usize] {
                continue;
            }
            if !self.adjacent(d, c) {
                chain.push(d);
                return true;
            }
            if self.is_parent(d, c) && self.mark_at(d, curr) == Some(Mark::Arrow) {
                on_path[d as usize] = true;
                chain.push(d);
                if self.extend_collider_chain(chain, on_path, c) {
                    return true;
                }
                chain.pop();
                on_path[d as usize] = false;
            }
        }
        false
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    /// A graph from glyph triples. Most of these are not valid PAGs, which is
    /// fine: the predicates are defined on any mixed graph.
    fn build(n: u32, edges: &[(u32, u32, &str)]) -> MarkedGraph {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let mut b = GraphBuilder::new_with_registry(n, true, &reg);
        for &(u, v, glyph) in edges {
            b.add_edge(u, v, reg.code_of(glyph).unwrap()).unwrap();
        }
        MarkedGraph::from_core(&b.finalize().unwrap()).unwrap()
    }

    /// The `pcalg::visibleEdge` documentation fixture `a --> b`, `b <-> c`,
    /// `b --> d`, `c --> d`.
    fn pcalg_fixture() -> MarkedGraph {
        build(
            4,
            &[(0, 1, "-->"), (1, 2, "<->"), (1, 3, "-->"), (2, 3, "-->")],
        )
    }

    #[test]
    fn mark_at_reads_both_endpoints() {
        let g = build(3, &[(0, 1, "o->")]);
        assert_eq!(g.mark_at(0, 1), Some(Mark::Circle));
        assert_eq!(g.mark_at(1, 0), Some(Mark::Arrow));
        assert_eq!(g.mark_at(0, 2), None);
        assert_eq!(g.mark_at(7, 0), None);
        assert!(g.adjacent(0, 1) && !g.adjacent(0, 2));
    }

    #[test]
    fn self_loops_and_parallel_edges_cannot_be_read() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let mut b = GraphBuilder::new_with_registry(2, false, &reg);
        b.add_edge(0, 1, reg.code_of("-->").unwrap()).unwrap();
        b.add_edge(0, 1, reg.code_of("<->").unwrap()).unwrap();
        assert!(MarkedGraph::from_core(&b.finalize().unwrap()).is_err());
    }

    #[test]
    fn derived_relations_agree_with_marks() {
        let g = build(3, &[(0, 1, "-->"), (1, 2, "<->")]);
        assert!(g.is_parent(0, 1) && !g.is_parent(1, 0));
        assert!(g.is_spouse(1, 2));
        assert_eq!(g.arrowhead_neighbors(1).collect::<Vec<_>>(), vec![0, 2]);
    }

    #[test]
    fn pcalg_visible_edge_fixture() {
        let g = pcalg_fixture();
        // Every node other than `a` is adjacent to `b`: no witness.
        assert!(!g.visible_edge(0, 1));
        // (a): `a --> b` is into `b`, and `a` is not adjacent to `d`.
        assert!(g.visible_edge(1, 3));
        // (b): the collider path `a --> b <-> c` into `c`, with `b --> d`.
        assert!(g.visible_edge(2, 3));
    }

    #[test]
    fn visible_via_condition_a() {
        let g = build(3, &[(0, 1, "o->"), (1, 2, "-->")]);
        assert!(g.visible_edge(1, 2));
        // Connecting the witness to 2 removes it.
        let h = build(3, &[(0, 1, "o->"), (1, 2, "-->"), (0, 2, "o->")]);
        assert!(!h.visible_edge(1, 2));
    }

    #[test]
    fn visible_via_condition_b_over_a_two_hop_collider_path() {
        // 0 --> 1 <-> 2 <-> 3 --> 4 with 1 --> 4 and 2 --> 4.
        let mut edges = vec![
            (0, 1, "-->"),
            (1, 2, "<->"),
            (2, 3, "<->"),
            (3, 4, "-->"),
            (2, 4, "-->"),
        ];
        edges.push((1, 4, "-->"));
        assert!(build(5, &edges).visible_edge(3, 4));
        // With 1 <-> 4 the interior vertex 1 is no parent of 4.
        edges.pop();
        edges.push((1, 4, "<->"));
        assert!(!build(5, &edges).visible_edge(3, 4));
    }

    #[test]
    fn invisible_without_a_witness_into_the_source() {
        assert!(!build(2, &[(0, 1, "-->")]).visible_edge(0, 1));
        // A tail or a circle at 0 is no witness.
        for glyph in ["-->", "--o"] {
            let g = build(3, &[(0, 1, "-->"), (0, 2, glyph)]);
            assert!(!g.visible_edge(0, 1), "`0 {} 2` is not into 0", glyph);
        }
    }

    #[test]
    fn only_directed_edges_can_be_visible() {
        for glyph in ["o->", "<->", "--o", "o-o", "---"] {
            let g = build(3, &[(0, 1, glyph), (2, 0, "o->")]);
            assert!(!g.visible_edge(0, 1), "`{}` must never be visible", glyph);
        }
        let g = build(3, &[(0, 1, "-->"), (2, 0, "o->")]);
        assert!(g.visible_edge(0, 1));
        assert!(!g.visible_edge(1, 0));
    }

    #[test]
    fn visibility_degenerate_arguments() {
        let g = build(3, &[(0, 1, "-->")]);
        assert!(!g.visible_edge(0, 2));
        assert!(!g.visible_edge(0, 0));
        assert!(!g.visible_edge(0, 7));
        assert!(!g.visible_edge(7, 0));
        assert!(!build(0, &[]).visible_edge(0, 0));
    }

    #[test]
    fn discriminating_path_on_the_pcalg_fixture() {
        // `pcalg:::minDiscrPath(amat, 2, 3, 4)` returns `1 2 3 4`.
        assert_eq!(
            pcalg_fixture().discriminating_path(1, 2, 3),
            Some(vec![0, 1, 2, 3])
        );
    }

    #[test]
    fn discriminating_path_returns_the_whole_path() {
        let g = build(
            5,
            &[
                (0, 1, "-->"),
                (1, 2, "<->"),
                (2, 3, "<->"),
                (3, 4, "--o"),
                (1, 4, "-->"),
                (2, 4, "-->"),
            ],
        );
        assert_eq!(g.discriminating_path(2, 3, 4), Some(vec![0, 1, 2, 3, 4]));
    }

    #[test]
    fn discriminating_path_rejects_bad_triples() {
        let g = pcalg_fixture();
        assert_eq!(g.discriminating_path(0, 2, 3), None); // a not a parent of c
        assert_eq!(g.discriminating_path(1, 0, 3), None); // b not adjacent to c
        assert_eq!(g.discriminating_path(1, 1, 3), None);
        assert_eq!(g.discriminating_path(1, 2, 9), None);
    }

    #[test]
    fn discriminating_path_needs_a_source_disconnected_from_c() {
        let g = build(
            4,
            &[
                (0, 1, "-->"),
                (1, 2, "<->"),
                (1, 3, "-->"),
                (2, 3, "-->"),
                (0, 3, "-->"),
            ],
        );
        assert_eq!(g.discriminating_path(1, 2, 3), None);
        assert!(!g.visible_edge(2, 3));
    }
}
