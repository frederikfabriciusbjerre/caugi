// SPDX-License-Identifier: MIT
//! Minimal m-separator over mixed graphs.
//!
//! Implements REACHABLE, FINDNEARESTSEP, and FINDMINSEP from
//! van der Zander & Liśkiewicz, *Finding minimal d-separators in linear time
//! and applications* (UAI 2020), Section 5. The algorithms are graph-class
//! agnostic and work for DAGs, ADMGs, and ancestral graphs (and CPDAGs/RCGs/MAGs
//! when those classes expose the [`MixedGraph`] trait).
//!
//! The algorithms run in O(n + m) and avoid the moralization step required by
//! older approaches.

use crate::graph::alg::bitset;
use std::collections::{HashSet, VecDeque};

/// View over a graph that can be traversed by the mixed-graph Bayes-ball.
///
/// Implementors expose the four edge categories (parents / children / spouses /
/// undirected neighbors) and the proper-ancestors mask `pAn`. ADMGs return an
/// empty slice from [`undirected_of`](MixedGraph::undirected_of) and route
/// `anteriors_mask` to their directed-only ancestors mask, since `pAn = An`
/// when there are no undirected edges.
pub(crate) trait MixedGraph {
    fn n(&self) -> u32;
    fn parents_of(&self, v: u32) -> &[u32];
    fn children_of(&self, v: u32) -> &[u32];
    fn spouses_of(&self, v: u32) -> &[u32];
    fn undirected_of(&self, v: u32) -> &[u32];
    /// `mask[v] == true` iff `v ∈ pAn(seeds) ∪ seeds`.
    fn anteriors_mask(&self, seeds: &[u32]) -> Vec<bool>;
}

/// Mark at a node V on one of its incident edges.
///
/// `Head` = arrowhead at V; `Tail` = no arrowhead at V on a directed edge;
/// `Undir` = endpoint of an undirected edge.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Mark {
    Tail = 0,
    Head = 1,
    Undir = 2,
}

#[inline]
fn validate_node_ids(nodes: &[u32], n: u32, ctx: &str) -> Result<(), String> {
    for &v in nodes {
        if v >= n {
            return Err(format!(
                "{}: node ID {} is out of bounds (graph has {} nodes)",
                ctx, v, n
            ));
        }
    }
    Ok(())
}

/// REACHABLE(G, X, A, Z) — the paper's Bayes-ball reachability over a mixed graph.
///
/// Returns a boolean mask where `mask[v] == true` iff there is an almost-definite-status
/// walk from some node in `xs` to `v` whose every node lies in `a_mask` and on which
/// every non-collider is outside `z` and every collider is inside `z`.
///
/// Start nodes are seeded with all three arrival marks because they have no real
/// incoming edge — this lets the walk leave each start in any direction. State =
/// (arrival-mark-at-V, V), so the visited array is `[bool; 3 * n]` and the runtime
/// is O(n + m).
fn reachable_mixed<G: MixedGraph>(g: &G, xs: &[u32], a_mask: &[bool], z: &[u32]) -> Vec<bool> {
    let n = g.n() as usize;

    let mut z_mask = vec![false; n];
    for &v in z {
        z_mask[v as usize] = true;
    }

    // visited[v][m] tracks whether (mark m, node v) has been processed.
    let mut visited = vec![[false; 3]; n];
    let mut q: VecDeque<(u32, Mark)> = VecDeque::new();

    for &x in xs {
        let xi = x as usize;
        if !a_mask[xi] {
            continue;
        }
        for m in [Mark::Tail, Mark::Head, Mark::Undir] {
            if !visited[xi][m as usize] {
                visited[xi][m as usize] = true;
                q.push_back((x, m));
            }
        }
    }

    while let Some((v, in_mark)) = q.pop_front() {
        let v_in_z = z_mask[v as usize];

        // Edge V <-- N (N is a parent of V): outgoing mark at V is Head;
        // mark at N (the next state) is Tail.
        for &nbr in g.parents_of(v) {
            relax(
                &mut q,
                &mut visited,
                a_mask,
                v_in_z,
                in_mark,
                Mark::Head,
                nbr,
                Mark::Tail,
            );
        }
        // Edge V --> N: out-mark at V is Tail; mark at N is Head.
        for &nbr in g.children_of(v) {
            relax(
                &mut q,
                &mut visited,
                a_mask,
                v_in_z,
                in_mark,
                Mark::Tail,
                nbr,
                Mark::Head,
            );
        }
        // Edge V <-> N: arrowheads at both ends.
        for &nbr in g.spouses_of(v) {
            relax(
                &mut q,
                &mut visited,
                a_mask,
                v_in_z,
                in_mark,
                Mark::Head,
                nbr,
                Mark::Head,
            );
        }
        // Edge V --- N: undirected at both ends.
        for &nbr in g.undirected_of(v) {
            relax(
                &mut q,
                &mut visited,
                a_mask,
                v_in_z,
                in_mark,
                Mark::Undir,
                nbr,
                Mark::Undir,
            );
        }
    }

    let mut reached = vec![false; n];
    for v in 0..n {
        reached[v] = visited[v][0] || visited[v][1] || visited[v][2];
    }
    reached
}

