// SPDX-License-Identifier: MIT
//! Graph transformations for DAGs: skeleton, moralize, to_cpdag, latent_project.

use super::Dag;
use crate::edges::EdgeClass;
use crate::graph::admg::Admg;
use crate::graph::alg::csr;
use crate::graph::pdag::Pdag;
use crate::graph::ug::Ug;
use crate::graph::CaugiGraph;
use std::collections::{BTreeSet, HashSet, VecDeque};
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
    pub fn to_cpdag(&self) -> Result<Pdag, String> {
        let n = self.n() as usize;

        let mut pa: Vec<HashSet<u32>> = vec![HashSet::new(); n];
        let mut ch: Vec<HashSet<u32>> = vec![HashSet::new(); n];
        let mut und: Vec<HashSet<u32>> = vec![HashSet::new(); n];

        #[inline]
        fn adjacent(
            a: usize,
            b: usize,
            und: &[HashSet<u32>],
            pa: &[HashSet<u32>],
            ch: &[HashSet<u32>],
        ) -> bool {
            und[a].contains(&(b as u32))
                || und[b].contains(&(a as u32))
                || pa[a].contains(&(b as u32))
                || ch[a].contains(&(b as u32))
                || pa[b].contains(&(a as u32))
                || ch[b].contains(&(a as u32))
        }

        #[inline]
        fn orient(
            a: u32,
            b: u32,
            und: &mut [HashSet<u32>],
            pa: &mut [HashSet<u32>],
            ch: &mut [HashSet<u32>],
        ) {
            let ai = a as usize;
            let bi = b as usize;
            und[ai].remove(&b);
            und[bi].remove(&a);
            ch[ai].insert(b);
            pa[bi].insert(a);
        }

        fn has_dir_path(ch: &[HashSet<u32>], src: u32, tgt: u32) -> bool {
            if src == tgt {
                return true;
            }
            let n = ch.len();
            let mut seen = vec![false; n];
            let mut q = VecDeque::new();
            q.push_back(src);
            while let Some(u) = q.pop_front() {
                if u == tgt {
                    return true;
                }
                if std::mem::replace(&mut seen[u as usize], true) {
                    continue;
                }
                for &v in &ch[u as usize] {
                    if !seen[v as usize] {
                        q.push_back(v);
                    }
                }
            }
            false
        }

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
                    if !adjacent(a, c, &und, &pa, &ch) {
                        orient(parents[i], b, &mut und, &mut pa, &mut ch);
                        orient(parents[j], b, &mut und, &mut pa, &mut ch);
                    }
                }
            }
        }

        // Meek closure (R1–R4)
        loop {
            let mut changed = false;

            // R1: a->b, b--c, a !~ c  ⇒  b->c
            for b in 0..n {
                if pa[b].is_empty() || und[b].is_empty() {
                    continue;
                }
                let pb: Vec<u32> = pa[b].iter().copied().collect();
                let ubs: Vec<u32> = und[b].clone().into_iter().collect();
                'c_loop: for c in ubs {
                    let ci = c as usize;
                    for &a in &pb {
                        if !adjacent(a as usize, ci, &und, &pa, &ch) {
                            orient(b as u32, c, &mut und, &mut pa, &mut ch);
                            changed = true;
                            continue 'c_loop;
                        }
                    }
                }
            }

            // R2: a--b and ∃ w: a->w, w->b  ⇒  a->b
            for a in 0..n {
                let uab: Vec<u32> = und[a].clone().into_iter().collect();
                for b_u in uab {
                    let b = b_u as usize;
                    if ch[a].iter().any(|w| pa[b].contains(w)) {
                        orient(a as u32, b_u, &mut und, &mut pa, &mut ch);
                        changed = true;
                        continue;
                    }
                    if ch[b].iter().any(|w| pa[a].contains(w)) {
                        orient(b_u, a as u32, &mut und, &mut pa, &mut ch);
                        changed = true;
                    }
                }
            }

            // R3: a--b and ∃ c,d: c->b, d->b, c !~ d, a--c, a--d  ⇒  a->b
            for a in 0..n {
                let uab: Vec<u32> = und[a].clone().into_iter().collect();
                for b_u in uab {
                    let b = b_u as usize;
                    let pb: Vec<u32> = pa[b].iter().copied().collect();
                    'pairs: for i in 0..pb.len() {
                        for j in (i + 1)..pb.len() {
                            let c = pb[i] as usize;
                            let d = pb[j] as usize;
                            if !adjacent(c, d, &und, &pa, &ch)
                                && und[a].contains(&pb[i])
                                && und[a].contains(&pb[j])
                            {
                                orient(a as u32, b_u, &mut und, &mut pa, &mut ch);
                                changed = true;
                                break 'pairs;
                            }
                        }
                    }
                }
            }

            // R4: a--b and (a ⇒ b or b ⇒ a)  ⇒  orient along reachability
            for a in 0..n {
                let uab: Vec<u32> = und[a].clone().into_iter().collect();
                for b_u in uab {
                    if has_dir_path(&ch, a as u32, b_u) {
                        orient(a as u32, b_u, &mut und, &mut pa, &mut ch);
                        changed = true;
                    } else if has_dir_path(&ch, b_u, a as u32) {
                        orient(b_u, a as u32, &mut und, &mut pa, &mut ch);
                        changed = true;
                    }
                }
            }

            if !changed {
                break;
            }
        }

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
    fn dag_core_transforms_match_graph_transforms() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let dag = Dag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let sk_core = dag.skeleton_core().unwrap();
        let sk = Ug::new(Arc::new(sk_core)).unwrap();
        assert_eq!(sk.neighbors_of(0), &[2]);
        assert_eq!(sk.neighbors_of(1), &[2]);
        assert_eq!(sk.neighbors_of(2), &[0, 1]);

        let moral_core = dag.moralize_core().unwrap();
        let moral = Ug::new(Arc::new(moral_core)).unwrap();
        assert_eq!(moral.neighbors_of(0), &[1, 2]);
        assert_eq!(moral.neighbors_of(1), &[0, 2]);
        assert_eq!(moral.neighbors_of(2), &[0, 1]);
    }

    #[test]
    fn dag_to_cpdag_meek_r1_orients_b_to_c() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // a -> b <- d, and b -> c in the DAG.
        // R1 should orient b -- c into b -> c after v-structure orientation at b.
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
