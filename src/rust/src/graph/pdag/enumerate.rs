// SPDX-License-Identifier: MIT
//! Enumerate all DAGs in the Markov equivalence class of a PDAG.
//!
//! Implements the recursive listing algorithm of Chickering (2002): pick the
//! lexicographically smallest undirected edge, branch on both orientations,
//! reject branches that introduce a new v-structure or a directed cycle,
//! propagate forced orientations via Meek's rules, and recurse.

use super::Pdag;
use crate::edges::EdgeClass;
use crate::graph::alg::meek;
use crate::graph::dag::Dag;
use crate::graph::CaugiGraph;
use std::collections::HashSet;
use std::sync::Arc;

impl Pdag {
    /// Enumerate every DAG in the Markov equivalence class.
    ///
    /// The input is normalized via [`Pdag::meek_closure`] first, so partial
    /// PDAGs (e.g. with background-knowledge orientations) are accepted.
    pub fn enumerate_mec(&self) -> Result<Vec<Dag>, String> {
        let closed = self.meek_closure()?;
        let (pa, ch, und) = closed.snapshot_sets();
        let input_pa = pa.clone();
        let skeleton = build_skeleton(&pa, &ch, &und);
        let mut leaves: Vec<(Vec<HashSet<u32>>, Vec<HashSet<u32>>)> = Vec::new();
        list_dags(pa, ch, und, &input_pa, &skeleton, &mut leaves);
        let mut out = Vec::with_capacity(leaves.len());
        for (pa, ch) in leaves {
            let core = build_dag_core(closed.core_ref(), &pa, &ch)?;
            let dag = Dag::new(Arc::new(core))?;
            out.push(dag);
        }
        Ok(out)
    }

    /// Count DAGs in the MEC without materializing them.
    pub fn count_mec(&self) -> Result<u64, String> {
        let closed = self.meek_closure()?;
        let (pa, ch, und) = closed.snapshot_sets();
        let input_pa = pa.clone();
        let skeleton = build_skeleton(&pa, &ch, &und);
        let mut count: u64 = 0;
        count_dags(pa, ch, und, &input_pa, &skeleton, &mut count);
        Ok(count)
    }

    /// One consistent DAG extension, by Dor and Tarsi's (1992) algorithm.
    ///
    /// Repeatedly take a node `x` that is a sink -- no directed edge out of
    /// it -- whose undirected neighbours are all adjacent to one another, and
    /// orient every one of those edges into `x`; then remove `x` and repeat.
    /// Orienting into a simplicial sink adds no v-structure and no cycle, and
    /// Dor and Tarsi show that if no such node exists at some step the PDAG
    /// has no consistent extension at all.
    ///
    /// The result keeps every directed edge of the input and orients every
    /// undirected one, so it is a consistent extension: same skeleton, same
    /// v-structures.
    ///
    /// # Errors
    ///
    /// When no step finds a simplicial sink, which means no DAG extends this
    /// PDAG.
    pub fn dag_extension(&self) -> Result<Dag, String> {
        let n = self.n() as usize;
        let (mut pa, mut ch, mut und) = self.snapshot_sets();
        let skeleton = build_skeleton(&pa, &ch, &und);
        let mut removed = vec![false; n];

        for _ in 0..n {
            // A sink with a complete undirected neighbourhood, among the
            // nodes not yet removed.
            let sink = (0..n).find(|&i| {
                if removed[i] {
                    return false;
                }
                if ch[i].iter().any(|&c| !removed[c as usize]) {
                    return false;
                }
                // Condition (b): every undirected neighbour of `i` is
                // adjacent to *all* the other nodes adjacent to `i`, the
                // parents included. Pairwise adjacency among the undirected
                // neighbours alone is not enough: orienting `y --> i` where
                // `i` has a parent `a` not adjacent to `y` would add the
                // v-structure `y --> i <-- a`.
                let present = |v: u32| !removed[v as usize];
                und[i].iter().copied().filter(|&u| present(u)).all(|y| {
                    skeleton[i]
                        .iter()
                        .copied()
                        .filter(|&z| present(z) && z != y)
                        .all(|z| skeleton[y as usize].contains(&z))
                })
            });
            let x = match sink {
                Some(x) => x,
                None => {
                    return Err("this PDAG cannot be extended to a DAG: no node is a \
                                sink whose undirected neighbours are all adjacent \
                                (Dor-Tarsi)"
                        .into())
                }
            };

            // Orient every remaining undirected edge at `x` into `x`.
            let xu = x as u32;
            let nbrs: Vec<u32> = und[x].iter().copied().collect();
            // Every neighbour here is still present: removing a node clears
            // its undirected edges from both sides.
            for u in nbrs {
                und[x].remove(&u);
                und[u as usize].remove(&xu);
                pa[x].insert(u);
                ch[u as usize].insert(xu);
            }
            removed[x] = true;
        }

        let core = build_dag_core(self.core_ref(), &pa, &ch)?;
        Dag::new(Arc::new(core))
    }

