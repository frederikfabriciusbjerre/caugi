// SPDX-License-Identifier: MIT
//! Zhang's complete orientation rules R1-R10, run to a fixed point on a
//! [`MarkedGraph`].
//!
//! All ten are needed: an incomplete rule set leaves the graph
//! under-oriented, and the `pag_to_mag` / `mag_to_pag` round trip would then
//! reject valid PAGs. R4 must decide whether the middle vertex of a
//! discriminating path is a collider, which needs either FCI's separating
//! sets or a member MAG; [`MarkedGraph::close`] takes the MAG.
//!
//! Every rule walks edges: the rows of the nodes involved, or the common
//! neighbours of an edge's two ends, never every node pair or triple.
//!
//! Ported from `CausalStructures.jl`, with two fixes:
//!
//! * its potentially-directed paths may cross `---`, which can never be
//!   oriented `-->`; [`MarkedGraph::possible_children`] excludes it.
//! * its R8 takes a tail *or circle* at `alpha`, which admits
//!   `alpha o-> beta --> gamma`; Zhang requires a tail.

use super::marked::MarkedGraph;
use crate::edges::Mark;

impl MarkedGraph {
    /// Close the marks under R1-R10 until no further mark is implied. `mag`
    /// is a member of the represented class, which R4 consults.
    pub(super) fn close(&mut self, mag: &MarkedGraph) {
        loop {
            let mut changed = false;
            changed |= self.rule_1();
            changed |= self.rule_2();
            changed |= self.rule_3();
            changed |= self.rule_4(mag);
            changed |= self.rule_5();
            changed |= self.rule_6();
            changed |= self.rule_7();
            changed |= self.rule_8();
            changed |= self.rule_9();
            changed |= self.rule_10();
            if !changed {
                return;
            }
        }
    }

    /// The neighbours of `b` whose edge has the mark `m` at `b`.
    fn with_near_mark(&self, b: u32, m: Mark) -> Vec<u32> {
        self.slots(b)
            .filter(|&k| self.near(k) == m)
            .map(|k| self.col(k))
            .collect()
    }

    /// The slots `k` of `a o-> c` edges in `a`'s row: a circle at `a` and an
    /// arrowhead at `c`.
    fn circle_arrow_slots(&self, a: u32) -> Vec<usize> {
        self.slots(a)
            .filter(|&k| self.near(k) == Mark::Circle && self.far(k) == Mark::Arrow)
            .collect()
    }

    /// R1: `a *-> b o-* c` with `a`, `c` non-adjacent implies `b --> c`.
    fn rule_1(&mut self) -> bool {
        let mut changed = false;
        for b in 0..self.n() {
            let into = self.with_near_mark(b, Mark::Arrow);
            if into.is_empty() {
                continue;
            }
            for k in self.slots(b) {
                let c = self.col(k);
                if self.near(k) == Mark::Circle
                    && into.iter().any(|&a| a != c && !self.adjacent(a, c))
                {
                    changed |= self.set_slot(k, Mark::Tail);
                    changed |= self.set(c, b, Mark::Arrow);
                }
            }
        }
        changed
    }

    /// R2: `a --> b *-> c` or `a *-> b --> c`, together with `a *-o c`,
    /// implies `a *-> c`.
    fn rule_2(&mut self) -> bool {
        let mut changed = false;
        for a in 0..self.n() {
            for k in self.slots(a) {
                if self.far(k) != Mark::Circle {
                    continue;
                }
                let c = self.col(k);
                // `kab` is `b` in `a`'s row and `kcb` is `b` in `c`'s row.
                let witness = self.common(a, c).into_iter().any(|(_, kab, kcb)| {
                    self.far(kab) == Mark::Arrow
                        && self.near(kcb) == Mark::Arrow
                        && (self.near(kab) == Mark::Tail || self.far(kcb) == Mark::Tail)
                });
                if witness {
                    changed |= self.set(c, a, Mark::Arrow);
                }
            }
        }
        changed
    }

