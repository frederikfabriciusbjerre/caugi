// SPDX-License-Identifier: MIT
//! Partial Ancestral Graph (PAG) wrapper, and the mark-level reading of a
//! graph that MAG and PAG predicates share.
//!
//! A PAG represents the Markov equivalence class of a maximal ancestral graph.
//! Each endpoint is an arrowhead, a tail or a circle, where a circle marks an
//! endpoint that is not invariant across the class. Selection bias is in
//! scope, so all six edge types `-->`, `---`, `<->`, `o-o`, `--o` and `o->`
//! are allowed.
//!
//! Construction validates completely: a graph is a PAG iff `pag_to_mag`
//! yields a MAG and `mag_to_pag` maps that MAG back to the graph.

mod marked;
mod orient;
mod transforms;

pub(crate) use marked::MarkedGraph;

use super::error::PagError;
use super::packed::{PackedBuckets, PackedBucketsBuilder};
use super::CaugiGraph;
use crate::edges::Mark;
use crate::graph::alg::traversal;
use std::sync::Arc;

/// Number of endpoint marks a PAG edge may carry (arrowhead, tail, circle).
const N_MARKS: usize = 3;
/// One bucket per ordered `(mark at me, mark at neighbor)` pair.
const N_BUCKETS: usize = N_MARKS * N_MARKS;

/// Position of `mark` in the bucket key, or `None` if the mark cannot appear in a PAG.
#[inline]
fn mark_index(mark: Mark) -> Option<usize> {
    match mark {
        Mark::Arrow => Some(0),
        Mark::Tail => Some(1),
        Mark::Circle => Some(2),
        Mark::Other => None,
    }
}

/// Bucket holding the neighbors reached by an edge with these marks.
///
/// Keying on the ordered mark pair rather than on hand-picked edge roles keeps a
/// single indexing rule for all six PAG edge types, so every PAG predicate is a
/// union of sorted slices.
#[inline]
fn bucket_index(my: Mark, nbr: Mark) -> Option<usize> {
    Some(mark_index(my)? * N_MARKS + mark_index(nbr)?)
}

#[derive(Debug, Clone)]
pub struct Pag {
    core: Arc<CaugiGraph>,
    /// Packed as one bucket per `(mark at me, mark at neighbor)` pair, in the
    /// order given by [`bucket_index`].
    packed: PackedBuckets<N_BUCKETS>,
}

impl Pag {
    /// Builds a `Pag` view over a class-agnostic CSR graph.
    ///
    /// Returns a `String` error for FFI compatibility. Use [`Pag::try_new`] for
    /// typed errors.
    pub fn new(core: Arc<CaugiGraph>) -> Result<Self, String> {
        Self::try_new(core).map_err(|e| e.to_string())
    }

    /// Builds a `Pag` view with typed errors, checking that the marks are
    /// the invariant marks of a Markov equivalence class.
    ///
    /// That is the round trip: [`Pag::to_mag`] must give an ancestral graph
    /// that is maximal, and [`Pag::from_mag`] must map it back to this graph.
    /// It rejects over-orientation (a definite mark that is not invariant) and
    /// under-orientation (a circle where an invariant mark belongs), and
    /// everything a structural check would: `to_mag` keeps every definite
    /// mark, so a definite cycle or anterior violation survives into the MAG.
    /// The maximality test makes this exponential in the worst case.
    pub fn try_new(core: Arc<CaugiGraph>) -> Result<Self, PagError> {
        let invalid = |reason: String| PagError::NotAnEquivalenceClass { reason };
        // The round trip compares one mark pair per node pair, so it cannot
        // see a self-loop or a parallel edge (Richardson and Spirtes 2002,
        // Sec. 2.2). Reject those first.
        core.check_simple().map_err(|e| invalid(e.to_string()))?;
        let pag = Self::index(core)?;
        let marks = MarkedGraph::from_core(pag.core_ref()).map_err(invalid)?;

        let mag = pag.to_mag().map_err(invalid)?;
        if !mag.is_mag() {
            return Err(invalid("its member ancestral graph is not maximal".into()));
        }
        // `to_mag` keeps the skeleton, so the two mark vectors line up.
        let back = transforms::pag_of_mag(&mag).map_err(invalid)?;
        if !back.same_marks(&marks) {
            return Err(invalid(
                "the marks are not the invariant marks of a Markov equivalence class; \
                 mag_to_pag does not map a member back to this graph"
                    .into(),
            ));
        }
        Ok(pag)
    }

    /// Builds a `Pag` without validating it, for [`Pag::from_mag`], whose
    /// output is a PAG by construction and which validation calls.
    pub(super) fn new_unchecked(core: Arc<CaugiGraph>) -> Result<Self, String> {
        Self::index(core).map_err(|e| e.to_string())
    }