    fn snapshot_sets(&self) -> (Vec<HashSet<u32>>, Vec<HashSet<u32>>, Vec<HashSet<u32>>) {
        let n = self.n() as usize;
        let mut pa = vec![HashSet::new(); n];
        let mut ch = vec![HashSet::new(); n];
        let mut und = vec![HashSet::new(); n];
        for i in 0..n {
            let u = i as u32;
            pa[i].extend(self.parents_of(u).iter().copied());
            ch[i].extend(self.children_of(u).iter().copied());
            und[i].extend(self.undirected_of(u).iter().copied());
        }
        (pa, ch, und)
    }
}

/// Build an undirected skeleton (each node's set of neighbours) from a closed
/// PDAG state: directed and undirected adjacencies are both treated as edges.
fn build_skeleton(
    pa: &[HashSet<u32>],
    ch: &[HashSet<u32>],
    und: &[HashSet<u32>],
) -> Vec<HashSet<u32>> {
    let n = pa.len();
    let mut s = vec![HashSet::<u32>::new(); n];
    for i in 0..n {
        s[i].extend(pa[i].iter().copied());
        s[i].extend(ch[i].iter().copied());
        s[i].extend(und[i].iter().copied());
    }
    s
}

/// True if the current parent sets contain a v-structure (p1 → v ← p2) with
/// p1 not adjacent to p2 in `skeleton` that was not already present in
/// `input_pa`. Meek's R1 guards against this when *it* orients an edge, but
/// R2/R3/R4 do not, so we re-check at recursion leaves.
fn has_new_v_structure(
    pa: &[HashSet<u32>],
    input_pa: &[HashSet<u32>],
    skeleton: &[HashSet<u32>],
) -> bool {
    for v in 0..pa.len() {
        if pa[v].len() < 2 {
            continue;
        }
        let parents: Vec<u32> = pa[v].iter().copied().collect();
        for i in 0..parents.len() {
            for j in (i + 1)..parents.len() {
                let p1 = parents[i];
                let p2 = parents[j];
                if skeleton[p1 as usize].contains(&p2) {
                    continue;
                }
                let was_v_structure = input_pa[v].contains(&p1) && input_pa[v].contains(&p2);
                if !was_v_structure {
                    return true;
                }
            }
        }
    }
    false
}

/// Lexicographically smallest undirected half-edge `(u, v)` with `u < v`.
fn smallest_und_edge(und: &[HashSet<u32>]) -> Option<(u32, u32)> {
    let mut best: Option<(u32, u32)> = None;
    for (i, set) in und.iter().enumerate() {
        let iu = i as u32;
        for &j in set {
            if j <= iu {
                continue;
            }
            let edge = (iu, j);
            match best {
                None => best = Some(edge),
                Some(cur) if edge < cur => best = Some(edge),
                _ => {}
            }
        }
    }
    best
}

/// True if orienting `a -> b` would create a new unshielded collider at `b`,
/// i.e. an existing parent `p` of `b` (other than `a`) is not adjacent to `a`.
fn would_create_v_structure(
    a: u32,
    b: u32,
    pa: &[HashSet<u32>],
    ch: &[HashSet<u32>],
    und: &[HashSet<u32>],
) -> bool {
    for &p in &pa[b as usize] {
        if p != a && !meek::adjacent(a as usize, p as usize, und, pa, ch) {
            return true;
        }
    }
    false
}

/// True if a directed path `src -> ... -> tgt` exists using only `ch`.
fn has_dir_path(ch: &[HashSet<u32>], src: u32, tgt: u32) -> bool {
    if src == tgt {
        return true;
    }
    let n = ch.len();
    let mut seen = vec![false; n];
    let mut stack = vec![src];
    while let Some(u) = stack.pop() {
        if u == tgt {
            return true;
        }
        if std::mem::replace(&mut seen[u as usize], true) {
            continue;
        }
        for &w in &ch[u as usize] {
            if !seen[w as usize] {
                stack.push(w);
            }
        }
    }
    false
}