    /// R3: `a *-> b <-* c` with `a *-o t o-* c`, `a` and `c` non-adjacent and
    /// `t *-o b`, implies `t *-> b`.
    fn rule_3(&mut self) -> bool {
        let mut changed = false;
        for t in 0..self.n() {
            for k in self.slots(t) {
                if self.far(k) != Mark::Circle {
                    continue;
                }
                let b = self.col(k);
                // Nodes `x` with `x *-> b` and `t o-* x`.
                let sides: Vec<u32> = self
                    .common(t, b)
                    .into_iter()
                    .filter(|&(_, ktx, kbx)| {
                        self.near(kbx) == Mark::Arrow && self.near(ktx) == Mark::Circle
                    })
                    .map(|(x, _, _)| x)
                    .collect();
                let unshielded = sides
                    .iter()
                    .enumerate()
                    .any(|(i, &a)| sides[i + 1..].iter().any(|&c| !self.adjacent(a, c)));
                if unshielded {
                    changed |= self.set(b, t, Mark::Arrow);
                }
            }
        }
        changed
    }

    /// R4: on a discriminating path for `<..., a, b, c>` with `b o-* c`,
    /// orient `b <-> c` when `b` is a collider in `mag` and `b --> c`
    /// otherwise.
    fn rule_4(&mut self, mag: &MarkedGraph) -> bool {
        let mut changed = false;
        for b in 0..self.n() {
            for k in self.slots(b) {
                if self.near(k) != Mark::Circle {
                    continue;
                }
                let c = self.col(k);
                if !self.has_discriminating_path(b, c) {
                    continue;
                }
                changed |= self.set(c, b, Mark::Arrow);
                let at_b = if mag.mark_at(b, c) == Some(Mark::Arrow) {
                    Mark::Arrow
                } else {
                    Mark::Tail
                };
                changed |= self.set_slot(k, at_b);
            }
        }
        changed
    }

    /// Is there a discriminating path for `<..., a, b, c>`, for some `a`?
    ///
    /// `a` is adjacent to both `b` and `c`. The mark at `b` is what R4
    /// decides, so it is not constrained here.
    fn has_discriminating_path(&self, b: u32, c: u32) -> bool {
        self.common(b, c)
            .into_iter()
            .any(|(a, _, _)| self.discriminating_path(a, b, c).is_some())
    }

    /// R5: `a o-o b` with an uncovered circle path between them makes that
    /// edge and every edge on the path undirected.
    fn rule_5(&mut self) -> bool {
        let mut changed = false;
        for a in 0..self.n() {
            for k in self.slots(a) {
                let b = self.col(k);
                if b < a || !(self.near(k) == Mark::Circle && self.far(k) == Mark::Circle) {
                    continue;
                }
                let path = match self.uncovered_circle_path(a, b) {
                    Some(p) => p,
                    None => continue,
                };
                for w in path.windows(2) {
                    changed |= self.set(w[0], w[1], Mark::Tail);
                    changed |= self.set(w[1], w[0], Mark::Tail);
                }
                changed |= self.set(a, b, Mark::Tail);
                changed |= self.set(b, a, Mark::Tail);
            }
        }
        changed
    }

    /// R6: `a --- b o-* c` implies a tail at `b` on the edge to `c`.
    fn rule_6(&mut self) -> bool {
        let mut changed = false;
        for b in 0..self.n() {
            let undirected = self
                .slots(b)
                .any(|k| self.near(k) == Mark::Tail && self.far(k) == Mark::Tail);
            if !undirected {
                continue;
            }
            for k in self.slots(b) {
                if self.near(k) == Mark::Circle {
                    changed |= self.set_slot(k, Mark::Tail);
                }
            }
        }
        changed
    }

