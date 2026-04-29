// SPDX-License-Identifier: MIT
//! M-separation implementation for ADMGs.

use super::Admg;
use crate::graph::alg::bitset;
use crate::graph::alg::min_msep::{self, MixedGraph};
use std::collections::HashSet;

impl MixedGraph for Admg {
    fn n(&self) -> u32 {
        Admg::n(self)
    }
    fn parents_of(&self, v: u32) -> &[u32] {
        Admg::parents_of(self, v)
    }
    fn children_of(&self, v: u32) -> &[u32] {
        Admg::children_of(self, v)
    }
    fn spouses_of(&self, v: u32) -> &[u32] {
        Admg::spouses_of(self, v)
    }
    fn undirected_of(&self, _v: u32) -> &[u32] {
        &[]
    }
    fn anteriors_mask(&self, seeds: &[u32]) -> Vec<bool> {
        // ADMGs have no undirected edges, so pAn = An.
        self.ancestors_mask(seeds)
    }
}

impl Admg {
    /// Ancestors mask including the seeds themselves.
    /// `mask[v] == true` iff `v ∈ An(seeds) ∪ seeds`.
    pub(super) fn ancestors_mask(&self, seeds: &[u32]) -> Vec<bool> {
        bitset::ancestors_mask(seeds, |u| self.parents_of(u), self.n())
    }

    /// Ancestors mask in the graph obtained by deleting every directed edge
    /// `(u → v)` in `removed_directed`.
    fn ancestors_mask_filtered(
        &self,
        seeds: &[u32],
        removed_directed: &HashSet<(u32, u32)>,
    ) -> Vec<bool> {
        let n = self.n() as usize;
        let mut a = vec![false; n];
        let mut st: Vec<u32> = Vec::new();
        let push_parents = |u: u32, st: &mut Vec<u32>| {
            for &p in self.parents_of(u) {
                if !removed_directed.contains(&(p, u)) {
                    st.push(p);
                }
            }
        };
        for &s in seeds {
            if !a[s as usize] {
                a[s as usize] = true;
                push_parents(s, &mut st);
            }
        }
        while let Some(u) = st.pop() {
            let ui = u as usize;
            if a[ui] {
                continue;
            }
            a[ui] = true;
            push_parents(u, &mut st);
        }
        a
    }

    /// Build a moral adjacency for m-separation in an ADMG.
    ///
    /// This extends the standard moralization to handle bidirected edges:
    /// 1. Connect parents with children (undirected)
    /// 2. Marry every pair of arrowhead endpoints at a common node
    ///    (i.e. every pair in `pa(v) ∪ sp(v)`)
    /// 3. Add bidirected edges as undirected edges
    fn moral_adj_admg(&self, mask: &[bool]) -> Vec<Vec<u32>> {
        self.moral_adj_admg_filtered(mask, &HashSet::new())
    }

    /// Variant of [`moral_adj_admg`](Self::moral_adj_admg) that ignores every
    /// directed edge `(u → v)` listed in `removed_directed`. Used to moralize
    /// the proper backdoor graph without rebuilding the underlying CSR.
    fn moral_adj_admg_filtered(
        &self,
        mask: &[bool],
        removed_directed: &HashSet<(u32, u32)>,
    ) -> Vec<Vec<u32>> {
        let n = self.n() as usize;
        let mut adj = vec![Vec::<u32>::new(); n];

        for v in 0..n as u32 {
            if !mask[v as usize] {
                continue;
            }

            // Effective directed parents (after deleting edges in `removed_directed`).
            let pa: Vec<u32> = self
                .parents_of(v)
                .iter()
                .copied()
                .filter(|&u| !removed_directed.contains(&(u, v)))
                .collect();

            // Connect with parents (as in standard moralization)
            for &p in &pa {
                if mask[p as usize] {
                    adj[v as usize].push(p);
                    adj[p as usize].push(v);
                }
            }

            // Add bidirected edges as undirected (spouses connect in moral graph)
            for &s in self.spouses_of(v) {
                if mask[s as usize] {
                    adj[v as usize].push(s);
                    // Note: the reverse will be added when we process node s
                }
            }

            // Marry every pair of arrowhead endpoints at v: pa(v) ∪ sp(v).
            // Both directed parents and spouses contribute an arrowhead at v,
            // so the full moralization rule must form a clique on this union.
            let mut heads: Vec<u32> = pa
                .iter()
                .copied()
                .chain(self.spouses_of(v).iter().copied())
                .filter(|u| mask[*u as usize])
                .collect();
            heads.sort_unstable();
            heads.dedup();
            for i in 0..heads.len() {
                for j in i + 1..heads.len() {
                    let hi = heads[i] as usize;
                    let hj = heads[j] as usize;
                    adj[hi].push(heads[j]);
                    adj[hj].push(heads[i]);
                }
            }
        }

        // Dedup neighbors per node
        for v in &mut adj {
            v.sort_unstable();
            v.dedup();
        }
        adj
    }