    /// Index the neighbours by mark pair, rejecting marks a PAG cannot carry.
    fn index(core: Arc<CaugiGraph>) -> Result<Self, PagError> {
        let n = core.n() as usize;
        let mut builder: PackedBucketsBuilder<N_BUCKETS> = PackedBucketsBuilder::new(n);
        for i in 0..n {
            for k in core.row_range(i as u32) {
                let (my, nbr) = core.marks(k);
                let bucket = bucket_index(my, nbr).ok_or_else(|| PagError::InvalidEdgeType {
                    found: core.spec(k).glyph.clone(),
                })?;
                builder.inc_degree(i, bucket);
            }
        }
        builder.finalize_degrees();
        for i in 0..n {
            for k in core.row_range(i as u32) {
                let (my, nbr) = core.marks(k);
                let bucket = bucket_index(my, nbr).expect("checked in the count pass");
                builder.scatter(i, bucket, core.col_index[k]);
            }
        }
        builder.sort_all();
        Ok(Self {
            core,
            packed: builder.build(),
        })
    }

    /// Number of nodes.
    #[inline]
    pub fn n(&self) -> u32 {
        self.core.n()
    }

    /// Sorted neighbors of `i` reached by an edge whose mark at `i` is `my` and
    /// whose mark at the neighbor is `nbr`.
    ///
    /// Returns an empty slice for mark pairs that cannot occur in a PAG.
    #[inline]
    pub fn neighbors_by_marks(&self, i: u32, my: Mark, nbr: Mark) -> &[u32] {
        match bucket_index(my, nbr) {
            Some(bucket) => self.packed.bucket_slice(i, bucket),
            None => &[],
        }
    }

    /// Sorted parents of `i`, i.e. the tail ends of `--> i`.
    #[inline]
    pub fn parents_of(&self, i: u32) -> &[u32] {
        self.neighbors_by_marks(i, Mark::Arrow, Mark::Tail)
    }

    /// Sorted children of `i`, i.e. the arrowhead ends of `i -->`.
    #[inline]
    pub fn children_of(&self, i: u32) -> &[u32] {
        self.neighbors_by_marks(i, Mark::Tail, Mark::Arrow)
    }

    /// Sorted spouses of `i`, i.e. neighbors joined by `<->`.
    #[inline]
    pub fn spouses_of(&self, i: u32) -> &[u32] {
        self.neighbors_by_marks(i, Mark::Arrow, Mark::Arrow)
    }

    /// Sorted neighbors joined to `i` by `---`.
    #[inline]
    pub fn undirected_of(&self, i: u32) -> &[u32] {
        self.neighbors_by_marks(i, Mark::Tail, Mark::Tail)
    }

    /// All neighbors of `i`, across every mark pair.
    #[inline]
    pub fn neighbors_of(&self, i: u32) -> &[u32] {
        self.packed.all_neighbors(i)
    }

    /// Neighbors joined to `i` by an edge carrying a circle at either end,
    /// i.e. by `o-o`, `o->` or `--o`.
    ///
    /// Allocates, because the contributing buckets are not contiguous under the
    /// mark-pair keying.
    pub fn partial_of(&self, i: u32) -> Vec<u32> {
        let mut out = Vec::new();
        for (my, nbr) in [
            (Mark::Arrow, Mark::Circle),
            (Mark::Tail, Mark::Circle),
            (Mark::Circle, Mark::Arrow),
            (Mark::Circle, Mark::Tail),
            (Mark::Circle, Mark::Circle),
        ] {
            out.extend_from_slice(self.neighbors_by_marks(i, my, nbr));
        }
        out.sort_unstable();
        out
    }

    /// Definite posteriors of `i`, via `-->` and `---` edges only.
    #[inline]
    pub fn posteriors_of(&self, i: u32) -> Vec<u32> {
        traversal::posteriors_of(
            self.n(),
            i,
            |u| self.children_of(u),
            |u| self.undirected_of(u),
        )
    }

    /// Definite ancestors of `i`, via `-->` edges only, in ascending order.
    #[inline]
    pub fn ancestors_of(&self, i: u32) -> Vec<u32> {
        traversal::ancestors_of(self.n(), i, |u| self.parents_of(u))
    }

    /// Definite descendants of `i`, via `-->` edges only, in ascending order.
    #[inline]
    pub fn descendants_of(&self, i: u32) -> Vec<u32> {
        traversal::descendants_of(self.n(), i, |u| self.children_of(u))
    }

    /// Definite anteriors of `i`, via `-->` and `---` edges only.
    #[inline]
    pub fn anteriors_of(&self, i: u32) -> Vec<u32> {
        traversal::anteriors_of(
            self.n(),
            i,
            |u| self.parents_of(u),
            |u| self.undirected_of(u),
        )
    }

