// SPDX-License-Identifier: MIT
//! Adjustment sets, backdoor criterion, and d-separation for DAGs.

use super::Dag;
use crate::graph::alg::{bitset, reachability, subsets};
use crate::graph::CaugiGraph;
use std::sync::Arc;

const NO_VALID_SET: &str = "No valid adjustment set exists for this X and Y.";

impl Dag {
    /// Parent-based adjustment set `Z = (⋃ Pa(X)) \ (X ∪ Y)`.
    ///
    /// With one treatment this is valid whenever any valid set exists. With
    /// several it can fail while others succeed, because a parent of one
    /// treatment can lie on a causal path from another (`W` in
    /// `X1 -> W -> X2`, `W -> Y`).
    ///
    /// # Errors
    ///
    /// When `Z` is not a valid adjustment set, saying whether any valid set
    /// exists.
    pub fn adjustment_set_parents(&self, xs: &[u32], ys: &[u32]) -> Result<Vec<u32>, String> {
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
        let z = bitset::collect_from_mask(&keep);
        if self.is_valid_adjustment_set(xs, ys, &z) {
            Ok(z)
        } else if self.adjustment_set_backdoor(xs, ys).is_err() {
            Err(NO_VALID_SET.into())
        } else {
            Err("The parents of X are not a valid adjustment set here; \
                 use type = \"backdoor\" or \"optimal\"."
                .into())
        }
    }

    /// Causal nodes `cn(Xs,Ys)`: the nodes outside `Xs` on proper causal paths
    /// from `Xs` to `Ys` (directed paths whose only node in `Xs` is the first),
    /// i.e. `v ∉ Xs` with `v ∈ De(Xs)` and a directed path to `Ys` avoiding `Xs`.
    fn causal_nodes(&self, xs: &[u32], ys: &[u32]) -> Vec<u32> {
        let de_x = self.descendants_mask(xs);
        let an_y = self.ancestors_mask_avoiding(ys, xs);
        let x_mask = bitset::mask_from(xs, self.n());
        (0..self.n())
            .filter(|&v| de_x[v as usize] && an_y[v as usize] && !x_mask[v as usize])
            .collect()
    }

    /// Forbidden set for adjustment: `forb(Xs,Ys) = De(cn(Xs,Ys)) ∪ Xs`
    /// (Perković et al., 2018). `cn` contains every `y ∈ Ys ∩ De(Xs)`, so their
    /// descendants are forbidden too. Conditioning on a forbidden node either
    /// blocks the causal effect (a node on the path) or opens a spurious path
    /// (a descendant of such a node), so no valid adjustment set may intersect
    /// it.
    fn forbidden_set(&self, xs: &[u32], ys: &[u32]) -> Vec<bool> {
        let mut forbidden = self.descendants_mask(&self.causal_nodes(xs, ys));
        for &x in xs {
            forbidden[x as usize] = true;
        }
        forbidden
    }

    /// Minimal backdoor adjustment set for `Xs → Ys`.
    ///
    /// Returns an inclusion-minimal valid adjustment set, computed in linear
    /// time as a minimal d-separator of `Xs` and `Ys` in the proper backdoor
    /// graph, restricted to the adjustable nodes `V \ (forb(Xs,Ys) ∪ Ys)` (the
    /// forbidden set already contains `Xs`). This is the construction of van der
    /// Zander, Liśkiewicz & Textor (2019), and it finds a set whenever one
    /// exists.
    ///
    /// Note: minimal here is inclusion-minimal, not minimum-cardinality, and is
    /// distinct from statistically optimal — see
    /// [`adjustment_set_optimal`](Self::adjustment_set_optimal) for the O-set.
    ///
    /// # Errors
    ///
    /// When no valid adjustment set exists. With one treatment that happens
    /// only when some `y` is a parent of `x`; with several
    /// it can also come from a confounder on a causal path, e.g. in
    /// `X1 -> L -> X2`, `L -> Y` only `L` blocks `X2 <- L -> Y`, but it lies on
    /// `X1 -> L -> Y`.
    pub fn adjustment_set_backdoor(&self, xs: &[u32], ys: &[u32]) -> Result<Vec<u32>, String> {
        let forb = self.forbidden_set(xs, ys);
        let restrict: Vec<u32> = (0..self.n())
            .filter(|v| !forb[*v as usize] && !ys.contains(v))
            .collect();

        // The proper backdoor graph removes the first edge of every proper
        // causal path, so a d-separator there blocks exactly the backdoor paths.
        self.proper_backdoor_graph(xs, ys)?
            .minimal_d_separator(xs, ys, &[], &restrict)?
            .ok_or_else(|| NO_VALID_SET.into())
    }

