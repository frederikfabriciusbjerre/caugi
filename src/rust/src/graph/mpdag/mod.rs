// SPDX-License-Identifier: MIT
//! Mpdag wrapper: a `Pdag` carrying type-level evidence of Meek closure.
//!
//! An MPDAG is a PDAG that is closed under Meek's orientation rules R1–R4.
//! `Mpdag` is composition over a `Pdag` (same `PackedBuckets<3>` storage) plus
//! a `MeekClosed` marker. Accessors are inherited from `Pdag` via `Deref`.

use super::pdag::Pdag;
use super::traits::{Acyclic, MeekClosed, NoBidirected};

#[derive(Debug, Clone)]
pub struct Mpdag {
    inner: Pdag,
}

impl Mpdag {
    /// Builds an `Mpdag` view from a `Pdag`, validating Meek closure.
    pub fn try_new(pdag: Pdag) -> Result<Self, String> {
        if !pdag.is_meek_closed() {
            return Err("graph is not MPDAG (not closed under Meek rules)".into());
        }
        if !pdag.is_extendable() {
            return Err("graph is not MPDAG (it has no consistent DAG extension)".into());
        }
        Ok(Self { inner: pdag })
    }

    /// Builds an `Mpdag` from a `Pdag` without re-validating Meek closure.
    ///
    /// The caller MUST guarantee the input is Meek-closed (e.g. produced by
    /// `Pdag::to_cpdag` or `Dag::to_cpdag`, whose outputs are closed by
    /// construction). A debug-only assertion catches misuse during development.
    #[allow(dead_code)] // used by PR3 fast paths
    pub(crate) fn from_closed_unchecked(pdag: Pdag) -> Self {
        debug_assert!(
            pdag.is_meek_closed(),
            "Mpdag::from_closed_unchecked called on a non-Meek-closed Pdag"
        );
        Self { inner: pdag }
    }

    /// Borrow the inner `Pdag`. Most callers don't need this — `Deref` lets
    /// `&Mpdag` be used anywhere `&Pdag` is expected.
    pub fn as_pdag(&self) -> &Pdag {
        &self.inner
    }
}

impl std::ops::Deref for Mpdag {
    type Target = Pdag;
    fn deref(&self) -> &Pdag {
        &self.inner
    }
}

impl Acyclic for Mpdag {}
impl MeekClosed for Mpdag {}
impl NoBidirected for Mpdag {}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use std::sync::Arc;

    fn closed_pdag() -> Pdag {
        // 0 --- 1 --- 2 forms a closed (chordal, no induced v-structures) PDAG.
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let und = reg.code_of("---").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, und).unwrap();
        b.add_edge(1, 2, und).unwrap();
        Pdag::new(Arc::new(b.finalize().unwrap())).unwrap()
    }

    fn non_closed_pdag() -> Pdag {
        // 0 -> 1 --- 2 with no edge between 0 and 2: Meek R1 would orient
        // 1 -> 2, so this PDAG is not Meek-closed.
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let dir = reg.code_of("-->").unwrap();
        let und = reg.code_of("---").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(1, 2, und).unwrap();
        Pdag::new(Arc::new(b.finalize().unwrap())).unwrap()
    }

    #[test]
    fn try_new_accepts_meek_closed_pdag() {
        let pdag = closed_pdag();
        let mpdag = Mpdag::try_new(pdag).expect("closed PDAG should be accepted");
        assert_eq!(mpdag.n(), 3);
    }

    #[test]
    fn try_new_rejects_non_meek_closed_pdag() {
        let pdag = non_closed_pdag();
        let err = Mpdag::try_new(pdag).expect_err("non-closed PDAG should be rejected");
        assert!(err.contains("MPDAG"));
    }

    #[test]
    fn deref_forwards_to_pdag() {
        let mpdag = Mpdag::try_new(closed_pdag()).unwrap();
        // Access a `Pdag` method via auto-deref.
        assert_eq!(mpdag.undirected_of(1).len(), 2);
        assert!(mpdag.parents_of(0).is_empty());
    }
}
