// SPDX-License-Identifier: MIT
//! Path predicates for Partial Ancestral Graphs: edge visibility,
//! discriminating paths and uncovered potentially-directed paths.
//!
//! These three are the primitives the FCI orientation rules R4 and R8-R10 are
//! built from, and they are also what the generalized adjustment criterion
//! needs for amenability. The signatures are chosen for those callers:
//!
//! * [`Pag::is_visible_edge`] is a pure predicate on an ordered pair.
//! * [`Pag::discriminating_path`] takes the triple `<a, b, c>` and returns the
//!   whole path `[d, ..., a, b, c]`, so R4 can read the path source `d` off
//!   `path[0]` for its sep-set lookup instead of searching twice.
//! * [`Pag::uncovered_pd_path`] takes the two endpoints plus optional pins on
//!   the vertices adjacent to them, which is exactly the freedom R9 and R10
//!   need, and returns the whole path including both endpoints.
//!
//! Definitions
//! -----------
//!
//! **Visible edge** (Zhang 2008, Def. 8; Maathuis and Colombo 2015, Def. 3.1).
//! A directed edge `a --> b` is *visible* iff there is a vertex `c` not
//! adjacent to `b` such that either
//!
//! * (a) there is an edge between `c` and `a` that is into `a`, or
//! * (b) there is a collider path between `c` and `a` that is into `a` and
//!   every non-endpoint vertex on it is a parent of `b`.
//!
//! Otherwise the edge is invisible. Only `-->` edges can be visible.
//!
//! **Discriminating path** for `<..., a, b, c>`. A path `p` from some `d` to
//! `c` through `a` and `b` such that `d` is not adjacent to `c`, and every
//! vertex strictly between `d` and `b` is both a collider on `p` and a parent
//! of `c`.
//!
//! **Uncovered path**: `<v0, ..., vn>` where `vi` and `vi+2` are non-adjacent
//! for every consecutive triple. **Potentially directed (pd)**: every
//! consecutive pair satisfies the possible-parent relation, i.e. no arrowhead
//! at `vi` and no tail at `vi+1`, so some member MAG orients the whole path
//! forward.
//!
//! Search strategy
//! ---------------
//!
//! Both path searches are depth-first with backtracking over a path-local
//! visited set, so what they return is always a genuine path and a path is
//! found whenever one exists. The surveyed references all use a breadth-first
//! search over a *global* visited set (`pcalg::minDiscrPath`, causality-lab's
//! `find_discriminating_path_to_triplet`, causal-learn's
//! `existsUncoveredPdPath`), which is cheaper but can miss a path whose
//! interior nodes were consumed by an earlier branch.

use super::marks::{MarkGraph, Marks};
use super::Pag;
use crate::edges::Mark;

/// A dense mark view of `cg`, which is what the shared path searches run on.
fn marks_of(cg: &Pag) -> Marks {
    let n = cg.n();
    let mut m = Marks::new(n);
    for i in 0..n {
        for &j in cg.neighbors_of(i) {
            if i < j {
                // Both marks are present whenever the pair is adjacent.
                let at_i = cg.mark_at(i, j).expect("adjacent");
                let at_j = cg.mark_at(j, i).expect("adjacent");
                m.add_edge(i, j, at_i, at_j);
            }
        }
    }
    m
}

impl MarkGraph for Pag {
    #[inline]
    fn n(&self) -> u32 {
        Pag::n(self)
    }
    #[inline]
    fn adjacent(&self, i: u32, j: u32) -> bool {
        Pag::adjacent(self, i, j)
    }
    #[inline]
    fn mark_at(&self, at: u32, from: u32) -> Option<Mark> {
        Pag::mark_at(self, at, from)
    }
}