fn list_dags(
    pa: Vec<HashSet<u32>>,
    ch: Vec<HashSet<u32>>,
    und: Vec<HashSet<u32>>,
    input_pa: &[HashSet<u32>],
    skeleton: &[HashSet<u32>],
    out: &mut Vec<(Vec<HashSet<u32>>, Vec<HashSet<u32>>)>,
) {
    let Some((u, v)) = smallest_und_edge(&und) else {
        if !has_new_v_structure(&pa, input_pa, skeleton) {
            out.push((pa, ch));
        }
        return;
    };
    for (a, b) in [(u, v), (v, u)] {
        if would_create_v_structure(a, b, &pa, &ch, &und) {
            continue;
        }
        if has_dir_path(&ch, b, a) {
            continue;
        }
        let mut pa2 = pa.clone();
        let mut ch2 = ch.clone();
        let mut und2 = und.clone();
        meek::orient(a, b, &mut und2, &mut pa2, &mut ch2);
        meek::apply_meek_closure(&mut pa2, &mut ch2, &mut und2, true);
        if has_new_v_structure(&pa2, input_pa, skeleton) {
            continue;
        }
        list_dags(pa2, ch2, und2, input_pa, skeleton, out);
    }
}

fn count_dags(
    pa: Vec<HashSet<u32>>,
    ch: Vec<HashSet<u32>>,
    und: Vec<HashSet<u32>>,
    input_pa: &[HashSet<u32>],
    skeleton: &[HashSet<u32>],
    count: &mut u64,
) {
    let Some((u, v)) = smallest_und_edge(&und) else {
        if !has_new_v_structure(&pa, input_pa, skeleton) {
            *count += 1;
        }
        return;
    };
    for (a, b) in [(u, v), (v, u)] {
        if would_create_v_structure(a, b, &pa, &ch, &und) {
            continue;
        }
        if has_dir_path(&ch, b, a) {
            continue;
        }
        let mut pa2 = pa.clone();
        let mut ch2 = ch.clone();
        let mut und2 = und.clone();
        meek::orient(a, b, &mut und2, &mut pa2, &mut ch2);
        meek::apply_meek_closure(&mut pa2, &mut ch2, &mut und2, true);
        if has_new_v_structure(&pa2, input_pa, skeleton) {
            continue;
        }
        count_dags(pa2, ch2, und2, input_pa, skeleton, count);
    }
}

