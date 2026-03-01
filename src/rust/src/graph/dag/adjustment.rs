// SPDX-License-Identifier: MIT
//! Adjustment sets, backdoor criterion, and d-separation for DAGs.

use super::Dag;
use crate::graph::alg::{bitset, reachability, subsets};
use crate::graph::CaugiGraph;
use std::sync::Arc;

impl Dag {
    /// Parent-based heuristic adjustment set:
    /// `Z = (⋃ Pa(X)) \ (X ∪ Y)`.
    pub fn adjustment_set_parents(&self, xs: &[u32], ys: &[u32]) -> Vec<u32> {
        let n = self.n();
        let mut keep = vec![false; n as usize];
        for &x in xs {
            for &p in self.parents_of(x) {
                keep[p as usize] = true;
            }
        }
        // Exclude X ∪ Y.
        let mut dropm = bitset::mask_from(xs, n);
        for &y in ys {
            dropm[y as usize] = true;
        }
        for i in 0..keep.len() {
            if dropm[i] {
                keep[i] = false;
            }
        }
        bitset::collect_from_mask(&keep)
    }

    /// Backdoor adjustment candidate set for `Xs → Ys`:
    /// `Z = ( (⋃ Pa(X)) ∩ An(Y) ) \ (De(X) ∪ X ∪ Y )`.
    pub fn adjustment_set_backdoor(&self, xs: &[u32], ys: &[u32]) -> Vec<u32> {
        let n = self.n();
        let an_mask = self.ancestors_mask(ys);

        let mut keep = vec![false; n as usize];
        for &x in xs {
            for &p in self.parents_of(x) {
                if an_mask[p as usize] {
                    keep[p as usize] = true;
                }
            }
        }

        let mut dropm = vec![false; n as usize];
        for &x in xs {
            let de_mask = bitset::descendants_mask(&[x], |u| self.children_of(u), self.n());
            for i in 0..n as usize {
                if de_mask[i] {
                    dropm[i] = true;
                }
            }
            dropm[x as usize] = true;
        }
        for &y in ys {
            dropm[y as usize] = true;
        }

        for i in 0..keep.len() {
            if dropm[i] {
                keep[i] = false;
            }
        }
        bitset::collect_from_mask(&keep)
    }

    /// Optimal O-set for single exposure-outcome pair `x → y`.
    ///
    /// Definition:
    /// - Let `Cn = (De(x) ∩ An(y)) ∪ {y if y ∈ De(x)}`.
    /// - Return `Pa(Cn) \ (Cn ∪ {x})`.
    pub fn adjustment_set_optimal(&self, x: u32, y: u32) -> Vec<u32> {
        let n = self.n() as usize;

        let mut de_mask = self.descendants_mask(&[x]);
        de_mask[x as usize] = false;

        let an_mask = self.ancestors_mask(&[y]);

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
            for &p in self.parents_of(v) {
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

    /// d-separation test via ancestral reduction + moralization + BFS.
    ///
    /// Returns `true` iff every `x ∈ xs` is d-separated from every `y ∈ ys` given `z`.
    pub fn d_separated(&self, xs: &[u32], ys: &[u32], z: &[u32]) -> bool {
        if xs.is_empty() || ys.is_empty() {
            return true;
        }
        let mut seeds = xs.to_vec();
        seeds.extend_from_slice(ys);
        seeds.extend_from_slice(z);
        seeds.sort_unstable();
        seeds.dedup();

        let mask = self.ancestors_mask(&seeds);

        let mut blocked = vec![false; self.n() as usize];
        for &v in z {
            blocked[v as usize] = true;
        }

        let adj = self.moral_adj(&mask);
        !reachability::reachable_to_any(&adj, &mask, xs, &blocked, ys)
    }

    /// Validates a proposed backdoor set `z` for pair `(x, y)`.
    ///
    /// Conditions:
    /// 1) `z` must not contain descendants of `x`.
    /// 2) Each parent `p` of `x` must be d-separated from `y` given `z ∪ {x}`.
    pub fn is_valid_backdoor_set(&self, x: u32, y: u32, z: &[u32]) -> bool {
        let de_mask = bitset::descendants_mask(&[x], |u| self.children_of(u), self.n());
        for &v in z {
            if de_mask[v as usize] {
                return false;
            }
        }

        let mut obs = Vec::with_capacity(z.len() + 1);
        obs.extend_from_slice(z);
        obs.push(x);
        for &p in self.parents_of(x) {
            if !self.d_separated(&[p], &[y], &obs) {
                return false;
            }
        }
        true
    }

    /// Universe of candidates for backdoor adjustment wrt. `(x, y)`.
    fn backdoor_universe(&self, x: u32, y: u32) -> Vec<u32> {
        let de_mask = bitset::descendants_mask(&[x], |u| self.children_of(u), self.n());
        (0..self.n())
            .filter(|&v| v != x && v != y && !de_mask[v as usize])
            .collect()
    }

    /// Enumerate all valid backdoor sets up to size `max_size`.
    /// If `minimal` is true, return only inclusion-minimal sets.
    pub fn all_backdoor_sets(&self, x: u32, y: u32, minimal: bool, max_size: u32) -> Vec<Vec<u32>> {
        let u = self.backdoor_universe(x, y);
        let mut acc = Vec::new();
        let mut cur = Vec::new();
        let max_size = max_size as usize;
        for k in 0..=max_size.min(u.len()) {
            subsets::k_subsets(&u, k, 0, &mut cur, &mut acc);
        }
        acc.retain(|z| self.is_valid_backdoor_set(x, y, z));
        if minimal {
            subsets::prune_minimal(&mut acc);
        }
        acc
    }

    /// Build the proper backdoor graph for `Xs → Ys` by removing the
    /// first edge of each proper causal path from any `x ∈ Xs` to any `y ∈ Ys`.
    pub fn proper_backdoor_graph(&self, xs: &[u32], ys: &[u32]) -> Result<Self, String> {
        let reach = self.can_reach_any_y(ys);
        let xs_mask = bitset::mask_from(xs, self.n());
        let core = self.rebuild_filtered(|u, k| self.drop_first_edge(&xs_mask, &reach, u, k))?;
        Dag::new(Arc::new(core))
    }

    /// Validates `z` as an adjustment set for `Xs → Ys` using the proper backdoor graph.
    pub fn is_valid_adjustment_set(&self, xs: &[u32], ys: &[u32], z: &[u32]) -> bool {
        self.proper_backdoor_graph(xs, ys)
            .map(|g| g.d_separated(xs, ys, z))
            .unwrap_or(false)
    }

    /// Build the proper backdoor graph core for `Xs → Ys`.
    pub fn proper_backdoor_core(&self, xs: &[u32], ys: &[u32]) -> Result<CaugiGraph, String> {
        let reach = self.can_reach_any_y(ys);
        let xs_mask = bitset::mask_from(xs, self.n());
        self.rebuild_filtered(|u, k| self.drop_first_edge(&xs_mask, &reach, u, k))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    #[test]
    fn dag_adjustment_parents_basic() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(2, 1, d).unwrap();

        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(g.adjustment_set_parents(&[1], &[2]), vec![0]);
    }

    #[test]
    fn dag_adjustment_backdoor_multi_x() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        b.add_edge(2, 3, d).unwrap();

        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(g.adjustment_set_backdoor(&[0, 1], &[3]).is_empty());
    }

    #[test]
    fn dag_optimal_adjustment_confounder_and_instrument() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(3, 1, d).unwrap();

        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(g.adjustment_set_optimal(1, 2), vec![0]);
    }