#[inline]
#[allow(clippy::too_many_arguments)]
fn relax(
    q: &mut VecDeque<(u32, Mark)>,
    visited: &mut [[bool; 3]],
    a_mask: &[bool],
    v_in_z: bool,
    in_mark_at_v: Mark,
    out_mark_at_v: Mark,
    nbr: u32,
    in_mark_at_n: Mark,
) {
    let ni = nbr as usize;
    if !a_mask[ni] {
        return;
    }
    let collider = matches!(in_mark_at_v, Mark::Head) && matches!(out_mark_at_v, Mark::Head);
    let pass = if v_in_z { collider } else { !collider };
    if !pass {
        return;
    }
    if !visited[ni][in_mark_at_n as usize] {
        visited[ni][in_mark_at_n as usize] = true;
        q.push_back((nbr, in_mark_at_n));
    }
}

/// FINDNEARESTSEP(G, X, Y, I, R) from the paper.
///
/// Returns `Some(Z)` with `I ⊆ Z ⊆ R` such that Z separates `xs` from `ys` and
/// is "nearest" to `xs` (uses ancestors closer to `xs` whenever possible), or
/// `None` if no separator exists within `restrict`.
pub(crate) fn find_nearest_sep<G: MixedGraph>(
    g: &G,
    xs: &[u32],
    ys: &[u32],
    include: &[u32],
    restrict: &[u32],
) -> Result<Option<Vec<u32>>, String> {
    let n = g.n();

    validate_node_ids(xs, n, "find_nearest_sep xs")?;
    validate_node_ids(ys, n, "find_nearest_sep ys")?;
    validate_node_ids(include, n, "find_nearest_sep include")?;
    validate_node_ids(restrict, n, "find_nearest_sep restrict")?;

    if xs.is_empty() || ys.is_empty() {
        return Ok(None);
    }

    // Contract: include ⊆ restrict.
    let restrict_set: HashSet<u32> = restrict.iter().copied().collect();
    for &i in include {
        if !restrict_set.contains(&i) {
            return Ok(None);
        }
    }

    let n_us = n as usize;

    // A := pAn(X ∪ Y ∪ I).
    let mut seeds = Vec::with_capacity(xs.len() + ys.len() + include.len());
    seeds.extend_from_slice(xs);
    seeds.extend_from_slice(ys);
    seeds.extend_from_slice(include);
    seeds.sort_unstable();
    seeds.dedup();
    let a_mask = g.anteriors_mask(&seeds);

    // Z0 := R ∩ (A \ (X ∪ Y)).
    let xs_set: HashSet<u32> = xs.iter().copied().collect();
    let ys_set: HashSet<u32> = ys.iter().copied().collect();
    let mut z0_mask = vec![false; n_us];
    for &r in restrict {
        let ri = r as usize;
        if a_mask[ri] && !xs_set.contains(&r) && !ys_set.contains(&r) {
            z0_mask[ri] = true;
        }
    }
    let z0 = bitset::collect_from_mask(&z0_mask);

    // X* := REACHABLE(G, X, A, Z0).
    let x_star_mask = reachable_mixed(g, xs, &a_mask, &z0);

    // X* ∩ Y == ∅ ?
    for &y in ys {
        if x_star_mask[y as usize] {
            return Ok(None);
        }
    }

    // Z := (Z0 ∩ X*) ∪ I.
    // The published paper writes "Z ∩ X*" at this step (paper line 837);
    // that's a typo — the corresponding step in FINDMINSEPINDAG (paper line 548)
    // confirms the intended Z0.
    let mut z_mask = vec![false; n_us];
    for v in 0..n_us {
        if z0_mask[v] && x_star_mask[v] {
            z_mask[v] = true;
        }
    }
    for &i in include {
        z_mask[i as usize] = true;
    }
    Ok(Some(bitset::collect_from_mask(&z_mask)))
}

