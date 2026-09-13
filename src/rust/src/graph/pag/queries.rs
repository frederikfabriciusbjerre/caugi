// SPDX-License-Identifier: MIT
//! Definite-status and possible-relation queries for Partial Ancestral Graphs.
//!
//! A circle endpoint means the mark is not invariant across the represented
//! Markov equivalence class, so most relations split into a *definite* form
//! (holds in every member MAG) and a *possible* form (holds in at least one).
//!
//! Definitions follow Maathuis and Colombo (2015, Def. 3.4) and Zhang (2008):
//!
//! * `b` is a **definite collider** on `<a, b, c>` when both edges have an
//!   arrowhead at `b`.
//! * `b` is a **definite non-collider** on `<a, b, c>` when at least one of the
//!   two edges has a tail at `b`, or both have a circle at `b` and `a` and `c`
//!   are not adjacent.
//! * Otherwise `b` is of uncertain status on that triple.
//!
//! Note this is deliberately not a port of `pywhy_graphs`'
//! `is_definite_noncollider`, which returns `true` for `a --> b o-- c`. There
//! `b` carries an arrowhead and a circle and so has no tail on either edge,
//! leaving its status uncertain rather than a definite non-collider.

use super::Pag;
use crate::edges::Mark;

impl Pag {
    /// Sorted possible parents of `v`.
    ///
    /// `u` is a possible parent of `v` when the edge between them has no
    /// arrowhead at `u` and no tail at `v`, so that some MAG in the class can
    /// orient it `u --> v`. Circles are permissive at either end.
    pub fn possible_parents_of(&self, v: u32) -> Vec<u32> {
        let mut out = Vec::new();
        // (mark at v, mark at u): an arrowhead or circle at v, a tail or
        // circle at u. `<->` is excluded by the arrowhead at u, and `---` by
        // the tail at v.
        for (at_v, at_u) in [
            (Mark::Arrow, Mark::Tail),
            (Mark::Arrow, Mark::Circle),
            (Mark::Circle, Mark::Tail),
            (Mark::Circle, Mark::Circle),
        ] {
            out.extend_from_slice(self.neighbors_by_marks(v, at_v, at_u));
        }
        out.sort_unstable();
        out
    }

    /// Sorted possible children of `v`, the converse of
    /// [`Pag::possible_parents_of`].
    pub fn possible_children_of(&self, v: u32) -> Vec<u32> {
        let mut out = Vec::new();
        for (at_v, at_u) in [
            (Mark::Tail, Mark::Arrow),
            (Mark::Circle, Mark::Arrow),
            (Mark::Tail, Mark::Circle),
            (Mark::Circle, Mark::Circle),
        ] {
            out.extend_from_slice(self.neighbors_by_marks(v, at_v, at_u));
        }
        out.sort_unstable();
        out
    }

    /// The mark at `at` on the edge joining it to `from`, or `None` when the
    /// two nodes are not adjacent.
    pub fn mark_at(&self, at: u32, from: u32) -> Option<Mark> {
        const MARKS: [Mark; 3] = [Mark::Arrow, Mark::Tail, Mark::Circle];
        for my in MARKS {
            for nbr in MARKS {
                if self
                    .neighbors_by_marks(at, my, nbr)
                    .binary_search(&from)
                    .is_ok()
                {
                    return Some(my);
                }
            }
        }
        None
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

    #[test]
    fn mark_at_reads_both_endpoints() {
        let p = build(2, &[(0, 1, "o->")]); // 0 o-> 1
        assert_eq!(p.mark_at(0, 1), Some(Mark::Circle));
        assert_eq!(p.mark_at(1, 0), Some(Mark::Arrow));
        assert_eq!(p.mark_at(0, 0), None);
    }

    #[test]
    fn mark_at_is_none_for_non_adjacent() {
        let p = build(3, &[(0, 1, "-->")]);
        assert_eq!(p.mark_at(0, 2), None);
        assert_eq!(p.mark_at(2, 0), None);
    }

    #[test]
    fn possible_parents_excludes_bidirected_and_undirected() {
        // 0 <-> 1: an arrowhead at 0 rules 1 out as a possible parent.
        let bi = build(2, &[(0, 1, "<->")]);
        assert!(bi.possible_parents_of(0).is_empty());
        assert!(bi.possible_children_of(0).is_empty());

        // 0 --- 1: a tail at 0 rules 1 out too.
        let un = build(2, &[(0, 1, "---")]);
        assert!(un.possible_parents_of(0).is_empty());
        assert!(un.possible_children_of(0).is_empty());
    }

    #[test]
    fn possible_parents_accepts_all_four_orientable_edges() {
        // Each of these can be oriented into node 0 by some member MAG.
        for glyph in ["-->", "o->", "--o", "o-o"] {
            let p = build(2, &[(1, 0, glyph)]);
            assert_eq!(
                p.possible_parents_of(0),
                vec![1],
                "1 should be a possible parent of 0 across `{}`",
                glyph
            );
        }
    }
}