    #[test]
    fn dag_d_separated_basic_patterns() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        assert!(!g.d_separated(&[0], &[2], &[]));
        assert!(g.d_separated(&[0], &[2], &[1]));
    }

    #[test]
    fn dag_d_separated_collider_activation() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        assert!(g.d_separated(&[0], &[1], &[]));
        assert!(!g.d_separated(&[0], &[1], &[2]));
    }

    #[test]
    fn dag_is_valid_backdoor_and_all_backdoor_sets() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        b.add_edge(0, 2, d).unwrap();

        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_valid_backdoor_set(1, 2, &[]));
        assert!(g.is_valid_backdoor_set(1, 2, &[0]));
        assert!(!g.is_valid_backdoor_set(0, 2, &[1])); // 1 is a descendant of 0

        let mut sets = g.all_backdoor_sets(1, 2, true, 20);
        sets.sort();
        assert_eq!(sets, vec![vec![0]]);
    }

    #[test]
    fn dag_is_valid_adjustment_set_via_proper_backdoor_graph() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        b.add_edge(0, 2, d).unwrap();

        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_valid_adjustment_set(&[1], &[2], &[]));
        assert!(g.is_valid_adjustment_set(&[1], &[2], &[0]));
    }

    #[test]
    fn dag_d_separated_empty_x_or_y_trivially_true() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        assert!(g.d_separated(&[], &[1], &[]));
        assert!(g.d_separated(&[0], &[], &[]));
    }

    #[test]
    fn dag_adjustment_backdoor_intersection_hits_equal_branch() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        b.add_edge(3, 1, d).unwrap();

        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(g.adjustment_set_backdoor(&[1], &[2]), vec![0, 3]);
    }

    #[test]
    fn dag_all_backdoor_sets_prunes_supersets() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        b.add_edge(2, 3, d).unwrap();
        b.add_edge(0, 3, d).unwrap();
        b.add_edge(1, 3, d).unwrap();

        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        let mut sets = dag.all_backdoor_sets(2, 3, true, 20);
        sets.sort();
        assert_eq!(sets, vec![vec![0, 1]]);
    }

    #[test]
    fn dag_adjustment_parents_excludes_x_and_y() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(2, 1, d).unwrap();
        b.add_edge(2, 3, d).unwrap();

        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(dag.adjustment_set_parents(&[1], &[3]), vec![0, 2]);
    }

    #[test]
    fn dag_proper_backdoor_graph_does_not_block_backdoor_by_itself() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        b.add_edge(0, 2, d).unwrap();

        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        let pb = dag.proper_backdoor_graph(&[1], &[2]).unwrap();

        assert_eq!(pb.parents_of(2), &[0]);
        assert!(!pb.d_separated(&[1], &[2], &[]));
    }

    #[test]
    fn dag_moral_adj_skips_parents_not_in_mask() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let mut a = vec![false; dag.n() as usize];
        a[2] = true;
        a[0] = true;

        let adj = dag.moral_adj(&a);

        assert_eq!(adj[2], vec![0]);
        assert_eq!(adj[0], vec![2]);
        assert!(adj[1].is_empty());
    }
}