    /// Optimal adjustment set (O-set) for `Xs → Ys`:
    /// `O(Xs,Ys) = Pa(cn(Xs,Ys)) \ forb(Xs,Ys)` (Henckel, Perković &
    /// Maathuis, 2022). Following their Remark 3.14, the nodes of `Ys` that are
    /// not descendants of `Xs` are dropped first, since the total effect on them
    /// is zero; the O-set is then for the remaining `Ys`. By their Theorem 3.13
    /// it is valid whenever any valid adjustment set exists, and among those it
    /// gives the smallest asymptotic variance in linear models.
    ///
    /// Returns the O-set and, when `return_dropped` is true, the dropped nodes
    /// of `Ys`, so a caller can tell its user which outcomes were left out.
    /// A dropped node can itself be in the O-set (`Y2` in `X -> Y1 <- Y2`).
    ///
    /// # Errors
    ///
    /// When no node of `Ys` is a descendant of `Xs`, or no valid adjustment set
    /// exists.
    pub fn adjustment_set_optimal(
        &self,
        xs: &[u32],
        ys: &[u32],
        return_dropped: bool,
    ) -> Result<(Vec<u32>, Option<Vec<u32>>), String> {
        let n = self.n() as usize;
        let de_x = self.descendants_mask(xs);
        let (ys, dropped): (Vec<u32>, Vec<u32>) =
            ys.iter().copied().partition(|&y| de_x[y as usize]);
        if ys.is_empty() {
            return Err(
                "No node in Y is a descendant of X, so the total effect of X \
                 on Y is zero; use type = \"backdoor\" for an adjustment set."
                    .into(),
            );
        }
        // Every y is now in cn, so De(cn) ∪ Xs = forb(Xs,Ys) already covers Ys.
        let cn = self.causal_nodes(xs, &ys);
        let mut drop = self.descendants_mask(&cn);
        for &x in xs {
            drop[x as usize] = true;
        }
        let mut keep = vec![false; n];
        for &c in &cn {
            for &p in self.parents_of(c) {
                keep[p as usize] = !drop[p as usize];
            }
        }
        let z = bitset::collect_from_mask(&keep);

        // With Ys ⊆ De(Xs), the O-set is invalid only when no valid set exists
        // (Henckel et al., 2022, Theorem 3.13). A valid set for the full Ys is
        // also valid for this subset, so none exists for the full Ys either.
        if self.is_valid_adjustment_set(xs, &ys, &z) {
            Ok((z, return_dropped.then_some(dropped)))
        } else {
            Err(NO_VALID_SET.into())
        }
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
        let core = self.proper_backdoor_core(xs, ys)?;
        Dag::new(Arc::new(core))
    }

    /// Validates `z` as an adjustment set for `Xs → Ys` by the generalized
    /// adjustment criterion: `z` avoids `forb(Xs,Ys) ∪ Ys`, and d-separates
    /// `Xs` from `Ys` in the proper backdoor graph.
    ///
    /// The separation test is a Bayes-ball traversal over the CSR, linear in
    /// the graph size. `d_separated` would moralize, which builds a clique on
    /// the parents of each node and is quadratic in the in-degree.
    pub fn is_valid_adjustment_set(&self, xs: &[u32], ys: &[u32], z: &[u32]) -> bool {
        let forb = self.forbidden_set(xs, ys);
        let y_mask = bitset::mask_from(ys, self.n());
        if z.iter().any(|&v| forb[v as usize] || y_mask[v as usize]) {
            return false;
        }
        self.proper_backdoor_graph(xs, ys)
            .and_then(|g| g.d_connected_restricted(xs, z, None))
            .map(|reached| !reached.iter().any(|&v| y_mask[v as usize]))
            .unwrap_or(false)
    }

