// SPDX-License-Identifier: MIT
//! CPDAG validation for PDAGs.

use super::Pdag;
use std::collections::{HashSet, VecDeque};

/// Why a PDAG is not a CPDAG.
#[derive(Debug, PartialEq)]
pub(crate) enum NotCpdag {
    /// A cycle `[v, ..., v]` with no chord in a chain component.
    ChordlessCycle(Vec<u32>),
    /// An arrow `a -> b` that is not strongly protected.
    UnprotectedArrow(u32, u32),
    /// Another condition fails.
    Other,
}

impl Pdag {
    /// Full CPDAG check. Returns true iff `self` is a CPDAG.
    pub fn is_cpdag(&self) -> bool {
        self.not_cpdag().is_none()
    }

    /// Why `self` is not a CPDAG, or `None` if it is one.
    pub(crate) fn not_cpdag(&self) -> Option<NotCpdag> {
        let n = self.n() as usize;
        if n <= 1 {
            return None;
        }

        // chain components
        let (comp, c) = self.chain_components();

        // no arrows within any undirected component, and the component DAG
        // must be acyclic
        if self.has_intra_component_arrows(&comp) || !self.component_dag_is_acyclic(&comp, c) {
            return Some(NotCpdag::Other);
        }

        // each undirected component is chordal
        if let Some((v, x, w)) = self.non_chordal_at(&comp, c) {
            return Some(
                self.chordless_cycle(v, x, w)
                    .map_or(NotCpdag::Other, NotCpdag::ChordlessCycle),
            );
        }

        // Meeks rules would not orient any more edges
        if !self.is_meek_closed() {
            return Some(NotCpdag::Other);
        }

        // every arrow is strongly protected
        self.unprotected_arrow()
            .map(|(a, b)| NotCpdag::UnprotectedArrow(a, b))
    }

    /// A chordless cycle through `v` and its non-adjacent neighbours `x` and
    /// `w`: `v`, then a shortest `x`-`w` path avoiding `v`'s other neighbours.
    /// No inner node of the path is adjacent to `v`, and a chord within the
    /// path would make it shorter.
    fn chordless_cycle(&self, v: u32, x: u32, w: u32) -> Option<Vec<u32>> {
        // prev[u] is u's predecessor on the path, or u itself when blocked.
        let mut prev = vec![u32::MAX; self.n() as usize];
        for &u in self.undirected_of(v).iter().chain([&v, &x]) {
            prev[u as usize] = u;
        }
        prev[w as usize] = u32::MAX;
        let mut queue = VecDeque::from([x]);
        while let Some(u) = queue.pop_front() {
            for &y in self.undirected_of(u) {
                if prev[y as usize] == u32::MAX {
                    prev[y as usize] = u;
                    queue.push_back(y);
                }
            }
        }
        if prev[w as usize] == u32::MAX {
            return None;
        }
        let mut cycle = vec![v, w];
        while *cycle.last().unwrap() != x {
            cycle.push(prev[*cycle.last().unwrap() as usize]);
        }
        cycle.push(v);
        Some(cycle)
    }

    /// True if the PDAG is closed under Meek orientation rules (R1..R4).
    ///
    /// See: C. Meek (1995). Causal inference and causal explanation with
    /// background knowledge. UAI-95, pp. 403–411.
    pub fn is_meek_closed(&self) -> bool {
        self.meeks_rules_blocked()
    }

    /// True if the PDAG has a consistent DAG extension (Dor & Tarsi 1992).
    pub fn is_extendable(&self) -> bool {
        self.dag_extension().is_ok()
    }

    /// DFS over undirected edges to get chain components.
    pub(crate) fn chain_components(&self) -> (Vec<usize>, usize) {
        let n = self.n() as usize;
        let mut comp = vec![usize::MAX; n];
        let mut st = Vec::new();
        let mut cid = 0usize;

        for s in 0..n {
            if comp[s] != usize::MAX {
                continue;
            }
            comp[s] = cid;
            st.clear();
            st.push(s as u32);
            while let Some(u) = st.pop() {
                for &w in self.undirected_of(u) {
                    let wi = w as usize;
                    if comp[wi] == usize::MAX {
                        comp[wi] = cid;
                        st.push(w);
                    }
                }
            }
            cid += 1;
        }
        (comp, cid)
    }

