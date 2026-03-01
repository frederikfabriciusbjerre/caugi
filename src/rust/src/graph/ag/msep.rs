// SPDX-License-Identifier: MIT
//! M-separation implementation for Ancestral Graphs.
//!
//! M-separation generalizes d-separation to ancestral graphs with directed,
//! bidirected, and undirected edges.
//!
//! A path m-connects s to t given Z if:
//! 1. Every non-collider on the path is outside Z
//! 2. Every collider c on the path is in Z or has a descendant in Z
//!
//! Where:
//! - Colliders are nodes where two arrowheads meet (← →, ← ↔, ↔ →, ↔ ↔)
//! - Non-colliders include chains and undirected edges

use super::Ag;
use crate::graph::alg::bitset;

impl Ag {
    /// Ancestors mask including the seeds themselves.
    /// `mask[v] == true` iff `v ∈ An(seeds) ∪ seeds`.
    #[allow(dead_code)]
    pub(super) fn ancestors_mask(&self, seeds: &[u32]) -> Vec<bool> {
        bitset::ancestors_mask(seeds, |u| self.parents_of(u), self.n())
    }

    /// Anteriors mask including the seeds themselves.
    /// `mask[v] == true` iff `v ∈ Ant(seeds) ∪ seeds`.
    /// Anteriors are nodes reachable via undirected edges or directed edges pointing toward.
    pub(super) fn anteriors_mask(&self, seeds: &[u32]) -> Vec<bool> {
        let n = self.n() as usize;
        let mut mask = vec![false; n];

        // Start with seeds
        let mut stack: Vec<u32> = seeds.to_vec();
        for &s in seeds {
            mask[s as usize] = true;
        }

        // BFS/DFS to find all anteriors
        while let Some(u) = stack.pop() {
            // Parents (directed edges pointing in)
            for &p in self.parents_of(u) {
                if !mask[p as usize] {
                    mask[p as usize] = true;
                    stack.push(p);
                }
            }
            // Undirected neighbors
            for &w in self.undirected_of(u) {
                if !mask[w as usize] {
                    mask[w as usize] = true;
                    stack.push(w);
                }
            }
        }

        mask
    }

    /// Returns true if `from` has an arrowhead at `to`.
    #[inline]
    fn arrowhead_at(&self, at: u32, from: u32) -> bool {
        self.parents_of(at).binary_search(&from).is_ok()
            || self.spouses_of(at).binary_search(&from).is_ok()
    }

