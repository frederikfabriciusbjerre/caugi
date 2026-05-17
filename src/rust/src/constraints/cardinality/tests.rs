//! Exhaustive correctness tests for the cardinality encoders.
//!
//! For every (n, k) in the covered range we enumerate **all `2^n`
//! Boolean assignments** of the input literals, force them via unit
//! clauses, and ask splr whether the augmented formula is satisfiable.
//! The encoding is correct iff:
//!
//!   * `at_most(k)`  is SAT exactly when the assignment has ≤ k trues
//!   * `at_least(k)` is SAT exactly when the assignment has ≥ k trues
//!   * `exactly(k)`  is SAT exactly when the assignment has = k trues
//!
//! This is the strongest validation we can do without trusting another
//! implementation: any soundness or completeness bug shows up as a
//! disagreement with the spec on at least one assignment.
//!
//! The fixtures (n up to 6) come straight from rustsat's testing
//! tradition — small enough to exhaust, large enough to catch
//! off-by-one bugs in the index arithmetic.

#![cfg(all(test, feature = "solver-splr"))]

use super::*;
use splr::{Certificate, Config, SolveIF, Solver, SolverError};

/// Run splr on a CNF and return whether the formula is satisfiable.
/// splr's `Err(EmptyClause)` and `Err(RootLevelConflict)` are not
/// build failures — they're the solver's way of saying "trivially
/// UNSAT". We treat both as a clean `false`.
fn is_sat(clauses: &[Vec<Lit>]) -> bool {
    if clauses.iter().any(|c| c.is_empty()) {
        return false;
    }
    let cfg = Config::default();
    match Solver::try_from((cfg, clauses)) {
        Ok(mut s) => matches!(s.solve(), Ok(Certificate::SAT(_))),
        // splr's try_from error type is itself a Result; an inner
        // `Ok(Certificate::UNSAT)` or any structural error means the
        // formula is unsatisfiable.
        Err(Ok(Certificate::UNSAT)) => false,
        Err(Ok(Certificate::SAT(_))) => true,
        Err(Err(SolverError::EmptyClause | SolverError::RootLevelConflict(_))) => false,
        Err(Err(e)) => panic!("splr rejected clauses with an unexpected error: {:?}", e),
    }
}

/// For each of the `2^n` Boolean assignments of `x_1..x_n`, return
/// the assignment as a vector of unit clauses (positive lit for true,
/// negative for false).
fn all_assignments(n: usize) -> impl Iterator<Item = Vec<Vec<Lit>>> {
    (0..(1u32 << n)).map(move |mask| {
        (0..n)
            .map(|i| {
                let lit = (i + 1) as Lit;
                if (mask >> i) & 1 == 1 {
                    vec![lit]
                } else {
                    vec![-lit]
                }
            })
            .collect()
    })
}

fn true_count(mask: u32, n: usize) -> u32 {
    (0..n).filter(|i| (mask >> i) & 1 == 1).count() as u32
}

/// Drive an encoder for every (n, k) in the covered range and every
/// `2^n` assignment, comparing the SAT outcome against `spec`.
fn check_exhaustive<F, S>(name: &str, max_n: usize, mut encoder: F, spec: S)
where
    F: FnMut(u32, &[Lit], &mut AuxAllocator) -> Vec<Vec<Lit>>,
    S: Fn(u32, u32) -> bool,
{
    for n in 1..=max_n {
        for k in 0..=(n as u32 + 1) {
            // Build the base encoding once per (n, k).
            let lits: Vec<Lit> = (1..=n as Lit).collect();
            let mut aux = AuxAllocator::new(n as i32 + 1);
            let base = encoder(k, &lits, &mut aux);

            for mask in 0..(1u32 << n) {
                let trues = true_count(mask, n);
                let expected = spec(trues, k);

                // Re-build per-iteration so we never share state.
                let mut clauses = base.clone();
                for (i, _) in lits.iter().enumerate() {
                    let lit = (i + 1) as Lit;
                    let unit = if (mask >> i) & 1 == 1 { lit } else { -lit };
                    clauses.push(vec![unit]);
                }
                let actual = is_sat(&clauses);

                assert_eq!(
                    actual, expected,
                    "{} encoder disagreed with spec on (n={}, k={}, mask={:0width$b}, trues={}): expected SAT={}, got SAT={}",
                    name, n, k, mask, trues, expected, actual, width = n
                );
            }
        }
    }
    let _ = all_assignments;
}

#[test]
fn at_most_exhaustive() {
    check_exhaustive(
        "at_most",
        6,
        |k, lits, aux| at_most(k, lits, aux),
        |trues, k| trues <= k,
    );
}

#[test]
fn at_least_exhaustive() {
    check_exhaustive(
        "at_least",
        6,
        |k, lits, aux| at_least(k, lits, aux),
        |trues, k| trues >= k,
    );
}

#[test]
fn exactly_exhaustive() {
    check_exhaustive(
        "exactly",
        5,
        |k, lits, aux| exactly(k, lits, aux),
        |trues, k| trues == k,
    );
}

// ── boundary / golden tests ────────────────────────────────────────────────
//
// Specific clause-count assertions to guard against silent algorithmic
// drift. These are NOT meant to match rustsat byte-for-byte (different
// encoding) — they pin our own implementation.

#[test]
fn at_most_zero_produces_unit_clauses() {
    let lits = vec![1, 2, 3, 4];
    let mut aux = AuxAllocator::new(5);
    let clauses = at_most(0, &lits, &mut aux);
    assert_eq!(clauses.len(), 4);
    for (cl, &lit) in clauses.iter().zip(lits.iter()) {
        assert_eq!(cl, &vec![-lit]);
    }
    assert_eq!(aux.peek_next(), 5, "no aux vars for at_most(0)");
}

#[test]
fn at_most_above_n_emits_nothing() {
    let lits = vec![1, 2, 3];
    let mut aux = AuxAllocator::new(4);
    assert!(at_most(3, &lits, &mut aux).is_empty());
    assert!(at_most(7, &lits, &mut aux).is_empty());
    assert_eq!(aux.peek_next(), 4, "no aux vars when constraint is vacuous");
}

#[test]
fn at_least_zero_emits_nothing() {
    let lits = vec![1, 2, 3];
    let mut aux = AuxAllocator::new(4);
    assert!(at_least(0, &lits, &mut aux).is_empty());
}

#[test]
fn at_least_above_n_is_unsat() {
    let lits: Vec<Lit> = vec![1, 2];
    let mut aux = AuxAllocator::new(3);
    let clauses = at_least(3, &lits, &mut aux);
    let expected: Vec<Vec<Lit>> = vec![vec![]];
    assert_eq!(clauses, expected, "should emit the empty clause");
}

#[test]
fn at_most_one_n_four_clause_count_matches_sinz() {
    // Sequential-counter for n=4, k=1:
    //   (A)  3 clauses  (i = 0..n-1)
    //   (B)  2 clauses  (i = 1..n-1, j = 0..k)
    //   (C)  0 clauses  (j = 1..k is empty for k=1)
    //   (D)  3 clauses  (i = 1..n)
    //   total = 8 clauses
    let lits: Vec<Lit> = vec![1, 2, 3, 4];
    let mut aux = AuxAllocator::new(5);
    let clauses = at_most(1, &lits, &mut aux);
    assert_eq!(clauses.len(), 8);
    // Sinz introduces (n-1)·k aux vars: 3 for n=4, k=1.
    assert_eq!(aux.peek_next(), 8, "3 aux vars consumed (ids 5, 6, 7)");
}