    /// True if any directed edge stays inside an undirected component.
    fn has_intra_component_arrows(&self, comp: &[usize]) -> bool {
        for u in 0..self.n() {
            let cu = comp[u as usize];
            for &p in self.parents_of(u) {
                if comp[p as usize] == cu {
                    return true;
                }
            }
            for &v in self.children_of(u) {
                if comp[v as usize] == cu {
                    return true;
                }
            }
        }
        false
    }

    /// Kahn on the component DAG.
    fn component_dag_is_acyclic(&self, comp: &[usize], c: usize) -> bool {
        let mut succ: Vec<Vec<usize>> = vec![Vec::new(); c];
        let mut indeg = vec![0usize; c];
        let mut seen = HashSet::<(usize, usize)>::new();

        for u in 0..self.n() {
            let cu = comp[u as usize];
            for &v in self.children_of(u) {
                let cv = comp[v as usize];
                if cu != cv && seen.insert((cu, cv)) {
                    succ[cu].push(cv);
                    indeg[cv] += 1;
                }
            }
        }

        let mut q: VecDeque<usize> = (0..c).filter(|&k| indeg[k] == 0).collect();
        let mut seen_cnt = 0usize;
        while let Some(x) = q.pop_front() {
            seen_cnt += 1;
            for &y in &succ[x] {
                indeg[y] -= 1;
                if indeg[y] == 0 {
                    q.push_back(y);
                }
            }
        }
        seen_cnt == c
    }

    /// Check chordality of all undirected components via MCS + clique test.
    /// Returns a node `v` with two non-adjacent neighbours `x` and `w` that
    /// the test requires adjacent, or `None` if every component is chordal.
    fn non_chordal_at(&self, comp: &[usize], c: usize) -> Option<(u32, u32, u32)> {
        let n = self.n() as usize;
        let mut nodes_in: Vec<Vec<usize>> = vec![Vec::new(); c];
        for v in 0..n {
            nodes_in[comp[v]].push(v);
        }

        let mut label = vec![0usize; n];
        let mut numbered = vec![false; n];
        let mut in_c = vec![false; n];
        let mut pos = vec![0usize; n];

        for nodes in nodes_in.into_iter() {
            if nodes.len() <= 2 {
                continue;
            }

            for &v in &nodes {
                in_c[v] = true;
                numbered[v] = false;
                label[v] = 0;
            }

            // MCS order
            let mut order = Vec::with_capacity(nodes.len());
            for _ in 0..nodes.len() {
                let mut pick = usize::MAX;
                let mut best = 0usize;
                for &v in &nodes {
                    if !numbered[v] && (pick == usize::MAX || label[v] > best) {
                        pick = v;
                        best = label[v];
                    }
                }
                assert!(pick != usize::MAX, "an unnumbered node remains");
                order.push(pick);
                numbered[pick] = true;
                for &w in self.undirected_of(pick as u32) {
                    let wi = w as usize;
                    if in_c[wi] && !numbered[wi] {
                        label[wi] += 1;
                    }
                }
            }

            for (i, &v) in order.iter().rev().enumerate() {
                pos[v] = i;
            }
            // clique test
            for (i, &v) in order.iter().rev().enumerate() {
                let mut higher: Vec<usize> = self
                    .undirected_of(v as u32)
                    .iter()
                    .map(|&w| w as usize)
                    .filter(|&w| in_c[w] && pos[w] > i)
                    .collect();

                if higher.len() <= 1 {
                    continue;
                }

                // Perfect elimination check (Tarjan & Yannakakis 1984): the
                // pivot must be the *nearest* later neighbour; checking the
                // others against it covers the whole clique by induction.
                higher.sort_unstable_by_key(|&w| pos[w]);
                let pvt = higher[0];
                for &w in &higher[1..] {
                    if self
                        .undirected_of(w as u32)
                        .binary_search(&(pvt as u32))
                        .is_err()
                    {
                        return Some((v as u32, pvt as u32, w as u32));
                    }
                }
            }

            for &v in &nodes {
                in_c[v] = false;
            }
        }

        None
    }

