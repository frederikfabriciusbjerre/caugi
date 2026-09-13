// SPDX-License-Identifier: MIT
//! Zhang's complete orientation rules R1-R10 for partial ancestral graphs.
//!
//! The rules resolve circle marks that are in fact invariant across the
//! represented Markov equivalence class. They run to a fixed point on a
//! [`Marks`] working graph via [`Marks::close`].
//!
//! R1-R4 give arrowhead completeness, R5-R7 handle selection bias, and
//! R8-R10 give tail completeness (Zhang 2008). All ten are needed: an
//! incomplete rule set leaves a graph under-oriented, which would then make
//! the `pag_to_mag` / `mag_to_pag` round trip reject valid PAGs.
//!
//! R4 is the one rule that cannot be applied from the partial graph alone. It
//! fires on a discriminating path and must then decide whether the middle
//! vertex is a collider, which needs either the separating sets FCI collects
//! from data or a known MAG to consult. `close` therefore takes the source
//! MAG's marks and reads the answer off them, as `CausalStructures.jl` does;
//! with no MAG available R4 is skipped and the caller gets an
//! arrowhead-incomplete result, so `close` is not exposed as a standalone
//! operation.
//!
//! Ported from `CausalStructures.jl`'s `_pag_rule_r1!` .. `_pag_rule_r10!`,
//! with two deliberate differences.
//!
//! First, its potentially-directed path search forbids only an arrowhead at
//! the near end of each edge, so it will traverse an `A --- B` edge. Such an
//! edge carries a definite tail at both ends and can never be oriented
//! `A --> B`, so it cannot lie on a potentially-directed path;
//! [`MarkGraph::possible_children`] excludes it. That only shows up when
//! selection bias is present, which is in scope here.
//!
//! Second, its R8 tests for an arrowhead at `beta` and a tail *or a circle* at
//! `alpha`, which both misses Zhang's `alpha --o beta --> gamma` antecedent
//! and admits `alpha o-> beta --> gamma`, where `alpha` need not be an
//! ancestor of `gamma` at all. [`Marks::rule_8`] follows Zhang: a tail at
//! `alpha` and either mark at `beta`.

use super::marks::{MarkGraph, Marks};
use crate::edges::Mark;

impl Marks {
    /// Close the marks under R1-R10 until no further mark is implied.
    ///
    /// `mag` supplies the marks of a MAG in the represented class, which R4
    /// consults; pass `None` to skip R4 and accept an arrowhead-incomplete
    /// result.
    pub(super) fn close(&mut self, mag: Option<&Marks>) {
        loop {
            let mut changed = false;
            changed |= self.rule_1();
            changed |= self.rule_2();
            changed |= self.rule_3();
            if let Some(m) = mag {
                changed |= self.rule_4(m);
            }
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
    fn rule_4(&mut self, mag: &Marks) -> bool {
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
            .any(|a| MarkGraph::discriminating_path(self, a, b, c).is_some())
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
        self.rule_8_scoped(None)
    }

    /// R8, optionally restricted to the nodes `scope` admits.
    ///
    /// See [`Marks::close_local`] for why the restriction is needed there.
    fn rule_8_scoped(&mut self, scope: Option<&[bool]>) -> bool {
        let n = self.n();
        let mut changed = false;
        let inside = |v: u32| match scope {
            Some(s) => s[v as usize],
            None => true,
        };
        for a in 0..n {
            for c in 0..n {
                if a == c || !self.is_circle_arrow(a, c) {
                    continue;
                }
                if !inside(a) || !inside(c) {
                    continue;
                }
                for b in 0..n {
                    if b == a || b == c || !self.adjacent(a, b) || !self.adjacent(b, c) {
                        continue;
                    }
                    if !inside(b) {
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
                    if MarkGraph::uncovered_pd_path(self, a, c, Some(b), None, &[]).is_some() {
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
                    if MarkGraph::uncovered_pd_path(self, a, b, Some(mu), None, &[c]).is_none() {
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
                        if MarkGraph::uncovered_pd_path(self, a, d, Some(omega), None, &[c])
                            .is_some()
                        {
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
