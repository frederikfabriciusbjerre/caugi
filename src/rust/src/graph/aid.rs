// SPDX-License-Identifier: MPL-2.0
//
// Adjustment Identification Distances (Ancestor-AID, Oset-AID, Parent-AID).
//
// This file is a clean reimplementation of the AID algorithms of
//   Henckel, Würtzen & Weichwald, "Adjustment Identification Distance:
//   A gadjid for Causal Structure Learning", UAI 2024 (arXiv:2402.08616),
// derived from the reference implementation in the `gadjid` crate
// (https://github.com/CausalDisco/gadjid, MPL-2.0). Because it is a
// derivative of that MPL-2.0 source, THIS FILE is licensed MPL-2.0, even
// though the rest of caugi is MIT.
//
// The novel part kept here is the walk-status reachability verifier
// (`reach_descendants` and `reach_validity`, Appendix D of the paper);
// adjustment sets and ancestor searches reuse caugi's own graph machinery.
// The verifier reads neighbours straight off the `Dag`/`Cpdag` inputs — a DAG
// just has no undirected edges — so no bespoke graph type or conversion is needed.

use rustc_hash::FxHashSet;

use crate::graph::alg::{adjustment::optimal_adjustment_set, traversal};
use crate::graph::{cpdag::Cpdag, dag::Dag};

type NodeSet = FxHashSet<u32>;

/// Edge type from a traversal perspective: how the edge points at the node it
/// is paired with. `X (-> Y)` is `Incoming` at Y; `X (<- Y)` is `Outgoing` at Y.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
enum Edge {
    Init,
    Incoming,
    Outgoing,
    Undirected,
}

/// Input for the AID functions. Only a DAG or a CPDAG is accepted. The verifier
/// reads neighbours through the accessors below, so it treats both uniformly.
pub enum AidInput<'a> {
    Dag(&'a Dag),
    Cpdag(&'a Cpdag),
}

impl AidInput<'_> {
    fn n(&self) -> u32 {
        match self {
            AidInput::Dag(d) => d.n(),
            AidInput::Cpdag(c) => c.n(),
        }
    }
    fn parents_of(&self, v: u32) -> &[u32] {
        match self {
            AidInput::Dag(d) => d.parents_of(v),
            AidInput::Cpdag(c) => c.parents_of(v),
        }
    }
    fn children_of(&self, v: u32) -> &[u32] {
        match self {
            AidInput::Dag(d) => d.children_of(v),
            AidInput::Cpdag(c) => c.children_of(v),
        }
    }
    /// A DAG has no `---` edges, so there is nothing to check for it.
    fn undirected_of(&self, v: u32) -> &[u32] {
        match self {
            AidInput::Dag(_) => &[],
            AidInput::Cpdag(c) => c.undirected_of(v),
        }
    }
}

/// Which AID variant to compute.
#[derive(Clone, Copy)]
pub enum AidType {
    Ancestor,
    Oset,
    Parent,
}

// ── Adjustment sets taken from the guess graph ───────────────────────────────

/// Ancestor adjustment set `An(t) \ {t}` (reuses caugi's traversal).
fn ancestor_set(g: &AidInput, t: u32) -> NodeSet {
    traversal::ancestors_of(g.n(), t, |u| g.parents_of(u))
        .into_iter()
        .collect()
}

// ── Walk-status reachability (the AID verifier core) ─────────────────────────

/// Possible children of `v` (along `-->` or `---`), skipping treatment `t`.
fn next_steps(g: &AidInput, t: u32, v: u32) -> Vec<(Edge, u32)> {
    let mut next = Vec::new();
    for &u in g.undirected_of(v) {
        if u != t {
            next.push((Edge::Undirected, u));
        }
    }
    for &c in g.children_of(v) {
        if c != t {
            next.push((Edge::Incoming, c));
        }
    }
    next
}