    /// No Meeks rule applies (R1..R4).
    fn meeks_rules_blocked(&self) -> bool {
        // R1: u->v, v--w, u !~ w  =>  v->w. The orientation is forced, so if it
        // would create a cycle or a new collider the PDAG has no extension at
        // all; either way the graph is not closed.
        for v in 0..self.n() {
            let pa = self.parents_of(v);
            for &w in self.undirected_of(v) {
                if pa.iter().any(|&u| !self.adjacent(u, w)) {
                    return false;
                }
            }
        }

        // R2: u--v and ∃ w with u->w, w->v
        for v in 0..self.n() {
            let pa_v = self.parents_of(v);
            for &u in self.undirected_of(v) {
                if Self::intersects_sorted(self.children_of(u), pa_v) {
                    return false;
                }
            }
        }

        // R3: u--v and ∃ w,x: w->v, x->v, w !~ x, u--w, u--x
        for v in 0..self.n() {
            let pv = self.parents_of(v);
            if pv.len() < 2 {
                continue;
            }
            for &u in self.undirected_of(v) {
                let und_u = self.undirected_of(u);
                for i in 0..pv.len() {
                    for j in (i + 1)..pv.len() {
                        let (w, x) = (pv[i], pv[j]);
                        if !self.adjacent(w, x)
                            && und_u.binary_search(&w).is_ok()
                            && und_u.binary_search(&x).is_ok()
                        {
                            return false;
                        }
                    }
                }
            }
        }

        // R4 (Meek 1995): u--v and ∃ c,d: u--c, c->d, d->v, c !~ v
        for v in 0..self.n() {
            let pa_v = self.parents_of(v);
            for &u in self.undirected_of(v) {
                for &c in self.undirected_of(u) {
                    if c != v
                        && !self.adjacent(c, v)
                        && Self::intersects_sorted(self.children_of(c), pa_v)
                    {
                        return false;
                    }
                }
            }
        }

        // Cycle avoidance: u--v and (u ⇒ v or v ⇒ u)
        for v in 0..self.n() {
            for &u in self.undirected_of(v) {
                if self.has_dir_path(u, v) || self.has_dir_path(v, u) {
                    return false;
                }
            }
        }

        true
    }