    /// Borrow the underlying class-agnostic graph.
    #[inline]
    pub fn core_ref(&self) -> &CaugiGraph {
        &self.core
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    fn core(n: u32, edges: &[(u32, u32, &str)]) -> Arc<CaugiGraph> {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let mut b = GraphBuilder::new_with_registry(n, false, &reg);
        for &(u, v, glyph) in edges {
            b.add_edge(u, v, reg.code_of(glyph).unwrap()).unwrap();
        }
        Arc::new(b.finalize().unwrap())
    }

    fn unchecked(n: u32, edges: &[(u32, u32, &str)]) -> Pag {
        Pag::new_unchecked(core(n, edges)).expect("construction failed")
    }

    #[test]
    fn buckets_neighbours_by_mark_pair() {
        let pag = unchecked(
            8,
            &[
                (0, 1, "-->"),
                (2, 3, "<->"),
                (4, 5, "o-o"),
                (0, 6, "o->"),
                (0, 7, "--o"),
            ],
        );
        assert_eq!(pag.children_of(0), &[1]);
        assert_eq!(pag.parents_of(1), &[0]);
        assert_eq!(pag.spouses_of(2), &[3]);
        assert_eq!(pag.neighbors_by_marks(4, Mark::Circle, Mark::Circle), &[5]);
        // `o->` and `--o` are neither children nor parents.
        assert_eq!(pag.neighbors_by_marks(0, Mark::Circle, Mark::Arrow), &[6]);
        assert_eq!(pag.neighbors_by_marks(6, Mark::Arrow, Mark::Circle), &[0]);
        assert_eq!(pag.neighbors_by_marks(0, Mark::Tail, Mark::Circle), &[7]);
        assert_eq!(pag.partial_of(0), vec![6, 7]);
        assert!(pag.undirected_of(0).is_empty());
    }

    #[test]
    fn valid_pags_are_accepted() {
        // The PAG of the collider `0 --> 2 <-- 1`.
        assert!(Pag::new(core(3, &[(0, 2, "o->"), (1, 2, "o->")])).is_ok());
        for n in [0u32, 1] {
            assert!(Pag::new(core(n, &[])).is_ok());
        }
    }

    #[test]
    fn structural_violations_are_rejected_by_the_round_trip() {
        for (what, n, edges) in [
            (
                "definite cycle",
                3,
                &[(0, 1, "-->"), (1, 2, "-->"), (2, 0, "-->")][..],
            ),
            (
                "almost directed cycle",
                3,
                &[(0, 1, "-->"), (1, 2, "-->"), (0, 2, "<->")],
            ),
            (
                "anterior via o->",
                3,
                &[(0, 1, "-->"), (1, 2, "-->"), (2, 0, "o->")],
            ),
            (
                "arrowhead at undirected",
                3,
                &[(0, 1, "---"), (2, 1, "-->")],
            ),
            ("o-> at undirected", 3, &[(0, 1, "---"), (2, 1, "o->")]),
        ] {
            assert!(Pag::new(core(n, edges)).is_err(), "{} accepted", what);
        }
    }

    #[test]
    fn self_loops_and_parallel_edges_are_rejected() {
        // Both survive the lossy mark-table round trip unchanged, so they
        // must be caught before it.
        let err = Pag::new(core(1, &[(0, 0, "-->")])).unwrap_err();
        assert!(err.contains("Self-loop"), "unexpected error: {}", err);
        let err = Pag::new(core(2, &[(0, 1, "o-o"), (0, 1, "-->")])).unwrap_err();
        assert!(err.contains("arallel"), "unexpected error: {}", err);
    }

    #[test]
    fn mis_oriented_graphs_are_rejected() {
        // Over-oriented: with 0 and 2 non-adjacent, whether 1 is a collider
        // differs between members.
        let err = Pag::new(core(3, &[(0, 1, "o->"), (1, 2, "o-o")])).unwrap_err();
        assert!(err.contains("invariant marks"), "unexpected error: {}", err);
        // Under-oriented: R1 makes `2 --> 3` invariant off the collider.
        let under = [(0, 2, "o->"), (1, 2, "o->"), (2, 3, "o-o")];
        assert!(Pag::new(core(4, &under)).is_err());
        assert!(Pag::new(core(4, &[(0, 2, "o->"), (1, 2, "o->"), (2, 3, "-->")])).is_ok());
    }

    #[test]
    fn definite_ancestry_ignores_circles() {
        let pag = unchecked(4, &[(0, 1, "-->"), (1, 2, "-->"), (2, 3, "o->")]);
        assert_eq!(pag.ancestors_of(2), &[0, 1]);
        assert_eq!(pag.descendants_of(0), &[1, 2]);
        assert!(pag.ancestors_of(3).is_empty());
    }

    #[test]
    fn anteriors_follow_undirected_edges() {
        let pag = unchecked(3, &[(0, 1, "---"), (1, 2, "-->")]);
        assert_eq!(pag.anteriors_of(1), &[0]);
        assert_eq!(pag.anteriors_of(2), &[0, 1]);
    }

    #[test]
    fn non_pag_mark_rejected() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let weird = reg
            .register(crate::edges::EdgeSpec {
                glyph: "x-x".into(),
                tail: Mark::Other,
                head: Mark::Other,
                symmetric: true,
                class: crate::edges::EdgeClass::Undirected,
            })
            .unwrap();
        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, weird).unwrap();
        let err = Pag::new_unchecked(Arc::new(b.finalize().unwrap())).unwrap_err();
        assert!(err.contains("x-x"), "unexpected error: {}", err);
    }
}