/// Conditioned step expansion for the adjustment verifier. Returns
/// `(edge, neighbour, blocked)`; `blocked` toggles at a (non-)collider that is
/// (not) in the adjustment set `z`.
fn next_steps_conditioned(
    g: &AidInput,
    t: u32,
    arrived_by: Edge,
    v: u32,
    node_is_adjustment: bool,
) -> Vec<(Edge, u32, bool)> {
    let mut next = Vec::new();
    if matches!(arrived_by, Edge::Incoming | Edge::Init | Edge::Outgoing) {
        // Stepping onto a parent flips the blocked flag only at a collider
        // (i.e. when we arrived along an incoming edge).
        let flip = matches!(arrived_by, Edge::Incoming);
        for &p in g.parents_of(v) {
            if p != t {
                next.push((Edge::Outgoing, p, node_is_adjustment ^ flip));
            }
        }
    }
    for &u in g.undirected_of(v) {
        if u != t {
            next.push((Edge::Undirected, u, node_is_adjustment));
        }
    }
    for &c in g.children_of(v) {
        if c != t {
            next.push((Edge::Incoming, c, node_is_adjustment));
        }
    }
    next
}

/// Possible descendants `PD` (incl. `t`) and the not-amenable set `NAM` of
/// nodes `y` for which `G` is not amenable relative to `(t, y)`.
fn reach_descendants(g: &AidInput, t: u32) -> (NodeSet, NodeSet) {
    #[derive(PartialEq, Eq, Hash, Clone, Copy)]
    enum Walk {
        D,
        PdAm,
        PdNam,
        Init,
    }

    let mut poss_desc: NodeSet = [t].into_iter().collect();
    let mut not_amenable = NodeSet::default();

    let mut visited = FxHashSet::<(Edge, u32, Walk)>::default();
    let mut stack = vec![(Edge::Init, t, Walk::Init)];

    while let Some((arrived_by, node, walk)) = stack.pop() {
        if !visited.insert((arrived_by, node, walk)) {
            continue;
        }
        match walk {
            Walk::PdNam => {
                not_amenable.insert(node);
                poss_desc.insert(node);
            }
            Walk::PdAm | Walk::D => {
                poss_desc.insert(node);
            }
            Walk::Init => (),
        }

        for (edge, w) in next_steps(g, t, node) {
            let next = match (walk, edge) {
                (Walk::Init, Edge::Incoming) => Walk::D,
                (Walk::Init, Edge::Undirected) => Walk::PdNam,
                (Walk::D, Edge::Incoming) => Walk::D,
                (Walk::D, Edge::Undirected) => Walk::PdAm,
                (Walk::PdAm, _) => Walk::PdAm,
                (Walk::PdNam, _) => Walk::PdNam,
                _ => continue,
            };
            stack.push((edge, w, next));
        }
    }

    (poss_desc, not_amenable)
}