    /// The first arrow that is not strongly protected (VS, SP1, SP2, SP3), or
    /// `None` if every arrow is.
    fn unprotected_arrow(&self) -> Option<(u32, u32)> {
        for a in 0..self.n() {
            for &b in self.children_of(a) {
                // VS (v-structure protection): ∃ c: c→b and c ⊥ a
                // (another parent of b that is not adjacent to a, forming a v-structure)
                if self
                    .parents_of(b)
                    .iter()
                    .any(|&c| c != a && !self.adjacent(c, a))
                {
                    continue;
                }
                // SP1: ∃ c: c->a and c !~ b
                if self.parents_of(a).iter().any(|&c| !self.adjacent(c, b)) {
                    continue;
                }
                // SP2: ∃ c: a->c and c->b
                if Self::intersects_sorted(self.children_of(a), self.parents_of(b)) {
                    continue;
                }
                // SP3: ∃ c,d: c->b, d->b, c !~ d, a--c, a--d
                let pb = self.parents_of(b);
                let und_a = self.undirected_of(a);
                let mut sp3 = false;
                for i in 0..pb.len() {
                    for j in (i + 1)..pb.len() {
                        let (c1, c2) = (pb[i], pb[j]);
                        if !self.adjacent(c1, c2)
                            && und_a.binary_search(&c1).is_ok()
                            && und_a.binary_search(&c2).is_ok()
                        {
                            sp3 = true;
                            break;
                        }
                    }
                    if sp3 {
                        break;
                    }
                }
                if sp3 {
                    continue;
                }
                // not strongly protected
                return Some((a, b));
            }
        }
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use std::sync::Arc;

    fn setup() -> (EdgeRegistry, u8, u8) {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d: u8 = reg.code_of("-->").unwrap();
        let u: u8 = reg.code_of("---").unwrap();
        (reg, d, u)
    }

    #[test]
    fn not_cpdag_names_a_chordless_cycle_in_every_non_chordal_ug_on_six_nodes() {
        let (reg, _d, u) = setup();
        let pairs: Vec<(u32, u32)> = (0..6)
            .flat_map(|a| (a + 1..6).map(move |b| (a, b)))
            .collect();
        for mask in 0u32..(1 << pairs.len()) {
            let adj = |a: u32, b: u32| {
                let (a, b) = (a.min(b), a.max(b));
                pairs
                    .iter()
                    .position(|&p| p == (a, b))
                    .is_some_and(|k| mask & (1 << k) != 0)
            };
            let mut b = GraphBuilder::new_with_registry(6, true, &reg);
            for (k, &(x, y)) in pairs.iter().enumerate() {
                if mask & (1 << k) != 0 {
                    b.add_edge(x, y, u).unwrap();
                }
            }
            let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
            // Brute force: some node set of size >= 4 induces a cycle.
            let has_chordless_cycle = (0u32..64).any(|set| {
                let nodes: Vec<u32> = (0..6).filter(|&v| set & (1 << v) != 0).collect();
                nodes.len() >= 4
                    && nodes
                        .iter()
                        .all(|&v| nodes.iter().filter(|&&w| w != v && adj(v, w)).count() == 2)
                    && {
                        // connected: walk the cycle from the first node
                        let (mut prev, mut cur, mut len) = (u32::MAX, nodes[0], 0);
                        loop {
                            let next = *nodes
                                .iter()
                                .find(|&&w| w != cur && w != prev && adj(cur, w))
                                .unwrap();
                            (prev, cur, len) = (cur, next, len + 1);
                            if cur == nodes[0] {
                                break len == nodes.len();
                            }
                        }
                    }
            });
            match g.not_cpdag() {
                None => assert!(!has_chordless_cycle, "mask {mask}"),
                Some(NotCpdag::ChordlessCycle(c)) => {
                    assert!(has_chordless_cycle, "mask {mask}");
                    let k = c.len() - 1;
                    assert!(k >= 4 && c[0] == c[k], "mask {mask}: {c:?}");
                    for i in 0..k {
                        for j in i + 1..k {
                            let consecutive = j == i + 1 || (i == 0 && j == k - 1);
                            assert_eq!(adj(c[i], c[j]), consecutive, "mask {mask}: {c:?}");
                        }
                    }
                }
                other => panic!("mask {mask}: {other:?}"),
            }
        }
    }

    #[test]
    fn not_cpdag_names_an_unprotected_arrow() {
        let (reg, d, _u) = setup();
        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert_eq!(g.not_cpdag(), Some(NotCpdag::UnprotectedArrow(0, 1)));
    }

    #[test]
    fn cpdag_trivial_undirected_is_cpdag() {
        let (reg, _d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(g.is_cpdag());
    }

    #[test]
    fn cpdag_triangle_partially_directed_rejected() {
        // In a triangle (complete graph), no v-structures are possible since all
        // nodes are adjacent. The CPDAG should be all undirected: 0—1, 0—2, 1—2.
        // A partially directed triangle like 0→1, 0→2, 1—2 is NOT a valid CPDAG.
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(1, 2, u).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_non_chordal_component_rejected() {
        let (reg, _d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(1, 2, u).unwrap();
        b.add_edge(2, 3, u).unwrap();
        b.add_edge(3, 0, u).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_meek_closure_would_change_rejected() {
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, u).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_directed_inside_component_rejected() {
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(1, 2, u).unwrap();
        b.add_edge(2, 3, u).unwrap();
        b.add_edge(1, 3, d).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_component_dag_cycle_rejected() {
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(2, 3, u).unwrap();
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(2, 1, d).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_singleton_ok() {
        let (reg, _d, _u) = setup();
        let b = GraphBuilder::new_with_registry(1, true, &reg);
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(g.is_cpdag());
    }

    #[test]
    fn cpdag_isolated_nodes_ok() {
        let (reg, _d, _u) = setup();
        let b = GraphBuilder::new_with_registry(5, true, &reg);
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(g.is_cpdag());
    }

    #[test]
    fn cpdag_single_directed_edge_rejected() {
        // A single directed edge A→B is NOT a valid CPDAG because the edge is
        // not protected by any v-structure. The correct CPDAG would be A—B.
        let (reg, d, _u) = setup();
        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_single_undirected_edge_ok() {
        // A single undirected edge A—B IS a valid CPDAG.
        let (reg, _d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(2, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(g.is_cpdag());
    }

    #[test]
    fn cpdag_pure_dag_chain_rejected() {
        // A pure directed chain is NOT a valid CPDAG because no edges are
        // strongly protected. The correct CPDAG would have all edges undirected.
        let (reg, d, _u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        b.add_edge(2, 3, d).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_pure_dag_v_structure_ok() {
        let (reg, d, _u) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(2, 1, d).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(g.is_cpdag());
    }

    #[test]
    fn cpdag_triangle_with_adjacent_parents_rejected() {
        // Regression test: A->B, C->B, A--C (triangle with directed edges into B).
        // Since A and C are adjacent (via the undirected edge), there's NO v-structure
        // at B. The directed edges A->B and C->B are not protected. NOT a valid CPDAG.
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap(); // A -> B
        b.add_edge(2, 1, d).unwrap(); // C -> B
        b.add_edge(0, 2, u).unwrap(); // A -- C
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_undirected_tree_ok() {
        let (reg, _d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(1, 2, u).unwrap();
        b.add_edge(2, 3, u).unwrap();
        b.add_edge(1, 4, u).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(g.is_cpdag());
    }

    #[test]
    fn cpdag_undirected_clique4_ok() {
        let (reg, _d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        for i in 0..4u32 {
            for j in (i + 1)..4u32 {
                b.add_edge(i, j, u).unwrap();
            }
        }
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(g.is_cpdag());
    }

    #[test]
    fn cpdag_non_chordal_5_cycle_rejected() {
        let (reg, _d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(1, 2, u).unwrap();
        b.add_edge(2, 3, u).unwrap();
        b.add_edge(3, 4, u).unwrap();
        b.add_edge(4, 0, u).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_no_arrows_inside_component_rejected_minimal() {
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(1, 2, u).unwrap();
        b.add_edge(0, 2, d).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_component_dag_two_components_no_vstruct_rejected() {
        // Two chain components {0,1} and {2,3} with all cross-edges directed.
        // Since all nodes are pairwise adjacent (complete K4), no v-structure
        // is possible, so the directed edges are not protected.
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(2, 3, u).unwrap();
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(0, 3, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        b.add_edge(1, 3, d).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_meeks_r1_rejected_multiple_parents() {
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(2, 1, d).unwrap();
        b.add_edge(1, 3, u).unwrap();
        b.add_edge(0, 3, u).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_meeks_r2_rejected() {
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(2, 1, d).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_meeks_r3_rejected() {
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(2, 1, d).unwrap();
        b.add_edge(3, 1, d).unwrap();
        b.add_edge(0, 2, u).unwrap();
        b.add_edge(0, 3, u).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_meeks_r4_rejected() {
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(2, 3, d).unwrap();
        b.add_edge(3, 1, d).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_triangle_with_directed_edges_into_fourth_rejected() {
        // Triangle {0,1,2} undirected with all edges pointing to node 3.
        // Since 0, 1, 2 are all pairwise adjacent, no v-structure at 3,
        // so the directed edges are not protected. This is NOT a valid CPDAG.
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(1, 2, u).unwrap();
        b.add_edge(0, 2, u).unwrap();
        b.add_edge(0, 3, d).unwrap();
        b.add_edge(1, 3, d).unwrap();
        b.add_edge(2, 3, d).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_triangle_undirected_ok() {
        // A fully undirected triangle IS a valid CPDAG (the equivalence class
        // of all DAGs on a complete graph with no v-structures).
        let (reg, _d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(0, 2, u).unwrap();
        b.add_edge(1, 2, u).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(g.is_cpdag());
    }

    #[test]
    fn cpdag_component_dag_multilevel_no_vstruct_rejected() {
        // Three chain components {0,1}, {2}, {3,4} with edges between them.
        // At node 2: parents 0 and 1 are adjacent (0—1), so no v-structure.
        // The directed edges into 2 are not protected. NOT a valid CPDAG.
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(3, 4, u).unwrap();
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        b.add_edge(2, 3, d).unwrap();
        b.add_edge(2, 4, d).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_component_dag_cycle_detected_even_with_many_edges() {
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(6, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(2, 3, u).unwrap();
        b.add_edge(4, 5, u).unwrap();
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(3, 4, d).unwrap();
        b.add_edge(5, 1, d).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!g.is_cpdag());
    }

    #[test]
    fn cpdag_chordal_undirected_with_chord_ok() {
        let (reg, _d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(1, 2, u).unwrap();
        b.add_edge(0, 2, u).unwrap();
        let g = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
        assert!(g.is_cpdag());
    }

    #[test]
    fn cpdag_internal_meeks_rules_r2_r3_and_reverse_r2() {
        let (reg, d, u) = setup();

        // R2 (forward): a--b with a->w->b
        let mut b1 = GraphBuilder::new_with_registry(3, true, &reg);
        b1.add_edge(0, 1, u).unwrap();
        b1.add_edge(0, 2, d).unwrap();
        b1.add_edge(2, 1, d).unwrap();
        let g1 = Pdag::new(Arc::new(b1.finalize().unwrap())).unwrap();
        assert!(!g1.meeks_rules_blocked());

        // R2 (reverse branch): a--b with b->w->a
        let mut b2 = GraphBuilder::new_with_registry(3, true, &reg);
        b2.add_edge(0, 1, u).unwrap();
        b2.add_edge(1, 2, d).unwrap();
        b2.add_edge(2, 0, d).unwrap();
        let g2 = Pdag::new(Arc::new(b2.finalize().unwrap())).unwrap();
        assert!(!g2.meeks_rules_blocked());

        // R3: a--b and c->b, d->b with c !~ d and a--c, a--d
        let mut b3 = GraphBuilder::new_with_registry(4, true, &reg);
        b3.add_edge(0, 1, u).unwrap();
        b3.add_edge(2, 1, d).unwrap();
        b3.add_edge(3, 1, d).unwrap();
        b3.add_edge(0, 2, u).unwrap();
        b3.add_edge(0, 3, u).unwrap();
        let g3 = Pdag::new(Arc::new(b3.finalize().unwrap())).unwrap();
        assert!(!g3.meeks_rules_blocked());

        // R4: a--b and directed path a=>b
        let mut b4 = GraphBuilder::new_with_registry(4, true, &reg);
        b4.add_edge(0, 1, u).unwrap();
        b4.add_edge(0, 2, d).unwrap();
        b4.add_edge(2, 3, d).unwrap();
        b4.add_edge(3, 1, d).unwrap();
        let g4 = Pdag::new(Arc::new(b4.finalize().unwrap())).unwrap();
        assert!(!g4.meeks_rules_blocked());
    }

    #[test]
    fn cpdag_internal_strong_protection_sp1_sp2_sp3() {
        let (reg, d, u) = setup();

        // SP1: c->a and c !~ b protect a->b
        let mut b1 = GraphBuilder::new_with_registry(3, true, &reg);
        b1.add_edge(0, 1, d).unwrap(); // a->b
        b1.add_edge(2, 0, d).unwrap(); // c->a
        let g1 = Pdag::new(Arc::new(b1.finalize().unwrap())).unwrap();
        assert!(g1.unprotected_arrow().is_some());

        // SP2: a->c and c->b protect a->b
        let mut b2 = GraphBuilder::new_with_registry(3, true, &reg);
        b2.add_edge(0, 1, d).unwrap(); // a->b
        b2.add_edge(0, 2, d).unwrap(); // a->c
        b2.add_edge(2, 1, d).unwrap(); // c->b
        let g2 = Pdag::new(Arc::new(b2.finalize().unwrap())).unwrap();
        assert!(g2.unprotected_arrow().is_some());

        // SP3: c,d -> b with c !~ d and a--c, a--d protect a->b
        let mut b3 = GraphBuilder::new_with_registry(4, true, &reg);
        b3.add_edge(0, 1, d).unwrap(); // a->b
        b3.add_edge(2, 1, d).unwrap(); // c->b
        b3.add_edge(3, 1, d).unwrap(); // d->b
        b3.add_edge(0, 2, u).unwrap(); // a--c
        b3.add_edge(0, 3, u).unwrap(); // a--d
        let g3 = Pdag::new(Arc::new(b3.finalize().unwrap())).unwrap();
        assert!(g3.unprotected_arrow().is_none());
    }
}
