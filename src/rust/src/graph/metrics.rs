// SPDX-License-Identifier: MIT
//! Class-agnostic Structural Hamming Distance over CaugiGraph.

use rustc_hash::FxHashMap;

use crate::{
    edges::{EdgeClass, Mark},
    graph::CaugiGraph,
};

/// Represents the semantic kind of an edge between two nodes.
/// - `Sym`: A symmetric edge (e.g., undirected `---` or bidirected `<->`).
/// - `Asym`: An asymmetric edge with direction; `is_outgoing=true` means the edge
///   points toward the neighbor (i.e., neighbor has Arrow mark).
#[derive(PartialEq, Eq, Clone, Copy)]
enum EdgeKind {
    Sym(EdgeClass),
    Asym(EdgeClass, bool),
}

/// Compute the EdgeKind for an edge at position `idx` in the graph's CSR storage.
#[inline]
fn compute_edge_kind(graph: &CaugiGraph, idx: usize) -> EdgeKind {
    let spec = &graph.registry.specs[graph.etype[idx] as usize];
    if spec.symmetric {
        EdgeKind::Sym(spec.class)
    } else {
        // Determine semantic direction: "outgoing" means neighbor has Arrow mark.
        // side[idx] stores position: 0 = tail position, 1 = head position.
        // If side=0, neighbor mark = spec.head; if side=1, neighbor mark = spec.tail.
        let neighbor_mark = if graph.side[idx] == 0 {
            spec.head
        } else {
            spec.tail
        };
        let is_outgoing = neighbor_mark == Mark::Arrow;
        EdgeKind::Asym(spec.class, is_outgoing)
    }
}

/// Advance cursor through a sorted adjacency list to find neighbor `target`.
/// Returns `(Some(edge_kind), new_cursor)` if found, `(None, new_cursor)` otherwise.
/// The cursor is advanced past any neighbors less than `target`.
#[inline]
fn find_edge_kind(
    graph: &CaugiGraph,
    target: u32,
    mut cursor: usize,
    row_end: usize,
) -> (Option<EdgeKind>, usize) {
    while cursor < row_end {
        let neighbor = graph.col_index[cursor];
        if neighbor < target {
            cursor += 1;
        } else if neighbor == target {
            return (Some(compute_edge_kind(graph, cursor)), cursor + 1);
        } else {
            // neighbor > target: target not in this row
            return (None, cursor);
        }
    }
    (None, cursor)
}

/// Advance cursor to check if any edge exists to `target` in a sorted adjacency list.
/// Returns `(true, new_cursor)` if found, `(false, new_cursor)` otherwise.
#[inline]
fn has_edge_to(
    graph: &CaugiGraph,
    target: u32,
    mut cursor: usize,
    row_end: usize,
) -> (bool, usize) {
    while cursor < row_end {
        let neighbor = graph.col_index[cursor];
        if neighbor < target {
            cursor += 1;
        } else if neighbor == target {
            return (true, cursor + 1);
        } else {
            return (false, cursor);
        }
    }
    (false, cursor)
}

/// Compute Structural Hamming Distance between two graphs with identical node ordering.
pub fn shd(truth: &CaugiGraph, guess: &CaugiGraph) -> (f64, usize) {
    shd_with_perm(truth, guess, &(0..truth.n()).collect::<Vec<_>>())
}

/// Compute Structural Hamming Distance with a node permutation mapping.
/// `perm[i]` gives the index in `guess` that corresponds to node `i` in `truth`.
pub fn shd_with_perm(truth: &CaugiGraph, guess: &CaugiGraph, perm: &[u32]) -> (f64, usize) {
    assert_eq!(truth.n(), guess.n(), "graph size mismatch");
    assert_eq!(perm.len() as u32, truth.n(), "perm length mismatch");
    let n = truth.n() as usize;
    if n <= 1 {
        return (0.0, 0);
    }

    let mut distance = 0usize;
    // Reuse HashMap across iterations to avoid repeated allocations.
    // FxHashMap is faster than std HashMap for integer keys.
    let mut guess_edges: FxHashMap<u32, EdgeKind> = FxHashMap::default();

    for u in 0..n {
        let row_t = truth.row_range(u as u32);
        let row_start = row_t.start;
        let row_end = row_t.end;
        let u_in_guess = perm[u];

        // Build a map of guess's edges for this row.
        // Necessary because perm[v] values are not in sorted order,
        // so we cannot use the sorted cursor traversal optimization.
        guess_edges.clear();
        for idx in guess.row_range(u_in_guess) {
            let neighbor = guess.col_index[idx];
            let kind = compute_edge_kind(guess, idx);
            guess_edges.insert(neighbor, kind);
        }

        let mut cursor_t = row_start;
        for v in (u + 1)..n {
            let (edge_in_truth, new_cursor) = find_edge_kind(truth, v as u32, cursor_t, row_end);
            cursor_t = new_cursor;

            let v_in_guess = perm[v];
            let edge_in_guess = guess_edges.get(&v_in_guess).copied();

            if edge_in_truth != edge_in_guess {
                distance += 1;
            }
        }
    }

    let num_pairs = n * (n - 1) / 2;
    ((distance as f64) / (num_pairs as f64), distance)
}

