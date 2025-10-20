// SPDX-License-Identifier: MIT
//! ADMG (Acyclic Directed Mixed Graph) wrapper with O(1) slice queries.

use super::CaugiGraph;
use crate::edges::EdgeClass;
use crate::graph::alg::directed_part_is_acyclic;
use std::sync::Arc;

#[derive(Debug, Clone)]
pub struct Admg {
    core: Arc<CaugiGraph>,
    /// len = n+1
    node_edge_ranges: Arc<[usize]>,
    /// len = n; (parents, bidirected, children)
    node_deg: Arc<[(u32, u32, u32)]>,
    /// packed as [parents | bidirected | children]
    neighborhoods: Arc<[u32]>,
}

impl Admg {
    pub fn new(core: Arc<CaugiGraph>) -> Result<Self, String> {
        let n = core.n() as usize;
        if !directed_part_is_acyclic(&core) {
            return Err("ADMG contains a directed cycle".into());
        }
        let mut deg: Vec<(u32, u32, u32)> = vec![(0, 0, 0); n];
        for i in 0..n {
            let r = core.row_range(i as u32);
            for k in r.clone() {
                let spec = &core.registry.specs[core.etype[k] as usize];
                match spec.class {
                    EdgeClass::Directed => {
                        if core.side[k] == 1 {
                            deg[i].0 += 1
                        } else {
                            deg[i].2 += 1
                        }
                    }
                    EdgeClass::Bidirected => deg[i].1 += 1,
                    // Throw error on undirected/partial edges
                    _ => {
                        return Err("ADMG cannot contain undirected/partial edges".into());
                    }
                }
            }
        }
        let mut node_edge_ranges = Vec::with_capacity(n + 1);
        node_edge_ranges.push(0usize);
        for i in 0..n {
            let (pa, bi, ch) = deg[i];
            let last = *node_edge_ranges.last().unwrap();
            node_edge_ranges.push(last + (pa + bi + ch) as usize);
        }
        let total = *node_edge_ranges.last().unwrap();
        let mut neigh = vec![0u32; total];

        // bucket bases
        let mut parent_base: Vec<usize> = vec![0; n];
        let mut bi_base: Vec<usize> = vec![0; n];
        let mut child_base: Vec<usize> = vec![0; n];
        for i in 0..n {
            let start = node_edge_ranges[i];
            let (pa, bi, _) = deg[i];
            parent_base[i] = start;
            bi_base[i] = start + pa as usize;
            child_base[i] = bi_base[i] + bi as usize;
        }
        let mut pcur = parent_base.clone();
        let mut bcur = bi_base.clone();
        let mut ccur = child_base.clone();

        for i in 0..n {
            let r = core.row_range(i as u32);
            for k in r.clone() {
                let spec = &core.registry.specs[core.etype[k] as usize];
                match spec.class {
                    EdgeClass::Directed => {
                        if core.side[k] == 1 {
                            let p = pcur[i];
                            neigh[p] = core.col_index[k];
                            pcur[i] += 1;
                        } else {
                            let p = ccur[i];
                            neigh[p] = core.col_index[k];
                            ccur[i] += 1;
                        }
                    }
                    EdgeClass::Bidirected => {
                        let p = bcur[i];
                        neigh[p] = core.col_index[k];
                        bcur[i] += 1;
                    }
                    _ => {
                        // Is only here to satisfy exhaustiveness. It's unreachable
                        unreachable!("Should have errored on undirected/partial edges earlier");
                    }
                }
            }
            // determinism
            let s = node_edge_ranges[i];
            let pm = bi_base[i];
            let bm = child_base[i];
            let e = node_edge_ranges[i + 1];
            neigh[s..pm].sort_unstable();
            neigh[pm..bm].sort_unstable();
            neigh[bm..e].sort_unstable();
        }

        Ok(Self {
            core,
            node_edge_ranges: node_edge_ranges.into(),
            node_deg: deg.into(),
            neighborhoods: neigh.into(),
        })
    }

    #[inline]
    pub fn n(&self) -> u32 {
        self.core.n()
    }
    #[inline]
    fn bounds(&self, i: u32) -> (usize, usize, usize, usize) {
        let i = i as usize;
        let s = self.node_edge_ranges[i];
        let e = self.node_edge_ranges[i + 1];
        let (pa, bi, ch) = self.node_deg[i];
        let pm = s + pa as usize;
        let bm = pm + bi as usize;
        let cs = e - ch as usize;
        (s, pm, bm, cs)
    }

    #[inline]
    pub fn parents_of(&self, i: u32) -> &[u32] {
        let (s, pm, _, _) = self.bounds(i);
        &self.neighborhoods[s..pm]
    }
    #[inline]
    pub fn children_of(&self, i: u32) -> &[u32] {
        let (_, _, _, cs) = self.bounds(i);
        let e = self.node_edge_ranges[i as usize + 1];
        &self.neighborhoods[cs..e]
    }
    #[inline]
    pub fn bidirected_of(&self, i: u32) -> &[u32] {
        let (_, pm, bm, _) = self.bounds(i);
        &self.neighborhoods[pm..bm]
    }

