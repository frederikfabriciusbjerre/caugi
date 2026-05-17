//! Sinz's sequential counter encoding for `at_most(k, x_1, …, x_n)`.
//!
//! Reference: Sinz, C. (2005). "Towards an Optimal CNF Encoding of
//! Boolean Cardinality Constraints", CP 2005.
//!
//! Auxiliary variables: `s_{i,j}` for `1 ≤ i ≤ n-1`, `1 ≤ j ≤ k`.
//! Intended meaning: `s_{i,j}` is true iff at least `j` of
//! `x_1, …, x_i` are true.
//!
//! Clauses (where `x_i` are the input literals, possibly negated):
//!   (A) `¬x_i ∨ s_{i,1}`              for `i = 1..n-1`
//!   (B) `¬s_{i-1,j} ∨ s_{i,j}`        for `i = 2..n-1`, `j = 1..k`
//!   (C) `¬x_i ∨ ¬s_{i-1,j-1} ∨ s_{i,j}`  for `i = 2..n-1`, `j = 2..k`
//!   (D) `¬x_i ∨ ¬s_{i-1,k}`           for `i = 2..n`  (the bound)
//!
//! Total clause count: `n + (n-2)·k + (n-2)·(k-1) + (n-1) = O(n·k)`.
//!
//! When `k == 0` the encoding degenerates to unit clauses `¬x_i` for
//! every literal; when `k >= n` the constraint is trivially satisfied
//! and no clauses are emitted. We special-case both at the API
//! boundary in [`super::at_most`].

use super::Lit;

/// Allocator for fresh auxiliary variables. Wraps the next-free
/// variable index in splr's 1-based positive-integer convention.
#[derive(Debug, Clone)]
pub struct AuxAllocator {
    next: i32,
}

impl AuxAllocator {
    /// Construct an allocator whose first issued variable is
    /// `starting_at`. Callers usually pass `n_input_vars + 1`.
    #[must_use]
    pub fn new(starting_at: i32) -> Self {
        assert!(starting_at > 0, "splr variable ids must be > 0");
        Self { next: starting_at }
    }

    /// Mint one fresh variable.
    pub fn fresh(&mut self) -> i32 {
        let v = self.next;
        self.next += 1;
        v
    }

    /// The next variable id that would be issued. Useful for tests
    /// that want to assert how many aux vars an encoder consumed.
    #[must_use]
    pub fn peek_next(&self) -> i32 {
        self.next
    }
}

pub(super) fn encode_at_most(k: u32, lits: &[Lit], aux: &mut AuxAllocator) -> Vec<Vec<Lit>> {
    let n = lits.len();
    if k == 0 {
        return lits.iter().map(|&l| vec![-l]).collect();
    }
    if (k as usize) >= n {
        return Vec::new();
    }
    if n == 1 {
        // Single literal with k >= 1 is trivially satisfied.
        return Vec::new();
    }

    // Allocate s_{i,j} for i in 1..=n-1, j in 1..=k.
    // We index 0-based internally: s[i-1][j-1] holds the aux var id.
    let mut s: Vec<Vec<i32>> = (0..n - 1)
        .map(|_| (0..k as usize).map(|_| aux.fresh()).collect())
        .collect();
    let _ = &mut s;

    let mut clauses: Vec<Vec<Lit>> = Vec::new();

    // (A) ¬x_i ∨ s_{i,1}  for i = 1..n-1
    for i in 0..n - 1 {
        clauses.push(vec![-lits[i], s[i][0]]);
    }

    // (B) ¬s_{i-1,j} ∨ s_{i,j}  for i = 2..n-1, j = 1..k
    for i in 1..n - 1 {
        for j in 0..k as usize {
            clauses.push(vec![-s[i - 1][j], s[i][j]]);
        }
    }

    // (C) ¬x_i ∨ ¬s_{i-1,j-1} ∨ s_{i,j}  for i = 2..n-1, j = 2..k
    for i in 1..n - 1 {
        for j in 1..k as usize {
            clauses.push(vec![-lits[i], -s[i - 1][j - 1], s[i][j]]);
        }
    }

    // (D) ¬x_i ∨ ¬s_{i-1,k}  for i = 2..n
    for i in 1..n {
        clauses.push(vec![-lits[i], -s[i - 1][k as usize - 1]]);
    }

    clauses
}