impl Pag {
    /// Is the directed edge `a --> b` visible?
    ///
    /// Returns `false` unless the edge is present and is `-->`; in particular
    /// `o->`, `<->`, `---`, `--o` and `o-o` are never visible, and neither is
    /// the reverse orientation of a `-->` edge.
    ///
    /// See the module documentation for the criterion. Condition (a) is a
    /// scan over the arrowheads at `a`; condition (b) is a discriminating-path
    /// search seeded at each spouse of `a` that is also a parent of `b`, which
    /// is the same reduction `pcalg::visibleEdge` and causality-lab's
    /// `_test_edge_visible` use.
    pub fn is_visible_edge(&self, a: u32, b: u32) -> bool {
        MarkGraph::visible_edge(self, a, b)
    }

    /// Find a discriminating path for the triple `<a, b, c>`.
    ///
    /// `b` is the middle vertex whose collider status the path discriminates,
    /// `c` the endpoint adjacent to `b`, and `a` the vertex on the other side
    /// of `b`. Returns the whole path `[d, v1, ..., a, b, c]` from its source
    /// `d` to `c`, or `None` when there is none.
    ///
    /// The three vertices are checked rather than assumed, so this is safe to
    /// call on any triple: `a` must be a parent of `c`, `b` must be adjacent
    /// to `c`, and the edge between `a` and `b` must have an arrowhead at `a`
    /// (so that `a` is a collider on the path).
    ///
    /// FCI's R4 consumes this as `path[0]` (the source `d`) plus the
    /// orientation of the triple it was given.
    pub fn discriminating_path(&self, a: u32, b: u32, c: u32) -> Option<Vec<u32>> {
        MarkGraph::discriminating_path(self, a, b, c)
    }

    /// Find an uncovered potentially-directed path from `x` to `y`.
    ///
    /// Returns the whole path `[x, v1, ..., y]`, both endpoints included, or
    /// `None` when there is none. Every consecutive pair on it satisfies the
    /// possible-parent relation (the endpoint edges included) and every
    /// consecutive triple has non-adjacent ends.
    ///
    /// `first` pins `path[1]`, the vertex adjacent to `x`, and `last` pins
    /// `path[len - 2]`, the vertex adjacent to `y`. R9 and R10 both quantify
    /// over the vertex adjacent to `x`, so they pin `first` and leave `last`
    /// open. For the trivial single-edge path `[x, y]` those two positions
    /// coincide with `y` and `x`, so it is returned only when `first` is
    /// `None` or `Some(y)` and `last` is `None` or `Some(x)`; that is the
    /// single-edge case R10 admits.
    ///
    /// Unlike causality-lab's `find_uncovered_path`, the triples that involve
    /// an endpoint are checked too, so a length-two path `[x, m, y]` is
    /// returned only when `x` and `y` are non-adjacent. Adjacent endpoints
    /// are otherwise fine, and R9 and R10 both rely on that: they search out
    /// of an `a o-> c` edge.
    pub fn uncovered_pd_path(
        &self,
        x: u32,
        y: u32,
        first: Option<u32>,
        last: Option<u32>,
        exclude: &[u32],
    ) -> Option<Vec<u32>> {
        MarkGraph::uncovered_pd_path(self, x, y, first, last, exclude)
    }