    #[inline]
    pub fn neighbors_of(&self, i: u32) -> &[u32] {
        let i = i as usize;
        let s = self.node_edge_ranges[i];
        let e = self.node_edge_ranges[i + 1];
        &self.neighborhoods[s..e]
    }

    #[inline]
    pub fn ancestors_of(&self, i: u32) -> Vec<u32> {
        let n = self.n() as usize;
        let mut seen = vec![false; n];
        let mut out = Vec::new();
        let mut stack: Vec<u32> = self.parents_of(i).to_vec();
        while let Some(u) = stack.pop() {
            let ui = u as usize;
            if seen[ui] {
                continue;
            }
            seen[ui] = true;
            out.push(u);
            stack.extend_from_slice(self.parents_of(u));
        }
        out.sort_unstable();
        out
    }
    #[inline]
    pub fn descendants_of(&self, i: u32) -> Vec<u32> {
        let n = self.n() as usize;
        let mut seen = vec![false; n];
        let mut out = Vec::new();
        let mut stack: Vec<u32> = self.children_of(i).to_vec();
        while let Some(u) = stack.pop() {
            let ui = u as usize;
            if seen[ui] {
                continue;
            }
            seen[ui] = true;
            out.push(u);
            stack.extend_from_slice(self.children_of(u));
        }
        out.sort_unstable();
        out
    }
    #[inline]
    pub fn markov_blanket_of(&self, i: u32) -> Vec<u32> {
        let mut mb: Vec<u32> = Vec::new();
        // Directed part
        mb.extend_from_slice(self.parents_of(i));
        mb.extend_from_slice(self.children_of(i));
        for &c in self.children_of(i) {
            for &p in self.parents_of(c) {
                if p != i {
                    mb.push(p);
                }
            }
        }
        // Bidirected neighbors represent latent confounding
        mb.extend_from_slice(self.bidirected_of(i));
        mb.sort_unstable();
        mb.dedup();
        mb
    }
    #[inline]
    pub fn exogenous_nodes(&self) -> Vec<u32> {
        (0..self.n())
            .filter(|&i| self.parents_of(i).is_empty())
            .collect()
    }

    pub fn core_ref(&self) -> &CaugiGraph {
        &self.core
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    #[test]
    fn admg_relations() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();
        let cbi = reg.code_of("<->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cbi).unwrap();
        let core = std::sync::Arc::new(b.finalize().unwrap());
        let g = Admg::new(core).expect("ADMG construction failed");
        assert_eq!(g.parents_of(1), vec![0]);
        assert_eq!(g.children_of(0), vec![1]);
        let mut bi = g.bidirected_of(1).to_vec();
        bi.sort_unstable();
        assert_eq!(bi, vec![2]);
        assert_eq!(g.n(), 3);
        assert_eq!(g.neighbors_of(0), vec![1]);
        assert_eq!(g.neighbors_of(1), vec![0, 2]);
        assert_eq!(g.neighbors_of(2), vec![1]);

        // get core
        let core = g.core_ref();
        assert_eq!(core.n(), 3);
    }

    #[test]
    fn admg_cycle_error() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cdir).unwrap();
        b.add_edge(2, 0, cdir).unwrap();
        let core = std::sync::Arc::new(b.finalize().unwrap());
        let r = Admg::new(core);
        assert!(r.is_err());
    }

    #[test]
    fn admg_an_de_directed_only() {
        // 0 -> 1 <-> 2
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();
        let cbi = reg.code_of("<->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cbi).unwrap();
        let g = Admg::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(g.ancestors_of(1), vec![0]);
        assert_eq!(g.descendants_of(0), vec![1]);
        assert!(g.ancestors_of(2).is_empty());
        assert!(g.descendants_of(2).is_empty());
    }

    #[test]
    fn admg_mb() {
        // 0 -> 1 <-> 2, and 1 <- 3
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let bi = r.code_of("<->").unwrap();
        let mut b = GraphBuilder::new_with_registry(4, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, bi).unwrap();
        b.add_edge(3, 1, d).unwrap();
        let g = Admg::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(g.markov_blanket_of(1), vec![0, 2, 3]); // parents {0,3}, bidirected {2}
        assert_eq!(g.markov_blanket_of(0), vec![1, 3]); // child {1}, co-parent via 1 {3}
    }
    #[test]
    fn admg_undirected_edge_error() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cund = reg.code_of("---").unwrap();
        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, cund).unwrap();
        let core = std::sync::Arc::new(b.finalize().unwrap());
        let r = Admg::new(core);
        assert!(r.is_err());
    }

    #[test]
    fn admg_partial_edge_error() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cpar = reg.code_of("o->").unwrap();
        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, cpar).unwrap();
        let core = std::sync::Arc::new(b.finalize().unwrap());
        let r = Admg::new(core);
        assert!(r.is_err());
    }

    #[test]
    fn admg_exogenous() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let bi = r.code_of("<->").unwrap();
        // 0->1, 1<->2; node 3 isolated
        let mut b = GraphBuilder::new_with_registry(4, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, bi).unwrap();
        let g = Admg::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(g.exogenous_nodes(), vec![0, 2, 3]);
    }
}