/// Compute skeleton Hamming Distance (ignores edge types and directions).
pub fn hd(truth: &CaugiGraph, guess: &CaugiGraph) -> (f64, usize) {
    assert_eq!(truth.n(), guess.n(), "graph size mismatch");
    let n = truth.n() as usize;
    if n <= 1 {
        return (0.0, 0);
    }

    let mut distance = 0usize;
    for u in 0..n {
        let row_t = truth.row_range(u as u32);
        let row_g = guess.row_range(u as u32);

        let mut cursor_t = row_t.start;
        let mut cursor_g = row_g.start;

        for v in (u + 1)..n {
            let (has_edge_t, new_cursor_t) = has_edge_to(truth, v as u32, cursor_t, row_t.end);
            let (has_edge_g, new_cursor_g) = has_edge_to(guess, v as u32, cursor_g, row_g.end);

            // XOR: count as difference if exactly one graph has the edge
            if has_edge_t ^ has_edge_g {
                distance += 1;
            }

            cursor_t = new_cursor_t;
            cursor_g = new_cursor_g;
        }
    }

    let num_pairs = n * (n - 1) / 2;
    ((distance as f64) / (num_pairs as f64), distance)
}

#[cfg(feature = "gadjid")]
pub mod aid {
    use crate::edges::EdgeClass;
    use crate::graph::CaugiGraph;
    use crate::graph::{dag::Dag, pdag::Pdag};
    use gadjid::PDAG as GPDAG;

