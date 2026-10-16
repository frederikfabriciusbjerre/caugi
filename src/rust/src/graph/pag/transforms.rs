// SPDX-License-Identifier: MIT
//! Moving between a PAG and the MAGs of its Markov equivalence class.

use super::mark_graph::MarkGraph;
use super::marks::Marks;
use super::Pag;
use crate::edges::Mark;
use crate::graph::ag::Ag;
use crate::graph::builder::GraphBuilder;
use crate::graph::{CaugiGraph, RegistrySnapshot};
use std::sync::Arc;

/// The registered edge code for an edge carrying `at_i` at its first endpoint
/// and `at_j` at its second, plus whether the endpoints must be swapped to
/// match the spec's own tail/head order.
fn code_for_marks(
    registry: &RegistrySnapshot,
    at_i: Mark,
    at_j: Mark,
) -> Result<(u8, bool), String> {
    for (code, spec) in registry.specs.iter().enumerate() {
        if spec.tail == at_i && spec.head == at_j {
            return Ok((code as u8, false));
        }
    }
    for (code, spec) in registry.specs.iter().enumerate() {
        if spec.tail == at_j && spec.head == at_i {
            return Ok((code as u8, true));
        }
    }
    Err(format!(
        "no registered edge has the endpoint marks {} .. {}",
        at_i, at_j
    ))
}

/// Build a CSR core from resolved marks, reusing `template`'s registry.
pub(super) fn core_from_marks(template: &CaugiGraph, marks: &Marks) -> Result<CaugiGraph, String> {
    let snapshot = Arc::new(template.registry.clone());
    let mut builder = GraphBuilder::new_from_snapshot(marks.n(), true, snapshot);
    for (i, j, at_i, at_j) in marks.edges() {
        let (code, swap) = code_for_marks(&template.registry, at_i, at_j)?;
        if swap {
            builder.add_edge(j, i, code).map_err(|e| e.to_string())?;
        } else {
            builder.add_edge(i, j, code).map_err(|e| e.to_string())?;
        }
    }
    builder.finalize()
}

impl Pag {
    /// A MAG from the Markov equivalence class this PAG represents (Zhang
    /// 2008, Thm. 2).
    ///
    /// A circle opposite a definite mark is resolved the only way that keeps
    /// it, so `o->` and `--o` become `-->`. The remaining `o-o` subgraph is
    /// oriented into a DAG with no unshielded colliders by simplicial
    /// elimination.
    ///
    /// Only ancestrality is checked. Maximality is checked once, when the PAG
    /// is validated in [`Pag::try_new`], so the result for a constructed `Pag`
    /// is always a MAG.
    pub fn to_mag(&self) -> Result<Ag, String> {
        let n = self.n();
        let mut marks = Marks::from_graph(self.core_ref());

        // Step 1: a circle opposite a fixed mark is determined. Opposite an
        // arrowhead it must be a tail; opposite a tail it must be an arrowhead,
        // so the tail end points into it.
        for i in 0..n {
            for j in 0..n {
                if i == j || marks.mark_at(i, j) != Some(Mark::Circle) {
                    continue;
                }
                match marks.mark_at(j, i) {
                    Some(Mark::Arrow) => {
                        marks.set(i, j, Mark::Tail);
                    }
                    Some(Mark::Tail) => {
                        marks.set(i, j, Mark::Arrow);
                    }
                    _ => {}
                }
            }
        }

        // Step 2: orient the remaining `o-o` component into a DAG with no
        // unshielded colliders.
        let mut circle_nbrs: Vec<Vec<u32>> = (0..n)
            .map(|i| {
                (0..n)
                    .filter(|&j| {
                        j != i
                            && marks.mark_at(i, j) == Some(Mark::Circle)
                            && marks.mark_at(j, i) == Some(Mark::Circle)
                    })
                    .collect()
            })
            .collect();

        loop {
            let remaining: Vec<u32> = (0..n)
                .filter(|&i| !circle_nbrs[i as usize].is_empty())
                .collect();
            if remaining.is_empty() {
                break;
            }
            // A simplicial vertex: orienting its circle neighbours into it adds
            // no unshielded collider. Only the circle neighbours need form a
            // clique, unlike `Pdag::dag_extension`; R1 has already ruled out
            // an arrowhead into `x` from a node non-adjacent to one of them.
            let simplicial = remaining.iter().copied().find(|&x| {
                let nbrs = &circle_nbrs[x as usize];
                nbrs.iter()
                    .enumerate()
                    .all(|(ii, &a)| nbrs.iter().skip(ii + 1).all(|&b| marks.adjacent(a, b)))
            });
            let x = match simplicial {
                Some(x) => x,
                None => {
                    return Err(
                        "the `o-o` component is not chordal, so this graph is not the PAG \
                         of any MAG"
                            .into(),
                    )
                }
            };
            let nbrs = std::mem::take(&mut circle_nbrs[x as usize]);
            for u in nbrs {
                marks.set(x, u, Mark::Arrow); // u --> x
                marks.set(u, x, Mark::Tail);
                circle_nbrs[u as usize].retain(|&w| w != x);
            }
        }

        let core = core_from_marks(self.core_ref(), &marks)?;
        Ag::new(Arc::new(core))
    }

