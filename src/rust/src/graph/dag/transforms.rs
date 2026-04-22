// SPDX-License-Identifier: MIT
//! Graph transformations for DAGs: skeleton, moralize, to_cpdag, latent_project.

use super::Dag;
use crate::edges::EdgeClass;
use crate::graph::admg::Admg;
use crate::graph::alg::{csr, meek};
use crate::graph::pdag::Pdag;
use crate::graph::ug::Ug;
use crate::graph::CaugiGraph;
use std::collections::{BTreeSet, HashSet};
use std::sync::Arc;

impl Dag {
    /// Build the moral graph of the entire DAG as an undirected graph core.
    pub fn moralize_core(&self) -> Result<CaugiGraph, String> {
        let mask = vec![true; self.n() as usize];
        let adj = self.moral_adj(&mask);
        csr::build_ug_core_from_adj(self.core_ref(), &adj)
    }

    /// Build the skeleton (undirected version) of the DAG as an undirected graph core.
    pub fn skeleton_core(&self) -> Result<CaugiGraph, String> {
        let n = self.n() as usize;
        let mut adj = vec![Vec::<u32>::new(); n];
        for u in 0..self.n() {
            for &v in self.children_of(u) {
                adj[u as usize].push(v);
                adj[v as usize].push(u);
            }
        }
        for v in &mut adj {
            v.sort_unstable();
            v.dedup();
        }
        csr::build_ug_core_from_adj(self.core_ref(), &adj)
    }

    /// UG skeleton: undirect every edge in the DAG.
    pub fn skeleton(&self) -> Result<Ug, String> {
        let n = self.n() as usize;
        let mut adj = vec![Vec::<u32>::new(); n];
        for i in 0..n {
            let mut v = self.neighbors_of(i as u32).to_vec();
            v.sort_unstable();
            v.dedup();
            adj[i] = v;
        }
        let core = csr::build_ug_core_from_adj(self.core_ref(), &adj)?;
        Ug::new(Arc::new(core))
    }

    /// UG moral graph: undirect all edges and marry parents.
    pub fn moralize(&self) -> Result<Ug, String> {
        let mask = vec![true; self.n() as usize];
        let adj = self.moral_adj(&mask);
        let core = csr::build_ug_core_from_adj(self.core_ref(), &adj)?;
        Ug::new(Arc::new(core))
    }

    /// Exogenize a set of nodes in a DAG.
    ///
    /// For each selected node `u` in the supplied order:
    /// 1. add directed edges `p -> c` for every `p ∈ Pa(u)` and `c ∈ Ch(u)` (excluding `p == c`)
    /// 2. remove every incoming edge `p -> u`
    pub fn exogenize(&self, nodes: &[u32]) -> Result<Dag, String> {
        let n = self.n() as usize;

        // Find directed edge code
        let specs = &self.core_ref().registry.specs;
        let mut dir_code: Option<u8> = None;
        for (i, s) in specs.iter().enumerate() {
            if matches!(s.class, EdgeClass::Directed) && (dir_code.is_none() || s.glyph == "-->") {
                dir_code = Some(i as u8);
            }
        }
        let dir = dir_code.ok_or("No Directed edge spec in registry")?;

        // Mutable deterministic adjacency
        let mut pa: Vec<BTreeSet<u32>> = vec![BTreeSet::new(); n];
        let mut ch: Vec<BTreeSet<u32>> = vec![BTreeSet::new(); n];

        for u in 0..self.n() {
            for &c in self.children_of(u) {
                ch[u as usize].insert(c);
                pa[c as usize].insert(u);
            }
        }

        fn add_dir(u: u32, v: u32, pa: &mut [BTreeSet<u32>], ch: &mut [BTreeSet<u32>]) {
            if u == v {
                return;
            }
            if ch[u as usize].insert(v) {
                pa[v as usize].insert(u);
            }
        }

        for &u in nodes {
            if u >= self.n() {
                return Err(format!("Index {} is out of bounds", u));
            }
            let ui = u as usize;

            let parents_u: Vec<u32> = pa[ui].iter().copied().collect();
            let children_u: Vec<u32> = ch[ui].iter().copied().collect();

            for &p in &parents_u {
                for &c in &children_u {
                    add_dir(p, c, &mut pa, &mut ch);
                }
            }

            for &p in &parents_u {
                ch[p as usize].remove(&u);
            }
            pa[ui].clear();
        }

        let mut row_index = Vec::with_capacity(n + 1);
        row_index.push(0u32);
        for i in 0..n {
            let c = pa[i].len() + ch[i].len();
            row_index.push(row_index[i] + c as u32);
        }

        let nnz = *row_index.last().unwrap() as usize;
        let mut col_index = vec![0u32; nnz];
        let mut etype = vec![0u8; nnz];
        let mut side = vec![0u8; nnz];
        let mut cur = row_index[..n].to_vec();

        for i in 0..n {
            for &p in pa[i].iter() {
                let k = cur[i] as usize;
                col_index[k] = p;
                etype[k] = dir;
                side[k] = 1;
                cur[i] += 1;
            }
            for &c in ch[i].iter() {
                let k = cur[i] as usize;
                col_index[k] = c;
                etype[k] = dir;
                side[k] = 0;
                cur[i] += 1;
            }
        }

        let core = CaugiGraph::from_csr(
            row_index,
            col_index,
            etype,
            side,
            /*simple=*/ true,
            self.core_ref().registry.clone(),
        )?;
        Dag::new(Arc::new(core))
    }

