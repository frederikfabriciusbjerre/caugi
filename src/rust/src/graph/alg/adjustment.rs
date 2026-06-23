// SPDX-License-Identifier: MIT
//! Generic adjustment-set algorithms over closure-based neighbor access.

use crate::graph::alg::bitset;

/// Optimal adjustment set (O-set) for a single exposure-outcome pair `x → y`.
///
/// `O(x, y) = Pa(Cn) \ (Cn ∪ {x})`, where the causal nodes
/// `Cn = (De(x) \ {x}) ∩ (An(y) ∪ {y})` are the nodes on proper causal paths
/// from `x` to `y`. (Subtracting `Cn ∪ {x}` is equivalent to subtracting the
/// forbidden set `De(x)`: any parent of a causal node that is also a descendant
/// of `x` is itself causal.)
///
/// Generic over directed neighbor access so it can be reused by the `Dag`
/// wrapper and by graphs given only as parent/child adjacency.
pub fn optimal_adjustment_set<'a, P, C>(n: u32, x: u32, y: u32, parents_of: P, children_of: C) -> Vec<u32>
where
    P: Fn(u32) -> &'a [u32],
    C: Fn(u32) -> &'a [u32],
{
    let n = n as usize;

    let mut de_mask = bitset::descendants_mask(&[x], &children_of, n as u32);
    de_mask[x as usize] = false;

    let an_mask = bitset::ancestors_mask(&[y], &parents_of, n as u32);

    let mut cn_mask = vec![false; n];
    for i in 0..n {
        if de_mask[i] && an_mask[i] {
            cn_mask[i] = true;
        }
    }
    if de_mask[y as usize] {
        cn_mask[y as usize] = true;
    }

    let mut pacn_mask = vec![false; n];
    for v in bitset::collect_from_mask(&cn_mask) {
        for &p in parents_of(v) {
            pacn_mask[p as usize] = true;
        }
    }
    pacn_mask[x as usize] = false;
    for i in 0..n {
        if cn_mask[i] {
            pacn_mask[i] = false;
        }
    }
    bitset::collect_from_mask(&pacn_mask)
}
