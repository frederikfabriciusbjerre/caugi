//! Cardinality encodings: `at_most(k, S)`, `at_least(k, S)`, `exactly(k, S)`
//! over Boolean literals, lowered to CNF.
//!
//! The encoder is intentionally tiny and self-contained: we don't want
//! the entire `rustsat` / `pumpkin` machinery for what is a textbook
//! O(n·k) clause expansion. Correctness is validated **exhaustively**
//! against the splr SAT solver in [`tests`] — for every (n, k) in the
//! covered range and every one of `2^n` Boolean assignments, we
//! confirm the encoding accepts the assignment iff the spec
//! (`true_count` vs `k`) says it should.
//!
//! The encoders accept signed `i32` literals in the splr convention:
//! positive means the variable's positive polarity, negative its
//! negation. Auxiliary variables for the encoding are minted from an
//! [`AuxAllocator`].
//!
//! References:
//!   * Sinz, C. (2005). "Towards an Optimal CNF Encoding of Boolean
//!     Cardinality Constraints", CP 2005.

mod sequential_counter;
#[cfg(all(test, feature = "solver-splr"))]
mod tests;

pub use sequential_counter::AuxAllocator;

use crate::constraints::ast::CardKind;

/// A literal in splr / DIMACS convention: positive `i` for variable
/// `i`, negative `-i` for its negation. Variable numbering starts at 1.
pub type Lit = i32;

/// Encode `at_most(k, lits)` as CNF. Returns the list of clauses
/// (each a `Vec<Lit>`).
///
/// Special cases:
///   * `k == 0`: emit unit clauses `¬lits[i]` for each literal.
///   * `k >= lits.len()`: trivially satisfied — emit no clauses.
///   * otherwise: Sinz's sequential counter.
pub fn at_most(k: u32, lits: &[Lit], aux: &mut AuxAllocator) -> Vec<Vec<Lit>> {
    sequential_counter::encode_at_most(k, lits, aux)
}

/// Encode `at_least(k, lits)` by reduction: `at_least(k, S) ≡
/// at_most(|S| − k, ¬S)`.
pub fn at_least(k: u32, lits: &[Lit], aux: &mut AuxAllocator) -> Vec<Vec<Lit>> {
    let n = lits.len() as u32;
    if k == 0 {
        return Vec::new();
    }
    if k > n {
        // Unsatisfiable on its own; emit the empty clause to force UNSAT.
        return vec![Vec::new()];
    }
    let negated: Vec<Lit> = lits.iter().map(|&l| -l).collect();
    at_most(n - k, &negated, aux)
}

/// Encode `exactly(k, lits)` as the conjunction of `at_most(k)` and
/// `at_least(k)`. The two halves share `lits` but each may introduce
/// its own auxiliary variables.
pub fn exactly(k: u32, lits: &[Lit], aux: &mut AuxAllocator) -> Vec<Vec<Lit>> {
    let mut clauses = at_most(k, lits, aux);
    clauses.extend(at_least(k, lits, aux));
    clauses
}

/// Dispatch on [`CardKind`] from the AST.
pub fn encode(kind: CardKind, k: u32, lits: &[Lit], aux: &mut AuxAllocator) -> Vec<Vec<Lit>> {
    match kind {
        CardKind::AtMost => at_most(k, lits, aux),
        CardKind::AtLeast => at_least(k, lits, aux),
        CardKind::Exactly => exactly(k, lits, aux),
    }
}