    /// BFS reachability check over moral graph.
    /// Returns true if any node in `src` can reach any node in `tgt` while avoiding `blocked`.
    fn reachable_in_moral(
        adj: &[Vec<u32>],
        mask: &[bool],
        src: &[u32],
        blocked: &[bool],
        tgt: &[u32],
    ) -> bool {
        use std::collections::VecDeque;
        let n = adj.len();
        let mut target = vec![false; n];
        for &y in tgt {
            if !blocked[y as usize] {
                target[y as usize] = true;
            }
        }

        let mut seen = vec![false; n];
        let mut q = VecDeque::new();
        for &x in src {
            let xi = x as usize;
            if mask[xi] && !blocked[xi] && !seen[xi] {
                seen[xi] = true;
                q.push_back(x);
            }
        }

        while let Some(u) = q.pop_front() {
            let ui = u as usize;
            if target[ui] {
                return true;
            }
            for &w in &adj[ui] {
                let wi = w as usize;
                if mask[wi] && !blocked[wi] && !seen[wi] {
                    seen[wi] = true;
                    q.push_back(w);
                }
            }
        }
        false
    }

    /// M-separation test for ADMGs.
    ///
    /// Tests whether `xs` is m-separated from `ys` given `z` in the ADMG.
    ///
    /// M-separation generalizes d-separation to ADMGs by:
    /// 1. Taking the ancestral subgraph of `xs ∪ ys ∪ z`
    /// 2. Moralizing it (marrying parents, keeping bidirected edges)
    /// 3. Removing conditioning nodes
    /// 4. Testing path connectivity
    ///
    /// Returns `true` iff `xs ⊥_m ys | z`.
    pub fn m_separated(&self, xs: &[u32], ys: &[u32], z: &[u32]) -> bool {
        if xs.is_empty() || ys.is_empty() {
            return true;
        }

        // Collect all seeds
        let mut seeds = xs.to_vec();
        seeds.extend_from_slice(ys);
        seeds.extend_from_slice(z);
        seeds.sort_unstable();
        seeds.dedup();

        // Get ancestral mask
        let mask = self.ancestors_mask(&seeds);

        // Build moral adjacency
        let adj = self.moral_adj_admg(&mask);

        // Block conditioned nodes
        let mut blocked = vec![false; self.n() as usize];
        for &v in z {
            blocked[v as usize] = true;
        }

        // Check if xs can reach ys in the moral graph
        !Self::reachable_in_moral(&adj, &mask, xs, &blocked, ys)
    }

    /// M-separation in the proper backdoor graph for `(xs, ys)`.
    ///
    /// The proper backdoor graph is `G` with the first edge of every proper
    /// causal path from `xs` to `ys` removed. A proper causal path is a
    /// directed path `x = v0 → v1 → ... → vk = y` whose internal nodes
    /// `v1, …, vk` are not in `xs`. Equivalently, the deleted edges are
    /// `x → v` with `x ∈ xs`, `v ∉ xs`, and `v ∈ An(ys) ∪ ys`.
    ///
    /// Returns `true` iff `xs ⊥_m ys | z` in that graph. Together with the
    /// forbidden-set check, this is the second condition of the Generalized
    /// Adjustment Criterion of Perković et al. (2018).
    pub(super) fn m_separated_pbg(&self, xs: &[u32], ys: &[u32], z: &[u32]) -> bool {
        if xs.is_empty() || ys.is_empty() {
            return true;
        }

        // First edges of proper causal paths from `xs` to `ys`.
        let an_y = self.ancestors_mask(ys);
        let x_set: HashSet<u32> = xs.iter().copied().collect();
        let mut removed: HashSet<(u32, u32)> = HashSet::new();
        for &x in xs {
            for &v in self.children_of(x) {
                if !x_set.contains(&v) && an_y[v as usize] {
                    removed.insert((x, v));
                }
            }
        }

        // m-separation in the proper backdoor graph.
        let mut seeds = xs.to_vec();
        seeds.extend_from_slice(ys);
        seeds.extend_from_slice(z);
        seeds.sort_unstable();
        seeds.dedup();

        let mask = self.ancestors_mask_filtered(&seeds, &removed);
        let adj = self.moral_adj_admg_filtered(&mask, &removed);

        let mut blocked = vec![false; self.n() as usize];
        for &v in z {
            blocked[v as usize] = true;
        }

        !Self::reachable_in_moral(&adj, &mask, xs, &blocked, ys)
    }

