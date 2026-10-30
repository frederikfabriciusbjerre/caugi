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
use super::CaugiGraph;
use crate::edges::Mark;
use std::sync::Arc;

#[derive(Debug, Clone)]
pub struct Pag {
    core: Arc<CaugiGraph>,
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

    /// Reject marks a PAG cannot carry.
    fn index(core: Arc<CaugiGraph>) -> Result<Self, PagError> {
        for i in 0..core.n() {
            for k in core.row_range(i) {
                if core.my_mark(k) == Mark::Other {
                    return Err(PagError::InvalidEdgeType {
                        found: core.spec(k).glyph.clone(),
                    });
                }
            }
        }
        Ok(Self { core })
    }

    /// Number of nodes.
    #[inline]
    pub fn n(&self) -> u32 {
        self.core.n()
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