/// FINDMINSEP(G, X, Y, I, R) from the paper. Runs FINDNEARESTSEP twice (once
/// from X, once from Y restricted to the first result) to obtain a minimal
/// separator. Linear time.
pub(crate) fn find_min_msep<G: MixedGraph>(
    g: &G,
    xs: &[u32],
    ys: &[u32],
    include: &[u32],
    restrict: &[u32],
) -> Result<Option<Vec<u32>>, String> {
    let zx = match find_nearest_sep(g, xs, ys, include, restrict)? {
        Some(z) => z,
        None => return Ok(None),
    };
    let zy = match find_nearest_sep(g, ys, xs, include, &zx)? {
        Some(z) => z,
        None => return Ok(None),
    };

    let n = g.n();
    let n_us = n as usize;
    let zx_mask = bitset::mask_from(&zx, n);
    let mut result = vec![false; n_us];
    for &v in &zy {
        if zx_mask[v as usize] {
            result[v as usize] = true;
        }
    }
    for &i in include {
        result[i as usize] = true;
    }
    Ok(Some(bitset::collect_from_mask(&result)))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Small synthetic mixed graph for unit tests.
    struct TestGraph {
        n: u32,
        parents: Vec<Vec<u32>>,
        children: Vec<Vec<u32>>,
        spouses: Vec<Vec<u32>>,
        undirected: Vec<Vec<u32>>,
    }

    impl TestGraph {
        fn new(n: u32) -> Self {
            let n_us = n as usize;
            Self {
                n,
                parents: vec![Vec::new(); n_us],
                children: vec![Vec::new(); n_us],
                spouses: vec![Vec::new(); n_us],
                undirected: vec![Vec::new(); n_us],
            }
        }
        fn directed(&mut self, u: u32, v: u32) {
            self.children[u as usize].push(v);
            self.parents[v as usize].push(u);
        }
        fn bidirected(&mut self, u: u32, v: u32) {
            self.spouses[u as usize].push(v);
            self.spouses[v as usize].push(u);
        }
        fn undirected_edge(&mut self, u: u32, v: u32) {
            self.undirected[u as usize].push(v);
            self.undirected[v as usize].push(u);
        }
        fn finalize(&mut self) {
            for v in 0..self.n as usize {
                self.parents[v].sort_unstable();
                self.parents[v].dedup();
                self.children[v].sort_unstable();
                self.children[v].dedup();
                self.spouses[v].sort_unstable();
                self.spouses[v].dedup();
                self.undirected[v].sort_unstable();
                self.undirected[v].dedup();
            }
        }
    }

    impl MixedGraph for TestGraph {
        fn n(&self) -> u32 {
            self.n
        }
        fn parents_of(&self, v: u32) -> &[u32] {
            &self.parents[v as usize]
        }
        fn children_of(&self, v: u32) -> &[u32] {
            &self.children[v as usize]
        }
        fn spouses_of(&self, v: u32) -> &[u32] {
            &self.spouses[v as usize]
        }
        fn undirected_of(&self, v: u32) -> &[u32] {
            &self.undirected[v as usize]
        }
        fn anteriors_mask(&self, seeds: &[u32]) -> Vec<bool> {
            // Anteriors: closure under parents and undirected neighbors.
            let n = self.n as usize;
            let mut mask = vec![false; n];
            let mut stack: Vec<u32> = Vec::new();
            for &s in seeds {
                if !mask[s as usize] {
                    mask[s as usize] = true;
                    stack.push(s);
                }
            }
            while let Some(u) = stack.pop() {
                for &p in self.parents_of(u) {
                    if !mask[p as usize] {
                        mask[p as usize] = true;
                        stack.push(p);
                    }
                }
                for &w in self.undirected_of(u) {
                    if !mask[w as usize] {
                        mask[w as usize] = true;
                        stack.push(w);
                    }
                }
            }
            mask
        }
    }

    fn is_separator<G: MixedGraph>(g: &G, xs: &[u32], ys: &[u32], z: &[u32]) -> bool {
        // Z separates X and Y iff REACHABLE(G, X, V, Z) ∩ Y = ∅.
        let a_mask = vec![true; g.n() as usize];
        let reached = reachable_mixed(g, xs, &a_mask, z);
        !ys.iter().any(|&y| reached[y as usize])
    }

    #[test]
    fn dag_chain_minimal_sep() {
        // 0 -> 1 -> 2; minimal sep for (0, 2) is {1}.
        let mut g = TestGraph::new(3);
        g.directed(0, 1);
        g.directed(1, 2);
        g.finalize();

        let z = find_min_msep(&g, &[0], &[2], &[], &[1]).unwrap().unwrap();
        assert_eq!(z, vec![1]);
    }

    #[test]
    fn dag_fork_minimal_sep() {
        // 0 -> 1, 0 -> 2; sep for (1, 2) is {0}.
        let mut g = TestGraph::new(3);
        g.directed(0, 1);
        g.directed(0, 2);
        g.finalize();

        let z = find_min_msep(&g, &[1], &[2], &[], &[0]).unwrap().unwrap();
        assert_eq!(z, vec![0]);
    }

    #[test]
    fn dag_collider_no_sep_when_conditioning_required() {
        // 0 -> 2 <- 1; (0,1) are unconditionally m-separated, sep is {}.
        let mut g = TestGraph::new(3);
        g.directed(0, 2);
        g.directed(1, 2);
        g.finalize();

        let z = find_min_msep(&g, &[0], &[1], &[], &[2]).unwrap().unwrap();
        assert!(z.is_empty());
    }

    #[test]
    fn dag_no_separator_for_direct_edge() {
        let mut g = TestGraph::new(2);
        g.directed(0, 1);
        g.finalize();

        let res = find_min_msep(&g, &[0], &[1], &[], &[]).unwrap();
        assert!(res.is_none());
    }

    #[test]
    fn admg_bidirected_confounder_unblockable() {
        // 0 <-> 1: latent confounder, no separator possible.
        let mut g = TestGraph::new(2);
        g.bidirected(0, 1);
        g.finalize();

        let res = find_min_msep(&g, &[0], &[1], &[], &[]).unwrap();
        assert!(res.is_none());
    }

    #[test]
    fn admg_bidirected_chain_separated_by_collider_avoidance() {
        // 0 <-> 1 <-> 2: pAn({0,2}) = {0,2}, so no path; sep is {} unconditionally.
        let mut g = TestGraph::new(3);
        g.bidirected(0, 1);
        g.bidirected(1, 2);
        g.finalize();

        let z = find_min_msep(&g, &[0], &[2], &[], &[1]).unwrap().unwrap();
        assert!(z.is_empty(), "expected empty separator, got {:?}", z);
    }

    #[test]
    fn admg_directed_with_bidirected_branch() {
        // 0 -> 1, 1 <-> 2, 2 -> 3. Sep for (0, 3) requires blocking 1->...->3.
        let mut g = TestGraph::new(4);
        g.directed(0, 1);
        g.bidirected(1, 2);
        g.directed(2, 3);
        g.finalize();

        let z = find_min_msep(&g, &[0], &[3], &[], &[1, 2])
            .unwrap()
            .unwrap();
        // Z must separate.
        assert!(is_separator(&g, &[0], &[3], &z));
        // Removing any element breaks separation.
        for i in 0..z.len() {
            let mut shrunk = z.clone();
            shrunk.remove(i);
            assert!(
                !is_separator(&g, &[0], &[3], &shrunk),
                "Z = {:?} is not minimal: removing index {} still separates",
                z,
                i
            );
        }
    }

    #[test]
    fn ag_undirected_chain_minimal_sep() {
        // 0 --- 1 --- 2; sep for (0, 2) is {1}.
        let mut g = TestGraph::new(3);
        g.undirected_edge(0, 1);
        g.undirected_edge(1, 2);
        g.finalize();

        let z = find_min_msep(&g, &[0], &[2], &[], &[1]).unwrap().unwrap();
        assert_eq!(z, vec![1]);
    }

    #[test]
    fn ag_mixed_directed_undirected() {
        // 0 -> 1 --- 2; sep for (0, 2) is {1}.
        let mut g = TestGraph::new(3);
        g.directed(0, 1);
        g.undirected_edge(1, 2);
        g.finalize();

        let z = find_min_msep(&g, &[0], &[2], &[], &[1]).unwrap().unwrap();
        assert_eq!(z, vec![1]);
    }

    #[test]
    fn include_must_be_subset_of_restrict() {
        let mut g = TestGraph::new(3);
        g.directed(0, 1);
        g.directed(1, 2);
        g.finalize();

        let res = find_min_msep(&g, &[0], &[2], &[2], &[0, 1]).unwrap();
        assert!(res.is_none());
    }

    #[test]
    fn empty_inputs_return_none() {
        let mut g = TestGraph::new(2);
        g.directed(0, 1);
        g.finalize();
        assert!(find_min_msep(&g, &[], &[1], &[], &[]).unwrap().is_none());
        assert!(find_min_msep(&g, &[0], &[], &[], &[]).unwrap().is_none());
    }

    #[test]
    fn out_of_bounds_node_errors() {
        let mut g = TestGraph::new(2);
        g.directed(0, 1);
        g.finalize();
        assert!(find_min_msep(&g, &[5], &[1], &[], &[]).is_err());
        assert!(find_min_msep(&g, &[0], &[5], &[], &[]).is_err());
        assert!(find_min_msep(&g, &[0], &[1], &[5], &[]).is_err());
        assert!(find_min_msep(&g, &[0], &[1], &[], &[5]).is_err());
    }

    #[test]
    fn collider_opens_when_conditioned() {
        // M-bias: 0 -> 2, 1 -> 2 (collider at 2), 0 -> 3, 1 -> 4.
        // Sep for (3, 4) is {} unconditionally; conditioning on 2 alone opens
        // the collider so {} no longer separates.
        let mut g = TestGraph::new(5);
        g.directed(0, 2);
        g.directed(1, 2);
        g.directed(0, 3);
        g.directed(1, 4);
        g.finalize();

        let z = find_min_msep(&g, &[3], &[4], &[], &[0, 1, 2])
            .unwrap()
            .unwrap();
        assert!(is_separator(&g, &[3], &[4], &z));
        // Adding 2 to z would be a superset; that's fine, but z itself shouldn't include 2.
        assert!(!z.contains(&2), "minimal sep should not include collider 2");
    }

    #[test]
    fn include_node_is_in_result() {
        // 0 -> 1 -> 2 -> 3; force include={1}, restrict={1,2}.
        let mut g = TestGraph::new(4);
        g.directed(0, 1);
        g.directed(1, 2);
        g.directed(2, 3);
        g.finalize();

        let z = find_min_msep(&g, &[0], &[3], &[1], &[1, 2])
            .unwrap()
            .unwrap();
        assert!(z.contains(&1));
        assert!(is_separator(&g, &[0], &[3], &z));
    }

    // ── Worked examples from van der Zander & Liśkiewicz (UAI 2020) Fig. 4 ──

    #[test]
    fn paper_figure_4_g1_returns_v2() {
        // G1: V1->X, V1->V2, X->V2, V2->V3, V3->Y. Paper claims FINDMINSEPINDAG
        // returns {V2} (the algorithm's "nearest to X" choice).
        // Node ids: 0=X, 1=Y, 2=V1, 3=V2, 4=V3.
        let mut g = TestGraph::new(5);
        g.directed(2, 0); // V1 -> X
        g.directed(2, 3); // V1 -> V2
        g.directed(0, 3); // X -> V2
        g.directed(3, 4); // V2 -> V3
        g.directed(4, 1); // V3 -> Y
        g.finalize();

        let z = find_min_msep(&g, &[0], &[1], &[], &[2, 3, 4])
            .unwrap()
            .unwrap();
        assert_eq!(z, vec![3], "paper Fig. 4 G1: expected {{V2}}, got {:?}", z);
    }

    #[test]
    fn paper_figure_4_g2_returns_v2_v3() {
        // G2: V1->X, V1->V2, V3->V2, V3->Y, U->X, U->V2, V2->Y. U is unobserved
        // so it is excluded from R. Paper claims FINDMINSEPINDAG returns {V2, V3}.
        // Node ids: 0=X, 1=Y, 2=V1, 3=V2, 4=V3, 5=U.
        let mut g = TestGraph::new(6);
        g.directed(2, 0); // V1 -> X
        g.directed(2, 3); // V1 -> V2
        g.directed(4, 3); // V3 -> V2
        g.directed(4, 1); // V3 -> Y
        g.directed(5, 0); // U -> X
        g.directed(5, 3); // U -> V2
        g.directed(3, 1); // V2 -> Y
        g.finalize();

        let z = find_min_msep(&g, &[0], &[1], &[], &[2, 3, 4])
            .unwrap()
            .unwrap();
        assert_eq!(
            z,
            vec![3, 4],
            "paper Fig. 4 G2: expected {{V2, V3}}, got {:?}",
            z
        );

        // Sanity: {V2} alone does NOT separate (collider V2 opens path
        // X<-V1->V2<-V3->Y when V2 is conditioned on); {V3} alone does NOT
        // separate (chain X<-V1->V2->Y goes through V2 unconditioned).
        assert!(!is_separator(&g, &[0], &[1], &[3]));
        assert!(!is_separator(&g, &[0], &[1], &[4]));
        // {V2, V3} separates.
        assert!(is_separator(&g, &[0], &[1], &z));
    }

    #[test]
    fn paper_figure_4_g1_empty_set_is_not_separator() {
        // Paper note (Sec. 3): "for an empty set Z = ∅ all nodes are reachable,
        // so X* = Y* = V in both DAGs and condition (a) shows Z = ∅ is not a
        // separator at all." We verify that with R = ∅ no separator is found.
        let mut g = TestGraph::new(5);
        g.directed(2, 0);
        g.directed(2, 3);
        g.directed(0, 3);
        g.directed(3, 4);
        g.directed(4, 1);
        g.finalize();

        assert!(find_min_msep(&g, &[0], &[1], &[], &[]).unwrap().is_none());
    }
}
