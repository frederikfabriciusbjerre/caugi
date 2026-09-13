// SPDX-License-Identifier: MIT
//! Partial Ancestral Graph (PAG) wrapper with O(1) slice queries via packed neighborhoods.
//!
//! A PAG represents a Markov equivalence class of maximal ancestral graphs. Each
//! edge endpoint carries one of three marks: an arrowhead, a tail, or a circle. A
//! circle means the mark is *not* invariant across the class, so the six edge
//! types are `-->`, `---`, `<->`, `o-o`, `--o` and `o->`.
//!
//! Selection bias is supported, so `---` and `--o` are permitted.
//!
//! This wrapper validates the *structural* invariants that every PAG satisfies
//! (stages S0 and S1):
//!
//! 1. Every endpoint mark is an arrowhead, a tail, or a circle.
//! 2. The definite directed part (`-->` only) is acyclic.
//! 3. If a node is the endpoint of an undirected edge, it carries no arrowhead.
//! 4. Anterior constraint: wherever there is a definite arrowhead at `v` on an
//!    edge from `u`, `v` is not a definite anterior of `u`.
//!
//! These are necessary but not sufficient. Deciding whether a graph is the PAG of
//! some MAG additionally requires the round-trip check through `pag_to_mag` and
//! `mag_to_pag`; see `todo.md`.

mod marks;
mod orient;
mod paths;
mod queries;
mod transforms;

use super::error::PagError;
use super::packed::{PackedBuckets, PackedBucketsBuilder};
use super::CaugiGraph;
use crate::edges::Mark;
use crate::graph::alg::directed_part_is_acyclic;
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