    /// R7: `a --o b o-* c` with `a`, `c` non-adjacent implies a tail at `b`
    /// on the edge to `c`.
    fn rule_7(&mut self) -> bool {
        let mut changed = false;
        for b in 0..self.n() {
            // `a --o b`: a circle at `b` and a tail at `a`.
            let tails: Vec<u32> = self
                .slots(b)
                .filter(|&k| self.near(k) == Mark::Circle && self.far(k) == Mark::Tail)
                .map(|k| self.col(k))
                .collect();
            if tails.is_empty() {
                continue;
            }
            for k in self.slots(b) {
                let c = self.col(k);
                if self.near(k) == Mark::Circle
                    && tails.iter().any(|&a| a != c && !self.adjacent(a, c))
                {
                    changed |= self.set_slot(k, Mark::Tail);
                }
            }
        }
        changed
    }

    /// R8: `a --> b --> c` or `a --o b --> c`, together with `a o-> c`,
    /// implies `a --> c`.
    fn rule_8(&mut self) -> bool {
        let mut changed = false;
        for a in 0..self.n() {
            for k in self.circle_arrow_slots(a) {
                let c = self.col(k);
                // `a --> b` or `a --o b`: a tail at `a`, and either mark at
                // `b`. A circle at `a` is not enough -- `a o-> b` may resolve
                // to `a <-> b`, which makes `a` no ancestor of `c`.
                let witness = self.common(a, c).into_iter().any(|(_, kab, kcb)| {
                    self.near(kab) == Mark::Tail
                        && matches!(self.far(kab), Mark::Arrow | Mark::Circle)
                        && self.near(kcb) == Mark::Arrow
                        && self.far(kcb) == Mark::Tail
                });
                if witness {
                    changed |= self.set_slot(k, Mark::Tail);
                }
            }
        }
        changed
    }

    /// R9: `a o-> c` with an uncovered potentially-directed path from `a` to
    /// `c` whose second vertex is not adjacent to `c` implies `a --> c`.
    fn rule_9(&mut self) -> bool {
        let mut changed = false;
        for a in 0..self.n() {
            for k in self.circle_arrow_slots(a) {
                let c = self.col(k);
                let witness = self.slots(a).any(|kb| {
                    let b = self.col(kb);
                    b != c
                        && self.near(kb) != Mark::Arrow
                        && !self.adjacent(b, c)
                        && self.uncovered_pd_path(a, c, Some(b), &[]).is_some()
                });
                if witness {
                    changed |= self.set_slot(k, Mark::Tail);
                }
            }
        }
        changed
    }

    /// R10: `a o-> c` with `b --> c <-- d` and uncovered potentially-directed
    /// paths from `a` to `b` and from `a` to `d` whose second vertices are
    /// distinct and non-adjacent implies `a --> c`.
    fn rule_10(&mut self) -> bool {
        let mut changed = false;
        for a in 0..self.n() {
            for k in self.circle_arrow_slots(a) {
                let c = self.col(k);
                let parents: Vec<u32> = self
                    .slots(c)
                    .filter(|&kc| self.near(kc) == Mark::Arrow && self.far(kc) == Mark::Tail)
                    .map(|kc| self.col(kc))
                    .collect();
                if parents.len() >= 2 && self.rule_10_witness(a, c, &parents) {
                    changed |= self.set_slot(k, Mark::Tail);
                }
            }
        }
        changed
    }

