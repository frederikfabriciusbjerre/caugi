//! Phase 0 solver smoke probes.
//!
//! Compile-time-gated tests that confirm the chosen Rust SAT solver
//! (splr) builds, links, and answers SAT / UNSAT correctly on small
//! instances. Activated with `--features solver-splr`.
//!
//! The wider Phase 0 spike compared splr against pumpkin-solver; the
//! results live in `extras/design/constraints-spike-s0.md`. Splr won on
//! vendored binary size (~+0.1 MB vs pumpkin's ~+5 MB), which more
//! than offsets the loss of native pseudo-boolean — that'll be
//! encoded as totalizer / sequential counter in the Phase 2 encoder.

#![cfg(feature = "solver-splr")]

pub mod splr_probe {
    //! splr sanity probes. Variables are positive integers (1-indexed);
    //! a clause is a `Vec<i32>` with positive literals for the variable
    //! and negative literals for its negation.

    use splr::{Certificate, Config, SolveIF, Solver, SolverError};

    fn run(clauses: Vec<Vec<i32>>) -> Result<Certificate, SolverError> {
        let mut s =
            Solver::try_from((Config::default(), clauses.as_slice())).expect("build solver");
        s.solve()
    }

    /// (x1 ∨ x2) ∧ (¬x1 ∨ x3) — must be SAT.
    pub fn solve_sat() -> bool {
        let clauses = vec![vec![1, 2], vec![-1, 3]];
        matches!(run(clauses), Ok(Certificate::SAT(_)))
    }

    /// Above plus (¬x2) ∧ (¬x3) — must be UNSAT.
    pub fn solve_unsat() -> bool {
        let clauses = vec![vec![1, 2], vec![-1, 3], vec![-2], vec![-3]];
        matches!(run(clauses), Ok(Certificate::UNSAT))
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn splr_sat() {
            assert!(solve_sat(), "splr should report the SAT instance as SAT");
        }

        #[test]
        fn splr_unsat() {
            assert!(
                solve_unsat(),
                "splr should report the UNSAT instance as UNSAT"
            );
        }
    }
}