/// Possible descendants `PD`, not-amenable `NAM`, and not-validly-adjusted
/// `NVA` (nodes `y` for which `z` is not a valid adjustment set for `(t, y)`).
/// `NAM ⊆ NVA`. This is the core verifier (Appendix D of the paper).
fn reach_validity(g: &AidInput, t: u32, z: &NodeSet) -> (NodeSet, NodeSet, NodeSet) {
    #[derive(PartialEq, Eq, Hash, Clone, Copy)]
    enum Walk {
        PdOpenAm,
        PdBlockedAm,
        PdOpenNam,
        PdBlockedNam,
        NonCausalOpen,
        Init,
    }

    let mut poss_de: NodeSet = [t].into_iter().collect();
    let mut not_amenable = NodeSet::default();
    let mut not_vas = z.clone();

    let mut visited = FxHashSet::<(Edge, u32, Walk)>::default();
    let mut stack = vec![(Edge::Init, t, Walk::Init)];

    while let Some((arrived_by, node, walk)) = stack.pop() {
        if !visited.insert((arrived_by, node, walk)) {
            continue;
        }
        match walk {
            Walk::PdOpenNam | Walk::PdBlockedNam => {
                not_amenable.insert(node);
                not_vas.insert(node); // keep NAM ⊆ NVA
                poss_de.insert(node);
            }
            Walk::NonCausalOpen => {
                not_vas.insert(node);
            }
            Walk::PdBlockedAm => {
                not_vas.insert(node);
                poss_de.insert(node);
            }
            Walk::PdOpenAm => {
                poss_de.insert(node);
            }
            Walk::Init => (),
        }
        let node_is_adjustment = z.contains(&node);

        for (edge, w, blocked) in next_steps_conditioned(g, t, arrived_by, node, node_is_adjustment)
        {
            let next = match walk {
                Walk::Init => match edge {
                    Edge::Incoming => Walk::PdOpenAm,
                    Edge::Outgoing => Walk::NonCausalOpen,
                    Edge::Undirected => Walk::PdOpenNam,
                    Edge::Init => continue,
                },
                Walk::PdOpenAm | Walk::PdBlockedAm => match edge {
                    Edge::Incoming | Edge::Undirected if blocked => Walk::PdBlockedAm,
                    Edge::Incoming | Edge::Undirected => walk,
                    Edge::Outgoing if !blocked && matches!(walk, Walk::PdOpenAm) => {
                        Walk::NonCausalOpen
                    }
                    _ => continue,
                },
                Walk::PdOpenNam | Walk::PdBlockedNam => match edge {
                    Edge::Incoming | Edge::Undirected if blocked => Walk::PdBlockedNam,
                    Edge::Incoming | Edge::Undirected => walk,
                    Edge::Outgoing if !blocked && matches!(walk, Walk::PdOpenNam) => {
                        Walk::NonCausalOpen
                    }
                    _ => continue,
                },
                Walk::NonCausalOpen if !blocked => Walk::NonCausalOpen,
                _ => continue,
            };
            stack.push((edge, w, next));
        }
    }

    (poss_de, not_amenable, not_vas)
}

// ── AID distances ────────────────────────────────────────────────────────────

#[inline]
fn normalize(mistakes: usize, n: u32) -> (f64, usize) {
    let n = n as usize;
    (mistakes as f64 / (n * (n - 1)) as f64, mistakes)
}

/// Relabel a guess-space node set into the true graph's node space.
/// `inv[g] = i` means guess-index `g` is true-index `i`.
fn to_truth(set: NodeSet, inv: &[usize]) -> NodeSet {
    set.iter().map(|&g| inv[g as usize] as u32).collect()
}

/// Verifier loop shared by ancestor/parent AID: for each `y`, the guess either
/// claims no effect (mistake if `y` could be an effect in the truth) or claims
/// an adjustment-identified effect (mistake on amenability disagreement, or if
/// the adjustment set is invalid in the truth). All sets are in true-space.
fn count_mistakes(
    n: u32,
    treatment: u32,
    claim_possible_effect: &NodeSet,
    nam_in_guess: &NodeSet,
    pd_in_truth: &NodeSet,
    nam_in_truth: &NodeSet,
    nva_in_truth: &NodeSet,
) -> usize {
    let mut mistakes = 0;
    for y in 0..n {
        if y == treatment {
            continue;
        }
        if !claim_possible_effect.contains(&y) {
            if pd_in_truth.contains(&y) {
                mistakes += 1;
            }
        } else {
            let nam_guess = nam_in_guess.contains(&y);
            let nam_truth = nam_in_truth.contains(&y);
            if nam_guess != nam_truth || (!nam_truth && nva_in_truth.contains(&y)) {
                mistakes += 1;
            }
        }
    }
    mistakes
}

/// Guess-side sets are computed in the guess's node space and relabelled into
/// the truth's space via `inv`; `perm[i]` is the guess-index of true-index `i`.
fn ancestor_aid(truth: &AidInput, guess: &AidInput, perm: &[u32], inv: &[usize]) -> (f64, usize) {
    // ponytail: sequential, not rayon — caugi has no rayon dep and these graphs
    // are small; parallelize per-treatment if AID ever shows up in a profile.
    let n = truth.n();
    let mut mistakes = 0;
    for t in 0..n {
        let gt = perm[t as usize];
        let z = to_truth(ancestor_set(guess, gt), inv);
        let (claim_g, nam_g) = reach_descendants(guess, gt);
        let (pd_t, nam_t, nva_t) = reach_validity(truth, t, &z);
        mistakes += count_mistakes(
            n,
            t,
            &to_truth(claim_g, inv),
            &to_truth(nam_g, inv),
            &pd_t,
            &nam_t,
            &nva_t,
        );
    }
    normalize(mistakes, n)
}

