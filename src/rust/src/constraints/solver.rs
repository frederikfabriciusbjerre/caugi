//! Solver wrapper around splr — satisfiability check and bounded
//! model enumeration via blocking clauses.
//!
//! Only available with `feature = "solver-splr"`.

#![cfg(feature = "solver-splr")]

use splr::{Certificate, Config, SolveIF, Solver, SolverError};

use super::cardinality::Lit;
use super::varmap::VarMap;

/// `Some(model)` if the formula is satisfiable, `None` otherwise.
/// `model[i]` is `true` iff variable `i + 1` is true.
pub fn solve(clauses: &[Vec<Lit>], n_vars: i32) -> Option<Vec<bool>> {
    if clauses.iter().any(|c| c.is_empty()) {
        return None;
    }
    if n_vars <= 0 {
        // Trivially satisfiable empty problem.
        return Some(Vec::new());
    }
    let cfg = Config::default();
    match Solver::try_from((cfg, clauses)) {
        Ok(mut s) => match s.solve() {
            Ok(Certificate::SAT(model)) => Some(model_to_bool_vec(&model, n_vars)),
            Ok(Certificate::UNSAT) => None,
            Err(SolverError::EmptyClause | SolverError::RootLevelConflict(_)) => None,
            Err(e) => panic!("splr unexpected error: {:?}", e),
        },
        Err(Ok(Certificate::SAT(model))) => Some(model_to_bool_vec(&model, n_vars)),
        Err(Ok(Certificate::UNSAT)) => None,
        Err(Err(SolverError::EmptyClause | SolverError::RootLevelConflict(_))) => None,
        Err(Err(e)) => panic!("splr unexpected error: {:?}", e),
    }
}

/// Enumerate up to `limit` distinct edge-variable assignments. Each
/// returned vector is the truth value of every variable (length =
/// `n_vars`); auxiliary variables are included but callers typically
/// only inspect the edge slice via [`VarMap`].
pub fn enumerate(clauses: &[Vec<Lit>], var_map: &VarMap, limit: usize) -> Vec<Vec<bool>> {
    if limit == 0 {
        return Vec::new();
    }
    let mut out = Vec::with_capacity(limit);
    let mut working = clauses.to_vec();
    let n_vars = var_map.n_vars();
    while out.len() < limit {
        let model = match solve(&working, n_vars) {
            Some(m) => m,
            None => break,
        };
        // Block this model on its edge-variable signature so we don't
        // re-enumerate the same graph via different aux assignments.
        let mut block = Vec::new();
        for (_, _, _, var) in var_map.iter_all_edges() {
            let idx = (var - 1) as usize;
            let val = model[idx];
            if val {
                block.push(-var);
            } else {
                block.push(var);
            }
        }
        if block.is_empty() {
            // Single (trivial) solution — no edges to block on.
            out.push(model);
            break;
        }
        out.push(model);
        working.push(block);
    }
    out
}

fn model_to_bool_vec(model: &[i32], n_vars: i32) -> Vec<bool> {
    let mut out = vec![false; n_vars as usize];
    for &lit in model {
        if lit > 0 {
            let idx = (lit - 1) as usize;
            if idx < out.len() {
                out[idx] = true;
            }
        }
    }
    out
}