    /// The PAG of `mag`'s Markov equivalence class.
    ///
    /// Starts from `mag`'s skeleton with every mark a circle, orients the
    /// unshielded colliders of `mag` (shared by every member), and closes
    /// under R1-R10, with R4 reading collider status off `mag`. No separating
    /// sets are needed because a member is in hand.
    pub fn from_mag(mag: &Ag) -> Result<Self, String> {
        let m = mag.core_ref();
        let mut marks = Marks::new(m.n());
        for i in 0..m.n() {
            for j in m.neighbors(i) {
                marks.add_edge(i, j, Mark::Circle, Mark::Circle);
            }
        }
        for b in 0..m.n() {
            let into_b: Vec<u32> = m
                .neighbors(b)
                .into_iter()
                .filter(|&a| m.mark_at(b, a) == Some(Mark::Arrow))
                .collect();
            for (k, &a) in into_b.iter().enumerate() {
                for &c in into_b.iter().skip(k + 1).filter(|&&c| !m.adjacent(a, c)) {
                    marks.set(b, a, Mark::Arrow);
                    marks.set(b, c, Mark::Arrow);
                }
            }
        }
        marks.close(m);
        // Unchecked: validation would call back into this.
        Pag::new_unchecked(Arc::new(core_from_marks(m, &marks)?))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;

    /// Build a MAG from glyphs, then its PAG.
    fn pag_of(n: u32, edges: &[(u32, u32, &str)]) -> Pag {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let mut b = GraphBuilder::new_with_registry(n, true, &reg);
        for &(u, v, glyph) in edges {
            b.add_edge(u, v, reg.code_of(glyph).unwrap()).unwrap();
        }
        let mag = Ag::new(Arc::new(b.finalize().unwrap())).expect("not a MAG");
        Pag::from_mag(&mag).expect("from_mag failed")
    }

    /// The glyph of the edge `{i, j}` as `<mark at i>-<mark at j>`.
    fn glyph(p: &Pag, i: u32, j: u32) -> String {
        let l = match p.core_ref().mark_at(i, j) {
            Some(Mark::Arrow) => '<',
            Some(Mark::Tail) => '-',
            Some(Mark::Circle) => 'o',
            _ => return "none".into(),
        };
        let r = match p.core_ref().mark_at(j, i) {
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
    // which the four-node ground-truth fixture barely reaches.

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
            assert!(p.core_ref().adjacent(u, v));
        }
        assert!(!p.core_ref().adjacent(0, 1));
        assert!(!p.core_ref().adjacent(0, 3));
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