fn parent_aid(truth: &AidInput, guess: &AidInput, perm: &[u32], inv: &[usize]) -> (f64, usize) {
    let n = truth.n();
    let mut mistakes = 0;
    for t in 0..n {
        let gt = perm[t as usize];
        let z = to_truth(guess.parents_of(gt).iter().copied().collect(), inv);
        // Like the original SID, claim all NonParents may be effects.
        let claim: NodeSet = (0..n).filter(|v| !z.contains(v)).collect();
        let (_pd_g, nam_g) = reach_descendants(guess, gt);
        let (pd_t, nam_t, nva_t) = reach_validity(truth, t, &z);
        mistakes += count_mistakes(n, t, &claim, &to_truth(nam_g, inv), &pd_t, &nam_t, &nva_t);
    }
    normalize(mistakes, n)
}

fn oset_aid(truth: &AidInput, guess: &AidInput, perm: &[u32], inv: &[usize]) -> (f64, usize) {
    let n = truth.n();
    let mut mistakes = 0;
    for t in 0..n {
        let gt = perm[t as usize];
        let (claim_g, nam_g) = reach_descendants(guess, gt);
        let claim = to_truth(claim_g, inv);
        let nam_guess = to_truth(nam_g, inv);
        let (pd_t, nam_t) = reach_descendants(truth, t);

        for y in 0..n {
            if y == t {
                continue;
            }
            if !claim.contains(&y) {
                if pd_t.contains(&y) {
                    mistakes += 1;
                }
            } else if nam_guess.contains(&y) != nam_t.contains(&y) {
                mistakes += 1;
            } else if !nam_guess.contains(&y) {
                // y is amenable in both graphs; the O-set is pair-specific and
                // reuses caugi's generic optimal-adjustment-set over the guess's
                // directed structure.
                let z = to_truth(
                    optimal_adjustment_set(guess.n(), gt, perm[y as usize], |u| guess.parents_of(u), |u| {
                        guess.children_of(u)
                    })
                    .into_iter()
                    .collect(),
                    inv,
                );
                // For an amenable y, NVA membership is exactly invalidity.
                let (_pd, _nam, nva) = reach_validity(truth, t, &z);
                if nva.contains(&y) {
                    mistakes += 1;
                }
            }
        }
    }
    normalize(mistakes, n)
}

// ── Public entry point (called from lib.rs) ──────────────────────────────────

