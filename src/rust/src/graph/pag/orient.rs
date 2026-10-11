// SPDX-License-Identifier: MIT
//! Zhang's complete orientation rules R1-R10, run to a fixed point on a
//! [`Marks`] working graph.
//!
//! All ten are needed: an incomplete rule set leaves the graph
//! under-oriented, and the `pag_to_mag` / `mag_to_pag` round trip would then
//! reject valid PAGs. R4 must decide whether the middle vertex of a
//! discriminating path is a collider, which needs either FCI's separating
//! sets or a member MAG; [`Marks::close`] takes the MAG.
//!
//! Ported from `CausalStructures.jl`, with two fixes:
//!
//! * its potentially-directed paths may cross `---`, which can never be
//!   oriented `-->`; [`MarkGraph::possible_children`] excludes it.
//! * its R8 takes a tail *or circle* at `alpha`, which admits
//!   `alpha o-> beta --> gamma`; Zhang requires a tail.

use super::mark_graph::MarkGraph;
use super::marks::Marks;
use crate::edges::Mark;

impl Marks {
    /// Close the marks under R1-R10 until no further mark is implied. `mag`
    /// is a member of the represented class, which R4 consults.
    pub(super) fn close(&mut self, mag: &impl MarkGraph) {
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

    /// R1: `a *-> b o-* c` with `a`, `c` non-adjacent implies `b --> c`.
    fn rule_1(&mut self) -> bool {
        let n = self.n();
        let mut changed = false;
        for b in 0..n {
            for a in 0..n {
                if a == b || self.mark_at(b, a) != Some(Mark::Arrow) {
                    continue;
                }
                for c in 0..n {
                    if c == a || c == b || self.adjacent(a, c) {
                        continue;
                    }
                    if self.mark_at(b, c) != Some(Mark::Circle) {
                        continue;
                    }
                    changed |= self.set(b, c, Mark::Tail);
                    changed |= self.set(c, b, Mark::Arrow);
                }
            }
        }
        changed
    }

    /// R2: `a --> b *-> c` or `a *-> b --> c`, together with `a *-o c`,
    /// implies `a *-> c`.
    fn rule_2(&mut self) -> bool {
        let n = self.n();
        let mut changed = false;
        for a in 0..n {
            for c in 0..n {
                if a == c || self.mark_at(c, a) != Some(Mark::Circle) {
                    continue;
                }
                for b in 0..n {
                    if b == a || b == c || !self.adjacent(a, b) || !self.adjacent(b, c) {
                        continue;
                    }
                    let into_b = self.mark_at(b, a) == Some(Mark::Arrow);
                    let chain_1 = into_b
                        && self.mark_at(a, b) == Some(Mark::Tail)
                        && self.mark_at(c, b) == Some(Mark::Arrow);
                    let chain_2 = into_b
                        && self.mark_at(c, b) == Some(Mark::Arrow)
                        && self.mark_at(b, c) == Some(Mark::Tail);
                    if chain_1 || chain_2 {
                        changed |= self.set(c, a, Mark::Arrow);
                        break;
                    }
                }
            }
        }
        changed
    }

    /// R3: `a *-> b <-* c` with `a *-o t o-* c`, `a` and `c` non-adjacent and
    /// `t *-o b`, implies `t *-> b`.
    fn rule_3(&mut self) -> bool {
        let n = self.n();
        let mut changed = false;
        for t in 0..n {
            for b in 0..n {
                if t == b || self.mark_at(b, t) != Some(Mark::Circle) {
                    continue;
                }
                let mut done = false;
                for a in 0..n {
                    if a == b || a == t || self.mark_at(b, a) != Some(Mark::Arrow) {
                        continue;
                    }
                    if self.mark_at(t, a) != Some(Mark::Circle) {
                        continue;
                    }
                    for c in 0..n {
                        if c == a || c == b || c == t || self.adjacent(a, c) {
                            continue;
                        }
                        if self.mark_at(b, c) != Some(Mark::Arrow) {
                            continue;
                        }
                        if self.mark_at(t, c) != Some(Mark::Circle) {
                            continue;
                        }
                        changed |= self.set(b, t, Mark::Arrow);
                        done = true;
                        break;
                    }
                    if done {
                        break;
                    }
                }
            }
        }
        changed
    }

    /// R4: on a discriminating path for `<..., a, b, c>` with `b o-* c`,
    /// orient `b <-> c` when `b` is a collider in `mag` and `b --> c`
    /// otherwise.
    fn rule_4(&mut self, mag: &impl MarkGraph) -> bool {
        let n = self.n();
        let mut changed = false;
        for b in 0..n {
            for c in 0..n {
                if b == c || !self.adjacent(b, c) {
                    continue;
                }
                if self.mark_at(b, c) != Some(Mark::Circle) {
                    continue;
                }
                if !self.has_discriminating_path(b, c) {
                    continue;
                }
                changed |= self.set(c, b, Mark::Arrow);
                if mag.mark_at(b, c) == Some(Mark::Arrow) {
                    changed |= self.set(b, c, Mark::Arrow);
                } else {
                    changed |= self.set(b, c, Mark::Tail);
                }
            }
        }
        changed
    }

    /// Is there a discriminating path for `<..., a, b, c>`, for some `a`?
    ///
    /// The mark at `b` is what R4 decides, so it is not constrained here.
    fn has_discriminating_path(&self, b: u32, c: u32) -> bool {
        (0..self.n())
            .filter(|&a| a != b && a != c)
            .any(|a| self.discriminating_path(a, b, c).is_some())
    }

    /// R5: `a o-o b` with an uncovered circle path between them makes that
    /// edge and every edge on the path undirected.
    fn rule_5(&mut self) -> bool {
        let n = self.n();
        let mut changed = false;
        for a in 0..n {
            for b in (a + 1)..n {
                if self.mark_at(a, b) != Some(Mark::Circle)
                    || self.mark_at(b, a) != Some(Mark::Circle)
                {
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
        let n = self.n();
        let mut changed = false;
        for b in 0..n {
            let has_undirected = (0..n).any(|a| {
                a != b
                    && self.mark_at(b, a) == Some(Mark::Tail)
                    && self.mark_at(a, b) == Some(Mark::Tail)
            });
            if !has_undirected {
                continue;
            }
            for c in 0..n {
                if c != b && self.mark_at(b, c) == Some(Mark::Circle) {
                    changed |= self.set(b, c, Mark::Tail);
                }
            }
        }
        changed
    }

    /// R7: `a --o b o-* c` with `a`, `c` non-adjacent implies a tail at `b`
    /// on the edge to `c`.
    fn rule_7(&mut self) -> bool {
        let n = self.n();
        let mut changed = false;
        for b in 0..n {
            for a in 0..n {
                if a == b {
                    continue;
                }
                // `a --o b`: a tail at `a`, a circle at `b`.
                if self.mark_at(b, a) != Some(Mark::Circle)
                    || self.mark_at(a, b) != Some(Mark::Tail)
                {
                    continue;
                }
                for c in 0..n {
                    if c == a || c == b || self.adjacent(a, c) {
                        continue;
                    }
                    if self.mark_at(b, c) == Some(Mark::Circle) {
                        changed |= self.set(b, c, Mark::Tail);
                    }
                }
            }
        }
        changed
    }

    /// R8: `a --> b --> c` or `a --o b --> c`, together with `a o-> c`,
    /// implies `a --> c`.
    fn rule_8(&mut self) -> bool {
        let n = self.n();
        let mut changed = false;
        for a in 0..n {
            for c in 0..n {
                if a == c || !self.is_circle_arrow(a, c) {
                    continue;
                }
                for b in 0..n {
                    if b == a || b == c || !self.adjacent(a, b) || !self.adjacent(b, c) {
                        continue;
                    }
                    // `a --> b` or `a --o b`: a tail at `a`, and either mark
                    // at `b`. A circle at `a` is not enough -- `a o-> b` may
                    // resolve to `a <-> b`, which makes `a` no ancestor of `c`.
                    let a_to_b = self.mark_at(a, b) == Some(Mark::Tail)
                        && matches!(self.mark_at(b, a), Some(Mark::Arrow) | Some(Mark::Circle));
                    let b_to_c = self.mark_at(c, b) == Some(Mark::Arrow)
                        && self.mark_at(b, c) == Some(Mark::Tail);
                    if a_to_b && b_to_c {
                        changed |= self.set(a, c, Mark::Tail);
                        break;
                    }
                }
            }
        }
        changed
    }

    /// R9: `a o-> c` with an uncovered potentially-directed path from `a` to
    /// `c` whose second vertex is not adjacent to `c` implies `a --> c`.
    fn rule_9(&mut self) -> bool {
        let n = self.n();
        let mut changed = false;
        for a in 0..n {
            for c in 0..n {
                if a == c || !self.is_circle_arrow(a, c) {
                    continue;
                }
                for b in 0..n {
                    if b == a || b == c || !self.adjacent(a, b) || self.adjacent(b, c) {
                        continue;
                    }
                    if self.mark_at(a, b) == Some(Mark::Arrow) {
                        continue;
                    }
                    if self.uncovered_pd_path(a, c, Some(b), &[]).is_some() {
                        changed |= self.set(a, c, Mark::Tail);
                        break;
                    }
                }
            }
        }
        changed
    }

    /// R10: `a o-> c` with `b --> c <-- d` and uncovered potentially-directed
    /// paths from `a` to `b` and from `a` to `d` whose second vertices are
    /// distinct and non-adjacent implies `a --> c`.
    fn rule_10(&mut self) -> bool {
        let n = self.n();
        let mut changed = false;
        for a in 0..n {
            for c in 0..n {
                if a == c || !self.is_circle_arrow(a, c) {
                    continue;
                }
                let parents: Vec<u32> = (0..n).filter(|&v| self.is_parent(v, c)).collect();
                if parents.len() < 2 {
                    continue;
                }
                if self.rule_10_witness(a, c, &parents) {
                    changed |= self.set(a, c, Mark::Tail);
                }
            }
        }
        changed
    }

    /// Is there a witness for R10 at `a o-> c` given the parents of `c`?
    fn rule_10_witness(&self, a: u32, c: u32, parents: &[u32]) -> bool {
        let n = self.n();
        for (bi, &b) in parents.iter().enumerate() {
            for (di, &d) in parents.iter().enumerate() {
                if bi == di {
                    continue;
                }
                for mu in 0..n {
                    if mu == a
                        || mu == c
                        || !self.adjacent(a, mu)
                        || self.mark_at(a, mu) == Some(Mark::Arrow)
                    {
                        continue;
                    }
                    if self.uncovered_pd_path(a, b, Some(mu), &[c]).is_none() {
                        continue;
                    }
                    for omega in 0..n {
                        if omega == a
                            || omega == c
                            || omega == mu
                            || !self.adjacent(a, omega)
                            || self.adjacent(mu, omega)
                            || self.mark_at(a, omega) == Some(Mark::Arrow)
                        {
                            continue;
                        }
                        if self.uncovered_pd_path(a, d, Some(omega), &[c]).is_some() {
                            return true;
                        }
                    }
                }
            }
        }
        false
    }

    /// Is the edge `a o-> c`, i.e. a circle at `a` and an arrowhead at `c`?
    #[inline]
    fn is_circle_arrow(&self, a: u32, c: u32) -> bool {
        self.mark_at(c, a) == Some(Mark::Arrow) && self.mark_at(a, c) == Some(Mark::Circle)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The four PAG marks, abbreviated for readable edge tables.
    const O: Mark = Mark::Circle;
    const A: Mark = Mark::Arrow;
    const T: Mark = Mark::Tail;

    /// A working graph on `n` nodes from `(i, j, mark at i, mark at j)` rows.
    fn marks(n: u32, edges: &[(u32, u32, Mark, Mark)]) -> Marks {
        let mut m = Marks::new(n);
        for &(i, j, at_i, at_j) in edges {
            m.add_edge(i, j, at_i, at_j);
        }
        m
    }

    /// Assert the full mark table, which pins down what the rule left alone
    /// as well as what it changed.
    fn assert_marks(m: &Marks, expected: &[(u32, u32, Mark, Mark)]) {
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
        let mut m = marks(5, &[(0, 1, T, O), (1, 2, O, T), (1, 3, O, A), (1, 4, O, O)]);
        assert!(m.rule_7());
        assert_marks(
            &m,
            &[(0, 1, T, O), (1, 2, T, T), (1, 3, T, A), (1, 4, T, O)],
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