    /// Is there a witness for R10 at `a o-> c` given the parents of `c`?
    ///
    /// One search per first vertex out of `a` and parent of `c`, instead of
    /// one per combination of two of each: the witness only needs two
    /// non-adjacent first vertices that reach two different parents.
    fn rule_10_witness(&self, a: u32, c: u32, parents: &[u32]) -> bool {
        let firsts: Vec<u32> = self
            .slots(a)
            .filter(|&k| self.col(k) != c && self.near(k) != Mark::Arrow)
            .map(|k| self.col(k))
            .collect();
        let reach: Vec<Vec<u32>> = firsts
            .iter()
            .map(|&mu| {
                parents
                    .iter()
                    .copied()
                    .filter(|&b| self.uncovered_pd_path(a, b, Some(mu), &[c]).is_some())
                    .collect()
            })
            .collect();
        (0..firsts.len()).any(|i| {
            (0..firsts.len()).any(|j| {
                i != j
                    && !self.adjacent(firsts[i], firsts[j])
                    && reach[i].iter().any(|&b| reach[j].iter().any(|&d| b != d))
            })
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::graph::pag::marked::from_mark_edges;

    /// The four PAG marks, abbreviated for readable edge tables.
    const O: Mark = Mark::Circle;
    const A: Mark = Mark::Arrow;
    const T: Mark = Mark::Tail;

    /// A working graph on `n` nodes from `(i, j, mark at i, mark at j)` rows.
    fn marks(n: u32, edges: &[(u32, u32, Mark, Mark)]) -> MarkedGraph {
        from_mark_edges(n, edges)
    }

    /// Assert the full mark table, which pins down what the rule left alone
    /// as well as what it changed.
    fn assert_marks(m: &MarkedGraph, expected: &[(u32, u32, Mark, Mark)]) {
        let mut want: Vec<_> = expected
            .iter()
            .map(|&(i, j, at_i, at_j)| {
                if i < j {
                    (i, j, at_i, at_j)
                } else {
                    (j, i, at_j, at_i)
                }
            })
            .collect();
        want.sort_by_key(|&(i, j, _, _)| (i, j));
        assert_eq!(m.edges(), want);
    }

    // --- R5 -------------------------------------------------------------
    // Ported from causality-lab's `test_orient_by_rule_5`.

    #[test]
    fn rule_5_orients_a_circle_cycle_of_length_four() {
        let mut m = marks(4, &[(0, 1, O, O), (1, 2, O, O), (2, 3, O, O), (3, 0, O, O)]);
        assert!(m.rule_5());
        assert_marks(
            &m,
            &[(0, 1, T, T), (1, 2, T, T), (2, 3, T, T), (3, 0, T, T)],
        );
    }

    #[test]
    fn rule_5_orients_a_circle_cycle_of_length_five() {
        let mut m = marks(
            5,
            &[
                (0, 1, O, O),
                (1, 2, O, O),
                (2, 3, O, O),
                (3, 4, O, O),
                (4, 0, O, O),
            ],
        );
        assert!(m.rule_5());
        assert_marks(
            &m,
            &[
                (0, 1, T, T),
                (1, 2, T, T),
                (2, 3, T, T),
                (3, 4, T, T),
                (4, 0, T, T),
            ],
        );
    }

    #[test]
    fn rule_5_leaves_the_chorded_part_of_a_cycle_alone() {
        // The chord `2 o-o 4` shortcuts the cycle, so only the edges on the
        // remaining uncovered circle path `2 - 1 - 0 - 4` are oriented.
        let mut m = marks(
            5,
            &[
                (0, 1, O, O),
                (1, 2, O, O),
                (2, 3, O, O),
                (3, 4, O, O),
                (4, 0, O, O),
                (2, 4, O, O),
            ],
        );
        assert!(m.rule_5());
        assert_marks(
            &m,
            &[
                (0, 1, T, T),
                (1, 2, T, T),
                (2, 3, O, O),
                (3, 4, O, O),
                (4, 0, T, T),
                (2, 4, T, T),
            ],
        );
    }

    #[test]
    fn rule_5_does_not_fire_when_every_circle_path_is_covered() {
        let edges = [
            (0, 1, O, O),
            (1, 2, O, O),
            (2, 3, O, O),
            (3, 4, O, O),
            (4, 0, O, O),
            (2, 4, O, O),
            (2, 0, O, O),
        ];
        let mut m = marks(5, &edges);
        assert!(!m.rule_5());
        assert_marks(&m, &edges);
    }

    // --- R6 -------------------------------------------------------------
    // Ported from causality-lab's `test_orient_by_rule_6`.

    #[test]
    fn rule_6_puts_a_tail_on_every_circle_beside_an_undirected_edge() {
        let mut m = marks(5, &[(0, 1, T, T), (1, 2, O, T), (1, 3, O, A), (1, 4, O, O)]);
        assert!(m.rule_6());
        assert_marks(
            &m,
            &[(0, 1, T, T), (1, 2, T, T), (1, 3, T, A), (1, 4, T, O)],
        );
    }

    #[test]
    fn rule_6_fires_on_the_undirected_edges_r5_produced() {
        let mut m = marks(
            5,
            &[
                (0, 1, O, O),
                (1, 2, O, O),
                (2, 3, O, O),
                (3, 4, O, O),
                (4, 0, O, O),
                (2, 4, O, O),
            ],
        );
        assert!(m.rule_5());
        assert!(m.rule_6());
        assert_marks(
            &m,
            &[
                (0, 1, T, T),
                (1, 2, T, T),
                (2, 3, T, O),
                (3, 4, O, T),
                (4, 0, T, T),
                (2, 4, T, T),
            ],
        );
    }

    #[test]
    fn rule_6_ignores_a_node_with_no_undirected_edge() {
        let edges = [(0, 1, T, O), (1, 2, O, T), (1, 3, O, A)];
        let mut m = marks(4, &edges);
        assert!(!m.rule_6());
        assert_marks(&m, &edges);
    }

    // --- R7 -------------------------------------------------------------
    // Ported from causality-lab's `test_orient_by_rule_7`.

    #[test]
    fn rule_7_puts_a_tail_on_circles_beside_a_tail_circle_edge() {
        // Both `0 --o 1` and `2 --o 1` qualify, so every circle at `1` gets a
        // tail, including the one on `0 --o 1` (via `2`, non-adjacent to `0`).
        // causality-lab's version wrote marks as it went, so it reached that
        // tail only through R6 on the next pass; the closed PAG is the same.
        let mut m = marks(5, &[(0, 1, T, O), (1, 2, O, T), (1, 3, O, A), (1, 4, O, O)]);
        assert!(m.rule_7());
        assert_marks(
            &m,
            &[(0, 1, T, T), (1, 2, T, T), (1, 3, T, A), (1, 4, T, O)],
        );
    }

    #[test]
    fn rule_7_needs_the_two_ends_to_be_non_adjacent() {
        // `0 --o 1 o-o 2` with `0` and `2` adjacent: the rule cannot fire.
        let edges = [(0, 1, T, O), (1, 2, O, O), (0, 2, O, O)];
        let mut m = marks(3, &edges);
        assert!(!m.rule_7());
        assert_marks(&m, &edges);
    }

    // --- R8 -------------------------------------------------------------
    // Ported from causality-lab's `test_orient_by_rule_8`.

    #[test]
    fn rule_8_fires_through_a_directed_edge() {
        // `0 --> 1 --> 2` with `0 o-> 2`.
        let mut m = marks(3, &[(0, 1, T, A), (1, 2, T, A), (0, 2, O, A)]);
        assert!(m.rule_8());
        assert_marks(&m, &[(0, 1, T, A), (1, 2, T, A), (0, 2, T, A)]);
    }

    #[test]
    fn rule_8_fires_through_a_tail_circle_edge() {
        // `0 --o 1 --> 2` with `0 o-> 2`. `CausalStructures.jl` misses this
        // case: it asks for an arrowhead at `1`.
        let mut m = marks(3, &[(0, 1, T, O), (1, 2, T, A), (0, 2, O, A)]);
        assert!(m.rule_8());
        assert_marks(&m, &[(0, 1, T, O), (1, 2, T, A), (0, 2, T, A)]);
    }

    #[test]
    fn rule_8_does_not_fire_through_a_circle_arrow_edge() {
        // `0 o-> 1 --> 2` with `0 o-> 2`: `0 <-> 1` is possible, so `0` need
        // not be an ancestor of `2` and the circle at `0` is not invariant.
        // `CausalStructures.jl` orients a tail here.
        let edges = [(0, 1, O, A), (1, 2, T, A), (0, 2, O, A)];
        let mut m = marks(3, &edges);
        assert!(!m.rule_8());
        assert_marks(&m, &edges);
    }

    // --- R9 -------------------------------------------------------------
    // Ported from causality-lab's `test_orient_by_rule_9`.

    #[test]
    fn rule_9_fires_along_an_uncovered_potentially_directed_path() {
        let mut m = marks(
            5,
            &[
                (0, 1, O, A),
                (0, 2, O, O),
                (2, 3, O, A),
                (3, 4, O, O),
                (4, 1, O, O),
            ],
        );
        assert!(m.rule_9());
        assert_marks(
            &m,
            &[
                (0, 1, T, A),
                (0, 2, O, O),
                (2, 3, T, A),
                (3, 4, O, O),
                (4, 1, O, O),
            ],
        );
    }

    #[test]
    fn rule_9_stops_at_an_arrowhead_on_the_path() {
        // The arrowhead at `3` on `3 <-o 4` breaks the path `0 - 2 - 3 - 4 - 1`,
        // so the tail at `0` is no longer implied. `2 o-> 3` still is, along
        // `2 - 0 - 1 - 4 - 3`.
        let mut m = marks(
            5,
            &[
                (0, 1, O, A),
                (0, 2, O, O),
                (2, 3, O, A),
                (3, 4, A, O),
                (4, 1, O, O),
            ],
        );
        assert!(m.rule_9());
        assert_marks(
            &m,
            &[
                (0, 1, O, A),
                (0, 2, O, O),
                (2, 3, T, A),
                (3, 4, A, O),
                (4, 1, O, O),
            ],
        );
    }

    // --- R10 ------------------------------------------------------------
    // Ported from causality-lab's `test_orient_by_rule_10`.

    #[test]
    fn rule_10_fires_on_two_single_edge_paths() {
        // `0 o-> 2` with `1 --> 2 <-- 3` and `0 o-> 1`, `0 o-> 3`.
        let mut m = marks(
            4,
            &[
                (0, 2, O, A),
                (0, 1, O, A),
                (0, 3, O, A),
                (1, 2, T, A),
                (3, 2, T, A),
            ],
        );
        assert!(m.rule_10());
        assert_marks(
            &m,
            &[
                (0, 2, T, A),
                (0, 1, O, A),
                (0, 3, O, A),
                (1, 2, T, A),
                (3, 2, T, A),
            ],
        );
    }

    #[test]
    fn rule_10_needs_the_two_path_starts_to_be_non_adjacent() {
        let edges = [
            (0, 2, O, A),
            (0, 1, O, A),
            (0, 3, O, A),
            (1, 2, T, A),
            (3, 2, T, A),
            (1, 3, O, O),
        ];
        let mut m = marks(4, &edges);
        assert!(!m.rule_10());
        assert_marks(&m, &edges);
    }

    #[test]
    fn rule_10_fires_with_one_single_edge_and_one_longer_path() {
        // Paths `<0, 3>` and `<0, 4, 5, 1>` into the two parents of `2`.
        let mut m = marks(
            6,
            &[
                (0, 2, O, A),
                (0, 3, O, A),
                (3, 2, T, A),
                (1, 2, T, A),
                (0, 4, O, O),
                (4, 5, O, A),
                (5, 1, O, O),
            ],
        );
        assert!(m.rule_10());
        assert_marks(
            &m,
            &[
                (0, 2, T, A),
                (0, 3, O, A),
                (3, 2, T, A),
                (1, 2, T, A),
                (0, 4, O, O),
                (4, 5, O, A),
                (5, 1, O, O),
            ],
        );
    }
}