    /// Input for AID functions. Only DAG or PDAG accepted.
    pub enum AidInput<'a> {
        Dag(&'a Dag),
        Pdag(&'a Pdag),
    }

    /// Build a gadjid PDAG. If `inv_guess_to_true` is Some, reindex nodes using that mapping.
    /// `inv_guess_to_true[j] = i` means: guess-index `j` should appear at position `i` in the true order.
    fn to_gadjid_pdag_with_map(
        x: AidInput<'_>,
        inv_guess_to_true: Option<&[usize]>,
    ) -> Result<GPDAG, String> {
        match x {
            AidInput::Dag(d) => {
                let n = d.n() as usize;
                if let Some(inv) = inv_guess_to_true {
                    if inv.len() != n {
                        return Err("index map length does not match graph size".into());
                    }
                }
                let mut a = vec![vec![0i8; n]; n];
                let core: &CaugiGraph = d.core_ref();
                for u in 0..n as u32 {
                    for k in core.row_range(u) {
                        let spec = core.spec(k);
                        // Use mark helper: is_outgoing_arrow means u -> v
                        if matches!(spec.class, EdgeClass::Directed) && core.is_outgoing_arrow(k) {
                            // u -> v in DAG
                            let u0 = u as usize;
                            let v0 = core.col_index[k] as usize;
                            let ur = inv_guess_to_true.map_or(u0, |inv| inv[u0]);
                            let vr = inv_guess_to_true.map_or(v0, |inv| inv[v0]);
                            a[ur][vr] = 1;
                        }
                    }
                }
                Ok(GPDAG::from_row_to_column_vecvec(a))
            }
            AidInput::Pdag(g) => {
                if !g.is_cpdag() {
                    return Err("Expected CPDAG input; got a PDAG that is not a CPDAG".into());
                }
                let n = g.n() as usize;
                if let Some(inv) = inv_guess_to_true {
                    if inv.len() != n {
                        return Err("index map length does not match graph size".into());
                    }
                }
                let mut a = vec![vec![0i8; n]; n];

                // directed edges p -> v
                for v in 0..g.n() {
                    for &p in g.parents_of(v) {
                        let p0 = p as usize;
                        let v0 = v as usize;
                        let pr = inv_guess_to_true.map_or(p0, |inv| inv[p0]);
                        let vr = inv_guess_to_true.map_or(v0, |inv| inv[v0]);
                        a[pr][vr] = 1;
                    }
                }
                // undirected edges v --- w
                for v in 0..g.n() {
                    for &w in g.undirected_of(v) {
                        let i0 = v as usize;
                        let j0 = w as usize;
                        let ir = inv_guess_to_true.map_or(i0, |inv| inv[i0]);
                        let jr = inv_guess_to_true.map_or(j0, |inv| inv[j0]);
                        a[ir][jr] = 2;
                        a[jr][ir] = 2;
                    }
                }
                Ok(GPDAG::from_row_to_column_vecvec(a))
            }
        }
    }

    /// Aligned variants. `inv_guess_to_true[j] = i`.
    pub fn ancestor_aid_align(
        true_g: AidInput<'_>,
        guess_g: AidInput<'_>,
        inv_guess_to_true: &[usize],
    ) -> Result<(f64, usize), String> {
        let t = to_gadjid_pdag_with_map(true_g, None)?;
        let g = to_gadjid_pdag_with_map(guess_g, Some(inv_guess_to_true))?;
        Ok(gadjid::graph_operations::ancestor_aid(&t, &g))
    }
    pub fn oset_aid_align(
        true_g: AidInput<'_>,
        guess_g: AidInput<'_>,
        inv_guess_to_true: &[usize],
    ) -> Result<(f64, usize), String> {
        let t = to_gadjid_pdag_with_map(true_g, None)?;
        let g = to_gadjid_pdag_with_map(guess_g, Some(inv_guess_to_true))?;
        Ok(gadjid::graph_operations::oset_aid(&t, &g))
    }
    pub fn parent_aid_align(
        true_g: AidInput<'_>,
        guess_g: AidInput<'_>,
        inv_guess_to_true: &[usize],
    ) -> Result<(f64, usize), String> {
        let t = to_gadjid_pdag_with_map(true_g, None)?;
        let g = to_gadjid_pdag_with_map(guess_g, Some(inv_guess_to_true))?;
        Ok(gadjid::graph_operations::parent_aid(&t, &g))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    #[test]
    fn identical_zero_shd() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let e_dir = reg.code_of("-->").unwrap();

        let mut gb = GraphBuilder::new_with_registry(3, true, &reg);
        gb.add_edge(0, 1, e_dir).unwrap();
        gb.add_edge(0, 2, e_dir).unwrap();
        let core = gb.finalize().unwrap();

        assert_eq!(shd(&core, &core), (0.0, 0));
    }

    #[test]
    fn reversed_direction_counts_one() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let e_dir = reg.code_of("-->").unwrap();

        // truth: 0->1
        let mut gb_t = GraphBuilder::new_with_registry(2, true, &reg);
        gb_t.add_edge(0, 1, e_dir).unwrap();
        let core_t = gb_t.finalize().unwrap();

        // guess: 1->0
        let mut gb_g = GraphBuilder::new_with_registry(2, true, &reg);
        gb_g.add_edge(1, 0, e_dir).unwrap();
        let core_g = gb_g.finalize().unwrap();

        assert_eq!(shd(&core_t, &core_g), (1.0, 1));
    }

    #[test]
    fn extra_edge_counts_once() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let e_dir = reg.code_of("-->").unwrap();

        // truth: 0->1
        let mut gb_t = GraphBuilder::new_with_registry(3, true, &reg);
        gb_t.add_edge(0, 1, e_dir).unwrap();
        let core_t = gb_t.finalize().unwrap();

        // guess: 0->1 plus 0->2
        let mut gb_g = GraphBuilder::new_with_registry(3, true, &reg);
        gb_g.add_edge(0, 1, e_dir).unwrap();
        gb_g.add_edge(0, 2, e_dir).unwrap();
        let core_g = gb_g.finalize().unwrap();