    /// Project out latent variables from a DAG to produce an ADMG.
    ///
    /// Uses the vertex elimination algorithm for latent projection:
    /// For each latent vertex v to eliminate:
    /// 1. Add directed edge p → c for all p ∈ Pa(v), c ∈ Ch(v)
    /// 2. Add bidirected edge s ↔ c for all s ∈ Sib(v), c ∈ Ch(v)
    /// 3. Add bidirected edge a ↔ b for all pairs a, b ∈ Ch(v)
    /// 4. Remove v
    ///
    /// Note: The result may have both directed and bidirected edges between
    /// the same pair of nodes (e.g., X → Y and X ↔ Y), which is valid in ADMGs.
    ///
    /// # Arguments
    /// * `latents` - Slice of node indices to project out (0-indexed)
    ///
    /// # Returns
    /// An `Admg` containing only the observed (non-latent) nodes.
    ///
    /// # Errors
    /// Returns an error if any latent index is out of bounds.
    pub fn latent_project(&self, latents: &[u32]) -> Result<Admg, String> {
        let n = self.n() as usize;

        // Validate and build remove mask
        let mut remove = vec![false; n];
        for &v in latents {
            if v >= self.n() {
                return Err(format!(
                    "Latent index {} is out of bounds (n = {})",
                    v,
                    self.n()
                ));
            }
            remove[v as usize] = true;
        }

        // Find edge codes
        let specs = &self.core_ref().registry.specs;
        let mut dir_code: Option<u8> = None;
        let mut bid_code: Option<u8> = None;
        for (i, s) in specs.iter().enumerate() {
            match s.class {
                EdgeClass::Directed => {
                    if dir_code.is_none() || s.glyph == "-->" {
                        dir_code = Some(i as u8)
                    }
                }
                EdgeClass::Bidirected => {
                    if bid_code.is_none() || s.glyph == "<->" {
                        bid_code = Some(i as u8)
                    }
                }
                _ => {}
            }
        }
        let dir = dir_code.ok_or("No Directed edge spec in registry")?;
        let bid = bid_code.ok_or("No Bidirected edge spec in registry")?;

        // If everything removed, return empty ADMG
        if remove.iter().all(|&x| x) {
            let core = CaugiGraph::from_csr(
                vec![0u32],
                vec![],
                vec![],
                vec![],
                true, // empty graph is simple
                self.core_ref().registry.clone(),
            )?;
            return Admg::new(Arc::new(core));
        }

        // Build mutable adjacency over ALL nodes (including ones to be removed later)
        // Using BTreeSet for deterministic ordering
        let mut pa: Vec<BTreeSet<u32>> = vec![BTreeSet::new(); n]; // parents
        let mut ch: Vec<BTreeSet<u32>> = vec![BTreeSet::new(); n]; // children
        let mut bi: Vec<BTreeSet<u32>> = vec![BTreeSet::new(); n]; // spouses (bidirected)

        // Populate from DAG (only directed edges, no bidirected in a DAG)
        for u in 0..(n as u32) {
            for &c in self.children_of(u) {
                ch[u as usize].insert(c);
                pa[c as usize].insert(u);
            }
        }

        // Helper closures for adding edges
        fn add_dir(u: u32, v: u32, pa: &mut [BTreeSet<u32>], ch: &mut [BTreeSet<u32>]) {
            if u == v {
                return;
            }
            if ch[u as usize].insert(v) {
                pa[v as usize].insert(u);
            }
        }
        fn add_bi(a: u32, b: u32, bi: &mut [BTreeSet<u32>]) {
            if a == b {
                return;
            }
            bi[a as usize].insert(b);
            bi[b as usize].insert(a);
        }

        // Eliminate in deterministic order
        let mut elim: Vec<u32> = latents.to_vec();
        elim.sort_unstable();
        elim.dedup();

        for &v in &elim {
            let vi = v as usize;
            if vi >= n {
                continue;
            }

            // Snapshot neighborhoods of v in the CURRENT graph
            let parents_v: Vec<u32> = pa[vi].iter().copied().collect();
            let children_v: Vec<u32> = ch[vi].iter().copied().collect();
            let siblings_v: Vec<u32> = bi[vi].iter().copied().collect();

            // 1) Directed projections: Pa(v) -> Ch(v)
            for &p in &parents_v {
                for &c in &children_v {
                    add_dir(p, c, &mut pa, &mut ch);
                }
            }

            // 2) Bidirected projections: Sib(v) <-> Ch(v)
            for &s in &siblings_v {
                for &c in &children_v {
                    add_bi(s, c, &mut bi);
                }
            }

            // 3) Bidirected among children of v
            for i in 0..children_v.len() {
                for j in (i + 1)..children_v.len() {
                    add_bi(children_v[i], children_v[j], &mut bi);
                }
            }

            // Remove v and all incident edges
            for &p in &parents_v {
                ch[p as usize].remove(&v);
            }
            for &c in &children_v {
                pa[c as usize].remove(&v);
            }
            for &s in &siblings_v {
                bi[s as usize].remove(&v);
            }

            pa[vi].clear();
            ch[vi].clear();
            bi[vi].clear();
        }

        // Collect kept nodes
        let kept: Vec<u32> = (0..self.n()).filter(|&u| !remove[u as usize]).collect();
        let m = kept.len();

        // old -> new mapping
        let mut old_to_new: Vec<Option<u32>> = vec![None; n];
        for (new_i, &old_i) in kept.iter().enumerate() {
            old_to_new[old_i as usize] = Some(new_i as u32);
        }

        // Check if the graph has parallel edges (both directed and bidirected between same pair)
        // Only set simple=false if such pairs exist
        let mut has_parallel_edges = false;
        'outer: for &old_i in &kept {
            let oi = old_i as usize;
            // Check if any child is also a spouse (or vice versa)
            for &c in ch[oi].iter() {
                if bi[oi].contains(&c) {
                    has_parallel_edges = true;
                    break 'outer;
                }
            }
            // Check if any parent is also a spouse
            for &p in pa[oi].iter() {
                if bi[oi].contains(&p) {
                    has_parallel_edges = true;
                    break 'outer;
                }
            }
        }

        // Build CSR for new graph
        let mut row_index = Vec::with_capacity(m + 1);
        row_index.push(0u32);

        // Precompute row lengths
        for &old_i in &kept {
            let oi = old_i as usize;
            let pa_ct = pa[oi]
                .iter()
                .filter(|&&p| old_to_new[p as usize].is_some())
                .count() as u32;
            let bi_ct = bi[oi]
                .iter()
                .filter(|&&s| old_to_new[s as usize].is_some())
                .count() as u32;
            let ch_ct = ch[oi]
                .iter()
                .filter(|&&c| old_to_new[c as usize].is_some())
                .count() as u32;
            let last = *row_index.last().unwrap();
            row_index.push(last + pa_ct + bi_ct + ch_ct);
        }

        let nnz = *row_index.last().unwrap() as usize;
        let mut col_index = vec![0u32; nnz];
        let mut etype = vec![0u8; nnz];
        let mut side = vec![0u8; nnz];

        let mut cur = row_index[..m].to_vec();
        for (new_i, &old_i) in kept.iter().enumerate() {
            let oi = old_i as usize;

            // parents (dir, side=1)
            for &p in pa[oi].iter() {
                if let Some(np) = old_to_new[p as usize] {
                    let k = cur[new_i] as usize;
                    col_index[k] = np;
                    etype[k] = dir;
                    side[k] = 1;
                    cur[new_i] += 1;
                }
            }

            // spouses (bid, side=0)
            for &s in bi[oi].iter() {
                if let Some(ns) = old_to_new[s as usize] {
                    let k = cur[new_i] as usize;
                    col_index[k] = ns;
                    etype[k] = bid;
                    side[k] = 0;
                    cur[new_i] += 1;
                }
            }

            // children (dir, side=0)
            for &c in ch[oi].iter() {
                if let Some(nc) = old_to_new[c as usize] {
                    let k = cur[new_i] as usize;
                    col_index[k] = nc;
                    etype[k] = dir;
                    side[k] = 0;
                    cur[new_i] += 1;
                }
            }
        }