    /// Computes a minimal m-separator for `xs` and `ys` in the ADMG.
    ///
    /// See [`crate::graph::alg::min_msep::find_min_msep`] for the algorithm
    /// (van der Zander & Liśkiewicz, UAI 2020). Linear time.
    pub fn minimal_m_separator(
        &self,
        xs: &[u32],
        ys: &[u32],
        include: &[u32],
        restrict: &[u32],
    ) -> Result<Option<Vec<u32>>, String> {
        min_msep::find_min_msep(self, xs, ys, include, restrict)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use std::sync::Arc;

    fn two_parents_one_child() -> Admg {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // 0 -> 2 <- 1
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        Admg::new(Arc::new(b.finalize().unwrap())).unwrap()
    }

    fn build_admg(n: u32, directed: &[(u32, u32)], bidirected: &[(u32, u32)]) -> Admg {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();
        let b = reg.code_of("<->").unwrap();
        let mut builder = GraphBuilder::new_with_registry(n, true, &reg);
        for &(u, v) in directed {
            builder.add_edge(u, v, d).unwrap();
        }
        for &(u, v) in bidirected {
            builder.add_edge(u, v, b).unwrap();
        }
        Admg::new(Arc::new(builder.finalize().unwrap())).unwrap()
    }

    #[test]
    fn minimal_m_separator_chain() {
        // 0 -> 1 -> 2; sep for (0, 2) given restrict={1} is {1}.
        let g = build_admg(3, &[(0, 1), (1, 2)], &[]);
        let z = g.minimal_m_separator(&[0], &[2], &[], &[1]).unwrap();
        assert_eq!(z, Some(vec![1]));
    }

    #[test]
    fn minimal_m_separator_bidirected_confounder_unblockable() {
        // 0 <-> 1: latent confounder, no separator.
        let g = build_admg(2, &[], &[(0, 1)]);
        let z = g.minimal_m_separator(&[0], &[1], &[], &[]).unwrap();
        assert!(z.is_none());
    }

    #[test]
    fn minimal_m_separator_directed_through_bidirected() {
        // 0 -> 1, 1 <-> 2, 2 -> 3; minimal sep for (0, 3) within {1, 2}.
        let g = build_admg(4, &[(0, 1), (2, 3)], &[(1, 2)]);
        let z = g
            .minimal_m_separator(&[0], &[3], &[], &[1, 2])
            .unwrap()
            .expect("expected a separator");
        // Z must m-separate.
        assert!(g.m_separated(&[0], &[3], &z));
        // Removing any element breaks separation.
        for i in 0..z.len() {
            let mut shrunk = z.clone();
            shrunk.remove(i);
            assert!(
                !g.m_separated(&[0], &[3], &shrunk),
                "Z = {:?} not minimal: removing index {} still m-separates",
                z,
                i
            );
        }
    }

    #[test]
    fn minimal_m_separator_iv_collider_blocks_separation() {
        // Instrumental variable: Z -> X -> Y, X <-> Y.
        // 0:Z, 1:X, 2:Y. Conditioning on X blocks the chain Z -> X -> Y but
        // simultaneously opens the collider X on the path Z -> X <-> Y, so no
        // separator with restrict={X} exists.
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();
        let b = reg.code_of("<->").unwrap();
        let mut builder = GraphBuilder::new_with_registry(3, false, &reg);
        builder.add_edge(0, 1, d).unwrap();
        builder.add_edge(1, 2, d).unwrap();
        builder.add_edge(1, 2, b).unwrap();
        let g = Admg::new(Arc::new(builder.finalize().unwrap())).unwrap();

        // No separator exists.
        assert!(g
            .minimal_m_separator(&[0], &[2], &[], &[1])
            .unwrap()
            .is_none());
    }

    #[test]
    fn minimal_m_separator_empty_inputs() {
        let g = build_admg(2, &[(0, 1)], &[]);
        assert!(g
            .minimal_m_separator(&[], &[1], &[], &[])
            .unwrap()
            .is_none());
        assert!(g
            .minimal_m_separator(&[0], &[], &[], &[])
            .unwrap()
            .is_none());
    }

    #[test]
    fn minimal_m_separator_out_of_bounds_errors() {
        let g = build_admg(2, &[(0, 1)], &[]);
        assert!(g.minimal_m_separator(&[5], &[1], &[], &[]).is_err());
        assert!(g.minimal_m_separator(&[0], &[5], &[], &[]).is_err());
        assert!(g.minimal_m_separator(&[0], &[1], &[5], &[]).is_err());
        assert!(g.minimal_m_separator(&[0], &[1], &[], &[5]).is_err());
    }

    #[test]
    fn moral_adj_admg_skips_masked_parents_in_parent_pair_loops() {
        let g = two_parents_one_child();

        // Hit line 47 path: first parent kept, second parent masked.
        let adj = g.moral_adj_admg(&[true, false, true]);
        assert_eq!(adj[2], vec![0]);
        assert!(adj[0].contains(&2));
        assert!(!adj[0].contains(&1));

        // Hit line 42 path: first parent masked entirely.
        let adj2 = g.moral_adj_admg(&[false, true, true]);
        assert_eq!(adj2[2], vec![1]);
        assert!(adj2[1].contains(&2));
    }
}
