// SPDX-License-Identifier: MIT
//! From a MAG to the PAG of its Markov equivalence class.

use super::marked::MarkedGraph;
use crate::edges::Mark;
use crate::graph::ag::Ag;
use crate::graph::CaugiGraph;

/// The PAG of `mag`'s Markov equivalence class, as a CSR core.
pub(crate) fn pag_of_mag(mag: &Ag) -> Result<CaugiGraph, String> {
    marks_of_mag(mag)?.to_core(&mag.core_ref().registry)
}

/// The marks of the PAG of `mag`'s Markov equivalence class.
///
/// Starts from `mag`'s skeleton with every mark a circle, orients the
/// unshielded colliders of `mag` (shared by every member), and closes under
/// R1-R10, with R4 reading collider status off `mag`. No separating sets are
/// needed because a member is in hand.
fn marks_of_mag(mag: &Ag) -> Result<MarkedGraph, String> {
    let m = MarkedGraph::from_core(mag.core_ref())?;
    let mut p = m.with_circles();
    for b in 0..m.n() {
        let into_b: Vec<usize> = m.slots(b).filter(|&k| m.near(k) == Mark::Arrow).collect();
        for (i, &ka) in into_b.iter().enumerate() {
            for &kc in &into_b[i + 1..] {
                if !m.adjacent(m.col(ka), m.col(kc)) {
                    p.set_slot(ka, Mark::Arrow);
                    p.set_slot(kc, Mark::Arrow);
                }
            }
        }
    }
    p.close(&m);
    Ok(p)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use std::sync::Arc;

    /// Build a MAG from glyphs, then its PAG.
    fn pag_of(n: u32, edges: &[(u32, u32, &str)]) -> MarkedGraph {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let mut b = GraphBuilder::new_with_registry(n, true, &reg);
        for &(u, v, glyph) in edges {
            b.add_edge(u, v, reg.code_of(glyph).unwrap()).unwrap();
        }
        let mag = Ag::new(Arc::new(b.finalize().unwrap())).expect("not a MAG");
        marks_of_mag(&mag).expect("marks_of_mag failed")
    }

    /// The glyph of the edge `{i, j}` as `<mark at i>-<mark at j>`.
    fn glyph(p: &MarkedGraph, i: u32, j: u32) -> String {
        let l = match p.mark_at(i, j) {
            Some(Mark::Arrow) => '<',
            Some(Mark::Tail) => '-',
            Some(Mark::Circle) => 'o',
            _ => return "none".into(),
        };
        let r = match p.mark_at(j, i) {
            Some(Mark::Arrow) => '>',
            Some(Mark::Tail) => '-',
            Some(Mark::Circle) => 'o',
            _ => return "none".into(),
        };
        format!("{}-{}", l, r)
    }

    // The expectations below are ported from `CausalStructures.jl`'s
    // `test-mag-to-pag.jl`, an independent implementation of the same
    // semantics. Its R4 cases in particular exercise discriminating paths,
    // which the four-node ground truth barely reaches.

    #[test]
    fn unshielded_collider_gets_invariant_arrowheads() {
        // A --> B <-- C, A and C non-adjacent.
        let p = pag_of(3, &[(0, 1, "-->"), (2, 1, "-->")]);
        assert_eq!(glyph(&p, 0, 1), "o->");
        assert_eq!(glyph(&p, 2, 1), "o->");
    }

    #[test]
    fn collider_from_a_latent_free_dag() {
        // A --> B --> D <-- C; only the marks at D are invariant.
        let p = pag_of(4, &[(0, 1, "-->"), (1, 3, "-->"), (2, 3, "-->")]);
        assert_eq!(glyph(&p, 0, 1), "o-o"); // reversible: no collider at B
        assert_eq!(glyph(&p, 1, 3), "o->");
        assert_eq!(glyph(&p, 2, 3), "o->");
    }

    #[test]
    fn directed_chain_has_no_invariant_marks() {
        // A --> B --> C is equivalent to the reversed chain and to the fork.
        let p = pag_of(3, &[(0, 1, "-->"), (1, 2, "-->")]);
        assert_eq!(glyph(&p, 0, 1), "o-o");
        assert_eq!(glyph(&p, 1, 2), "o-o");
    }

    #[test]
    fn single_edge_has_no_invariant_marks() {
        for g in ["-->", "<->"] {
            let p = pag_of(2, &[(0, 1, g)]);
            assert_eq!(glyph(&p, 0, 1), "o-o", "for a lone `{}` edge", g);
        }
    }

    #[test]
    fn rule_1_propagates_a_tail_off_a_collider() {
        // A --> C <-- B with C --> D, and A,D and B,D non-adjacent. The
        // collider gives A o-> C <-o B; R1 then orients C --> D.
        let p = pag_of(4, &[(0, 2, "-->"), (1, 2, "-->"), (2, 3, "-->")]);
        assert_eq!(glyph(&p, 0, 2), "o->");
        assert_eq!(glyph(&p, 1, 2), "o->");
        assert_eq!(glyph(&p, 2, 3), "-->");
    }

    #[test]
    fn rule_4_orients_a_collider_on_a_discriminating_path() {
        // Discriminating path <D, A, B, C> for B: D <-> A <-> B with A --> C
        // and D not adjacent to C. B <-> C makes B a collider, so R4 keeps
        // both arrowheads.
        // nodes: 0 = D, 1 = A, 2 = B, 3 = C
        let p = pag_of(
            4,
            &[(0, 1, "<->"), (1, 2, "<->"), (1, 3, "-->"), (2, 3, "<->")],
        );
        assert_eq!(glyph(&p, 2, 3), "<->");
        assert_eq!(glyph(&p, 1, 3), "-->");
    }

    #[test]
    fn rule_4_orients_a_non_collider_on_a_discriminating_path() {
        // Same configuration with B --> C, so B is a non-collider and R4
        // makes the tail at B invariant.
        let p = pag_of(
            4,
            &[(0, 1, "<->"), (1, 2, "<->"), (1, 3, "-->"), (2, 3, "-->")],
        );
        assert_eq!(glyph(&p, 2, 3), "-->");
        assert_eq!(glyph(&p, 1, 3), "-->");
    }

    #[test]
    fn rule_4_distinguishes_the_two_non_equivalent_mags() {
        // The two graphs above share a skeleton and their unshielded collider
        // and differ only in the discriminating-path triple, so R4 is what
        // separates them. Without it both would come out identical.
        let collider = pag_of(
            4,
            &[(0, 1, "<->"), (1, 2, "<->"), (1, 3, "-->"), (2, 3, "<->")],
        );
        let non_collider = pag_of(
            4,
            &[(0, 1, "<->"), (1, 2, "<->"), (1, 3, "-->"), (2, 3, "-->")],
        );
        assert_ne!(glyph(&collider, 2, 3), glyph(&non_collider, 2, 3));
    }

    #[test]
    fn rule_4_with_an_intermediate_parent_vertex() {
        // Discriminating path <D, X, A, B, C> for B: D <-> X <-> A <-> B with
        // X and A both parents of C and D not adjacent to C.
        // nodes: 0 = D, 1 = X, 2 = A, 3 = B, 4 = C
        let edges: &[(u32, u32, &str)] = &[
            (0, 1, "<->"),
            (1, 2, "<->"),
            (2, 3, "<->"),
            (1, 4, "-->"),
            (2, 4, "-->"),
        ];
        let mut collider = edges.to_vec();
        collider.push((3, 4, "<->"));
        assert_eq!(glyph(&pag_of(5, &collider), 3, 4), "<->");

        let mut non_collider = edges.to_vec();
        non_collider.push((3, 4, "-->"));
        assert_eq!(glyph(&pag_of(5, &non_collider), 3, 4), "-->");
    }

    #[test]
    fn skeleton_is_preserved() {
        let p = pag_of(4, &[(0, 2, "-->"), (1, 2, "-->"), (2, 3, "-->")]);
        for &(u, v) in &[(0u32, 2u32), (1, 2), (2, 3)] {
            assert!(p.adjacent(u, v));
        }
        assert!(!p.adjacent(0, 1));
        assert!(!p.adjacent(0, 3));
    }

    #[test]
    fn an_undirected_edge_is_kept_only_when_it_is_invariant() {
        // `A --- B, B --> C` is Markov equivalent to `A --> B, B --> C` and to
        // `A <-- B, B --> C`, so neither mark on the A-B edge is invariant and
        // the selection edge does *not* survive into the PAG. Undirected
        // marks are preserved by `pag_to_mag`, which reads a definite mark;
        // here the question is whether the mark is definite at all.
        let p = pag_of(3, &[(0, 1, "---"), (1, 2, "-->")]);
        assert_eq!(glyph(&p, 0, 1), "o-o");
    }

    #[test]
    fn empty_and_single_node_graphs_round_trip() {
        for n in [0u32, 1, 2] {
            let p = pag_of(n, &[]);
            assert_eq!(p.n(), n);
        }
    }
}
