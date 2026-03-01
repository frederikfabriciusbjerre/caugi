// SPDX-License-Identifier: MIT
//! Adjustment criteria (Generalized Adjustment Criterion) for ADMGs.

use super::Admg;
use crate::graph::alg::bitset;
use std::collections::HashSet;

impl Admg {
    /// Descendants mask including seeds.
    pub(super) fn descendants_mask(&self, seeds: &[u32]) -> Vec<bool> {
        bitset::descendants_mask(seeds, |u| self.children_of(u), self.n())
    }

    /// Compute the "forbidden" set for adjustment per the Generalized Adjustment Criterion.
    ///
    /// The forbidden set is: forb_G(X,Y) = De(cn(X,Y) \ Y) ∪ X
    ///
    /// where cn(X,Y) = nodes on proper causal paths from X to Y, i.e., nodes v such that:
    /// - v is reachable from X via directed edges (v ∈ De(X) ∪ X), AND
    /// - Y is reachable from v via directed edges (v ∈ An(Y) ∪ Y)
    ///
    /// Adjusting for any node in this set can:
    /// 1. Block the causal effect (if on the path itself)
    /// 2. Open spurious paths via collider bias (if descendant of a node on the path)
    fn forbidden_set(&self, xs: &[u32], ys: &[u32]) -> Vec<bool> {
        let n = self.n() as usize;

        // Step 1: Compute De(X) ∪ X (nodes reachable from X, including X)
        let de_x = self.descendants_mask(xs);

        // Step 2: Compute An(Y) ∪ Y (nodes that can reach Y, including Y)
        let an_y = self.ancestors_mask(ys);

        // Step 3: Find cn(X,Y) = nodes on proper causal paths
        // A node v is on a causal path if v ∈ (De(X) ∪ X) AND v ∈ (An(Y) ∪ Y)
        let mut causal_nodes: Vec<u32> = Vec::new();
        for v in 0..n as u32 {
            if de_x[v as usize] && an_y[v as usize] {
                causal_nodes.push(v);
            }
        }

        // Step 4: Compute cn \ Y (exclude Y from causal nodes for descendants computation)
        // Use HashSet for O(1) membership lookup instead of O(|Y|) linear search
        let y_set: HashSet<u32> = ys.iter().copied().collect();
        let causal_nodes_minus_y: Vec<u32> = causal_nodes
            .into_iter()
            .filter(|v| !y_set.contains(v))
            .collect();

        // Step 5: Compute De(cn \ Y) - this includes cn \ Y itself since descendants_mask
        // includes the seeds
        let mut forbidden = self.descendants_mask(&causal_nodes_minus_y);

        // Step 6: Add X to forbidden set
        for &x in xs {
            forbidden[x as usize] = true;
        }

        forbidden
    }

    /// Validate whether Z is a valid adjustment set for estimating X → Y.
    ///
    /// Uses the generalized adjustment criterion (GAC) for ADMGs:
    /// 1. Z ∩ forb(X,Y) = ∅, where forb(X,Y) = De(cn(X,Y) \ Y) ∪ X
    ///    (Z must not contain any node in the forbidden set)
    /// 2. All non-causal paths from X to Y are blocked by Z
    ///
    /// The forbidden set includes X, all nodes on proper causal paths from X to Y,
    /// and all descendants of those path nodes (except Y). Conditioning on forbidden
    /// nodes can block the causal effect or open spurious paths via collider bias.
    pub fn is_valid_adjustment_set(&self, xs: &[u32], ys: &[u32], z: &[u32]) -> bool {
        // Check condition 1: Z contains no forbidden nodes
        let forbidden = self.forbidden_set(xs, ys);
        for &v in z {
            if forbidden[v as usize] {
                return false;
            }
        }

        // Check condition 2: X and Y are m-separated given Z in the proper backdoor graph
        // For ADMGs, we need to check m-separation while considering that:
        // - Proper causal paths from X to Y should be "blocked"
        // - Bidirected edges still create confounding paths

        // Build the conditioning set: Z ∪ X (we condition on X to block causal paths)
        let mut obs = Vec::with_capacity(z.len() + xs.len());
        obs.extend_from_slice(z);
        obs.extend_from_slice(xs);

        // For each x ∈ X, check that all backdoor paths are blocked
        // A backdoor path starts with an edge INTO x or a bidirected edge from x
        for &x in xs {
            // Check parents of x (backdoor through directed edges into x)
            for &p in self.parents_of(x) {
                if !self.m_separated(&[p], ys, &obs) {
                    return false;
                }
            }

            // Check spouses of x (backdoor through bidirected edges)
            for &s in self.spouses_of(x) {
                if !self.m_separated(&[s], ys, &obs) {
                    return false;
                }
            }
        }

        true
    }