    /// Build an augmented adjacency for m-separation in an ancestral graph.
    ///
    /// The augmented graph connects endpoints of any collider path in the
    /// anterior subgraph (and keeps all original adjacencies).
    fn augmented_adj_ag(&self, mask: &[bool]) -> Vec<Vec<u32>> {
        use std::collections::VecDeque;

        let n = self.n() as usize;
        let mut adj = vec![Vec::<u32>::new(); n];

        // visited pairs (prev, curr) for collider-path exploration
        let mut visited = vec![0u32; n * n];
        let mut stamp: u32 = 1;

        for s in 0..n as u32 {
            if !mask[s as usize] {
                continue;
            }

            // Rotate stamp to avoid clearing the visited array each time.
            if stamp == u32::MAX {
                visited.fill(0);
                stamp = 1;
            } else {
                stamp += 1;
            }

            let mut q: VecDeque<(u32, u32)> = VecDeque::new();

            // Start from direct neighbors (collider path length 1).
            for &v in self.neighbors_of(s) {
                if !mask[v as usize] || v == s {
                    continue;
                }
                adj[s as usize].push(v);
                adj[v as usize].push(s);

                let idx = (s as usize) * n + v as usize;
                if visited[idx] != stamp {
                    visited[idx] = stamp;
                    q.push_back((s, v));
                }
            }

            while let Some((prev, curr)) = q.pop_front() {
                for &next in self.neighbors_of(curr) {
                    if next == prev || !mask[next as usize] {
                        continue;
                    }

                    // Extend only through collider nodes.
                    if !(self.arrowhead_at(curr, prev) && self.arrowhead_at(curr, next)) {
                        continue;
                    }

                    let idx = (curr as usize) * n + next as usize;
                    if visited[idx] == stamp {
                        continue;
                    }
                    visited[idx] = stamp;
                    q.push_back((curr, next));

                    if next != s {
                        adj[s as usize].push(next);
                        adj[next as usize].push(s);
                    }
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

    /// BFS reachability check over augmented graph.
    /// Returns true if any node in `src` can reach any node in `tgt` while avoiding `blocked`.
    fn reachable_in_augmented(
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

    /// M-separation test for ancestral graphs.
    ///
    /// Tests whether `xs` is m-separated from `ys` given `z` in the ancestral graph.
    ///
    /// M-separation generalizes d-separation to ancestral graphs by:
    /// 1. Taking the anterior subgraph of `xs ∪ ys ∪ z` (anteriors include nodes
    ///    reachable via undirected edges, not just directed ancestors)
    /// 2. Building the augmented graph (connect endpoints of collider paths)
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

        // Get anterior mask (includes undirected paths)
        let mask = self.anteriors_mask(&seeds);

        // Build augmented adjacency
        let adj = self.augmented_adj_ag(&mask);

        // Block conditioned nodes
        let mut blocked = vec![false; self.n() as usize];
        for &v in z {
            blocked[v as usize] = true;
        }

        // Check if xs can reach ys in the augmented graph
        !Self::reachable_in_augmented(&adj, &mask, xs, &blocked, ys)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use std::sync::Arc;

    fn setup() -> (EdgeRegistry, u8, u8, u8) {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let dir = reg.code_of("-->").unwrap();
        let bid = reg.code_of("<->").unwrap();
        let und = reg.code_of("---").unwrap();
        (reg, dir, bid, und)
    }

    #[test]
    fn msep_chain() {
        let (reg, dir, _bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        // Chain: 0 -> 1 -> 2
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(1, 2, dir).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();

        // 0 and 2 are not m-separated unconditionally
        assert!(!ag.m_separated(&[0], &[2], &[]));

        // 0 and 2 are m-separated given 1
        assert!(ag.m_separated(&[0], &[2], &[1]));
    }

    #[test]
    fn msep_collider() {
        let (reg, dir, _bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        // Collider: 0 -> 2 <- 1
        b.add_edge(0, 2, dir).unwrap();
        b.add_edge(1, 2, dir).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();

        // 0 and 1 are m-separated unconditionally (collider blocks path)
        assert!(ag.m_separated(&[0], &[1], &[]));

        // 0 and 1 are NOT m-separated given 2 (collider opens)
        assert!(!ag.m_separated(&[0], &[1], &[2]));
    }

    #[test]
    fn msep_bidirected_confounding() {
        let (reg, dir, bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        // Valid AG: 0 -> 1, 2 <-> 3, 0 -> 3
        // No anterior constraint violations (bidirected between nodes with no directed path)
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(0, 3, dir).unwrap();
        b.add_edge(2, 3, bid).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();

        // 2 and 3 are not m-separated (bidirected edge connects them)
        assert!(!ag.m_separated(&[2], &[3], &[]));

        // 0 and 2 are m-separated (no path)
        assert!(ag.m_separated(&[0], &[2], &[]));
    }

    #[test]
    fn msep_undirected_path() {
        let (reg, _dir, _bid, und) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        // Undirected chain: 0 --- 1 --- 2
        b.add_edge(0, 1, und).unwrap();
        b.add_edge(1, 2, und).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();

        // 0 and 2 are not m-separated unconditionally (connected via undirected)
        assert!(!ag.m_separated(&[0], &[2], &[]));

        // 0 and 2 are m-separated given 1
        assert!(ag.m_separated(&[0], &[2], &[1]));
    }

    #[test]
    fn msep_empty_sets() {
        let (reg, dir, _bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, dir).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();

        // Empty X or Y is trivially m-separated
        assert!(ag.m_separated(&[], &[1], &[]));
        assert!(ag.m_separated(&[0], &[], &[]));
    }

    #[test]
    fn msep_m_bias() {
        let (reg, dir, _bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        // M-bias structure:
        // U1 -> X, U1 -> M, U2 -> M, U2 -> Y
        // 0:U1, 1:U2, 2:X, 3:M, 4:Y
        b.add_edge(0, 2, dir).unwrap(); // U1 -> X
        b.add_edge(0, 3, dir).unwrap(); // U1 -> M
        b.add_edge(1, 3, dir).unwrap(); // U2 -> M
        b.add_edge(1, 4, dir).unwrap(); // U2 -> Y

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();

        // X and Y are m-separated unconditionally
        assert!(ag.m_separated(&[2], &[4], &[]));

        // X and Y are NOT m-separated given M (collider bias)
        assert!(!ag.m_separated(&[2], &[4], &[3]));
    }

    #[test]
    fn msep_pure_bidirected_chain() {
        let (reg, _dir, bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        // Chain of bidirected: 0 <-> 1 <-> 2
        b.add_edge(0, 1, bid).unwrap();
        b.add_edge(1, 2, bid).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();

        // M-separation uses the anterior subgraph (directed-into + undirected edges).
        // Since there are no such edges, Ant({0,2}) = {0,2} (node 1 is not included).
        // In this subgraph, 0 and 2 have no connecting edges, so they are m-separated.
        assert!(ag.m_separated(&[0], &[2], &[]));

        // When conditioning on 1, the collider path 0 <-> 1 <-> 2 opens.
        assert!(!ag.m_separated(&[0], &[2], &[1]));
    }

    #[test]
    fn msep_multi_collider_bidirected_chain() {
        let (reg, _dir, bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        // Chain of bidirected: 0 <-> 1 <-> 2 <-> 3
        b.add_edge(0, 1, bid).unwrap();
        b.add_edge(1, 2, bid).unwrap();
        b.add_edge(2, 3, bid).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();

        // Colliders block the path unless conditioned on.
        assert!(ag.m_separated(&[0], &[3], &[]));

        // Conditioning on both colliders opens the collider path.
        assert!(!ag.m_separated(&[0], &[3], &[1, 2]));
    }

    #[test]
    fn msep_internal_masks_and_augmented_adj_paths() {
        let (reg, _dir, bid, _und) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        // Bidirected triangle gives multiple collider-path traversal routes.
        b.add_edge(0, 1, bid).unwrap();
        b.add_edge(1, 2, bid).unwrap();
        b.add_edge(0, 2, bid).unwrap();

        let ag = Ag::new(Arc::new(b.finalize().unwrap())).unwrap();

        // Cover internal ancestor-mask helper.
        let an = ag.ancestors_mask(&[2]);
        assert_eq!(an.len(), 3);
        assert!(an[2]);

        // Cover augmented adjacency construction for dense collider structure.
        let mask = vec![true; 3];
        let adj = ag.augmented_adj_ag(&mask);
        assert_eq!(adj.len(), 3);
        assert!(adj[0].contains(&1));
        assert!(adj[0].contains(&2));
    }
}
