// SPDX-License-Identifier: MIT
//! A graph read by endpoint mark, and the path predicates built on it.
//!
//! Every PAG predicate and orientation rule needs only the node count, the
//! neighbours of a node and the mark at one end of an edge. [`MarkGraph`]
//! requires exactly those and derives the rest, so each search is written
//! once and runs on both
//!
//! * [`CaugiGraph`], the CSR core behind every class (so on a MAG as well as a
//!   PAG), and
//! * [`Marks`](super::marks::Marks), the dense mutable graph the orientation
//!   rules resolve circles on.
//!
//! The path searches are depth-first with a path-local visited set, so they
//! find a path whenever one exists. The breadth-first searches with a global
//! visited set used by `pcalg` and causality-lab are cheaper but can miss a
//! path whose interior was consumed by an earlier branch.

use crate::edges::Mark;
use crate::graph::CaugiGraph;

/// Read-only access to a mixed graph by endpoint mark.
pub(crate) trait MarkGraph {
    /// Number of nodes.
    fn n(&self) -> u32;

    /// Every node adjacent to `i`.
    fn neighbors(&self, i: u32) -> Vec<u32>;

    /// The mark at `at` on the edge joining it to `from`, or `None` when the
    /// two are not adjacent.
    fn mark_at(&self, at: u32, from: u32) -> Option<Mark>;

    // ── derived relations ────────────────────────────────────────────────

    /// Are `i` and `j` joined by an edge?
    fn adjacent(&self, i: u32, j: u32) -> bool {
        self.mark_at(i, j).is_some()
    }

    /// Is `p --> c`?
    fn is_parent(&self, p: u32, c: u32) -> bool {
        self.mark_at(c, p) == Some(Mark::Arrow) && self.mark_at(p, c) == Some(Mark::Tail)
    }

    /// Is `a <-> b`?
    fn is_spouse(&self, a: u32, b: u32) -> bool {
        self.mark_at(a, b) == Some(Mark::Arrow) && self.mark_at(b, a) == Some(Mark::Arrow)
    }

    /// Is `i o-o j`?
    fn is_circle_circle(&self, i: u32, j: u32) -> bool {
        self.mark_at(i, j) == Some(Mark::Circle) && self.mark_at(j, i) == Some(Mark::Circle)
    }

    /// Neighbours joined to `i` by an edge with an arrowhead at `i`.
    fn arrowhead_neighbors(&self, i: u32) -> Vec<u32> {
        self.neighbors(i)
            .into_iter()
            .filter(|&j| self.mark_at(i, j) == Some(Mark::Arrow))
            .collect()
    }

    /// Neighbours `j` such that some member MAG can orient `i --> j`: no
    /// arrowhead at `i` and no tail at `j`.
    fn possible_children(&self, i: u32) -> Vec<u32> {
        self.neighbors(i)
            .into_iter()
            .filter(|&j| {
                matches!(self.mark_at(i, j), Some(Mark::Tail | Mark::Circle))
                    && matches!(self.mark_at(j, i), Some(Mark::Arrow | Mark::Circle))
            })
            .collect()
    }

    // ── path predicates ─────────────────────────────────────────────────