fn build_dag_core(
    template: &CaugiGraph,
    pa: &[HashSet<u32>],
    ch: &[HashSet<u32>],
) -> Result<CaugiGraph, String> {
    let n = pa.len();

    let specs = &template.registry.specs;
    let mut dir_code: Option<u8> = None;
    for (i, s) in specs.iter().enumerate() {
        if matches!(s.class, EdgeClass::Directed) && (dir_code.is_none() || s.glyph == "-->") {
            dir_code = Some(i as u8);
        }
    }
    let dir = dir_code.ok_or("No Directed edge spec in registry")?;

    let mut row_index = Vec::with_capacity(n + 1);
    row_index.push(0u32);
    for i in 0..n {
        let c = pa[i].len() + ch[i].len();
        row_index.push(row_index[i] + c as u32);
    }
    let nnz = *row_index.last().unwrap() as usize;
    let mut col_index = vec![0u32; nnz];
    let etype = vec![dir; nnz];
    let mut side = vec![0u8; nnz];
    let mut cur = row_index[..n].to_vec();

    for i in 0..n {
        let mut parents: Vec<u32> = pa[i].iter().copied().collect();
        parents.sort_unstable();
        for p in parents {
            let k = cur[i] as usize;
            col_index[k] = p;
            side[k] = 1; // head side: incoming arrow
            cur[i] += 1;
        }
        let mut children: Vec<u32> = ch[i].iter().copied().collect();
        children.sort_unstable();
        for c in children {
            let k = cur[i] as usize;
            col_index[k] = c;
            side[k] = 0; // tail side: outgoing arrow
            cur[i] += 1;
        }
    }

    CaugiGraph::from_csr(
        row_index,
        col_index,
        etype,
        side,
        true,
        template.registry.clone(),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    fn setup() -> (EdgeRegistry, u8, u8) {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();
        let u = reg.code_of("---").unwrap();
        (reg, d, u)
    }

    fn directed_pairs(dag: &Dag) -> Vec<(u32, u32)> {
        let mut out = Vec::new();
        for i in 0..dag.n() {
            for &c in dag.children_of(i) {
                out.push((i, c));
            }
        }
        out.sort_unstable();
        out
    }

    /// Every undirected edge oriented, every directed edge kept, and the
    /// skeleton unchanged -- the definition of a consistent extension, minus
    /// the v-structure condition, which the tests below check case by case.
    fn assert_extends(p: &Pdag, dag: &Dag) {
        for i in 0..p.n() {
            for &c in p.children_of(i) {
                assert!(
                    dag.children_of(i).contains(&c),
                    "directed edge {i} --> {c} was not kept"
                );
            }
            let mut skel_p: Vec<u32> = p.neighbors_of(i).to_vec();
            let mut skel_d: Vec<u32> = dag
                .parents_of(i)
                .iter()
                .chain(dag.children_of(i))
                .copied()
                .collect();
            skel_p.sort_unstable();
            skel_d.sort_unstable();
            assert_eq!(skel_p, skel_d, "skeleton differs at node {i}");
        }
    }

    #[test]
    fn dag_extension_orients_a_chain_without_a_v_structure() {
        // A--B--C extends to one of the three orientations that avoid
        // A --> B <-- C.
        let (reg, _d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(1, 2, u).unwrap();
        let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let dag = p.dag_extension().unwrap();
        assert_extends(&p, &dag);
        let pairs = directed_pairs(&dag);
        assert!(!(pairs.contains(&(0, 1)) && pairs.contains(&(2, 1))));
        assert!(p
            .enumerate_mec()
            .unwrap()
            .iter()
            .any(|d| directed_pairs(d) == pairs));
    }

    #[test]
    fn dag_extension_keeps_directed_edges_and_the_existing_v_structure() {
        // A --> B <-- C with D--B: `D --> B` would add a v-structure with
        // A and C, but they are already a v-structure at B, so the only
        // question is that D--B gets oriented and nothing else moves.
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(2, 1, d).unwrap();
        b.add_edge(3, 1, u).unwrap();
        let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let dag = p.dag_extension().unwrap();
        assert_extends(&p, &dag);
        assert!(directed_pairs(&dag).contains(&(1, 3)), "B --> D expected");
    }

    #[test]
    fn dag_extension_orients_a_triangle() {
        // A fully undirected triangle: every node is simplicial, so the
        // first one picked becomes the sink.
        let (reg, _d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(1, 2, u).unwrap();
        b.add_edge(0, 2, u).unwrap();
        let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let dag = p.dag_extension().unwrap();
        assert_extends(&p, &dag);
        assert_eq!(directed_pairs(&dag).len(), 3);
    }

    #[test]
    fn dag_extension_refuses_a_pdag_with_no_consistent_extension() {
        // The undirected four-cycle is not chordal, so no node is
        // simplicial: whichever edge is oriented first leaves a v-structure
        // that was not there.
        let (reg, _d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        for (i, j) in [(0, 1), (1, 2), (2, 3), (3, 0)] {
            b.add_edge(i, j, u).unwrap();
        }
        let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let err = p.dag_extension().unwrap_err();
        assert!(err.contains("cannot be extended to a DAG"), "{err}");
    }

    #[test]
    fn dag_extension_does_not_add_a_v_structure_off_a_parent() {
        // `A --> B, B--C, C--A`: orienting `C --> B` is fine because C and A
        // are adjacent, so the collider at B stays shielded. The weaker
        // condition (b) -- undirected neighbours pairwise adjacent -- would
        // also accept it, which is why the case above is the one that
        // separates them.
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, u).unwrap();
        b.add_edge(2, 0, u).unwrap();
        let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let dag = p.dag_extension().unwrap();
        assert_extends(&p, &dag);
        assert_eq!(directed_pairs(&dag), vec![(0, 1), (2, 0), (2, 1)]);
    }

    #[test]
    fn dag_extension_of_an_edgeless_or_already_directed_pdag_is_itself() {
        let (reg, d, _u) = setup();
        for edges in [vec![], vec![(0u32, 1u32), (1, 2)]] {
            let mut b = GraphBuilder::new_with_registry(3, true, &reg);
            for (u, v) in &edges {
                b.add_edge(*u, *v, d).unwrap();
            }
            let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
            let dag = p.dag_extension().unwrap();
            assert_extends(&p, &dag);
            assert_eq!(directed_pairs(&dag), edges);
        }
    }

    #[test]
    fn dag_extension_agrees_with_the_enumeration_on_every_small_pdag() {
        // Whatever the extension returns must be one of the DAGs in the
        // class, on every undirected graph on four nodes -- which is the
        // consistency claim, checked against an independent implementation.
        let (reg, _d, u) = setup();
        let pairs = [(0u32, 1u32), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3)];
        let mut extended = 0;
        let mut refused = 0;
        for mask in 0..(1u32 << 6) {
            let mut b = GraphBuilder::new_with_registry(4, true, &reg);
            for (k, (i, j)) in pairs.iter().enumerate() {
                if mask & (1 << k) != 0 {
                    b.add_edge(*i, *j, u).unwrap();
                }
            }
            let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();
            match p.dag_extension() {
                Ok(dag) => {
                    assert_extends(&p, &dag);
                    let want = directed_pairs(&dag);
                    assert!(
                        p.enumerate_mec()
                            .unwrap()
                            .iter()
                            .any(|d| directed_pairs(d) == want),
                        "mask {mask}: extension is not in the class"
                    );
                    extended += 1;
                }
                // An undirected graph always extends unless it is not
                // chordal, e.g. the four-cycle.
                Err(_) => refused += 1,
            }
        }
        assert_eq!(extended + refused, 64);
        assert!(refused > 0 && extended > 0);
    }

    #[test]
    fn enumerate_chain_a_b_c_has_three_dags() {
        // A--B--C: 3 valid DAGs (orientations without v-structure A->B<-C).
        let (reg, _d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(1, 2, u).unwrap();
        let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let dags = p.enumerate_mec().unwrap();
        assert_eq!(dags.len(), 3);
        assert_eq!(p.count_mec().unwrap(), 3);

        // No DAG should be A->B<-C.
        for dag in &dags {
            let pairs = directed_pairs(dag);
            assert!(!(pairs.contains(&(0, 1)) && pairs.contains(&(2, 1))));
        }
    }

    #[test]
    fn enumerate_v_structure_pdag_returns_singleton() {
        // A->B<-C is already a DAG / CPDAG with no undirected edges.
        let (reg, d, _u) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(2, 1, d).unwrap();
        let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let dags = p.enumerate_mec().unwrap();
        assert_eq!(dags.len(), 1);
        assert_eq!(p.count_mec().unwrap(), 1);
        assert_eq!(directed_pairs(&dags[0]), vec![(0, 1), (2, 1)]);
    }

    #[test]
    fn enumerate_triangle_undirected_has_six_dags() {
        // A--B, A--C, B--C (chordal 3-clique): every acyclic orientation is
        // valid (no v-structure possible), so |MEC| = 3! = 6.
        let (reg, _d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(0, 2, u).unwrap();
        b.add_edge(1, 2, u).unwrap();
        let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let dags = p.enumerate_mec().unwrap();
        assert_eq!(dags.len(), 6);
        assert_eq!(p.count_mec().unwrap(), 6);

        // All DAGs are distinct.
        let mut sigs: Vec<Vec<(u32, u32)>> = dags.iter().map(directed_pairs).collect();
        sigs.sort();
        sigs.dedup();
        assert_eq!(sigs.len(), 6);
    }

    #[test]
    fn enumerate_v_structure_plus_undirected_branch() {
        // A->C<-B, C--D: v-structure fixed; D's orientation constrained by
        // Meek R1 to D->C? No: R1 says A->C, C--D, A!~D => C->D.
        // The CPDAG closure orients C->D; so the MEC has exactly 1 DAG.
        let (reg, d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 2, d).unwrap(); // A->C
        b.add_edge(1, 2, d).unwrap(); // B->C
        b.add_edge(2, 3, u).unwrap(); // C--D
        let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let dags = p.enumerate_mec().unwrap();
        assert_eq!(dags.len(), 1);
        assert_eq!(p.count_mec().unwrap(), 1);
        let pairs = directed_pairs(&dags[0]);
        assert!(pairs.contains(&(0, 2)));
        assert!(pairs.contains(&(1, 2)));
        assert!(pairs.contains(&(2, 3)));
    }

    #[test]
    fn enumerate_two_independent_chain_components_multiplies() {
        // A--B and C--D-E (path) in two separate components, plus isolated F.
        // |MEC| = 2 (A--B) * 3 (C--D--E) = 6.
        let (reg, _d, u) = setup();
        let mut b = GraphBuilder::new_with_registry(6, true, &reg);
        b.add_edge(0, 1, u).unwrap(); // A--B
        b.add_edge(2, 3, u).unwrap(); // C--D
        b.add_edge(3, 4, u).unwrap(); // D--E
        let p = Pdag::new(Arc::new(b.finalize().unwrap())).unwrap();

        let dags = p.enumerate_mec().unwrap();
        assert_eq!(dags.len(), 6);
        assert_eq!(p.count_mec().unwrap(), 6);
    }
}