/// Compute the chosen AID variant. `inv_guess_to_true[j] = i` maps guess-index
/// `j` to true-position `i` (aligning the guess onto the truth's node order).
pub fn aid(
    kind: AidType,
    true_g: AidInput<'_>,
    guess_g: AidInput<'_>,
    inv_guess_to_true: &[usize],
) -> Result<(f64, usize), String> {
    let n = true_g.n() as usize;
    if guess_g.n() as usize != n {
        return Err("both graphs must contain the same number of nodes".into());
    }
    if n < 2 {
        return Err("graph must contain at least 2 nodes".into());
    }
    if inv_guess_to_true.len() != n {
        return Err("index map length does not match graph size".into());
    }
    // perm is the inverse of inv: perm[i] is the guess-index of true-index i.
    let mut perm = vec![0u32; n];
    for (g, &i) in inv_guess_to_true.iter().enumerate() {
        perm[i] = g as u32;
    }
    Ok(match kind {
        AidType::Ancestor => ancestor_aid(&true_g, &guess_g, &perm, inv_guess_to_true),
        AidType::Oset => oset_aid(&true_g, &guess_g, &perm, inv_guess_to_true),
        AidType::Parent => parent_aid(&true_g, &guess_g, &perm, inv_guess_to_true),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use crate::graph::pdag::Pdag;
    use std::sync::Arc;

    fn dag(n: u32, edges: &[(u32, u32)]) -> Dag {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(n, true, &reg);
        for &(u, v) in edges {
            b.add_edge(u, v, d).unwrap();
        }
        Dag::new(Arc::new(b.finalize().unwrap())).unwrap()
    }

    fn cpdag(n: u32, directed: &[(u32, u32)], undirected: &[(u32, u32)]) -> Cpdag {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();
        let u = reg.code_of("---").unwrap();
        let mut b = GraphBuilder::new_with_registry(n, true, &reg);
        for &(a, c) in directed {
            b.add_edge(a, c, d).unwrap();
        }
        for &(a, c) in undirected {
            b.add_edge(a, c, u).unwrap();
        }
        Cpdag::try_new(Pdag::new(Arc::new(b.finalize().unwrap())).unwrap()).unwrap()
    }

    fn ident(n: usize) -> Vec<usize> {
        (0..n).collect()
    }

    const KINDS: [AidType; 3] = [AidType::Ancestor, AidType::Oset, AidType::Parent];

    #[test]
    fn identical_dag_is_zero() {
        let g = dag(3, &[(0, 1), (1, 2)]);
        let inv = ident(3);
        for kind in KINDS {
            assert_eq!(
                aid(kind, AidInput::Dag(&g), AidInput::Dag(&g), &inv).unwrap(),
                (0.0, 0)
            );
        }
    }

    #[test]
    fn permutation_corrected_by_inverse_map() {
        // truth 0->1->2; guess relabelled by [1,2,0] => inverse [2,0,1].
        let t = dag(3, &[(0, 1), (1, 2)]);
        let g = dag(3, &[(1, 2), (2, 0)]);
        let inv = [2usize, 0, 1];
        for kind in KINDS {
            assert_eq!(aid(kind, AidInput::Dag(&t), AidInput::Dag(&g), &inv).unwrap().1, 0);
        }
    }

    #[test]
    fn nam_counted_as_mistake_x_y() {
        // cpdag X---Y vs dag X->Y: all three AIDs report (1.0, 2).
        let d = dag(2, &[(0, 1)]);
        let c = cpdag(2, &[], &[(0, 1)]);
        let inv = ident(2);
        for kind in KINDS {
            assert_eq!(aid(kind, AidInput::Dag(&d), AidInput::Cpdag(&c), &inv).unwrap(), (1.0, 2));
            assert_eq!(aid(kind, AidInput::Cpdag(&c), AidInput::Dag(&d), &inv).unwrap(), (1.0, 2));
        }
    }

    #[test]
    fn sid_paper_example() {
        // Parent-AID = SID for DAGs (example from the SID paper).
        let g = dag(5, &[(0, 1), (0, 2), (0, 3), (0, 4), (1, 2), (1, 3), (1, 4)]);
        let h2 = dag(5, &[(0, 2), (0, 3), (0, 4), (1, 0), (1, 2), (1, 3), (1, 4)]);
        let inv = ident(5);
        assert_eq!(
            aid(AidType::Parent, AidInput::Dag(&g), AidInput::Dag(&h2), &inv).unwrap(),
            (0.4, 8)
        );
    }

    #[test]
    fn cpdag_v_structure_identical_zero() {
        // CPDAG with a v-structure 0 -> 2 <- 1.
        let c = cpdag(3, &[(0, 2), (1, 2)], &[]);
        let inv = ident(3);
        for kind in KINDS {
            assert_eq!(aid(kind, AidInput::Cpdag(&c), AidInput::Cpdag(&c), &inv).unwrap().1, 0);
        }
    }

    #[test]
    fn rejects_bad_index_map() {
        let g = dag(3, &[(0, 1), (1, 2)]);
        let bad = [0usize, 1];
        let err = aid(AidType::Ancestor, AidInput::Dag(&g), AidInput::Dag(&g), &bad).unwrap_err();
        assert!(err.contains("index map length"));
    }
}