    /// Build the proper backdoor graph core for `Xs → Ys`.
    pub fn proper_backdoor_core(&self, xs: &[u32], ys: &[u32]) -> Result<CaugiGraph, String> {
        let reach = self.ancestors_mask_avoiding(ys, xs);
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
        b.add_edge(1, 2, d).unwrap();

        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(g.adjustment_set_parents(&[1], &[2]).unwrap(), vec![0]);
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
        assert!(g.adjustment_set_backdoor(&[0, 1], &[3]).unwrap().is_empty());
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
        assert_eq!(
            g.adjustment_set_optimal(&[1], &[2], false).unwrap().0,
            vec![0]
        );
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
    fn dag_adjustment_backdoor_minimal_is_empty_without_backdoor_paths() {
        // 0 -> 1 -> 2, 3 -> 1. For X=1, Y=2 there is no backdoor path (both
        // parents of 1 only reach 2 through the causal edge 1 -> 2), so the
        // minimal adjustment set is empty. The non-minimal parent set {0, 3}
        // is also valid but unnecessarily large.
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        b.add_edge(3, 1, d).unwrap();

        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        let z = g.adjustment_set_backdoor(&[1], &[2]).unwrap();
        assert!(z.is_empty());
        assert!(g.is_valid_backdoor_set(1, 2, &z));
    }

    #[test]
    fn dag_adjustment_backdoor_parent_not_ancestor_of_y() {
        // Regression for #308: `C -> B -> X`, `C -> Y`.
        // The backdoor path `X <- B <- C -> Y` must be blocked. `B` is a parent
        // of `X` but not an ancestor of `Y`, so a spurious `∩ An(Y)` filter
        // wrongly dropped it and returned the (invalid) empty set.
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // C=0, B=1, X=2, Y=3
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, d).unwrap(); // C -> B
        b.add_edge(1, 2, d).unwrap(); // B -> X
        b.add_edge(0, 3, d).unwrap(); // C -> Y

        let g = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        let z = g.adjustment_set_backdoor(&[2], &[3]).unwrap();
        assert_eq!(z, vec![1]); // {B}
        assert!(g.is_valid_backdoor_set(2, 3, &z));
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
        assert_eq!(dag.adjustment_set_parents(&[1], &[3]).unwrap(), vec![0, 2]);
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

    fn dag_from(n: u32, edges: &[(u32, u32)]) -> Dag {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(n, true, &reg);
        for &(u, v) in edges {
            b.add_edge(u, v, d).unwrap();
        }
        Dag::new(Arc::new(b.finalize().unwrap())).unwrap()
    }

    #[test]
    fn dag_adjustment_several_treatments_uses_proper_causal_paths() {
        // X1=0 -> W=1 -> X2=2 -> Y=3: W reaches Y only through X2, so it is
        // not causal and the parents of X are a valid set.
        let g = dag_from(4, &[(0, 1), (1, 2), (2, 3)]);
        assert_eq!(g.adjustment_set_parents(&[0, 2], &[3]).unwrap(), vec![1]);
        assert!(g.adjustment_set_backdoor(&[0, 2], &[3]).unwrap().is_empty());
        assert!(g
            .adjustment_set_optimal(&[0, 2], &[3], false)
            .unwrap()
            .0
            .is_empty());
        assert!(g.is_valid_adjustment_set(&[0, 2], &[3], &[1]));
    }

    #[test]
    fn dag_adjustment_errors_when_no_valid_set_exists() {
        // X1=0 -> L=1 -> X2=2, L -> Y=3: only L blocks X2 <- L -> Y, but L is
        // on the causal path X1 -> L -> Y.
        let g = dag_from(4, &[(0, 1), (1, 2), (1, 3)]);
        for err in [
            g.adjustment_set_parents(&[0, 2], &[3]).unwrap_err(),
            g.adjustment_set_backdoor(&[0, 2], &[3]).unwrap_err(),
            g.adjustment_set_optimal(&[0, 2], &[3], false).unwrap_err(),
        ] {
            assert_eq!(err, NO_VALID_SET);
        }
        // Y=1 is a parent of X=0.
        let g = dag_from(2, &[(1, 0)]);
        assert_eq!(
            g.adjustment_set_backdoor(&[0], &[1]).unwrap_err(),
            NO_VALID_SET
        );
    }

    #[test]
    fn dag_optimal_drops_outcomes_that_are_not_descendants() {
        // X=0 -> Y1=1, X <- U=2 -> Y2=3: Y2 is dropped (Henckel et al., 2022,
        // Remark 3.14) and the O-set for Y1 is empty.
        let g = dag_from(4, &[(0, 1), (2, 0), (2, 3)]);
        assert_eq!(
            g.adjustment_set_optimal(&[0], &[1, 3], true).unwrap(),
            (vec![], Some(vec![3]))
        );
        let err = g.adjustment_set_optimal(&[0], &[3], false).unwrap_err();
        assert!(err.contains("No node in Y is a descendant of X"));

        // X=0 -> Y1=1 <- Y2=2: the dropped Y2 is a parent of Y1, so it is in
        // the O-set for Y1.
        let g = dag_from(3, &[(0, 1), (2, 1)]);
        assert_eq!(
            g.adjustment_set_optimal(&[0], &[1, 2], true).unwrap(),
            (vec![2], Some(vec![2]))
        );
    }

    #[test]
    fn dag_optimal_matches_single_pair_o_set_on_every_four_node_dag() {
        // Every DAG on 4 nodes with topological order 0 < 1 < 2 < 3.
        let pairs: Vec<(u32, u32)> = (0..4)
            .flat_map(|u| (u + 1..4).map(move |v| (u, v)))
            .collect();
        for mask in 0u32..(1 << pairs.len()) {
            let edges: Vec<(u32, u32)> = pairs
                .iter()
                .enumerate()
                .filter(|(i, _)| mask & (1 << i) != 0)
                .map(|(_, &e)| e)
                .collect();
            let g = dag_from(4, &edges);
            for x in 0..4 {
                let de = g.descendants_mask(&[x]);
                for y in (0..4).filter(|&y| y != x && de[y as usize]) {
                    let single = crate::graph::alg::adjustment::optimal_adjustment_set(
                        g.n(),
                        x,
                        y,
                        |u| g.parents_of(u),
                        |u| g.children_of(u),
                    );
                    assert_eq!(
                        g.adjustment_set_optimal(&[x], &[y], false).unwrap().0,
                        single,
                        "edges {edges:?}, x {x}, y {y}"
                    );
                }
            }
        }
    }

    #[test]
    fn dag_adjustment_validation_matches_moralized_separation() {
        // Every DAG on 4 nodes with topological order 0 < 1 < 2 < 3, every
        // disjoint X (1-2 nodes), Y (1 node) and Z: the Bayes-ball check must
        // agree with forbidden-set + moralized d-separation in the proper
        // backdoor graph.
        let pairs: Vec<(u32, u32)> = (0..4)
            .flat_map(|u| (u + 1..4).map(move |v| (u, v)))
            .collect();
        let xs_choices: Vec<Vec<u32>> = (0..4)
            .map(|a| vec![a])
            .chain((0..4).flat_map(|a| (a + 1..4).map(move |b| vec![a, b])))
            .collect();
        for mask in 0u32..(1 << pairs.len()) {
            let edges: Vec<(u32, u32)> = pairs
                .iter()
                .enumerate()
                .filter(|(i, _)| mask & (1 << i) != 0)
                .map(|(_, &e)| e)
                .collect();
            let g = dag_from(4, &edges);
            for xs in &xs_choices {
                for y in (0..4).filter(|v| !xs.contains(v)) {
                    let rest: Vec<u32> = (0..4).filter(|v| !xs.contains(v) && *v != y).collect();
                    let forb = g.forbidden_set(xs, &[y]);
                    let pbg = g.proper_backdoor_graph(xs, &[y]).unwrap();
                    for zmask in 0u32..(1 << rest.len()) {
                        let z: Vec<u32> = rest
                            .iter()
                            .enumerate()
                            .filter(|(i, _)| zmask & (1 << i) != 0)
                            .map(|(_, &v)| v)
                            .collect();
                        let moralized =
                            !z.iter().any(|&v| forb[v as usize]) && pbg.d_separated(xs, &[y], &z);
                        assert_eq!(
                            g.is_valid_adjustment_set(xs, &[y], &z),
                            moralized,
                            "edges {edges:?}, xs {xs:?}, y {y}, z {z:?}"
                        );
                    }
                }
            }
        }
    }

    #[test]
    fn dag_adjustment_is_linear_in_the_in_degree() {
        // U_i -> X for 20 000 parents, X -> Y. Moralizing would build a
        // 20 000-clique (~2e8 edges); the Bayes-ball check stays linear.
        let k = 20_000u32;
        let (x, y) = (k, k + 1);
        let mut edges: Vec<(u32, u32)> = (0..k).map(|u| (u, x)).collect();
        edges.push((x, y));
        let g = dag_from(k + 2, &edges);
        assert!(g
            .adjustment_set_optimal(&[x], &[y], false)
            .unwrap()
            .0
            .is_empty());
        assert_eq!(
            g.adjustment_set_parents(&[x], &[y]).unwrap().len(),
            k as usize
        );
    }
}