    /// Simple parent-based adjustment set for ADMGs.
    /// Returns Pa(X) \ (X ∪ Y) if it's a valid adjustment set.
    pub fn adjustment_set_parents(&self, xs: &[u32], ys: &[u32]) -> Option<Vec<u32>> {
        let n = self.n() as usize;
        let mut keep = vec![false; n];

        // Collect parents of X
        for &x in xs {
            for &p in self.parents_of(x) {
                keep[p as usize] = true;
            }
        }

        // Exclude X ∪ Y
        for &x in xs {
            keep[x as usize] = false;
        }
        for &y in ys {
            keep[y as usize] = false;
        }

        let z = bitset::collect_from_mask(&keep);

        // Validate
        if self.is_valid_adjustment_set(xs, ys, &z) {
            Some(z)
        } else {
            None
        }
    }

    /// Backdoor adjustment set for ADMGs.
    /// Returns (Pa(X) ∩ An(Y)) \ (De(X) ∪ X ∪ Y) if valid.
    pub fn adjustment_set_backdoor(&self, xs: &[u32], ys: &[u32]) -> Option<Vec<u32>> {
        let n = self.n() as usize;

        // An(Y)
        let an_mask = self.ancestors_mask(ys);

        // Pa(X) ∩ An(Y)
        let mut keep = vec![false; n];
        for &x in xs {
            for &p in self.parents_of(x) {
                if an_mask[p as usize] {
                    keep[p as usize] = true;
                }
            }
        }

        // Exclude De(X) ∪ X ∪ Y
        let de_mask = self.descendants_mask(xs);
        for i in 0..n {
            if de_mask[i] {
                keep[i] = false;
            }
        }
        for &x in xs {
            keep[x as usize] = false;
        }
        for &y in ys {
            keep[y as usize] = false;
        }

        let z = bitset::collect_from_mask(&keep);

        if self.is_valid_adjustment_set(xs, ys, &z) {
            Some(z)
        } else {
            None
        }
    }

    /// Enumerate all valid adjustment sets up to a given size.
    pub fn all_adjustment_sets(
        &self,
        xs: &[u32],
        ys: &[u32],
        minimal: bool,
        max_size: u32,
    ) -> Vec<Vec<u32>> {
        // Universe of candidates: not in forbidden set or Y
        // The forbidden set already includes X
        let forbidden = self.forbidden_set(xs, ys);
        let y_set: HashSet<u32> = ys.iter().copied().collect();
        let universe: Vec<u32> = (0..self.n())
            .filter(|&v| {
                let vi = v as usize;
                !forbidden[vi] && !y_set.contains(&v)
            })
            .collect();

        let mut valid_sets = Vec::new();
        let mut cur = Vec::new();
        let max_k = (max_size as usize).min(universe.len());

        // Enumerate all subsets up to max_size
        for k in 0..=max_k {
            Self::k_subsets(&universe, k, 0, &mut cur, &mut valid_sets, |z| {
                self.is_valid_adjustment_set(xs, ys, z)
            });
        }

        if minimal {
            Self::prune_minimal(&mut valid_sets);
        }

        valid_sets
    }

    /// Enumerate all k-subsets of `u`, collecting those satisfying `pred`.
    fn k_subsets<F>(
        u: &[u32],
        k: usize,
        start: usize,
        cur: &mut Vec<u32>,
        out: &mut Vec<Vec<u32>>,
        pred: F,
    ) where
        F: Fn(&[u32]) -> bool + Copy,
    {
        if cur.len() == k {
            if pred(cur) {
                out.push(cur.clone());
            }
            return;
        }
        for i in start..u.len() {
            cur.push(u[i]);
            Self::k_subsets(u, k, i + 1, cur, out, pred);
            cur.pop();
        }
    }

    /// Remove non-minimal supersets, keeping only inclusion-minimal sets.
    fn prune_minimal(sets: &mut Vec<Vec<u32>>) {
        sets.iter_mut().for_each(|v| {
            v.sort_unstable();
            v.dedup();
        });
        sets.sort();

        let mut out: Vec<Vec<u32>> = Vec::new();
        'next: for z in sets.drain(..) {
            // Skip if z is a superset of some existing set
            for s in &out {
                if s.iter().all(|v| z.binary_search(v).is_ok()) {
                    continue 'next;
                }
            }
            // Remove any existing superset of z
            out.retain(|s| !z.iter().all(|v| s.binary_search(v).is_ok()));
            out.push(z);
        }
        *sets = out;
    }
}

#[cfg(test)]
mod tests {
    use super::Admg;

    #[test]
    fn prune_minimal_skips_supersets_of_existing_sets() {
        let mut sets = vec![
            vec![2, 3],
            vec![],
            vec![2],
            vec![3],
            vec![2, 2, 3],
            vec![2, 3, 4],
        ];

        Admg::prune_minimal(&mut sets);
        assert_eq!(sets, vec![Vec::<u32>::new()]);
    }
}