    /// A dense mark view of this graph, for the orientation rules.
    pub(super) fn to_marks(&self) -> Marks {
        marks_of(self)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use std::sync::Arc;

    fn build(n: u32, edges: &[(u32, u32, &str)]) -> Pag {
        // `new_unchecked`: these exercise the mark primitives on synthetic
        // configurations, most of which are not valid PAGs. `Pag::new` now
        // runs the full equivalence-class check, which would reject them.
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let mut b = GraphBuilder::new_with_registry(n, true, &reg);
        for &(u, v, glyph) in edges {
            b.add_edge(u, v, reg.code_of(glyph).unwrap()).unwrap();
        }
        Pag::new_unchecked(Arc::new(b.finalize().unwrap())).expect("construction failed")
    }

    /// The `pcalg::visibleEdge` documentation fixture, as
    /// `matrix(c(0,3,0,0, 2,0,2,3, 0,2,0,3, 0,2,2,0), 4, 4)` with names
    /// `a, b, c, d`: `a --> b`, `b <-> c`, `b --> d`, `c --> d`.
    fn pcalg_fixture() -> Pag {
        build(
            4,
            &[
                (0, 1, "-->"), // a --> b
                (1, 2, "<->"), // b <-> c
                (1, 3, "-->"), // b --> d
                (2, 3, "-->"), // c --> d
            ],
        )
    }

    #[test]
    fn pcalg_visible_edge_fixture() {
        let p = pcalg_fixture();
        // Every node other than `a` is adjacent to `b`, so no witness `c`
        // exists and `a --> b` is invisible.
        assert!(!p.is_visible_edge(0, 1));
        // `a --> b` puts an arrowhead on `b`, and `a` is not adjacent to `d`,
        // so condition (a) fires for `b --> d`.
        assert!(p.is_visible_edge(1, 3));
        // `a` is not adjacent to `c`, so condition (a) cannot fire for
        // `c --> d`; the collider path `a --> b <-> c` into `c`, whose only
        // non-endpoint `b` is a parent of `d`, makes it visible via (b).
        assert!(p.is_visible_edge(2, 3));
    }

    #[test]
    fn visible_via_condition_a() {
        // 0 o-> 1 --> 2 with 0 and 2 non-adjacent: an arrowhead at 1 from a
        // node disconnected from 2 is enough on its own.
        let p = build(3, &[(0, 1, "o->"), (1, 2, "-->")]);
        assert!(p.is_visible_edge(1, 2));

        // Connect 0 to 2 and the witness is gone; nothing else can serve.
        let q = build(3, &[(0, 1, "o->"), (1, 2, "-->"), (0, 2, "o->")]);
        assert!(!q.is_visible_edge(1, 2));
    }

    #[test]
    fn visible_via_condition_b_over_a_two_hop_collider_path() {
        // 0 --> 1 <-> 2 <-> 3 --> 4, with 1 --> 4 and 2 --> 4.
        // The only arrowhead at 3 comes from 2, which is adjacent to 4, so
        // condition (a) cannot fire. The collider path <0, 1, 2, 3> is into 3
        // and its non-endpoints 1 and 2 are both parents of 4, so (b) does.
        let p = build(
            5,
            &[
                (0, 1, "-->"),
                (1, 2, "<->"),
                (2, 3, "<->"),
                (3, 4, "-->"),
                (1, 4, "-->"),
                (2, 4, "-->"),
            ],
        );
        assert!(p.is_visible_edge(3, 4));

        // Replace 1 --> 4 by 1 <-> 4 and the interior vertex 1 is no longer a
        // parent of 4. It is still adjacent to 4, so it cannot serve as the
        // path source either, and the edge becomes invisible.
        let q = build(
            5,
            &[
                (0, 1, "-->"),
                (1, 2, "<->"),
                (2, 3, "<->"),
                (3, 4, "-->"),
                (1, 4, "<->"),
                (2, 4, "-->"),
            ],
        );
        assert!(!q.is_visible_edge(3, 4));
    }

    #[test]
    fn invisible_edge_with_no_witness() {
        // A lone directed edge has no candidate witness at all.
        let p = build(2, &[(0, 1, "-->")]);
        assert!(!p.is_visible_edge(0, 1));

        // A candidate that is not adjacent to 1 but whose edge is not *into*
        // 0 is no witness: a tail and a circle at 0 are both non-arrowheads.
        for glyph in ["-->", "--o"] {
            let q = build(3, &[(0, 1, "-->"), (0, 2, glyph)]);
            assert!(
                !q.is_visible_edge(0, 1),
                "`0 {} 2` is not into 0 and must not witness visibility",
                glyph
            );
        }
    }

    #[test]
    fn only_directed_edges_can_be_visible() {
        for glyph in ["o->", "<->", "--o", "o-o"] {
            // 2 o-> 0 supplies a witness into 0 that is not adjacent to 1, so
            // the only reason to return false is the type of the 0-1 edge.
            let p = build(3, &[(0, 1, glyph), (2, 0, "o->")]);
            assert!(
                !p.is_visible_edge(0, 1),
                "`{}` must never be visible",
                glyph
            );
        }
        // `---` gets no witness: an undirected endpoint carries no arrowhead
        // in a PAG, so `2 o-> 0` alongside `0 --- 1` is not even constructible.
        let und = build(3, &[(0, 1, "---")]);
        assert!(!und.is_visible_edge(0, 1));
        // The same witness makes the directed case visible, which pins the
        // fixture above as a real control.
        let p = build(3, &[(0, 1, "-->"), (2, 0, "o->")]);
        assert!(p.is_visible_edge(0, 1));
        // Visibility is directed: the reverse pair is not the edge.
        assert!(!p.is_visible_edge(1, 0));
    }

    #[test]
    fn visibility_edge_cases() {
        // Non-adjacent, self pair and out-of-range indices are all false
        // rather than panics.
        let p = build(3, &[(0, 1, "-->")]);
        assert!(!p.is_visible_edge(0, 2));
        assert!(!p.is_visible_edge(0, 0));
        assert!(!p.is_visible_edge(0, 7));
        assert!(!p.is_visible_edge(7, 0));

        let empty = build(0, &[]);
        assert!(!empty.is_visible_edge(0, 0));
        let single = build(1, &[]);
        assert!(!single.is_visible_edge(0, 0));
    }

    #[test]
    fn discriminating_path_on_the_pcalg_fixture() {
        let p = pcalg_fixture();
        // `pcalg:::minDiscrPath(amat, 2, 3, 4)` returns `1 2 3 4`, i.e.
        // <a, b, c, d>: `a` is not adjacent to `d`, and the interior vertex
        // `b` is a collider on the path and a parent of `d`.
        assert_eq!(p.discriminating_path(1, 2, 3), Some(vec![0, 1, 2, 3]));
    }

    #[test]
    fn discriminating_path_returns_the_whole_path() {
        // 0 --> 1 <-> 2 <-> 3 --o 4 with 1 --> 4 and 2 --> 4.
        let p = build(
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
        assert_eq!(
            p.discriminating_path(2, 3, 4),
            Some(vec![0, 1, 2, 3, 4]),
            "the source 0 must come first so R4 can read it off path[0]"
        );
    }

    #[test]
    fn discriminating_path_rejects_bad_triples() {
        let p = pcalg_fixture();
        // `a` must be a parent of `c`: `a --> b` is not into `d`.
        assert_eq!(p.discriminating_path(0, 2, 3), None);
        // `b` must be adjacent to `c`: `a` is not adjacent to `d`.
        assert_eq!(p.discriminating_path(1, 0, 3), None);
        // Degenerate triples are rejected rather than searched.
        assert_eq!(p.discriminating_path(1, 1, 3), None);
        assert_eq!(p.discriminating_path(1, 2, 9), None);
    }

    #[test]
    fn discriminating_path_needs_a_source_disconnected_from_c() {
        // Same shape as the fixture, but 0 is now adjacent to 3, so there is
        // no legal source and the triple is not discriminated.
        let p = build(
            4,
            &[
                (0, 1, "-->"),
                (1, 2, "<->"),
                (1, 3, "-->"),
                (2, 3, "-->"),
                (0, 3, "-->"),
            ],
        );
        assert_eq!(p.discriminating_path(1, 2, 3), None);
        assert!(!p.is_visible_edge(2, 3));
    }

    #[test]
    fn uncovered_pd_path_basics() {
        // 0 o-> 1 o-> 2 with 0 and 2 non-adjacent.
        let p = build(3, &[(0, 1, "o->"), (1, 2, "o->")]);
        assert_eq!(
            p.uncovered_pd_path(0, 2, None, None, &[]),
            Some(vec![0, 1, 2])
        );
        assert_eq!(
            p.uncovered_pd_path(0, 2, Some(1), Some(1), &[]),
            Some(vec![0, 1, 2])
        );
        // The pd relation is directed: there is no path back.
        assert_eq!(p.uncovered_pd_path(2, 0, None, None, &[]), None);
        // Degenerate and out-of-range arguments.
        assert_eq!(p.uncovered_pd_path(0, 0, None, None, &[]), None);
        assert_eq!(p.uncovered_pd_path(0, 9, None, None, &[]), None);
    }

    #[test]
    fn uncovered_pd_path_rejects_a_covered_triple() {
        // Adding 0 o-> 2 shields the triple <0, 1, 2>, so the two-edge path
        // is covered. The single-edge path 0 o-> 2 remains.
        let p = build(3, &[(0, 1, "o->"), (1, 2, "o->"), (0, 2, "o->")]);
        assert_eq!(p.uncovered_pd_path(0, 2, None, None, &[]), Some(vec![0, 2]));
        assert_eq!(p.uncovered_pd_path(0, 2, Some(1), None, &[]), None);
    }

    #[test]
    fn uncovered_pd_path_allows_adjacent_endpoints_on_longer_paths() {
        // 0 o-> 1 o-> 2 o-> 3 alongside 0 o-> 3. The triples <0, 1, 2> and
        // <1, 2, 3> are both unshielded, so the long path is uncovered even
        // though its endpoints are adjacent. This is the shape R9 and R10
        // search for out of an `a o-> c` edge.
        let p = build(
            4,
            &[(0, 1, "o->"), (1, 2, "o->"), (2, 3, "o->"), (0, 3, "o->")],
        );
        assert_eq!(
            p.uncovered_pd_path(0, 3, Some(1), None, &[]),
            Some(vec![0, 1, 2, 3])
        );
        assert_eq!(
            p.uncovered_pd_path(0, 3, Some(1), Some(2), &[])
                .unwrap()
                .len(),
            4
        );
        // `last` pins the far end, so an impossible pin fails.
        assert_eq!(p.uncovered_pd_path(0, 3, Some(1), Some(1), &[]), None);
        // The single-edge path is the one whose pins collapse onto the
        // endpoints themselves.
        assert_eq!(
            p.uncovered_pd_path(0, 3, Some(3), Some(0), &[]),
            Some(vec![0, 3])
        );
    }

    #[test]
    fn uncovered_pd_path_needs_every_edge_potentially_directed() {
        // A bidirected edge has an arrowhead at 0, so no member MAG orients
        // <0, 1, 2> forward.
        let p = build(3, &[(0, 1, "<->"), (1, 2, "o->")]);
        assert_eq!(p.uncovered_pd_path(0, 2, None, None, &[]), None);
        // An undirected edge has a tail at 1, which blocks it too.
        let q = build(3, &[(0, 1, "---"), (1, 2, "--o")]);
        assert_eq!(q.uncovered_pd_path(0, 2, None, None, &[]), None);
        // A partially undirected edge is fine in the forward direction.
        let r = build(3, &[(0, 1, "--o"), (1, 2, "--o")]);
        assert_eq!(
            r.uncovered_pd_path(0, 2, None, None, &[]),
            Some(vec![0, 1, 2])
        );
    }

    #[test]
    fn uncovered_pd_path_backtracks_past_a_covered_branch() {
        // Out of 0 there are two pd continuations, 1 and 2. Going by way of 1
        // is a dead end (1 has no pd continuation), so the search must back
        // up and take 2. Node 3 is the target.
        let p = build(4, &[(0, 1, "o->"), (0, 2, "o->"), (2, 3, "o->")]);
        assert_eq!(
            p.uncovered_pd_path(0, 3, None, None, &[]),
            Some(vec![0, 2, 3])
        );
    }

    #[test]
    fn uncovered_pd_path_stays_simple_around_a_cycle() {
        // A triangle of circles makes every neighbor a possible child, so the
        // path-local visited set is what keeps the search finite.
        let p = build(
            4,
            &[(0, 1, "o-o"), (1, 2, "o-o"), (0, 2, "o-o"), (2, 3, "o-o")],
        );
        let path = p
            .uncovered_pd_path(0, 3, None, None, &[])
            .expect("a path exists");
        let mut sorted = path.clone();
        sorted.sort_unstable();
        sorted.dedup();
        assert_eq!(sorted.len(), path.len(), "path repeats a node: {:?}", path);
        assert_eq!(path.first(), Some(&0));
        assert_eq!(path.last(), Some(&3));
    }
}