/// Is the directed edge `a --> b` visible in the maximal ancestral graph `mag`?
///
/// Visibility is defined for MAGs as well as PAGs -- `pcalg::visibleEdge`
/// documents "in a MAG or in a PAG" -- and the criterion is identical, so this
/// shares the implementation. It exists because [`marks::MarkGraph`] is private
/// to this module while `Ag` lives next door.
pub fn visible_edge_in_mag(mag: &crate::graph::ag::Ag, a: u32, b: u32) -> bool {
    marks::MarkGraph::visible_edge(mag, a, b)
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

    /// Builds a `Pag` view with typed error handling, checking the full
    /// invariant: the structural constraints *and* that the marks really are
    /// the invariant marks of a Markov equivalence class.
    ///
    /// The latter is decided by the round trip through [`Pag::to_mag`] and
    /// [`Pag::from_mag`]. It is what rules out an over-oriented graph (a
    /// definite mark that is not in fact invariant) or an under-oriented one
    /// (a circle where an invariant mark belongs); no structural check can see
    /// either. It also makes construction exponential in the worst case, since
    /// it tests the constructed MAG for maximality.
    pub fn try_new(core: Arc<CaugiGraph>) -> Result<Self, PagError> {
        let pag = Self::structural(core)?;

        let mag = pag
            .to_mag()
            .map_err(|e| PagError::NotAnEquivalenceClass { reason: e })?;
        let back =
            Self::from_mag(&mag).map_err(|e| PagError::NotAnEquivalenceClass { reason: e })?;
        if back.to_marks().edges() != pag.to_marks().edges() {
            return Err(PagError::NotAnEquivalenceClass {
                reason: "the marks are not the invariant marks of a Markov equivalence \
                         class; mag_to_pag does not map a member back to this graph"
                    .into(),
            });
        }
        Ok(pag)
    }

    /// Builds a `Pag` checking only the structural invariants.
    ///
    /// Used by [`Pag::from_mag`], whose output is a PAG by construction and
    /// which the full check would call back into.
    pub(super) fn new_unchecked(core: Arc<CaugiGraph>) -> Result<Self, String> {
        Self::structural(core).map_err(|e| e.to_string())
    }

    /// The structural invariants only: stages S0 and S1.
    fn structural(core: Arc<CaugiGraph>) -> Result<Self, PagError> {
        let n = core.n() as usize;

        let mut builder: PackedBucketsBuilder<N_BUCKETS> = PackedBucketsBuilder::new(n);
        let mut has_undirected = vec![false; n];
        let mut has_arrowhead = vec![false; n];

        // Count pass, which also rejects marks that cannot appear in a PAG.
        for i in 0..n {
            for k in core.row_range(i as u32) {
                let (my, nbr) = core.marks(k);
                let bucket = bucket_index(my, nbr).ok_or_else(|| PagError::InvalidEdgeType {
                    found: core.spec(k).glyph.clone(),
                })?;
                builder.inc_degree(i, bucket);
                if my == Mark::Arrow {
                    has_arrowhead[i] = true;
                }
                if my == Mark::Tail && nbr == Mark::Tail {
                    has_undirected[i] = true;
                }
            }
        }

        if !directed_part_is_acyclic(&core) {
            return Err(PagError::DirectedCycle);
        }

        for i in 0..n {
            if has_undirected[i] && has_arrowhead[i] {
                return Err(PagError::UndirectedConstraintViolation { node: i as u32 });
            }
        }

        builder.finalize_degrees();

        for i in 0..n {
            for k in core.row_range(i as u32) {
                let (my, nbr) = core.marks(k);
                let bucket =
                    bucket_index(my, nbr).expect("invalid marks rejected in the count pass");
                builder.scatter(i, bucket, core.col_index[k]);
            }
        }

        builder.sort_all();

        let pag = Self {
            core,
            packed: builder.build(),
        };
        pag.validate_anterior_constraint()?;
        Ok(pag)
    }

    /// Every definite arrowhead must respect the anterior constraint.
    ///
    /// This covers arrowheads contributed by `-->`, `<->` and `o->` alike: a
    /// circle is not a definite mark, so only the arrowhead end constrains.
    fn validate_anterior_constraint(&self) -> Result<(), PagError> {
        for v in 0..self.n() {
            for u in self.arrowheads_at(v) {
                if self.is_anterior_of(v, u) {
                    return Err(PagError::AnteriorConstraintViolation {
                        source: u,
                        target: v,
                    });
                }
            }
        }
        Ok(())
    }

    /// Is `v` a definite anterior of `u`?
    fn is_anterior_of(&self, v: u32, u: u32) -> bool {
        if v == u {
            return true;
        }
        self.anteriors_of(u).binary_search(&v).is_ok()
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

    /// Sorted neighbors joined to `i` by `o-o`.
    #[inline]
    pub fn circles_of(&self, i: u32) -> &[u32] {
        self.neighbors_by_marks(i, Mark::Circle, Mark::Circle)
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

    /// Are `a` and `b` adjacent by any edge?
    pub fn adjacent(&self, a: u32, b: u32) -> bool {
        // `neighbors_of` concatenates individually-sorted buckets, so the
        // combined slice is not globally sorted; search each bucket instead.
        (0..N_BUCKETS).any(|bucket| {
            self.packed
                .bucket_slice(a, bucket)
                .binary_search(&b)
                .is_ok()
        })
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

impl Pag {
    /// Neighbors joined to `i` by an edge with a definite arrowhead at `i`.
    ///
    /// Allocates, because the three contributing buckets (`<->`, `<--`, `<-o`)
    /// are not contiguous under the mark-pair keying.
    fn arrowheads_at(&self, i: u32) -> Vec<u32> {
        let mut out = Vec::new();
        for nbr in [Mark::Arrow, Mark::Tail, Mark::Circle] {
            out.extend_from_slice(self.neighbors_by_marks(i, Mark::Arrow, nbr));
        }
        out
    }
}

impl crate::graph::traits::DirectedNeighbors for Pag {
    #[inline]
    fn n(&self) -> u32 {
        Pag::n(self)
    }
    #[inline]
    fn parents_of(&self, i: u32) -> &[u32] {
        Pag::parents_of(self, i)
    }
    #[inline]
    fn children_of(&self, i: u32) -> &[u32] {
        Pag::children_of(self, i)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    /// Registry plus the codes for all six PAG edge types.
    struct Codes {
        reg: EdgeRegistry,
        dir: u8,
        bid: u8,
        und: u8,
        cc: u8,
        ca: u8,
        tc: u8,
    }

    fn setup() -> Codes {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        Codes {
            dir: reg.code_of("-->").unwrap(),
            bid: reg.code_of("<->").unwrap(),
            und: reg.code_of("---").unwrap(),
            cc: reg.code_of("o-o").unwrap(),
            ca: reg.code_of("o->").unwrap(),
            tc: reg.code_of("--o").unwrap(),
            reg,
        }
    }

    #[test]
    fn accepts_all_six_edge_types_and_buckets_them_by_marks() {
        let c = setup();
        let mut b = GraphBuilder::new_with_registry(7, true, &c.reg);
        b.add_edge(0, 1, c.dir).unwrap(); // 0 --> 1
        b.add_edge(2, 3, c.bid).unwrap(); // 2 <-> 3
        b.add_edge(4, 5, c.cc).unwrap(); // 4 o-o 5
        b.add_edge(0, 6, c.ca).unwrap(); // 0 o-> 6
        let pag = Pag::new_unchecked(Arc::new(b.finalize().unwrap())).expect("construction failed");

        assert_eq!(pag.n(), 7);
        assert_eq!(pag.children_of(0), &[1]);
        assert_eq!(pag.parents_of(1), &[0]);
        assert_eq!(pag.spouses_of(2), &[3]);
        assert_eq!(pag.circles_of(4), &[5]);
        // `0 o-> 6` is a circle at 0 and an arrowhead at 6, so it lands in
        // neither `children_of` nor `parents_of`.
        assert_eq!(pag.children_of(0), &[1]);
        assert_eq!(pag.neighbors_by_marks(0, Mark::Circle, Mark::Arrow), &[6]);
        assert_eq!(pag.neighbors_by_marks(6, Mark::Arrow, Mark::Circle), &[0]);
        assert!(pag.adjacent(0, 6) && pag.adjacent(6, 0));
    }

    #[test]
    fn partially_undirected_edge_is_accepted() {
        let c = setup();
        let mut b = GraphBuilder::new_with_registry(2, true, &c.reg);
        b.add_edge(0, 1, c.tc).unwrap(); // 0 --o 1, selection bias in scope
        let pag = Pag::new_unchecked(Arc::new(b.finalize().unwrap())).expect("construction failed");
        assert_eq!(pag.neighbors_by_marks(0, Mark::Tail, Mark::Circle), &[1]);
        assert_eq!(pag.neighbors_by_marks(1, Mark::Circle, Mark::Tail), &[0]);
        assert!(pag.undirected_of(0).is_empty());
    }

    #[test]
    fn definite_directed_cycle_rejected() {
        let c = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &c.reg);
        b.add_edge(0, 1, c.dir).unwrap();
        b.add_edge(1, 2, c.dir).unwrap();
        b.add_edge(2, 0, c.dir).unwrap();
        let err = Pag::new_unchecked(Arc::new(b.finalize().unwrap())).unwrap_err();
        assert!(err.contains("cycle"), "unexpected error: {}", err);
    }

    #[test]
    fn circle_arrow_cycle_is_allowed() {
        // `o->` carries no definite tail, so a cycle of them is not a definite
        // directed cycle and must not be rejected at this stage.
        let c = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &c.reg);
        b.add_edge(0, 1, c.ca).unwrap();
        b.add_edge(1, 2, c.ca).unwrap();
        b.add_edge(2, 0, c.ca).unwrap();
        assert!(Pag::new_unchecked(Arc::new(b.finalize().unwrap())).is_ok());
    }

    #[test]
    fn almost_directed_cycle_rejected() {
        // 0 --> 1 --> 2 together with 0 <-> 2 puts an arrowhead at 0 from a
        // node that 0 is an ancestor of.
        let c = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &c.reg);
        b.add_edge(0, 1, c.dir).unwrap();
        b.add_edge(1, 2, c.dir).unwrap();
        b.add_edge(0, 2, c.bid).unwrap();
        let err = Pag::new_unchecked(Arc::new(b.finalize().unwrap())).unwrap_err();
        assert!(err.contains("Anterior"), "unexpected error: {}", err);
    }

    #[test]
    fn anterior_constraint_applies_to_circle_arrow_edges() {
        // 0 --> 1 --> 2 with 2 o-> 0: the arrowhead at 0 is definite even
        // though the other end is a circle, so the constraint must bite.
        let c = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &c.reg);
        b.add_edge(0, 1, c.dir).unwrap();
        b.add_edge(1, 2, c.dir).unwrap();
        b.add_edge(2, 0, c.ca).unwrap();
        let err = Pag::new_unchecked(Arc::new(b.finalize().unwrap())).unwrap_err();
        assert!(err.contains("Anterior"), "unexpected error: {}", err);
    }

    #[test]
    fn undirected_endpoint_with_arrowhead_rejected() {
        let c = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &c.reg);
        b.add_edge(0, 1, c.und).unwrap(); // 0 --- 1
        b.add_edge(2, 1, c.dir).unwrap(); // 2 --> 1, arrowhead at 1
        let err = Pag::new_unchecked(Arc::new(b.finalize().unwrap())).unwrap_err();
        assert!(err.contains("Undirected"), "unexpected error: {}", err);
    }

    #[test]
    fn undirected_endpoint_with_circle_arrowhead_rejected() {
        // The arrowhead at 1 is definite even though 2's end is a circle.
        let c = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &c.reg);
        b.add_edge(0, 1, c.und).unwrap();
        b.add_edge(2, 1, c.ca).unwrap();
        let err = Pag::new_unchecked(Arc::new(b.finalize().unwrap())).unwrap_err();
        assert!(err.contains("Undirected"), "unexpected error: {}", err);
    }

    #[test]
    fn undirected_endpoint_with_circle_tail_allowed() {
        // `--o` leaves the mark at 1 undetermined, so it does not conflict
        // with 0 --- 1 at this stage.
        let c = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &c.reg);
        b.add_edge(0, 1, c.und).unwrap();
        b.add_edge(2, 1, c.tc).unwrap();
        assert!(Pag::new_unchecked(Arc::new(b.finalize().unwrap())).is_ok());
    }

    #[test]
    fn definite_ancestry_ignores_circles() {
        let c = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &c.reg);
        b.add_edge(0, 1, c.dir).unwrap(); // 0 --> 1
        b.add_edge(1, 2, c.dir).unwrap(); // 1 --> 2
        b.add_edge(2, 3, c.ca).unwrap(); // 2 o-> 3, not definite ancestry
        let pag = Pag::new_unchecked(Arc::new(b.finalize().unwrap())).expect("construction failed");
        assert_eq!(pag.ancestors_of(2), &[0, 1]);
        assert_eq!(pag.descendants_of(0), &[1, 2]);
        assert!(pag.ancestors_of(3).is_empty());
    }

    #[test]
    fn anteriors_follow_undirected_edges() {
        // An undirected endpoint may carry a tail but never an arrowhead, so
        // the directed edge has to leave the undirected component.
        let c = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &c.reg);
        b.add_edge(0, 1, c.und).unwrap(); // 0 --- 1
        b.add_edge(1, 2, c.dir).unwrap(); // 1 --> 2
        let pag = Pag::new_unchecked(Arc::new(b.finalize().unwrap())).expect("construction failed");
        assert_eq!(pag.anteriors_of(1), &[0]);
        assert_eq!(pag.anteriors_of(2), &[0, 1]);
    }

    #[test]
    fn empty_and_single_node_graphs_are_valid() {
        let c = setup();
        for n in [0u32, 1] {
            let b = GraphBuilder::new_with_registry(n, true, &c.reg);
            let pag =
                Pag::new_unchecked(Arc::new(b.finalize().unwrap())).expect("construction failed");
            assert_eq!(pag.n(), n);
        }
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