    /// Is the directed edge `a --> b` visible (Zhang 2008, Def. 8)?
    ///
    /// Visible iff some `c` not adjacent to `b` has (a) an edge into `a`, or
    /// (b) a collider path into `a` whose non-endpoints are all parents of
    /// `b`. Only `-->` can be visible.
    fn visible_edge(&self, a: u32, b: u32) -> bool {
        if a == b || a >= self.n() || b >= self.n() || !self.is_parent(a, b) {
            return false;
        }
        // (a): `c *-> a --> b` with `c` and `b` non-adjacent.
        if self
            .arrowhead_neighbors(a)
            .into_iter()
            .any(|c| c != b && !self.adjacent(c, b))
        {
            return true;
        }
        // (b): the last non-endpoint `d` of the collider path is a spouse of
        // `a` and a parent of `b`, and the rest of the path discriminates
        // `<d, a, b>`.
        self.neighbors(a).into_iter().any(|d| {
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
    fn discriminating_path(&self, a: u32, b: u32, c: u32) -> Option<Vec<u32>> {
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

    /// An uncovered potentially-directed path `[x, first, ..., y]` avoiding
    /// `exclude`.
    ///
    /// Every consecutive pair satisfies [`possible_children`](Self::possible_children)
    /// and every consecutive triple has non-adjacent ends, the triples at the
    /// endpoints included. `first`, when given, pins the vertex after `x`; the
    /// single-edge path `[x, y]` is returned only when `first` is `None` or
    /// `Some(y)`.
    fn uncovered_pd_path(
        &self,
        x: u32,
        y: u32,
        first: Option<u32>,
        exclude: &[u32],
    ) -> Option<Vec<u32>> {
        let n = self.n();
        if x == y || x >= n || y >= n || exclude.contains(&x) || exclude.contains(&y) {
            return None;
        }
        // Excluded vertices are pre-marked as used.
        let mut on_path = vec![false; n as usize];
        on_path[x as usize] = true;
        for &e in exclude.iter().filter(|&&e| e < n) {
            on_path[e as usize] = true;
        }
        let mut path = vec![x];
        self.extend_pd_path(&mut path, &mut on_path, y, first)
            .then_some(path)
    }

    /// Extend the potentially-directed path in `path` toward `y`.
    fn extend_pd_path(
        &self,
        path: &mut Vec<u32>,
        on_path: &mut [bool],
        y: u32,
        first: Option<u32>,
    ) -> bool {
        let curr = path[path.len() - 1];
        let prev = path.len().checked_sub(2).map(|k| path[k]);
        for next in self.possible_children(curr) {
            if path.len() == 1 && first.is_some_and(|f| next != f) {
                continue;
            }
            if prev.is_some_and(|p| self.adjacent(p, next)) {
                continue; // covered
            }
            if next == y {
                path.push(y);
                return true;
            }
            if on_path[next as usize] {
                continue;
            }
            on_path[next as usize] = true;
            path.push(next);
            if self.extend_pd_path(path, on_path, y, first) {
                return true;
            }
            path.pop();
            on_path[next as usize] = false;
        }
        false
    }

    /// An uncovered circle path `[a, c, ..., d, b]` not using the edge `a-b`,
    /// with `c` not adjacent to `b` and `d` not adjacent to `a`: the witness
    /// R5 needs.
    fn uncovered_circle_path(&self, a: u32, b: u32) -> Option<Vec<u32>> {
        let n = self.n();
        if a == b || a >= n || b >= n {
            return None;
        }
        for c in self.neighbors(a) {
            if c == b || !self.is_circle_circle(a, c) || self.adjacent(b, c) {
                continue;
            }
            let mut on_path = vec![false; n as usize];
            for v in [a, b, c] {
                on_path[v as usize] = true;
            }
            let mut path = vec![a, c];
            if self.extend_circle_path(&mut path, &mut on_path, a, b, c) {
                return Some(path);
            }
        }
        None
    }

    /// Extend the circle path in `path` toward `b`.
    fn extend_circle_path(
        &self,
        path: &mut Vec<u32>,
        on_path: &mut [bool],
        a: u32,
        b: u32,
        c: u32,
    ) -> bool {
        let curr = path[path.len() - 1];
        let prev = path[path.len() - 2];
        if curr != c
            && self.is_circle_circle(curr, b)
            && !self.adjacent(a, curr)
            && !self.adjacent(prev, b)
        {
            path.push(b);
            return true;
        }
        for next in self.neighbors(curr) {
            if next == b
                || on_path[next as usize]
                || !self.is_circle_circle(curr, next)
                || self.adjacent(prev, next)
            {
                continue;
            }
            on_path[next as usize] = true;
            path.push(next);
            if self.extend_circle_path(path, on_path, a, b, c) {
                return true;
            }
            path.pop();
            on_path[next as usize] = false;
        }
        false
    }
}

/// The CSR core read by mark, which covers every class at once.
impl MarkGraph for CaugiGraph {
    #[inline]
    fn n(&self) -> u32 {
        CaugiGraph::n(self)
    }

    fn neighbors(&self, i: u32) -> Vec<u32> {
        self.col_index[self.row_range(i)].to_vec()
    }

    fn mark_at(&self, at: u32, from: u32) -> Option<Mark> {
        if at >= self.n() {
            return None;
        }
        self.row_range(at)
            .find(|&k| self.col_index[k] == from)
            .map(|k| self.my_mark(k))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    /// A core from glyph triples. Most of these are not valid PAGs, which is
    /// fine: the predicates are defined on any mixed graph.
    fn build(n: u32, edges: &[(u32, u32, &str)]) -> CaugiGraph {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let mut b = GraphBuilder::new_with_registry(n, true, &reg);
        for &(u, v, glyph) in edges {
            b.add_edge(u, v, reg.code_of(glyph).unwrap()).unwrap();
        }
        b.finalize().unwrap()
    }

    /// The `pcalg::visibleEdge` documentation fixture `a --> b`, `b <-> c`,
    /// `b --> d`, `c --> d`.
    fn pcalg_fixture() -> CaugiGraph {
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
    fn derived_relations_agree_with_marks() {
        let g = build(3, &[(0, 1, "-->"), (1, 2, "<->")]);
        assert!(g.is_parent(0, 1) && !g.is_parent(1, 0));
        assert!(g.is_spouse(1, 2));
        assert_eq!(g.arrowhead_neighbors(1), vec![0, 2]);
        assert_eq!(g.possible_children(0), vec![1]);
        assert!(g.possible_children(1).is_empty());
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

    #[test]
    fn uncovered_pd_path_basics() {
        let g = build(3, &[(0, 1, "o->"), (1, 2, "o->")]);
        assert_eq!(g.uncovered_pd_path(0, 2, None, &[]), Some(vec![0, 1, 2]));
        assert_eq!(g.uncovered_pd_path(0, 2, Some(1), &[]), Some(vec![0, 1, 2]));
        assert_eq!(g.uncovered_pd_path(0, 2, None, &[1]), None);
        assert_eq!(g.uncovered_pd_path(2, 0, None, &[]), None);
        assert_eq!(g.uncovered_pd_path(0, 0, None, &[]), None);
        assert_eq!(g.uncovered_pd_path(0, 9, None, &[]), None);
    }

    #[test]
    fn uncovered_pd_path_rejects_a_covered_triple() {
        let g = build(3, &[(0, 1, "o->"), (1, 2, "o->"), (0, 2, "o->")]);
        assert_eq!(g.uncovered_pd_path(0, 2, None, &[]), Some(vec![0, 2]));
        assert_eq!(g.uncovered_pd_path(0, 2, Some(1), &[]), None);
    }

    #[test]
    fn uncovered_pd_path_allows_adjacent_endpoints_on_longer_paths() {
        // The shape R9 and R10 search for out of an `a o-> c` edge.
        let g = build(
            4,
            &[(0, 1, "o->"), (1, 2, "o->"), (2, 3, "o->"), (0, 3, "o->")],
        );
        assert_eq!(
            g.uncovered_pd_path(0, 3, Some(1), &[]),
            Some(vec![0, 1, 2, 3])
        );
        assert_eq!(g.uncovered_pd_path(0, 3, Some(3), &[]), Some(vec![0, 3]));
    }

    #[test]
    fn uncovered_pd_path_needs_every_edge_potentially_directed() {
        let bi = build(3, &[(0, 1, "<->"), (1, 2, "o->")]);
        assert_eq!(bi.uncovered_pd_path(0, 2, None, &[]), None);
        let und = build(3, &[(0, 1, "---"), (1, 2, "--o")]);
        assert_eq!(und.uncovered_pd_path(0, 2, None, &[]), None);
        let sel = build(3, &[(0, 1, "--o"), (1, 2, "--o")]);
        assert_eq!(sel.uncovered_pd_path(0, 2, None, &[]), Some(vec![0, 1, 2]));
    }

    #[test]
    fn uncovered_pd_path_backtracks_and_stays_simple() {
        let g = build(4, &[(0, 1, "o->"), (0, 2, "o->"), (2, 3, "o->")]);
        assert_eq!(g.uncovered_pd_path(0, 3, None, &[]), Some(vec![0, 2, 3]));

        let cyc = build(
            4,
            &[(0, 1, "o-o"), (1, 2, "o-o"), (0, 2, "o-o"), (2, 3, "o-o")],
        );
        let path = cyc.uncovered_pd_path(0, 3, None, &[]).expect("a path");
        let mut uniq = path.clone();
        uniq.sort_unstable();
        uniq.dedup();
        assert_eq!(uniq.len(), path.len(), "path repeats a node: {:?}", path);
    }
}