        assert_eq!(shd(&core_t, &core_g), (1.0 / 3.0, 1));
    }

    #[test]
    fn undirected_vs_bidirected_different() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let e_und = reg.code_of("---").unwrap();
        let e_bi = reg.code_of("<->").unwrap();

        // truth: 1---2
        let mut gb_t = GraphBuilder::new_with_registry(3, true, &reg);
        gb_t.add_edge(1, 2, e_und).unwrap();
        let core_t = gb_t.finalize().unwrap();

        // guess: 1<->2
        let mut gb_g = GraphBuilder::new_with_registry(3, true, &reg);
        gb_g.add_edge(1, 2, e_bi).unwrap();
        let core_g = gb_g.finalize().unwrap();

        assert_eq!(shd(&core_t, &core_g), (1.0 / 3.0, 1));
    }

    #[test]
    fn mixed_graph_partial_diffs() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let e_dir = reg.code_of("-->").unwrap();
        let e_und = reg.code_of("---").unwrap();
        let e_bi = reg.code_of("<->").unwrap();

        // truth: 0->1, 1---2
        let mut gb_t = GraphBuilder::new_with_registry(3, true, &reg);
        gb_t.add_edge(0, 1, e_dir).unwrap();
        gb_t.add_edge(1, 2, e_und).unwrap();
        let core_t = gb_t.finalize().unwrap();

        // guess: 0->1, 1<->2
        let mut gb_g = GraphBuilder::new_with_registry(3, true, &reg);
        gb_g.add_edge(0, 1, e_dir).unwrap();
        gb_g.add_edge(1, 2, e_bi).unwrap();
        let core_g = gb_g.finalize().unwrap();

        assert_eq!(shd(&core_t, &core_g), (1.0 / 3.0, 1));
    }

    #[test]
    fn different_number_of_nodes() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let e_dir = reg.code_of("-->").unwrap();

        let mut gb1 = GraphBuilder::new_with_registry(2, true, &reg);
        gb1.add_edge(0, 1, e_dir).unwrap();
        let core1 = gb1.finalize().unwrap();

        let mut gb2 = GraphBuilder::new_with_registry(3, true, &reg);
        gb2.add_edge(0, 1, e_dir).unwrap();
        let core2 = gb2.finalize().unwrap();

        let result = std::panic::catch_unwind(|| shd(&core1, &core2));
        assert!(result.is_err());
    }

    #[test]
    fn shd_custom_glyph_opposite_same_direction_is_zero() {
        use crate::edges::{EdgeClass, EdgeRegistry, EdgeSpec, Mark};
        use crate::graph::builder::GraphBuilder;
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        reg.register(EdgeSpec {
            glyph: "<--".into(),
            tail: Mark::Arrow,
            head: Mark::Tail,
            symmetric: false,
            class: EdgeClass::Directed,
        })
        .unwrap();
        let dir = reg.code_of("-->").unwrap();
        let rev = reg.code_of("<--").unwrap();

        // A -> B
        let mut b1 = GraphBuilder::new_with_registry(2, true, &reg);
        b1.add_edge(0, 1, dir).unwrap();
        let c1 = b1.finalize().unwrap();

        // B <-- A  (also A -> B)
        let mut b2 = GraphBuilder::new_with_registry(2, true, &reg);
        b2.add_edge(1, 0, rev).unwrap();
        let c2 = b2.finalize().unwrap();

        assert_eq!(shd(&c1, &c2), (0.0, 0));
    }

    #[test]
    fn hd_identical_zero() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let dir = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, dir).unwrap();
        b.add_edge(0, 2, dir).unwrap();
        let c = b.finalize().unwrap();
        assert_eq!(hd(&c, &c), (0.0, 0));
    }

    #[test]
    fn hd_direction_ignored() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let dir = reg.code_of("-->").unwrap();
        // 0->1 vs 1->0 should be HD=0
        let mut bt = GraphBuilder::new_with_registry(2, true, &reg);
        bt.add_edge(0, 1, dir).unwrap();
        let ct = bt.finalize().unwrap();
        let mut bg = GraphBuilder::new_with_registry(2, true, &reg);
        bg.add_edge(1, 0, dir).unwrap();
        let cg = bg.finalize().unwrap();
        assert_eq!(hd(&ct, &cg), (0.0, 0));
    }

    #[test]
    fn hd_undirected_vs_bidirected_ignored() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let und = reg.code_of("---").unwrap();
        let bi = reg.code_of("<->").unwrap();
        let mut bt = GraphBuilder::new_with_registry(3, true, &reg);
        bt.add_edge(1, 2, und).unwrap();
        let ct = bt.finalize().unwrap();
        let mut bg = GraphBuilder::new_with_registry(3, true, &reg);
        bg.add_edge(1, 2, bi).unwrap();
        let cg = bg.finalize().unwrap();
        assert_eq!(hd(&ct, &cg), (0.0, 0));
    }

    #[test]
    fn hd_extra_edge_counts_once() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let dir = reg.code_of("-->").unwrap();
        let mut bt = GraphBuilder::new_with_registry(3, true, &reg);
        bt.add_edge(0, 1, dir).unwrap();
        let ct = bt.finalize().unwrap();
        let mut bg = GraphBuilder::new_with_registry(3, true, &reg);
        bg.add_edge(0, 1, dir).unwrap();
        bg.add_edge(0, 2, dir).unwrap();
        let cg = bg.finalize().unwrap();
        assert_eq!(hd(&ct, &cg), (1.0 / 3.0, 1));
    }

    #[test]
    fn hd_size_mismatch_panics() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let dir = reg.code_of("-->").unwrap();
        let mut b1 = GraphBuilder::new_with_registry(2, true, &reg);
        b1.add_edge(0, 1, dir).unwrap();
        let c1 = b1.finalize().unwrap();
        let mut b2 = GraphBuilder::new_with_registry(3, true, &reg);
        b2.add_edge(0, 1, dir).unwrap();
        let c2 = b2.finalize().unwrap();
        let res = std::panic::catch_unwind(|| hd(&c1, &c2));
        assert!(res.is_err());
    }

    #[cfg(feature = "gadjid")]
    #[test]
    fn aid_to_gadjid_map_length_mismatch_errors() {
        use super::aid::{ancestor_aid_align, AidInput};
        use crate::graph::dag::Dag;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // n = 3 DAG
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let dag = Dag::new(std::sync::Arc::new(b.finalize().unwrap())).unwrap();

        // Wrong-length inverse map (2 instead of 3)
        let bad_inv = [0usize, 1usize];
        let err = ancestor_aid_align(AidInput::Dag(&dag), AidInput::Dag(&dag), &bad_inv);
        assert!(
            matches!(err, Err(msg) if msg.contains("index map length does not match graph size"))
        );
    }

    #[cfg(feature = "gadjid")]
    #[test]
    fn aid_to_gadjid_rejects_non_cpdag() {
        use super::aid::{oset_aid_align, AidInput};
        use crate::graph::pdag::Pdag;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let u = reg.code_of("---").unwrap();

        // Build a PDAG that is valid as a PDAG but NOT a CPDAG: undirected 4-cycle without chord
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(1, 2, u).unwrap();
        b.add_edge(2, 3, u).unwrap();
        b.add_edge(3, 0, u).unwrap();
        let p = Pdag::new(std::sync::Arc::new(b.finalize().unwrap())).unwrap();
        assert!(!p.is_cpdag());

        let inv = [0usize, 1usize, 2usize, 3usize];
        let err = oset_aid_align(AidInput::Pdag(&p), AidInput::Pdag(&p), &inv);
        assert!(matches!(err, Err(msg) if msg.contains("Expected CPDAG")));
    }

    #[cfg(feature = "gadjid")]
    #[test]
    fn aid_align_identical_dag_zero_errors() {
        use super::aid::{ancestor_aid_align, oset_aid_align, parent_aid_align, AidInput};
        use crate::graph::dag::Dag;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // 0 -> 1 -> 2
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let dag = Dag::new(std::sync::Arc::new(b.finalize().unwrap())).unwrap();

        let inv = [0usize, 1usize, 2usize];
        assert_eq!(
            ancestor_aid_align(AidInput::Dag(&dag), AidInput::Dag(&dag), &inv)
                .unwrap()
                .1,
            0
        );
        assert_eq!(
            oset_aid_align(AidInput::Dag(&dag), AidInput::Dag(&dag), &inv)
                .unwrap()
                .1,
            0
        );
        assert_eq!(
            parent_aid_align(AidInput::Dag(&dag), AidInput::Dag(&dag), &inv)
                .unwrap()
                .1,
            0
        );
    }

    #[cfg(feature = "gadjid")]
    #[test]
    fn aid_align_permutation_corrected_by_inverse_map() {
        use super::aid::{ancestor_aid_align, oset_aid_align, parent_aid_align, AidInput};
        use crate::graph::dag::Dag;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // True DAG: 0 -> 1 -> 2
        let mut bt = GraphBuilder::new_with_registry(3, true, &reg);
        bt.add_edge(0, 1, d).unwrap();
        bt.add_edge(1, 2, d).unwrap();
        let t = Dag::new(std::sync::Arc::new(bt.finalize().unwrap())).unwrap();

        // Guess DAG is relabeled: 1 -> 2, 2 -> 0  (permutation [1,2,0])
        let mut bg = GraphBuilder::new_with_registry(3, true, &reg);
        bg.add_edge(1, 2, d).unwrap();
        bg.add_edge(2, 0, d).unwrap();
        let g = Dag::new(std::sync::Arc::new(bg.finalize().unwrap())).unwrap();

        // inv_guess_to_true[j] = i  => inverse of [1,2,0] is [2,0,1]
        let inv = [2usize, 0usize, 1usize];

        assert_eq!(
            ancestor_aid_align(AidInput::Dag(&t), AidInput::Dag(&g), &inv)
                .unwrap()
                .1,
            0
        );
        assert_eq!(
            oset_aid_align(AidInput::Dag(&t), AidInput::Dag(&g), &inv)
                .unwrap()
                .1,
            0
        );
        assert_eq!(
            parent_aid_align(AidInput::Dag(&t), AidInput::Dag(&g), &inv)
                .unwrap()
                .1,
            0
        );
    }

    #[cfg(feature = "gadjid")]
    #[test]
    fn aid_align_cpdag_identical_zero_errors() {
        use super::aid::{ancestor_aid_align, oset_aid_align, parent_aid_align, AidInput};
        use crate::graph::pdag::Pdag;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // CPDAG: v-structure 0 -> 2 <- 1 (collider at 2)
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let p = Pdag::new(std::sync::Arc::new(b.finalize().unwrap())).unwrap();
        assert!(p.is_cpdag());

        let inv = [0usize, 1usize, 2usize];
        assert_eq!(
            ancestor_aid_align(AidInput::Pdag(&p), AidInput::Pdag(&p), &inv)
                .unwrap()
                .1,
            0
        );
        assert_eq!(
            oset_aid_align(AidInput::Pdag(&p), AidInput::Pdag(&p), &inv)
                .unwrap()
                .1,
            0
        );
        assert_eq!(
            parent_aid_align(AidInput::Pdag(&p), AidInput::Pdag(&p), &inv)
                .unwrap()
                .1,
            0
        );
    }

    #[cfg(feature = "gadjid")]
    #[test]
    fn aid_align_cpdag_structure_difference_counts_mistake() {
        use super::aid::{oset_aid_align, AidInput};
        use crate::graph::pdag::Pdag;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // True CPDAG: v-structure 0 -> 2 <- 1 (collider at 2)
        let mut bt = GraphBuilder::new_with_registry(3, true, &reg);
        bt.add_edge(0, 2, d).unwrap();
        bt.add_edge(1, 2, d).unwrap();
        let p_true = Pdag::new(std::sync::Arc::new(bt.finalize().unwrap())).unwrap();
        assert!(p_true.is_cpdag());

        // Guess CPDAG: different v-structure 0 -> 1 <- 2 (collider at 1 instead of 2)
        let mut bg = GraphBuilder::new_with_registry(3, true, &reg);
        bg.add_edge(0, 1, d).unwrap();
        bg.add_edge(2, 1, d).unwrap();
        let p_guess = Pdag::new(std::sync::Arc::new(bg.finalize().unwrap())).unwrap();
        assert!(p_guess.is_cpdag());

        let inv = [0usize, 1usize, 2usize];
        let (_f, m) =
            oset_aid_align(AidInput::Pdag(&p_true), AidInput::Pdag(&p_guess), &inv).unwrap();
        assert!(m > 0);
    }

    #[test]
    fn shd_finds_edge_when_neighbor_gt_target() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;

        // t: edge 0->2 only; g: empty. For pair (u=0,v=1), row has neighbor=2>1 ⇒ early None.
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut bt = GraphBuilder::new_with_registry(3, true, &reg);
        bt.add_edge(0, 2, d).unwrap();
        let t = bt.finalize().unwrap();

        let bg = GraphBuilder::new_with_registry(3, true, &reg);
        let g = bg.finalize().unwrap();

        assert_eq!(shd(&t, &g), (1.0 / 3.0, 1));
    }

    #[test]
    fn hd_returns_false_when_neighbor_gt_target() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;

        // Same shape as above. For has_edge_to at (0,1) we hit neighbor>target ⇒ false.
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut bt = GraphBuilder::new_with_registry(3, true, &reg);
        bt.add_edge(0, 2, d).unwrap();
        let t = bt.finalize().unwrap();

        let bg = GraphBuilder::new_with_registry(3, true, &reg);
        let g = bg.finalize().unwrap();

        assert_eq!(hd(&t, &g), (1.0 / 3.0, 1));
    }

    #[test]
    fn shd_with_perm_n_le_1_fast_path() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();

        let b1 = GraphBuilder::new_with_registry(1, true, &reg);
        let t = b1.finalize().unwrap();
        let b2 = GraphBuilder::new_with_registry(1, true, &reg);
        let g = b2.finalize().unwrap();

        let (f, d) = shd_with_perm(&t, &g, &[0]);
        assert_eq!((f, d), (0.0, 0));
    }

    #[test]
    fn hd_n_le_1_fast_path() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();

        let b1 = GraphBuilder::new_with_registry(1, true, &reg);
        let t = b1.finalize().unwrap();
        let b2 = GraphBuilder::new_with_registry(1, true, &reg);
        let g = b2.finalize().unwrap();

        let (f, d) = hd(&t, &g);
        assert_eq!((f, d), (0.0, 0));
    }

    #[cfg(feature = "gadjid")]
    #[test]
    fn aid_pdag_inv_length_err_line_hit() {
        use super::aid::{oset_aid_align, AidInput};
        use crate::graph::pdag::Pdag;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // Build a valid CPDAG with n=3: v-structure 0->2<-1
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let p = Pdag::new(std::sync::Arc::new(b.finalize().unwrap())).unwrap();
        assert!(p.is_cpdag());

        // Wrong-length inverse map to hit the PDAG arm's length check.
        let bad_inv = [0usize, 1usize];
        let err = oset_aid_align(AidInput::Pdag(&p), AidInput::Pdag(&p), &bad_inv).unwrap_err();
        assert!(err.contains("index map length does not match graph size"));
    }

    /// Test that shd_with_perm correctly handles non-identity permutations.
    /// This is the exact bug case: same edges but different node orderings.
    /// Graph t: nodes A=0, B=1, C=2, D=3 with edges A---B, A-->C, D-->C
    /// Graph g: nodes D=0, C=1, A=2, B=3 with same logical edges
    /// Permutation maps t's indices to g's: perm = [2, 3, 1, 0]
    #[test]
    fn shd_with_perm_different_node_order_same_edges() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let dir = reg.code_of("-->").unwrap();
        let und = reg.code_of("---").unwrap();

        // Graph t: A=0, B=1, C=2, D=3
        // Edges: A---B (0---1), A-->C (0-->2), D-->C (3-->2)
        let mut bt = GraphBuilder::new_with_registry(4, true, &reg);
        bt.add_edge(0, 1, und).unwrap(); // A --- B
        bt.add_edge(0, 2, dir).unwrap(); // A --> C
        bt.add_edge(3, 2, dir).unwrap(); // D --> C
        let t = bt.finalize().unwrap();

        // Graph g: D=0, C=1, A=2, B=3
        // Same logical edges: A---B (2---3), A-->C (2-->1), D-->C (0-->1)
        let mut bg = GraphBuilder::new_with_registry(4, true, &reg);
        bg.add_edge(2, 3, und).unwrap(); // A --- B
        bg.add_edge(2, 1, dir).unwrap(); // A --> C
        bg.add_edge(0, 1, dir).unwrap(); // D --> C
        let g = bg.finalize().unwrap();

        // perm[i] = index in g that corresponds to node i in t
        // t: A=0 -> g: A=2, so perm[0] = 2
        // t: B=1 -> g: B=3, so perm[1] = 3
        // t: C=2 -> g: C=1, so perm[2] = 1
        // t: D=3 -> g: D=0, so perm[3] = 0
        let perm = [2u32, 3, 1, 0];

        let (norm, count) = shd_with_perm(&t, &g, &perm);
        assert_eq!(
            count, 0,
            "Same edges with different node order should have SHD=0"
        );
        assert_eq!(norm, 0.0);
    }

    /// Test shd_with_perm with reversed permutation.
    #[test]
    fn shd_with_perm_reversed_order() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let dir = reg.code_of("-->").unwrap();

        // Graph t: 0->1->2
        let mut bt = GraphBuilder::new_with_registry(3, true, &reg);
        bt.add_edge(0, 1, dir).unwrap();
        bt.add_edge(1, 2, dir).unwrap();
        let t = bt.finalize().unwrap();

        // Graph g: same structure but nodes reversed: 2->1->0
        // In g's indexing: 0->1->2 (same as t)
        // But we'll build it as if logical order is reversed
        let mut bg = GraphBuilder::new_with_registry(3, true, &reg);
        bg.add_edge(2, 1, dir).unwrap(); // logical 0->1
        bg.add_edge(1, 0, dir).unwrap(); // logical 1->2
        let g = bg.finalize().unwrap();

        // perm: t's node i corresponds to g's node (2-i)
        let perm = [2u32, 1, 0];

        let (norm, count) = shd_with_perm(&t, &g, &perm);
        assert_eq!(count, 0);
        assert_eq!(norm, 0.0);
    }

    /// Test shd_with_perm correctly detects differences with permutation.
    #[test]
    fn shd_with_perm_detects_difference() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let dir = reg.code_of("-->").unwrap();
        let und = reg.code_of("---").unwrap();

        // Graph t: 0->1, 0->2
        let mut bt = GraphBuilder::new_with_registry(3, true, &reg);
        bt.add_edge(0, 1, dir).unwrap();
        bt.add_edge(0, 2, dir).unwrap();
        let t = bt.finalize().unwrap();

        // Graph g: 0->1, 0---2 (undirected instead of directed)
        // With permutation [1, 2, 0] (rotated)
        // In g's ordering: node 1 in t -> node 2 in g, etc.
        let mut bg = GraphBuilder::new_with_registry(3, true, &reg);
        bg.add_edge(1, 2, dir).unwrap(); // corresponds to 0->1 in t
        bg.add_edge(1, 0, und).unwrap(); // corresponds to 0---2 in t (DIFFERENT!)
        let g = bg.finalize().unwrap();

        let perm = [1u32, 2, 0];

        let (_, count) = shd_with_perm(&t, &g, &perm);
        assert_eq!(
            count, 1,
            "Should detect one difference: directed vs undirected"
        );
    }

    /// Test shd_with_perm with larger graph and complex permutation.
    #[test]
    fn shd_with_perm_larger_graph() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let dir = reg.code_of("-->").unwrap();
        let und = reg.code_of("---").unwrap();
        let bi = reg.code_of("<->").unwrap();

        // Graph t: 6 nodes with various edges
        // 0->1, 1->2, 2---3, 3<->4, 4->5
        let mut bt = GraphBuilder::new_with_registry(6, true, &reg);
        bt.add_edge(0, 1, dir).unwrap();
        bt.add_edge(1, 2, dir).unwrap();
        bt.add_edge(2, 3, und).unwrap();
        bt.add_edge(3, 4, bi).unwrap();
        bt.add_edge(4, 5, dir).unwrap();
        let t = bt.finalize().unwrap();

        // Graph g: same edges but with permutation [3, 5, 1, 4, 0, 2]
        // t's node 0 -> g's node 3
        // t's node 1 -> g's node 5
        // t's node 2 -> g's node 1
        // t's node 3 -> g's node 4
        // t's node 4 -> g's node 0
        // t's node 5 -> g's node 2
        let mut bg = GraphBuilder::new_with_registry(6, true, &reg);
        bg.add_edge(3, 5, dir).unwrap(); // 0->1 in t
        bg.add_edge(5, 1, dir).unwrap(); // 1->2 in t
        bg.add_edge(1, 4, und).unwrap(); // 2---3 in t
        bg.add_edge(4, 0, bi).unwrap(); // 3<->4 in t
        bg.add_edge(0, 2, dir).unwrap(); // 4->5 in t
        let g = bg.finalize().unwrap();

        let perm = [3u32, 5, 1, 4, 0, 2];

        let (norm, count) = shd_with_perm(&t, &g, &perm);
        assert_eq!(
            count, 0,
            "Same edges with complex permutation should have SHD=0"
        );
        assert_eq!(norm, 0.0);
    }
}
