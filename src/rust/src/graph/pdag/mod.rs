// SPDX-License-Identifier: MIT
//! Pdag wrapper with O(1) slice queries via packed neighborhoods.

mod cpdag;
mod transforms;

use super::error::PdagError;
use super::CaugiGraph;
use crate::edges::EdgeClass;
use crate::graph::alg::directed_part_is_acyclic;
use crate::graph::alg::traversal;
use std::sync::Arc;

#[derive(Debug, Clone)]
pub struct Pdag {
    core: Arc<CaugiGraph>,
    /// len = n+1
    node_edge_ranges: Arc<[usize]>,
    /// len = n; (parents, undirected, children)
    node_deg: Arc<[(u32, u32, u32)]>,
    /// packed as [parents | undirected | children]
    neighborhoods: Arc<[u32]>,
}

impl Pdag {
    /// Builds a `Pdag` view over a class-agnostic CSR graph.
    ///
    /// Returns a `String` error for FFI compatibility. Use `try_new` for typed errors.
    pub fn new(core: Arc<CaugiGraph>) -> Result<Self, String> {
        Self::try_new(core).map_err(|e| e.to_string())
    }

    /// Builds a `Pdag` view with typed error handling.
    pub fn try_new(core: Arc<CaugiGraph>) -> Result<Self, PdagError> {
        let n = core.n() as usize;
        if !directed_part_is_acyclic(&core) {
            return Err(PdagError::DirectedCycle);
        }
        // Count degrees using mark helpers.
        // is_incoming_arrow(k) = Arrow points INTO me = neighbor is parent
        let mut deg: Vec<(u32, u32, u32)> = vec![(0, 0, 0); n];
        for i in 0..n {
            for k in core.row_range(i as u32) {
                let spec = core.spec(k);
                match spec.class {
                    EdgeClass::Directed => {
                        if core.is_incoming_arrow(k) {
                            deg[i].0 += 1; // parent
                        } else {
                            deg[i].2 += 1; // child
                        }
                    }
                    EdgeClass::Undirected => deg[i].1 += 1,
                    _ => {
                        return Err(PdagError::InvalidEdgeType {
                            found: spec.glyph.clone(),
                        });
                    }
                }
            }
        }
        let mut node_edge_ranges = Vec::with_capacity(n + 1);
        node_edge_ranges.push(0usize);
        for i in 0..n {
            let (pa, u, ch) = deg[i];
            let last = *node_edge_ranges.last().unwrap();
            node_edge_ranges.push(last + (pa + u + ch) as usize);
        }
        let total = *node_edge_ranges.last().unwrap();
        let mut neigh = vec![0u32; total];

        // bucket bases
        let mut parent_base: Vec<usize> = vec![0; n];
        let mut und_base: Vec<usize> = vec![0; n];
        let mut child_base: Vec<usize> = vec![0; n];
        for i in 0..n {
            let start = node_edge_ranges[i];
            let (pa, u, _) = deg[i];
            parent_base[i] = start;
            und_base[i] = start + pa as usize;
            child_base[i] = und_base[i] + u as usize;
        }
        let mut pcur = parent_base.clone();
        let mut ucur = und_base.clone();
        let mut ccur = child_base.clone();

        for i in 0..n {
            for k in core.row_range(i as u32) {
                let spec = core.spec(k);
                match spec.class {
                    EdgeClass::Directed => {
                        if core.is_incoming_arrow(k) {
                            neigh[pcur[i]] = core.col_index[k];
                            pcur[i] += 1;
                        } else {
                            neigh[ccur[i]] = core.col_index[k];
                            ccur[i] += 1;
                        }
                    }
                    EdgeClass::Undirected => {
                        neigh[ucur[i]] = core.col_index[k];
                        ucur[i] += 1;
                    }
                    _ => {
                        unreachable!("Should have errored on partial/bidirected edges earlier");
                    }
                }
            }
            // determinism
            let s = node_edge_ranges[i];
            let pm = und_base[i];
            let um = child_base[i];
            let e = node_edge_ranges[i + 1];
            neigh[s..pm].sort_unstable();
            neigh[pm..um].sort_unstable();
            neigh[um..e].sort_unstable();
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
        let (pa, u, ch) = self.node_deg[i];
        let pm = s + pa as usize;
        let um = pm + u as usize;
        let cs = e - ch as usize;
        (s, pm, um, cs)
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
    pub fn undirected_of(&self, i: u32) -> &[u32] {
        let (_, pm, um, _) = self.bounds(i);
        &self.neighborhoods[pm..um]
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
        traversal::ancestors_of(self.n(), i, |u| self.parents_of(u))
    }

    #[inline]
    pub fn descendants_of(&self, i: u32) -> Vec<u32> {
        traversal::descendants_of(self.n(), i, |u| self.children_of(u))
    }

    #[inline]
    pub fn anteriors_of(&self, i: u32) -> Vec<u32> {
        traversal::anteriors_of(
            self.n(),
            i,
            |u| self.parents_of(u),
            |u| self.undirected_of(u),
        )
    }

    #[inline]
    pub fn markov_blanket_of(&self, i: u32) -> Vec<u32> {
        let mut mb: Vec<u32> = Vec::new();
        // DAG part
        mb.extend_from_slice(self.parents_of(i));
        mb.extend_from_slice(self.children_of(i));
        for &c in self.children_of(i) {
            for &p in self.parents_of(c) {
                if p != i {
                    mb.push(p);
                }
            }
        }
        // undirected neighbors belong to the blanket in (C)PDAGs
        mb.extend_from_slice(self.undirected_of(i));
        mb.sort_unstable();
        mb.dedup();
        mb
    }

    #[inline]
    pub fn exogenous_nodes(&self, undirected_as_parents: bool) -> Vec<u32> {
        (0..self.n())
            .filter(|&i| {
                let no_pa = self.parents_of(i).is_empty();
                if undirected_as_parents {
                    no_pa && self.undirected_of(i).is_empty()
                } else {
                    no_pa
                }
            })
            .collect()
    }

    pub fn core_ref(&self) -> &CaugiGraph {
        &self.core
    }
}

// -------- Internal helpers --------
impl Pdag {
    #[inline]
    pub(crate) fn adjacent(&self, a: u32, b: u32) -> bool {
        self.neighbors_of(a).binary_search(&b).is_ok()
    }

    #[inline]
    pub(crate) fn intersects_sorted(a: &[u32], b: &[u32]) -> bool {
        use std::cmp::Ordering::*;
        let (mut i, mut j) = (0usize, 0usize);
        while i < a.len() && j < b.len() {
            match a[i].cmp(&b[j]) {
                Less => i += 1,
                Greater => j += 1,
                Equal => return true,
            }
        }
        false
    }

    #[inline]
    pub(crate) fn has_dir_path(&self, src: u32, tgt: u32) -> bool {
        let n = self.n() as usize;
        if src == tgt {
            return true;
        }
        let mut seen = vec![false; n];
        use std::collections::VecDeque;
        let mut q = VecDeque::new();
        q.push_back(src);
        while let Some(u) = q.pop_front() {
            if u == tgt {
                return true;
            }
            if std::mem::replace(&mut seen[u as usize], true) {
                continue;
            }
            for &w in self.children_of(u) {
                if !seen[w as usize] {
                    q.push_back(w);
                }
            }
        }
        false
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    #[test]
    fn pdag_relations() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();
        let cund = reg.code_of("---").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cund).unwrap();
        let core = std::sync::Arc::new(b.finalize().unwrap());
        let g = Pdag::new(core).expect("Pdag construction failed");
        assert_eq!(g.parents_of(1), vec![0]);
        assert_eq!(g.children_of(0), vec![1]);
        let mut u = g.undirected_of(1).to_vec();
        u.sort_unstable();
        assert_eq!(u, vec![2]);
        assert_eq!(g.n(), 3);
        assert_eq!(g.neighbors_of(0), vec![1]);
        assert_eq!(g.neighbors_of(1), vec![0, 2]);
        assert_eq!(g.neighbors_of(2), vec![1]);

        let core = g.core_ref();
        assert_eq!(core.n(), 3);
    }

    #[test]
    fn pdag_cycle_error() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cdir).unwrap();
        b.add_edge(2, 0, cdir).unwrap();
        let core = std::sync::Arc::new(b.finalize().unwrap());
        let r = Pdag::new(core);
        assert!(r.is_err());
    }

    #[test]
    fn pdag_an_de_directed_only() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();
        let cund = reg.code_of("---").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cund).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(g.ancestors_of(1), vec![0]);
        assert_eq!(g.descendants_of(0), vec![1]);
        assert!(g.ancestors_of(2).is_empty());
        assert!(g.descendants_of(2).is_empty());
    }

    #[test]
    fn pdag_mb() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let u = r.code_of("---").unwrap();
        let mut b = GraphBuilder::new_with_registry(4, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, u).unwrap();
        b.add_edge(3, 1, d).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(g.markov_blanket_of(1), vec![0, 2, 3]);
        assert_eq!(g.markov_blanket_of(0), vec![1, 3]);
    }

    #[test]
    fn pdag_partial_edge_error() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cpar = reg.code_of("o->").unwrap();
        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, cpar).unwrap();
        let core = std::sync::Arc::new(b.finalize().unwrap());
        let r = Pdag::new(core);
        assert!(r.is_err());
    }

    #[test]
    fn pdag_exogenous() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let u = r.code_of("---").unwrap();
        let mut b = GraphBuilder::new_with_registry(4, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, u).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(g.exogenous_nodes(false), vec![0, 2, 3]);
        assert_eq!(g.exogenous_nodes(true), vec![0, 3]);
    }
}