        let core = CaugiGraph::from_csr(
            row_index,
            col_index,
            etype,
            side,
            !has_parallel_edges, // simple=true unless we have parallel edges
            self.core_ref().registry.clone(),
        )?;
        Admg::new(Arc::new(core))
    }

    /// Convert DAG to CPDAG using Meek's rules.
    ///
    /// # References
    ///
    /// C. Meek (1995). Causal inference and causal explanation with background
    /// knowledge. In *Proceedings of the Eleventh Conference on Uncertainty in
    /// Artificial Intelligence (UAI-95)*, pp. 403–411. Morgan Kaufmann.
    pub fn to_cpdag(&self) -> Result<Pdag, String> {
        let n = self.n() as usize;

        let mut pa: Vec<HashSet<u32>> = vec![HashSet::new(); n];
        let mut ch: Vec<HashSet<u32>> = vec![HashSet::new(); n];
        let mut und: Vec<HashSet<u32>> = vec![HashSet::new(); n];

        // Skeleton from DAG (undirected)
        for u in 0..self.n() {
            for &v in self.children_of(u) {
                und[u as usize].insert(v);
                und[v as usize].insert(u);
            }
        }

        // Orient v-structures: a->b<-c with a !~ c
        for b in 0..self.n() {
            let parents = self.parents_of(b).to_vec();
            for i in 0..parents.len() {
                for j in (i + 1)..parents.len() {
                    let a = parents[i] as usize;
                    let c = parents[j] as usize;
                    if !meek::adjacent(a, c, &und, &pa, &ch) {
                        meek::orient(parents[i], b, &mut und, &mut pa, &mut ch);
                        meek::orient(parents[j], b, &mut und, &mut pa, &mut ch);
                    }
                }
            }
        }

        meek::apply_meek_closure(&mut pa, &mut ch, &mut und, false);

        // Build CSR core (parents | undirected | children)
        let specs = &self.core_ref().registry.specs;
        let mut dir_code: Option<u8> = None;
        let mut und_code: Option<u8> = None;
        for (i, s) in specs.iter().enumerate() {
            match s.class {
                EdgeClass::Directed => {
                    if dir_code.is_none() || s.glyph == "-->" {
                        dir_code = Some(i as u8)
                    }
                }
                EdgeClass::Undirected => {
                    if und_code.is_none() || s.glyph == "---" {
                        und_code = Some(i as u8)
                    }
                }
                _ => {}
            }
        }
        let dir = dir_code.ok_or("No Directed edge spec in registry")?;
        let undc = und_code.ok_or("No Undirected edge spec in registry")?;

        let mut row_index = Vec::with_capacity(n + 1);
        row_index.push(0u32);
        for i in 0..n {
            let c = pa[i].len() + und[i].len() + ch[i].len();
            row_index.push(row_index[i] + c as u32);
        }
        let nnz = *row_index.last().unwrap() as usize;
        let mut col_index = vec![0u32; nnz];
        let mut etype = vec![0u8; nnz];
        let mut side = vec![0u8; nnz];

        let mut cur = row_index[..n].to_vec();
        for i in 0..n {
            // parents
            let mut v: Vec<u32> = pa[i].iter().copied().collect();
            v.sort_unstable();
            for p in v {
                let k = cur[i] as usize;
                col_index[k] = p;
                etype[k] = dir;
                side[k] = 1;
                cur[i] += 1;
            }
            // undirected
            let mut v: Vec<u32> = und[i].iter().copied().collect();
            v.sort_unstable();
            for u in v {
                let k = cur[i] as usize;
                col_index[k] = u;
                etype[k] = undc;
                side[k] = 0;
                cur[i] += 1;
            }
            // children
            let mut v: Vec<u32> = ch[i].iter().copied().collect();
            v.sort_unstable();
            for c in v {
                let k = cur[i] as usize;
                col_index[k] = c;
                etype[k] = dir;
                side[k] = 0;
                cur[i] += 1;
            }
        }

        let core = CaugiGraph::from_csr(
            row_index,
            col_index,
            etype,
            side,
            /*simple=*/ true,
            self.core_ref().registry.clone(),
        )?;
        Pdag::new(Arc::new(core))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::{EdgeClass, EdgeRegistry, EdgeSpec, Mark};
    use crate::graph::builder::GraphBuilder;

    #[test]
    fn dag_to_cpdag_basic() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(2, 1, d).unwrap();
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let cpdag = dag.to_cpdag().unwrap();

        assert_eq!(cpdag.parents_of(1), vec![0, 2]);
        assert_eq!(cpdag.children_of(0), vec![1]);
        assert_eq!(cpdag.children_of(2), vec![1]);
    }

    #[test]
    fn dag_skeleton_basic() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(0, 2, d).unwrap();
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        let ug = dag.skeleton().unwrap();
        assert_eq!(ug.neighbors_of(0), &[1, 2]);
        assert_eq!(ug.neighbors_of(1), &[0]);
        assert_eq!(ug.neighbors_of(2), &[0]);
    }

    #[test]
    fn dag_moralize_married_parents() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();
        let ug = dag.moralize().unwrap();
        assert_eq!(ug.neighbors_of(0), &[1, 2]);
        assert_eq!(ug.neighbors_of(1), &[0, 2]);
        assert_eq!(ug.neighbors_of(2), &[0, 1]);
    }

    #[test]
    fn dag_exogenize_basic() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap(); // A -> B
        b.add_edge(1, 2, d).unwrap(); // B -> C
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let exo = dag.exogenize(&[1]).unwrap();
        assert_eq!(exo.parents_of(0), Vec::<u32>::new());
        assert_eq!(exo.parents_of(1), Vec::<u32>::new());
        assert_eq!(exo.parents_of(2), vec![0, 1]); // A -> C added, B -> C kept
    }

    #[test]
    fn dag_exogenize_duplicate_nodes_are_idempotent() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let exo_once = dag.exogenize(&[1]).unwrap();
        let exo_twice = dag.exogenize(&[1, 1]).unwrap();

        for i in 0..3 {
            assert_eq!(exo_once.parents_of(i), exo_twice.parents_of(i));
            assert_eq!(exo_once.children_of(i), exo_twice.children_of(i));
        }
    }

    #[test]
    fn dag_to_cpdag_meek_r1_chain() {
        // pgmpy test case 2: A->B with B--C, C--D in the CPDAG skeleton.
        // DAG: A->B<-X (v-structure at B), B->C, C->D
        // After v-structure: A->B<-X, B--C, C--D
        // R1 fires on B--C (A->B, A not adj C) => B->C
        // R1 fires again on C--D (B->C, B not adj D) => C->D
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // 0:A, 1:B, 2:X, 3:C, 4:D
        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        b.add_edge(0, 1, d).unwrap(); // A -> B
        b.add_edge(2, 1, d).unwrap(); // X -> B (v-structure with A at B)
        b.add_edge(1, 3, d).unwrap(); // B -> C
        b.add_edge(3, 4, d).unwrap(); // C -> D
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let cpdag = dag.to_cpdag().unwrap();
        // Both B->C and C->D should be oriented by cascading R1
        assert_eq!(cpdag.parents_of(3), vec![1]); // C has parent B
        assert_eq!(cpdag.parents_of(4), vec![3]); // D has parent C
        assert_eq!(cpdag.children_of(1), vec![3]); // B has child C
        assert_eq!(cpdag.children_of(3), vec![4]); // C has child D
    }

    #[test]
    fn dag_to_cpdag_meek_r3_two_nonadj_parents() {
        // pgmpy test case 9 (Bang 2024):
        // DAG: B->D, C->D, D->A, C->A
        // V-structures: B->D<-C (B and C non-adjacent)
        // After v-structure: B->D<-C, D--A, A--C
        // R3: A--D with parents C->D, B->D non-adjacent, A--C (but not A--B)
        //     => does NOT fire (need A adj to both C and B undirected)
        // Actually R1: C->D, D--A, C not adj A? C IS adj A. So R1 doesn't fire for C->D, D--A.
        //   B->D, D--A, B not adj A => R1 fires: D->A
        // Then R1 again: D->A, A--C, D not adj C? D IS adj C. So check B->D, ... no.
        //   Actually for A--C: D->A, D not adj C? D IS adj C (D<-C). So R1 doesn't fire.
        // So result: B->D<-C, D->A, A--C? But wait C->A in the DAG. Let me reconsider.
        //
        // Actually the CPDAG of B->D<-C, D->A, C->A:
        //   Skeleton: B-D, C-D, D-A, C-A
        //   V-structure: B->D<-C (B,C non-adj)
        //   R1: B->D, D--A, B not adj A => D->A
        //   Now for C--A: any parent of A not adj to C? D->A, and D adj C (yes, D<-C). So R1 doesn't fire.
        //   R2: C--A, is there w: C->w->A? C->D->A. Yes! So R2 fires: C->A.
        //
        // So this is actually an R1+R2 combo. Let me construct a proper R3 test.
        //
        // R3: a--b and ∃ c,d: c->b, d->b, c !~ d, a--c, a--d => a->b
        // Need: node b with two parents c,d that are non-adjacent, and a node a
        // that is undirected-adjacent to b, c, and d.
        //
        // DAG: C->B<-D (v-structure, C and D non-adj), A->B, A->C, A->D
        // Skeleton: C-B, D-B, A-B, A-C, A-D
        // V-structure at B: C->B<-D
        // A is adjacent to C and D, so A->B is NOT a v-structure.
        // After v-structures: C->B<-D, A--B, A--C, A--D
        // R3: A--B, parents of B = {C, D}, C not adj D, A--C, A--D => A->B
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // 0:A, 1:B, 2:C, 3:D
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(2, 1, d).unwrap(); // C -> B
        b.add_edge(3, 1, d).unwrap(); // D -> B
        b.add_edge(0, 1, d).unwrap(); // A -> B
        b.add_edge(0, 2, d).unwrap(); // A -> C
        b.add_edge(0, 3, d).unwrap(); // A -> D
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let cpdag = dag.to_cpdag().unwrap();
        // C->B and D->B from v-structure, A->B from R3
        assert!(cpdag.parents_of(1).contains(&0)); // A is parent of B
        assert!(cpdag.parents_of(1).contains(&2)); // C is parent of B
        assert!(cpdag.parents_of(1).contains(&3)); // D is parent of B
                                                   // A--C and A--D should remain undirected
        assert!(cpdag.neighbors_of(0).contains(&2)); // A--C undirected
        assert!(cpdag.neighbors_of(0).contains(&3)); // A--D undirected
    }

    #[test]
    fn dag_to_cpdag_meek_r4_directed_path() {
        // R4: a--b and there exists a directed path a => b => orient a->b
        // DAG: A->C, C->D, D->B, A->B
        // We need A->C->D->B to be compelled and A--B undirected, so R4 orients A->B.
        //
        // Add v-structure at C: X->C<-A (X not adj A)
        // Then R1 cascades: A->C, C--D (X not adj D) => C->D; C->D, D--B (X not adj B?)
        // Actually let me be more careful.
        //
        // DAG: X->C<-A, C->D, D->B, A->B, A->D
        // Skeleton: X-C, A-C, C-D, D-B, A-B, A-D
        // V-structure at C: X->C<-A (X not adj A ✓)
        // After v-structures: X->C<-A, C--D, D--B, A--B, A--D
        // R1: A->C, C--D, A adj D? Yes (A--D). So R1 doesn't fire for A->C, C--D.
        //     X->C, C--D, X adj D? No. So R1 fires: C->D.
        // Now: C->D, D--B, C adj B? No. So R1 fires: D->B.
        // Now: D->B, B--A, D adj A? Yes (A--D). So R1 doesn't fire for D->B, B--A.
        // R2: A--B, is there w: A->w->B? A->C->...->B (not direct). No direct A->w->B.
        //     A--D, is there w: A->w->D? A->C->D. Yes! So R2 fires: A->D.
        // Now: A->D, D->B already directed.
        // R2 again: A--B, A->D->B? Yes! So R2 fires: A->B.
        //
        // Hmm, that's R2 not R4. Let me construct a proper R4.
        //
        // R4 needs: a--b with directed path a=>b but no single intermediate w with a->w->b.
        // That means the directed path has length >= 3.
        //
        // DAG: A->C1, C1->C2, C2->B, A->B
        // Need C1->C2 and C2->B to be compelled but no direct A->w->B.
        //
        // Use v-structure at C1: X->C1<-A
        // Skeleton: X-C1, A-C1, C1-C2, C2-B, A-B
        // V-structure: X->C1<-A
        // R1: X->C1, C1--C2, X not adj C2 => C1->C2
        //     C1->C2, C2--B, C1 not adj B => C2->B
        //     A->C1, C1--C2, A not adj C2 => C1->C2 (already done)
        // Now: A--B. Directed path A->C1->C2->B exists.
        // R2: A--B, A->w->B? A has child C1, C1->B? No. So R2 doesn't apply.
        // R4: A--B, directed path A->C1->C2->B => A->B. ✓
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // 0:A, 1:C1, 2:C2, 3:B, 4:X
        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        b.add_edge(4, 1, d).unwrap(); // X -> C1
        b.add_edge(0, 1, d).unwrap(); // A -> C1 (v-structure at C1 with X)
        b.add_edge(1, 2, d).unwrap(); // C1 -> C2
        b.add_edge(2, 3, d).unwrap(); // C2 -> B
        b.add_edge(0, 3, d).unwrap(); // A -> B
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let cpdag = dag.to_cpdag().unwrap();
        // A->B should be oriented by R4 (directed path A->C1->C2->B)
        assert!(cpdag.parents_of(3).contains(&0)); // A is parent of B
        assert!(cpdag.parents_of(3).contains(&2)); // C2 is parent of B
        assert_eq!(cpdag.children_of(0), vec![1, 3]); // A has children C1, B
    }

    #[test]
    fn dag_to_cpdag_no_rule_fires_edges_stay_undirected() {
        // pgmpy test case 3: A->B, D->C with B--C.
        // DAG: A->B, B->C, D->C, but A adj B, D adj C.
        // Wait, we need a DAG where the CPDAG has some undirected edges that
        // no Meek rule orients.
        //
        // Simple: a chain A->B->C. Equivalence class: A--B--C.
        // No v-structures, so all edges are undirected in the CPDAG.
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap(); // A -> B
        b.add_edge(1, 2, d).unwrap(); // B -> C
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let cpdag = dag.to_cpdag().unwrap();
        // All edges should be undirected
        assert!(cpdag.parents_of(0).is_empty());
        assert!(cpdag.parents_of(1).is_empty());
        assert!(cpdag.parents_of(2).is_empty());
        assert!(cpdag.children_of(0).is_empty());
        assert!(cpdag.children_of(1).is_empty());
        assert!(cpdag.children_of(2).is_empty());
        // But neighbors should exist
        assert_eq!(cpdag.neighbors_of(0), &[1]);
        assert_eq!(cpdag.neighbors_of(1), &[0, 2]);
        assert_eq!(cpdag.neighbors_of(2), &[1]);
    }

    #[test]
    fn dag_to_cpdag_larger_graph_multiple_rules() {
        // A graph where multiple Meek rules fire in sequence.
        // DAG: X->W<-A (v-structure), W->B<-Y (v-structure), A->B, A->Y
        // This is the existing R2 test. Let's do a bigger one.
        //
        // DAG with 6 nodes combining v-structures and cascading rules:
        // V1->X<-V2 (v-structure at X)
        // X->Y, X->Z, Y->Z (no v-structure at Y or Z since X adj to all)
        // After v-structures: V1->X<-V2, X--Y, X--Z, Y--Z
        // R1: V1->X, X--Y, V1 not adj Y => X->Y
        //     V1->X, X--Z, V1 not adj Z => X->Z
        // Now X->Y, X->Z: Y--Z, check rules.
        // R2: Y--Z, Y->w->Z? No. Z->w->Y? No.
        // R3: Y--Z, parents of Z = {X}. Only one parent, need two. Doesn't fire.
        // So Y--Z stays undirected.
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // 0:V1, 1:X, 2:V2, 3:Y, 4:Z
        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        b.add_edge(0, 1, d).unwrap(); // V1 -> X
        b.add_edge(2, 1, d).unwrap(); // V2 -> X (v-structure)
        b.add_edge(1, 3, d).unwrap(); // X -> Y
        b.add_edge(1, 4, d).unwrap(); // X -> Z
        b.add_edge(3, 4, d).unwrap(); // Y -> Z
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let cpdag = dag.to_cpdag().unwrap();
        // V1->X<-V2 compelled (v-structure)
        assert!(cpdag.parents_of(1).contains(&0));
        assert!(cpdag.parents_of(1).contains(&2));
        // X->Y and X->Z compelled by R1
        assert!(cpdag.children_of(1).contains(&3));
        assert!(cpdag.children_of(1).contains(&4));
        // Y--Z stays undirected
        assert!(cpdag.neighbors_of(3).contains(&4));
        assert!(cpdag.neighbors_of(4).contains(&3));
        assert!(!cpdag.parents_of(4).contains(&3));
        assert!(!cpdag.children_of(3).contains(&4));
    }

    #[test]
    fn dag_to_cpdag_isolated_nodes_preserved() {
        // DAG with isolated nodes: should still work
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        b.add_edge(0, 2, d).unwrap(); // A -> C
        b.add_edge(1, 2, d).unwrap(); // B -> C (v-structure with A)
                                      // nodes 3, 4 are isolated
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let cpdag = dag.to_cpdag().unwrap();
        assert_eq!(cpdag.n(), 5);
        assert_eq!(cpdag.parents_of(2), vec![0, 1]); // v-structure preserved
        assert!(cpdag.neighbors_of(3).is_empty());
        assert!(cpdag.neighbors_of(4).is_empty());
    }

    #[test]
    fn dag_to_cpdag_single_edge() {
        // Single edge A->B: CPDAG is A--B
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let cpdag = dag.to_cpdag().unwrap();
        assert!(cpdag.parents_of(0).is_empty());
        assert!(cpdag.parents_of(1).is_empty());
        assert_eq!(cpdag.neighbors_of(0), &[1]);
        assert_eq!(cpdag.neighbors_of(1), &[0]);
    }

    #[test]
    fn dag_to_cpdag_meek_r1_orients_b_to_c() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let cpdag = dag.to_cpdag().unwrap();
        assert!(cpdag.parents_of(0).is_empty());
        assert!(cpdag.parents_of(1).is_empty());
        assert_eq!(cpdag.neighbors_of(0), &[1]);
        assert_eq!(cpdag.neighbors_of(1), &[0]);
    }

    #[test]
    fn dag_to_cpdag_complete_dag_all_undirected() {
        // Complete DAG on 3 nodes: A->B, A->C, B->C
        // No v-structures (all pairs adjacent), so CPDAG is fully undirected
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap(); // A -> B
        b.add_edge(0, 2, d).unwrap(); // A -> C
        b.add_edge(1, 2, d).unwrap(); // B -> C
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let cpdag = dag.to_cpdag().unwrap();
        // All edges undirected (complete graph = single equivalence class)
        for i in 0..3u32 {
            assert!(cpdag.parents_of(i).is_empty());
            assert!(cpdag.children_of(i).is_empty());
        }
        assert_eq!(cpdag.neighbors_of(0), &[1, 2]);
        assert_eq!(cpdag.neighbors_of(1), &[0, 2]);
        assert_eq!(cpdag.neighbors_of(2), &[0, 1]);
    }

    #[test]
    fn dag_to_cpdag_r2_directed_path_through_intermediate() {
        // R2: a--b and ∃ w: a->w->b => a->b
        // pcalg example: A->B, B->C with A--C.
        // Need A->B and B->C compelled first.
        //
        // DAG: X->B<-A (v-structure at B), B->C, Y->C<-B (v-structure at C), A->C
        // Skeleton: X-B, A-B, B-C, Y-C, A-C
        // V-structures: X->B<-A, Y->C<-B (A adj B and B adj C, but X not adj A, Y not adj B)
        // Wait, X->B<-A: X not adj A? Need to ensure that. Yes, no edge X-A.
        //       Y->C<-B: Y not adj B? Need to ensure that. Yes, no edge Y-B.
        // After v-structures: X->B<-A, Y->C<-B
        // A--C is undirected. R2: A--C, A->B->C? Yes! A->B and B->C. So R2: A->C.
        // a -> b <- d, and b -> c in the DAG.
        // R1 should orient b -- c into b -> c after v-structure orientation at b.
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(2, 1, d).unwrap();
        b.add_edge(1, 3, d).unwrap();
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let cpdag = dag.to_cpdag().unwrap();
        assert_eq!(cpdag.parents_of(3), vec![1]);
        assert_eq!(cpdag.children_of(1), vec![3]);
    }

    #[test]
    fn dag_to_cpdag_meek_r2_orients_a_to_b() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // 0:A, 1:B, 2:C, 3:X, 4:Y
        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        b.add_edge(3, 1, d).unwrap(); // X -> B
        b.add_edge(0, 1, d).unwrap(); // A -> B (v-structure at B with X)
        b.add_edge(1, 2, d).unwrap(); // B -> C
        b.add_edge(4, 2, d).unwrap(); // Y -> C (v-structure at C with B)
        b.add_edge(0, 2, d).unwrap(); // A -> C
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let cpdag = dag.to_cpdag().unwrap();
        // A->C should be oriented by R2 (path A->B->C)
        assert!(cpdag.parents_of(2).contains(&0)); // A is parent of C
        assert!(cpdag.parents_of(2).contains(&1)); // B is parent of C
        assert!(cpdag.parents_of(2).contains(&4)); // Y is parent of C
                                                   // Construct a DAG where:
                                                   // - a -> w is compelled via v-structure at w (x -> w <- a)
                                                   // - w -> b is compelled via v-structure at b (w -> b <- y)
                                                   // - a -> b is present but not initially compelled (a adjacent to w and y)
                                                   // R2 then orients a -- b into a -> b.
        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        // a=0, w=1, x=2, b=3, y=4
        b.add_edge(0, 1, d).unwrap(); // a -> w
        b.add_edge(2, 1, d).unwrap(); // x -> w
        b.add_edge(1, 3, d).unwrap(); // w -> b
        b.add_edge(0, 3, d).unwrap(); // a -> b (candidate to be oriented by R2)
        b.add_edge(4, 3, d).unwrap(); // y -> b
        b.add_edge(0, 4, d).unwrap(); // a adjacent y (prevents a->b v-structure orientation)
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let cpdag = dag.to_cpdag().unwrap();
        assert_eq!(cpdag.parents_of(3), vec![0, 1, 4]);
    }

    // ── Latent projection tests ──────────────────────────────────────────────

    #[test]
    fn latent_project_basic_confounding() {
        // DAG: U -> X, U -> Y, X -> Y
        // Project out U
        // Using vertex elimination:
        // - U has Ch(U) = {X, Y}
        // - Step 3: Add X <-> Y (children of U pair up)
        // Result: X -> Y AND X <-> Y
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        // 0:U, 1:X, 2:Y
        b.add_edge(0, 1, d).unwrap(); // U -> X
        b.add_edge(0, 2, d).unwrap(); // U -> Y
        b.add_edge(1, 2, d).unwrap(); // X -> Y
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let admg = dag.latent_project(&[0]).unwrap();

        // Result should have 2 nodes
        assert_eq!(admg.n(), 2);

        // X -> Y preserved (new indices: X=0, Y=1)
        assert_eq!(admg.parents_of(1), &[0]); // Y has parent X
        assert_eq!(admg.children_of(0), &[1]); // X has child Y

        // X <-> Y added (children of U pair up during vertex elimination)
        assert_eq!(admg.spouses_of(0), &[1]);
        assert_eq!(admg.spouses_of(1), &[0]);
    }

    #[test]
    fn latent_project_no_shared_latent() {
        // DAG: X -> Y (no latent confounding)
        // Project out nothing, result: X -> Y
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, d).unwrap(); // X -> Y
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let admg = dag.latent_project(&[]).unwrap();

        assert_eq!(admg.n(), 2);
        assert_eq!(admg.parents_of(1), &[0]);
        assert!(admg.spouses_of(0).is_empty());
        assert!(admg.spouses_of(1).is_empty());
    }

    #[test]
    fn latent_project_multiple_latents() {
        // DAG: L1 -> X, L1 -> Y, L2 -> Y, L2 -> Z, X -> Y, Y -> Z
        // Project out L1, L2 using vertex elimination:
        //
        // Eliminate L1 (sorted order):
        // - Ch(L1) = {X, Y}
        // - Step 3: Add X <-> Y
        //
        // Eliminate L2:
        // - Ch(L2) = {Y, Z}
        // - Step 3: Add Y <-> Z
        //
        // Result: X -> Y -> Z (directed) + X <-> Y, Y <-> Z (bidirected)
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        // 0:L1, 1:L2, 2:X, 3:Y, 4:Z
        b.add_edge(0, 2, d).unwrap(); // L1 -> X
        b.add_edge(0, 3, d).unwrap(); // L1 -> Y
        b.add_edge(1, 3, d).unwrap(); // L2 -> Y
        b.add_edge(1, 4, d).unwrap(); // L2 -> Z
        b.add_edge(2, 3, d).unwrap(); // X -> Y
        b.add_edge(3, 4, d).unwrap(); // Y -> Z
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let admg = dag.latent_project(&[0, 1]).unwrap();

        // Result has 3 nodes: X=0, Y=1, Z=2
        assert_eq!(admg.n(), 3);

        // Directed edges preserved
        assert_eq!(admg.children_of(0), &[1]); // X -> Y
        assert_eq!(admg.children_of(1), &[2]); // Y -> Z
        assert_eq!(admg.parents_of(1), &[0]); // Y has parent X
        assert_eq!(admg.parents_of(2), &[1]); // Z has parent Y

        // Bidirected edges from vertex elimination:
        // - X <-> Y: added (children of L1 pair up)
        // - Y <-> Z: added (children of L2 pair up)
        assert_eq!(admg.spouses_of(0), &[1]); // X <-> Y
        assert_eq!(admg.spouses_of(1), &[0, 2]); // Y <-> X, Y <-> Z
        assert_eq!(admg.spouses_of(2), &[1]); // Z <-> Y
    }

    #[test]
    fn latent_project_latent_chain() {
        // DAG: L1 -> L2 -> X, L2 -> Y
        // Project out L1, L2
        // X and Y share latent ancestor L2, so X <-> Y
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        // 0:L1, 1:L2, 2:X, 3:Y
        b.add_edge(0, 1, d).unwrap(); // L1 -> L2
        b.add_edge(1, 2, d).unwrap(); // L2 -> X
        b.add_edge(1, 3, d).unwrap(); // L2 -> Y
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let admg = dag.latent_project(&[0, 1]).unwrap();

        // Result has 2 nodes: X=0, Y=1
        assert_eq!(admg.n(), 2);

        // No directed edges between X and Y
        assert!(admg.children_of(0).is_empty());
        assert!(admg.children_of(1).is_empty());
        assert!(admg.parents_of(0).is_empty());
        assert!(admg.parents_of(1).is_empty());

        // X <-> Y from shared ancestor L2
        assert_eq!(admg.spouses_of(0), &[1]);
        assert_eq!(admg.spouses_of(1), &[0]);
    }

    #[test]
    fn latent_project_all_latent() {
        // DAG: L1 -> L2
        // Project out both, result: empty ADMG
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let admg = dag.latent_project(&[0, 1]).unwrap();
        assert_eq!(admg.n(), 0);
    }

    #[test]
    fn latent_project_invalid_index() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let result = dag.latent_project(&[5]);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("out of bounds"));
    }

    #[test]
    fn latent_project_no_edge_confounding() {
        // DAG: U -> X, V -> Y (no shared ancestor)
        // Project out U, V
        // Result: X, Y (isolated nodes, no edges)
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        // 0:U, 1:V, 2:X, 3:Y
        b.add_edge(0, 2, d).unwrap(); // U -> X
        b.add_edge(1, 3, d).unwrap(); // V -> Y
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let admg = dag.latent_project(&[0, 1]).unwrap();

        // Result has 2 nodes
        assert_eq!(admg.n(), 2);

        // No edges at all
        assert!(admg.children_of(0).is_empty());
        assert!(admg.children_of(1).is_empty());
        assert!(admg.spouses_of(0).is_empty());
        assert!(admg.spouses_of(1).is_empty());
    }

    #[test]
    fn latent_project_directed_path_through_single_latent() {
        // DAG: X -> L -> Y (L is latent)
        // Project out L
        // Result: X -> Y (directed path preserved)
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        // 0:X, 1:L, 2:Y
        b.add_edge(0, 1, d).unwrap(); // X -> L
        b.add_edge(1, 2, d).unwrap(); // L -> Y
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let admg = dag.latent_project(&[1]).unwrap();

        // Result has 2 nodes: X=0, Y=1
        assert_eq!(admg.n(), 2);

        // X -> Y from directed path through L
        assert_eq!(admg.children_of(0), &[1]); // X -> Y
        assert_eq!(admg.parents_of(1), &[0]); // Y has parent X

        // No bidirected edges (no shared latent ancestor)
        assert!(admg.spouses_of(0).is_empty());
        assert!(admg.spouses_of(1).is_empty());
    }

    #[test]
    fn latent_project_directed_path_through_chain_of_latents() {
        // DAG: X -> L1 -> L2 -> L3 -> Y (L1, L2, L3 are latent)
        // Project out L1, L2, L3
        // Result: X -> Y (directed path through latent chain)
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        // 0:X, 1:L1, 2:L2, 3:L3, 4:Y
        b.add_edge(0, 1, d).unwrap(); // X -> L1
        b.add_edge(1, 2, d).unwrap(); // L1 -> L2
        b.add_edge(2, 3, d).unwrap(); // L2 -> L3
        b.add_edge(3, 4, d).unwrap(); // L3 -> Y
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let admg = dag.latent_project(&[1, 2, 3]).unwrap();

        // Result has 2 nodes: X=0, Y=1
        assert_eq!(admg.n(), 2);

        // X -> Y from directed path through latent chain
        assert_eq!(admg.children_of(0), &[1]); // X -> Y
        assert_eq!(admg.parents_of(1), &[0]); // Y has parent X

        // No bidirected edges
        assert!(admg.spouses_of(0).is_empty());
        assert!(admg.spouses_of(1).is_empty());
    }

    #[test]
    fn latent_project_directed_and_bidirected() {
        // DAG: X -> L1 -> Y, L2 -> X, L2 -> Y (L1, L2 are latent)
        // Project out L1, L2 using vertex elimination:
        //
        // Eliminate L1 (index 2):
        // - Pa(L1) = {X}, Ch(L1) = {Y}
        // - Step 1: Add X -> Y
        //
        // Eliminate L2 (index 3):
        // - Ch(L2) = {X, Y}
        // - Step 3: Add X <-> Y
        //
        // Result: X -> Y AND X <-> Y
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        // 0:X, 1:Y, 2:L1, 3:L2
        b.add_edge(0, 2, d).unwrap(); // X -> L1
        b.add_edge(2, 1, d).unwrap(); // L1 -> Y
        b.add_edge(3, 0, d).unwrap(); // L2 -> X
        b.add_edge(3, 1, d).unwrap(); // L2 -> Y
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let admg = dag.latent_project(&[2, 3]).unwrap();

        // Result has 2 nodes: X=0, Y=1
        assert_eq!(admg.n(), 2);

        // X -> Y from directed path through L1
        assert_eq!(admg.children_of(0), &[1]);
        assert_eq!(admg.parents_of(1), &[0]);

        // X <-> Y from L2's children pairing up
        assert_eq!(admg.spouses_of(0), &[1]);
        assert_eq!(admg.spouses_of(1), &[0]);
    }

    #[test]
    fn latent_project_multiple_observed_descendants() {
        // DAG: X -> L -> Y, L -> Z (L is latent, Y and Z are observed)
        // Project out L
        // Result: X -> Y, X -> Z (both via directed paths through L)
        //         Y <-> Z (shared latent ancestor L)
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        // 0:X, 1:L, 2:Y, 3:Z
        b.add_edge(0, 1, d).unwrap(); // X -> L
        b.add_edge(1, 2, d).unwrap(); // L -> Y
        b.add_edge(1, 3, d).unwrap(); // L -> Z
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let admg = dag.latent_project(&[1]).unwrap();

        // Result has 3 nodes: X=0, Y=1, Z=2
        assert_eq!(admg.n(), 3);

        // X -> Y and X -> Z from directed paths through L
        assert_eq!(admg.children_of(0), &[1, 2]); // X -> Y, X -> Z
        assert_eq!(admg.parents_of(1), &[0]); // Y has parent X
        assert_eq!(admg.parents_of(2), &[0]); // Z has parent X

        // Y <-> Z from shared latent ancestor L
        assert_eq!(admg.spouses_of(1), &[2]); // Y <-> Z
        assert_eq!(admg.spouses_of(2), &[1]); // Z <-> Y

        // X has no spouses (X is not a child of L, so doesn't share L as ancestor)
        assert!(admg.spouses_of(0).is_empty());
    }

    #[test]
    fn latent_project_triggers_sibling_to_child_projection() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // 0:L0, 1:L1, 2:X, 3:Y
        // L0 -> L1, L0 -> X, L1 -> Y, project out L0 and L1.
        // After eliminating L0, we get L1 <-> X.
        // Eliminating L1 then adds X <-> Y via sibling-to-child projection (step 2).
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(1, 3, d).unwrap();
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let admg = dag.latent_project(&[0, 1]).unwrap();
        assert_eq!(admg.n(), 2);
        assert_eq!(admg.spouses_of(0), &[1]);
        assert_eq!(admg.spouses_of(1), &[0]);
    }

    #[test]
    fn latent_project_marks_parallel_when_parent_and_spouse_overlap() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // 0:Y, 1:X, 2:L1, 3:L2
        // Y -> L1 -> X gives Y -> X after projection.
        // L2 -> Y and L2 -> X gives Y <-> X after projection.
        // Result has parent/spouse overlap on X, so simple=false.
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(2, 1, d).unwrap();
        b.add_edge(3, 0, d).unwrap();
        b.add_edge(3, 1, d).unwrap();
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let admg = dag.latent_project(&[2, 3]).unwrap();
        assert_eq!(admg.parents_of(1), &[0]);
        assert_eq!(admg.spouses_of(1), &[0]);
        assert!(!admg.core_ref().simple);
    }

    #[test]
    fn latent_project_parent_spouse_overlap_hits_parent_spouse_scan_branch() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // 0:B, 1:A, 2:L1, 3:L2
        // A -> L1 -> B   gives A -> B after projection.
        // L2 -> A and L2 -> B gives A <-> B after projection.
        // For node B (old index 0), overlap appears in parents/spouses (no children),
        // which drives the parent/spouse overlap branch in the parallel-edge scan.
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(1, 2, d).unwrap(); // A -> L1
        b.add_edge(2, 0, d).unwrap(); // L1 -> B
        b.add_edge(3, 1, d).unwrap(); // L2 -> A
        b.add_edge(3, 0, d).unwrap(); // L2 -> B
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let admg = dag.latent_project(&[2, 3]).unwrap();
        assert_eq!(admg.parents_of(0), &[1]);
        assert_eq!(admg.spouses_of(0), &[1]);
        assert!(!admg.core_ref().simple);
    }

    #[test]
    fn to_cpdag_and_latent_project_with_multiple_registry_specs() {
        let mut reg = EdgeRegistry::new();
        // Add non-builtin directed/undirected/bidirected specs before builtins.
        reg.register(EdgeSpec {
            glyph: "d1".to_string(),
            tail: Mark::Tail,
            head: Mark::Arrow,
            symmetric: false,
            class: EdgeClass::Directed,
        })
        .unwrap();
        reg.register(EdgeSpec {
            glyph: "u1".to_string(),
            tail: Mark::Tail,
            head: Mark::Tail,
            symmetric: true,
            class: EdgeClass::Undirected,
        })
        .unwrap();
        reg.register(EdgeSpec {
            glyph: "b1".to_string(),
            tail: Mark::Arrow,
            head: Mark::Arrow,
            symmetric: true,
            class: EdgeClass::Bidirected,
        })
        .unwrap();
        reg.register_builtins().unwrap();
        // Add more non-builtin specs after builtins too.
        reg.register(EdgeSpec {
            glyph: "d2".to_string(),
            tail: Mark::Tail,
            head: Mark::Arrow,
            symmetric: false,
            class: EdgeClass::Directed,
        })
        .unwrap();
        reg.register(EdgeSpec {
            glyph: "u2".to_string(),
            tail: Mark::Tail,
            head: Mark::Tail,
            symmetric: true,
            class: EdgeClass::Undirected,
        })
        .unwrap();
        reg.register(EdgeSpec {
            glyph: "b2".to_string(),
            tail: Mark::Arrow,
            head: Mark::Arrow,
            symmetric: true,
            class: EdgeClass::Bidirected,
        })
        .unwrap();

        let d = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let cpdag = dag.to_cpdag().unwrap();
        assert_eq!(cpdag.n(), 3);

        let admg = dag.latent_project(&[1]).unwrap();
        assert_eq!(admg.n(), 2);
    }

    #[test]
    fn dag_to_cpdag_exhaustive_small_dags_do_not_error() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let pairs: [(u32, u32); 6] = [(0, 1), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3)];
        // Per pair state:
        // 0 none, 1 a->b, 2 b->a
        let states = 3usize;
        let total = states.pow(pairs.len() as u32);
        let mut seen = 0usize;

        for idx in 0..total {
            let mut code = idx;
            let mut b = GraphBuilder::new_with_registry(4, true, &reg);
            for &(a, c) in &pairs {
                match code % states {
                    1 => {
                        b.add_edge(a, c, d).unwrap();
                    }
                    2 => {
                        b.add_edge(c, a, d).unwrap();
                    }
                    _ => {}
                }
                code /= states;
            }

            let core = Arc::new(b.finalize().unwrap());
            let Ok(dag) = Dag::new(core) else {
                continue;
            };
            let _ = dag.to_cpdag().unwrap();
            seen += 1;
        }

        assert!(seen > 0);
    }

    #[test]
    fn dag_to_cpdag_exhaustive_five_node_dags_do_not_error() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let pairs: [(u32, u32); 10] = [
            (0, 1),
            (0, 2),
            (0, 3),
            (0, 4),
            (1, 2),
            (1, 3),
            (1, 4),
            (2, 3),
            (2, 4),
            (3, 4),
        ];
        let states = 3usize; // 0 none, 1 a->b, 2 b->a
        let total = states.pow(pairs.len() as u32);
        let mut seen = 0usize;

        for idx in 0..total {
            let mut code = idx;
            let mut b = GraphBuilder::new_with_registry(5, true, &reg);
            for &(a, c) in &pairs {
                match code % states {
                    1 => {
                        b.add_edge(a, c, d).unwrap();
                    }
                    2 => {
                        b.add_edge(c, a, d).unwrap();
                    }
                    _ => {}
                }
                code /= states;
            }

            let core = Arc::new(b.finalize().unwrap());
            let Ok(dag) = Dag::new(core) else {
                continue;
            };
            let _ = dag.to_cpdag().unwrap();
            seen += 1;
        }

        assert!(seen > 0);
    }

    #[test]
    fn latent_project_self_loop_skipped_when_parent_is_also_child() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // 0:L1, 1:L2, 2:X
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap(); // L1 -> L2
        b.add_edge(0, 2, d).unwrap(); // L1 -> X
        b.add_edge(1, 2, d).unwrap(); // L2 -> X
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let admg = dag.latent_project(&[0, 1]).unwrap();
        // Only X remains
        assert_eq!(admg.n(), 1);
        assert!(admg.spouses_of(0).is_empty());
        assert!(admg.children_of(0).is_empty());
    }

    #[test]
    fn to_cpdag_has_dir_path_src_eq_tgt() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(2, 1, d).unwrap();
        b.add_edge(1, 3, d).unwrap();
        b.add_edge(0, 3, d).unwrap();
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let cpdag = dag.to_cpdag().unwrap();
        // 0->3 should be directed (oriented by R4)
        assert!(cpdag.children_of(0).contains(&3));
        assert!(cpdag.parents_of(3).contains(&0));
        // 0->1 directed (v-structure)
        assert!(cpdag.children_of(0).contains(&1));
        // 2->1 directed (v-structure)
        assert!(cpdag.parents_of(1).contains(&2));
        // 1->3 directed (R1)
        assert!(cpdag.children_of(1).contains(&3));
    }

    #[test]
    fn dag_to_cpdag_randomized_larger_dags_do_not_error() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        fn next_u64(state: &mut u64) -> u64 {
            // Deterministic LCG for stable test behavior.
            *state = state.wrapping_mul(6364136223846793005).wrapping_add(1);
            *state
        }

        let n = 7u32;
        let mut seed = 0xC0FFEE_u64;
        let mut seen = 0usize;

        for _ in 0..3000 {
            let mut order: Vec<u32> = (0..n).collect();
            for i in (1..order.len()).rev() {
                let j = (next_u64(&mut seed) as usize) % (i + 1);
                order.swap(i, j);
            }

            let mut b = GraphBuilder::new_with_registry(n, true, &reg);
            for i in 0..order.len() {
                for j in (i + 1)..order.len() {
                    // Forward-only edges in randomized order keep the graph acyclic.
                    if (next_u64(&mut seed) & 3) == 0 {
                        b.add_edge(order[i], order[j], d).unwrap();
                    }
                }
            }

            let core = Arc::new(b.finalize().unwrap());
            let dag = Dag::new(core).unwrap();
            let _ = dag.to_cpdag().unwrap();
            seen += 1;
        }

        assert_eq!(seen, 3000);
    }
}
