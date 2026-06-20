// SPDX-License-Identifier: MIT
//! Cpdag wrapper: an `Mpdag` carrying type-level evidence of being the essential
//! graph of a Markov equivalence class.
//!
//! A CPDAG (completed PDAG) is the canonical representative of a Markov
//! equivalence class of DAGs: a PDAG whose chain components are chordal, whose
//! component DAG is acyclic, that is closed under Meek's rules, and whose every
//! arrow is strongly protected. Since CPDAG ⊆ MPDAG ⊆ PDAG, `Cpdag` is
//! composition over an `Mpdag` (same `PackedBuckets<3>` storage) plus a stronger
//! invariant. Accessors are inherited from `Mpdag` (and thus `Pdag`) via `Deref`.

use super::mpdag::Mpdag;
use super::pdag::Pdag;
use super::traits::{Acyclic, MeekClosed, NoBidirected};

#[derive(Debug, Clone)]
pub struct Cpdag {
    inner: Mpdag,
}

impl Cpdag {
    /// Builds a `Cpdag` view from a `Pdag`, validating the full CPDAG invariant
    /// (chordal chain components, acyclic component DAG, Meek closure, and strong
    /// arrow protection) via [`Pdag::is_cpdag`].
    pub fn try_new(pdag: Pdag) -> Result<Self, String> {
        if !pdag.is_cpdag() {
            return Err(
                "graph is not a CPDAG (chain components must be chordal and every arrow \
                 strongly protected under a Meek-closed orientation)"
                    .into(),
            );
        }
        // A CPDAG is Meek-closed by definition, so this never re-fails.
        let mpdag = Mpdag::from_closed_unchecked(pdag);
        Ok(Self { inner: mpdag })
    }

    /// Builds a `Cpdag` from an `Mpdag` without re-validating the CPDAG invariant.
    ///
    /// The caller MUST guarantee the input is a genuine CPDAG (e.g. produced by
    /// `Dag::to_cpdag`, whose output is the essential graph of the DAG's Markov
    /// equivalence class). A debug-only assertion catches misuse during
    /// development.
    pub(crate) fn from_valid_unchecked(mpdag: Mpdag) -> Self {
        debug_assert!(
            mpdag.is_cpdag(),
            "Cpdag::from_valid_unchecked called on a non-CPDAG Mpdag"
        );
        Self { inner: mpdag }
    }

    /// Borrow the inner `Mpdag`. A CPDAG is always an MPDAG.
    pub fn as_mpdag(&self) -> &Mpdag {
        &self.inner
    }

    /// Borrow the inner `Pdag`. Most callers don't need this — `Deref` lets
    /// `&Cpdag` be used anywhere `&Pdag` (or `&Mpdag`) is expected.
    pub fn as_pdag(&self) -> &Pdag {
        self.inner.as_pdag()
    }

    /// Consume the `Cpdag`, yielding the inner `Mpdag` (a downgrade — every CPDAG
    /// is an MPDAG). Used when a caller asks for an MPDAG view of a CPDAG.
    pub fn into_mpdag(self) -> Mpdag {
        self.inner
    }
}

impl std::ops::Deref for Cpdag {
    type Target = Mpdag;
    fn deref(&self) -> &Mpdag {
        &self.inner
    }
}

impl Acyclic for Cpdag {}
impl MeekClosed for Cpdag {}
impl NoBidirected for Cpdag {}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use std::sync::Arc;

    fn cpdag_pdag() -> Pdag {
        // 0 --- 1 --- 2: a chordal, v-structure-free chain. This is the CPDAG of
        // e.g. 0 -> 1 -> 2 (its Markov equivalence class has no compelled edges).
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let und = reg.code_of("---").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, und).unwrap();
        b.add_edge(1, 2, und).unwrap();
        Pdag::new(Arc::new(b.finalize().unwrap())).unwrap()
    }

    fn meek_closed_non_cpdag_pdag() -> Pdag {
        // 0 --- 1 --- 2 --- 3 --- 0: a chordless undirected 4-cycle. It is
        // Meek-closed (all undirected, no v-structures to fire R1–R4), but its
        // single chain component is not chordal, so it is not a CPDAG.
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let und = reg.code_of("---").unwrap();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, und).unwrap();
        b.add_edge(1, 2, und).unwrap();
        b.add_edge(2, 3, und).unwrap();
        b.add_edge(3, 0, und).unwrap();
        Pdag::new(Arc::new(b.finalize().unwrap())).unwrap()
    }

    #[test]
    fn try_new_accepts_cpdag() {
        let pdag = cpdag_pdag();
        assert!(pdag.is_meek_closed());
        let cpdag = Cpdag::try_new(pdag).expect("a genuine CPDAG should be accepted");
        assert_eq!(cpdag.n(), 3);
    }

    #[test]
    fn try_new_rejects_meek_closed_non_cpdag() {
        let pdag = meek_closed_non_cpdag_pdag();
        // Confirm the premise: Meek-closed but not a CPDAG.
        assert!(pdag.is_meek_closed());
        assert!(!pdag.is_cpdag());
        let err = Cpdag::try_new(pdag).expect_err("a non-chordal cycle is not a CPDAG");
        assert!(err.contains("CPDAG"));
    }

    #[test]
    fn deref_forwards_through_mpdag_to_pdag() {
        let cpdag = Cpdag::try_new(cpdag_pdag()).unwrap();
        // Access a `Pdag` method via auto-deref (Cpdag -> Mpdag -> Pdag).
        assert_eq!(cpdag.undirected_of(1).len(), 2);
        assert!(cpdag.parents_of(0).is_empty());
    }

    #[test]
    fn into_mpdag_downgrades() {
        let cpdag = Cpdag::try_new(cpdag_pdag()).unwrap();
        let mpdag = cpdag.into_mpdag();
        assert_eq!(mpdag.n(), 3);
    }
}
