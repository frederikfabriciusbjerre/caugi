// SPDX-License-Identifier: MIT
//! Pag (Partial Ancestral Graph) wrapper with O(1) slice queries via packed neighborhoods.

use super::CaugiGraph;
use crate::edges::EdgeClass;
use crate::graph::alg::directed_part_is_acyclic;
use std::sync::Arc;

#[derive(Debug, Clone)]
pub struct Pag {
    core: Arc<CaugiGraph>,
    /// len = n+1
    node_edge_ranges: Arc<[usize]>,
    /// len = n; (parents, undirected, children, bidirected, partial, partial_directed, partial_undirected)
    node_deg: Arc<[(u32, u32, u32, u32, u32, u32, u32)]>,
    /// packed as [parents | undirected | children | bidirected | partial | partial_directed | partial_undirected]
    neighborhoods: Arc<[u32]>,
}

impl Pag {
    pub fn new(core: Arc<CaugiGraph>) -> Result<Self, String> {
        let n = core.n() as usize;
        if !directed_part_is_acyclic(&core) {
            return Err("PAG contains a directed cycle".into());
        }
        let mut deg: Vec<(u32, u32, u32, u32, u32, u32, u32)> = vec![(0, 0, 0, 0, 0, 0, 0); n];
        for i in 0..n {
            let r = core.row_range(i as u32);
            for k in r.clone() {
                let spec = &core.registry.specs[core.etype[k] as usize];
                match spec.class {
                    EdgeClass::Directed => {
                        if core.side[k] == 1 {
                            deg[i].0 += 1 // parents
                        } else {
                            deg[i].2 += 1 // children
                        }
                    }
                    EdgeClass::Undirected => deg[i].1 += 1,
                    EdgeClass::Bidirected => deg[i].3 += 1,
                    EdgeClass::Partial => deg[i].4 += 1,
                    EdgeClass::PartiallyDirected => deg[i].5 += 1,
                    EdgeClass::PartiallyUndirected => deg[i].6 += 1,
                }
            }
        }
        let mut node_edge_ranges = Vec::with_capacity(n + 1);
        node_edge_ranges.push(0usize);
        for i in 0..n {
            let (pa, u, ch, bi, part, part_dir, part_und) = deg[i];
            let last = *node_edge_ranges.last().unwrap();
            node_edge_ranges.push(last + (pa + u + ch + bi + part + part_dir + part_und) as usize);
        }
        let total = *node_edge_ranges.last().unwrap();
        let mut neigh = vec![0u32; total];

        // bucket bases
        let mut parent_base: Vec<usize> = vec![0; n];
        let mut und_base: Vec<usize> = vec![0; n];
        let mut child_base: Vec<usize> = vec![0; n];
        let mut bi_base: Vec<usize> = vec![0; n];
        let mut part_base: Vec<usize> = vec![0; n];
        let mut part_dir_base: Vec<usize> = vec![0; n];
        let mut part_und_base: Vec<usize> = vec![0; n];
        
        for i in 0..n {
            let start = node_edge_ranges[i];
            let (pa, u, ch, bi, part, part_dir, _part_und) = deg[i];
            parent_base[i] = start;
            und_base[i] = start + pa as usize;
            child_base[i] = und_base[i] + u as usize;
            bi_base[i] = child_base[i] + ch as usize;
            part_base[i] = bi_base[i] + bi as usize;
            part_dir_base[i] = part_base[i] + part as usize;
            part_und_base[i] = part_dir_base[i] + part_dir as usize;
        }
        let mut pcur = parent_base.clone();
        let mut ucur = und_base.clone();
        let mut ccur = child_base.clone();
        let mut bicur = bi_base.clone();
        let mut partcur = part_base.clone();
        let mut partdircur = part_dir_base.clone();
        let mut partundcur = part_und_base.clone();

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
                    EdgeClass::Undirected => {
                        let p = ucur[i];
                        neigh[p] = core.col_index[k];
                        ucur[i] += 1;
                    }
                    EdgeClass::Bidirected => {
                        let p = bicur[i];
                        neigh[p] = core.col_index[k];
                        bicur[i] += 1;
                    }
                    EdgeClass::Partial => {
                        let p = partcur[i];
                        neigh[p] = core.col_index[k];
                        partcur[i] += 1;
                    }
                    EdgeClass::PartiallyDirected => {
                        let p = partdircur[i];
                        neigh[p] = core.col_index[k];
                        partdircur[i] += 1;
                    }
                    EdgeClass::PartiallyUndirected => {
                        let p = partundcur[i];
                        neigh[p] = core.col_index[k];
                        partundcur[i] += 1;
                    }
                }
            }
            // determinism: sort each segment
            let s = node_edge_ranges[i];
            let pm = und_base[i];
            let um = child_base[i];
            let cm = bi_base[i];
            let bim = part_base[i];
            let partm = part_dir_base[i];
            let partdirm = part_und_base[i];
            let e = node_edge_ranges[i + 1];
            neigh[s..pm].sort_unstable();
            neigh[pm..um].sort_unstable();
            neigh[um..cm].sort_unstable();
            neigh[cm..bim].sort_unstable();
            neigh[bim..partm].sort_unstable();
            neigh[partm..partdirm].sort_unstable();
            neigh[partdirm..e].sort_unstable();
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
    fn bounds(&self, i: u32) -> (usize, usize, usize, usize, usize, usize, usize, usize) {
        let i = i as usize;
        let s = self.node_edge_ranges[i];
        let e = self.node_edge_ranges[i + 1];
        let (pa, u, ch, bi, part, part_dir, part_und) = self.node_deg[i];
        let pm = s + pa as usize;
        let um = pm + u as usize;
        let cm = um + ch as usize;
        let bim = cm + bi as usize;
        let partm = bim + part as usize;
        let partdirm = partm + part_dir as usize;
        let partundm = partdirm + part_und as usize;
        debug_assert_eq!(partundm, e);
        (s, pm, um, cm, bim, partm, partdirm, e)
    }

    #[inline]
    pub fn parents_of(&self, i: u32) -> &[u32] {
        let (s, pm, _, _, _, _, _, _) = self.bounds(i);
        &self.neighborhoods[s..pm]
    }
    
    #[inline]
    pub fn children_of(&self, i: u32) -> &[u32] {
        let (_, _, um, cm, _, _, _, _) = self.bounds(i);
        &self.neighborhoods[um..cm]
    }
    
    #[inline]
    pub fn undirected_of(&self, i: u32) -> &[u32] {
        let (_, pm, um, _, _, _, _, _) = self.bounds(i);
        &self.neighborhoods[pm..um]
    }
    
    #[inline]
    pub fn bidirected_of(&self, i: u32) -> &[u32] {
        let (_, _, _, cm, bim, _, _, _) = self.bounds(i);
        &self.neighborhoods[cm..bim]
    }
    
    #[inline]
    pub fn partial_of(&self, i: u32) -> &[u32] {
        let (_, _, _, _, bim, partm, _, _) = self.bounds(i);
        &self.neighborhoods[bim..partm]
    }
    
    #[inline]
    pub fn partially_directed_of(&self, i: u32) -> &[u32] {
        let (_, _, _, _, _, partm, partdirm, _) = self.bounds(i);
        &self.neighborhoods[partm..partdirm]
    }
    
    #[inline]
    pub fn partially_undirected_of(&self, i: u32) -> &[u32] {
        let (_, _, _, _, _, _, partdirm, e) = self.bounds(i);
        &self.neighborhoods[partdirm..e]
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
        // Add directed neighbors
        mb.extend_from_slice(self.parents_of(i));
        mb.extend_from_slice(self.children_of(i));
        for &c in self.children_of(i) {
            for &p in self.parents_of(c) {
                if p != i {
                    mb.push(p);
                }
            }
        }
        // Add undirected neighbors
        mb.extend_from_slice(self.undirected_of(i));
        // Add bidirected neighbors (latent confounders)
        mb.extend_from_slice(self.bidirected_of(i));
        // Add partial edge neighbors
        mb.extend_from_slice(self.partial_of(i));
        mb.extend_from_slice(self.partially_directed_of(i));
        mb.extend_from_slice(self.partially_undirected_of(i));
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
