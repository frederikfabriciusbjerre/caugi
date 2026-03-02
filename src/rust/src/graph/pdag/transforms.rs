// SPDX-License-Identifier: MIT
//! Graph transformations for PDAGs.

use super::Pdag;
use crate::edges::EdgeClass;
use crate::graph::alg::csr;
use crate::graph::ug::Ug;
use std::collections::{BTreeSet, VecDeque};
use std::sync::Arc;

impl Pdag {
    /// UG skeleton of a PDAG: ignore orientation and keep every adjacency once per side.
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

    /// Orient all compelled edges implied by Meek rules (R1..R4).
    ///
    /// Returns a new PDAG that is closed under Meek orientation rules.
    pub fn meek_closure(&self) -> Result<Pdag, String> {
        type NodeSet = BTreeSet<u32>;

        let n = self.n() as usize;
        let mut pa: Vec<NodeSet> = (0..n)
            .map(|i| self.parents_of(i as u32).iter().copied().collect())
            .collect();
        let mut ch: Vec<NodeSet> = (0..n)
            .map(|i| self.children_of(i as u32).iter().copied().collect())
            .collect();
        let mut und: Vec<NodeSet> = (0..n)
            .map(|i| self.undirected_of(i as u32).iter().copied().collect())
            .collect();

        #[inline]
        fn snapshot(nodes: &NodeSet) -> Vec<u32> {
            nodes.iter().copied().collect()
        }

        #[inline]
        fn adjacent(a: usize, b: usize, und: &[NodeSet], pa: &[NodeSet], ch: &[NodeSet]) -> bool {
            let bu = b as u32;
            let au = a as u32;
            und[a].contains(&bu)
                || und[b].contains(&au)
                || pa[a].contains(&bu)
                || ch[a].contains(&bu)
                || pa[b].contains(&au)
                || ch[b].contains(&au)
        }

        #[inline]
        fn orient(a: u32, b: u32, und: &mut [NodeSet], pa: &mut [NodeSet], ch: &mut [NodeSet]) {
            let ai = a as usize;
            let bi = b as usize;
            und[ai].remove(&b);
            und[bi].remove(&a);
            ch[ai].insert(b);
            pa[bi].insert(a);
        }

        fn has_dir_path(ch: &[NodeSet], src: u32, tgt: u32) -> bool {
            if src == tgt {
                return true;
            }
            let mut seen = vec![false; ch.len()];
            let mut queue = VecDeque::from([src]);
            while let Some(u) = queue.pop_front() {
                let ui = u as usize;
                if seen[ui] {
                    continue;
                }
                if u == tgt {
                    return true;
                }
                seen[ui] = true;
                for &v in &ch[ui] {
                    if !seen[v as usize] {
                        queue.push_back(v);
                    }
                }
            }
            false
        }

        #[inline]
        fn try_orient(
            a: u32,
            b: u32,
            und: &mut [NodeSet],
            pa: &mut [NodeSet],
            ch: &mut [NodeSet],
        ) -> bool {
            let ai = a as usize;
            let bi = b as usize;
            if !und[ai].contains(&b) || !und[bi].contains(&a) {
                return false;
            }
            // Preserve PDAG acyclicity while applying Meek-style orientations.
            if has_dir_path(ch, b, a) {
                return false;
            }
            orient(a, b, und, pa, ch);
            true
        }

        loop {
            let mut changed = false;

            // R1: a->b, b--c, a !~ c  =>  b->c
            for b in 0..n {
                if pa[b].is_empty() || und[b].is_empty() {
                    continue;
                }
                let parents = snapshot(&pa[b]);
                for c in snapshot(&und[b]) {
                    let should_orient = parents
                        .iter()
                        .any(|&a| !adjacent(a as usize, c as usize, &und, &pa, &ch));
                    if should_orient && try_orient(b as u32, c, &mut und, &mut pa, &mut ch) {
                        changed = true;
                    }
                }
            }

            // R2: a--b and exists w: a->w->b  =>  a->b
            for a in 0..n {
                for b_u in snapshot(&und[a]) {
                    let b = b_u as usize;
                    if ch[a].iter().any(|w| pa[b].contains(w)) {
                        if try_orient(a as u32, b_u, &mut und, &mut pa, &mut ch) {
                            changed = true;
                        }
                    } else if ch[b].iter().any(|w| pa[a].contains(w)) {
                        if try_orient(b_u, a as u32, &mut und, &mut pa, &mut ch) {
                            changed = true;
                        }
                    }
                }
            }

            // R3: a--b and exists c,d: c->b, d->b, c !~ d, a--c, a--d  =>  a->b
            for a in 0..n {
                for b_u in snapshot(&und[a]) {
                    let b = b_u as usize;
                    let parents = snapshot(&pa[b]);
                    let should_orient = parents.iter().enumerate().any(|(i, &c)| {
                        parents[(i + 1)..].iter().any(|&d| {
                            !adjacent(c as usize, d as usize, &und, &pa, &ch)
                                && und[a].contains(&c)
                                && und[a].contains(&d)
                        })
                    });
                    if should_orient && try_orient(a as u32, b_u, &mut und, &mut pa, &mut ch) {
                        changed = true;
                    }
                }
            }

            // R4: a--b and (a => b or b => a)  =>  orient along reachability
            for a in 0..n {
                for b_u in snapshot(&und[a]) {
                    if has_dir_path(&ch, a as u32, b_u) {
                        if try_orient(a as u32, b_u, &mut und, &mut pa, &mut ch) {
                            changed = true;
                        }
                    } else if has_dir_path(&ch, b_u, a as u32) {
                        if try_orient(b_u, a as u32, &mut und, &mut pa, &mut ch) {
                            changed = true;
                        }
                    }
                }
            }

            if !changed {
                break;
            }
        }

        // Build CSR core from [parents | undirected | children].
        let specs = &self.core_ref().registry.specs;
        let mut dir_code: Option<u8> = None;
        let mut und_code: Option<u8> = None;
        for (i, s) in specs.iter().enumerate() {
            let code = i as u8;
            if s.class == EdgeClass::Directed && (dir_code.is_none() || s.glyph == "-->") {
                dir_code = Some(code);
            }
            if s.class == EdgeClass::Undirected && (und_code.is_none() || s.glyph == "---") {
                und_code = Some(code);
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
        let nnz = row_index[n] as usize;
        let mut col_index = vec![0u32; nnz];
        let mut etype = vec![0u8; nnz];
        let mut side = vec![0u8; nnz];

        let mut cur = row_index[..n].to_vec();
        for i in 0..n {
            for &p in &pa[i] {
                let k = cur[i] as usize;
                col_index[k] = p;
                etype[k] = dir;
                side[k] = 1;
                cur[i] += 1;
            }
            for &u in &und[i] {
                let k = cur[i] as usize;
                col_index[k] = u;
                etype[k] = undc;
                side[k] = 0;
                cur[i] += 1;
            }
            for &c in &ch[i] {
                let k = cur[i] as usize;
                col_index[k] = c;
                etype[k] = dir;
                side[k] = 0;
                cur[i] += 1;
            }
        }

        let core = crate::graph::CaugiGraph::from_csr(
            row_index,
            col_index,
            etype,
            side,
            true,
            self.core_ref().registry.clone(),
        )?;
        Pdag::new(Arc::new(core))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    #[test]
    fn pdag_skeleton_undirects_all_adjacencies() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();
        let u = reg.code_of("---").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, u).unwrap();
        let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let ug = p.skeleton().unwrap();
        assert_eq!(ug.neighbors_of(0), &[1]);
        assert_eq!(ug.neighbors_of(1), &[0, 2]);
        assert_eq!(ug.neighbors_of(2), &[1]);
    }

    fn setup() -> (EdgeRegistry, u8, u8) {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();
        let u = reg.code_of("---").unwrap();
        (reg, d, u)
    }

    #[test]
    fn pdag_meek_closure_orients_r1() {
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(2, 1, d).unwrap();
        b.add_edge(1, 3, u).unwrap();
        b.add_edge(0, 3, u).unwrap();
        let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let m = p.meek_closure().unwrap();
        assert!(m.children_of(1).contains(&3));
        assert!(!m.undirected_of(1).contains(&3));
        assert!(m.is_meek_closed());
    }

    #[test]
    fn pdag_meek_closure_orients_r2() {
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(2, 1, d).unwrap();
        let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let m = p.meek_closure().unwrap();
        assert!(m.children_of(0).contains(&1));
        assert!(!m.undirected_of(0).contains(&1));
        assert!(m.is_meek_closed());
    }

    #[test]
    fn pdag_meek_closure_orients_r3() {
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(2, 1, d).unwrap();
        b.add_edge(3, 1, d).unwrap();
        b.add_edge(0, 2, u).unwrap();
        b.add_edge(0, 3, u).unwrap();
        let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let m = p.meek_closure().unwrap();
        assert!(m.children_of(0).contains(&1));
        assert!(!m.undirected_of(0).contains(&1));
        assert!(m.is_meek_closed());
    }

    #[test]
    fn pdag_meek_closure_orients_r4() {
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(2, 3, d).unwrap();
        b.add_edge(3, 1, d).unwrap();
        let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let m = p.meek_closure().unwrap();
        assert!(m.children_of(0).contains(&1));
        assert!(!m.undirected_of(0).contains(&1));
        assert!(m.is_meek_closed());
    }

    #[test]
    fn pdag_meek_closure_is_idempotent() {
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(2, 3, d).unwrap();
        b.add_edge(3, 1, d).unwrap();
        let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let m1 = p.meek_closure().unwrap();
        let m2 = m1.meek_closure().unwrap();
        for i in 0..m1.n() {
            assert_eq!(m1.parents_of(i), m2.parents_of(i));
            assert_eq!(m1.undirected_of(i), m2.undirected_of(i));
            assert_eq!(m1.children_of(i), m2.children_of(i));
        }
    }
}
