// SPDX-License-Identifier: MIT
//! A mark-oriented view over a partial mixed graph, plus a mutable dense
//! representation of one.
//!
//! Everything a PAG path predicate or orientation rule needs is expressible
//! from three primitives: the node count, adjacency, and the mark at one end
//! of an edge. [`MarkGraph`] requires exactly those and derives the rest, so
//! the path searches are written once and shared by
//!
//! * [`Pag`](super::Pag), which is immutable and CSR-backed, and
//! * [`Marks`], which is dense and mutable and is what the orientation rules
//!   work on as they resolve circles.
//!
//! Without that sharing the rules would need their own copy of the path
//! searches, which could then silently diverge from the ones the public API
//! exposes.

use crate::edges::Mark;
use crate::graph::ag::Ag;

/// Read-only access to a partial mixed graph by endpoint mark.
pub(super) trait MarkGraph {
    /// Number of nodes.
    fn n(&self) -> u32;

    /// Are `i` and `j` joined by an edge?
    fn adjacent(&self, i: u32, j: u32) -> bool;

    /// The mark at `at` on the edge joining it to `from`, or `None` when the
    /// two are not adjacent.
    fn mark_at(&self, at: u32, from: u32) -> Option<Mark>;

    // ── derived relations ────────────────────────────────────────────────

    /// Is `p --> c`?
    fn is_parent(&self, p: u32, c: u32) -> bool {
        self.mark_at(c, p) == Some(Mark::Arrow) && self.mark_at(p, c) == Some(Mark::Tail)
    }

    /// Is `a <-> b`?
    fn is_spouse(&self, a: u32, b: u32) -> bool {
        self.mark_at(a, b) == Some(Mark::Arrow) && self.mark_at(b, a) == Some(Mark::Arrow)
    }

    /// Neighbours joined to `i` by an edge with an arrowhead at `i`, ascending.
    fn arrowhead_neighbors(&self, i: u32) -> Vec<u32> {
        (0..self.n())
            .filter(|&j| j != i && self.mark_at(i, j) == Some(Mark::Arrow))
            .collect()
    }

    /// Neighbours `j` such that some member MAG can orient `i --> j`, i.e. no
    /// arrowhead at `i` and no tail at `j`. Ascending.
    fn possible_children(&self, i: u32) -> Vec<u32> {
        (0..self.n())
            .filter(|&j| {
                j != i
                    && matches!(self.mark_at(i, j), Some(Mark::Tail) | Some(Mark::Circle))
                    && matches!(self.mark_at(j, i), Some(Mark::Arrow) | Some(Mark::Circle))
            })
            .collect()
    }

    // ── path predicates ─────────────────────────────────────────────────

    /// Is the directed edge `a --> b` visible?
    ///
    /// See [`super::Pag::is_visible_edge`] for the criterion.
    fn visible_edge(&self, a: u32, b: u32) -> bool {
        if a == b || a >= self.n() || b >= self.n() {
            return false;
        }
        // The edge must be `a --> b`: a tail at `a` and an arrowhead at `b`.
        if !self.is_parent(a, b) {
            return false;
        }

        // Condition (a): `c *-> a --> b` with `c` and `b` non-adjacent.
        for c in self.arrowhead_neighbors(a) {
            if c != b && !self.adjacent(c, b) {
                return true;
            }
        }

        // Condition (b): a collider path `c *-> ... <-> d <-> a` into `a`
        // whose non-endpoints are all parents of `b`. The last such
        // non-endpoint `d` is a spouse of `a` and a parent of `b`, and the
        // rest of the path is a discriminating path for `<d, a, b>`.
        for d in 0..self.n() {
            if d != a && d != b && self.is_spouse(a, d) && self.is_parent(d, b) {
                if self.discriminating_path(d, a, b).is_some() {
                    return true;
                }
            }
        }
        false
    }

    /// Find a discriminating path for the triple `<a, b, c>`.
    ///
    /// See [`super::Pag::discriminating_path`].
    fn discriminating_path(&self, a: u32, b: u32, c: u32) -> Option<Vec<u32>> {
        let n = self.n();
        if a >= n || b >= n || c >= n || a == b || b == c || a == c {
            return None;
        }
        // `a` lies strictly between the source and `b`, so it must be a
        // collider on the path and a parent of `c`.
        if !self.is_parent(a, c) {
            return None;
        }
        if self.mark_at(a, b) != Some(Mark::Arrow) {
            return None;
        }
        // `b` is a non-endpoint of the path, so it is adjacent to `c`.
        if !self.adjacent(b, c) {
            return None;
        }

        let mut on_path = vec![false; n as usize];
        on_path[a as usize] = true;
        on_path[b as usize] = true;
        on_path[c as usize] = true;
        // Built back to front: the collider chain from `a` outward, reversed
        // on return so that the source comes first.
        let mut chain = vec![a];
        if self.extend_collider_chain(&mut chain, &mut on_path, c) {
            chain.reverse();
            chain.push(b);
            chain.push(c);
            return Some(chain);
        }
        None
    }

    /// Extend the collider chain in `chain` away from `c`.
    ///
    /// `chain` holds the vertices strictly between the source and `b`, in
    /// order of decreasing distance from the source. Every one of them is a
    /// collider on the path and a parent of `c`. The recursion terminates as
    /// soon as it can attach a source `d` that is not adjacent to `c`.
    fn extend_collider_chain(&self, chain: &mut Vec<u32>, on_path: &mut [bool], c: u32) -> bool {
        let curr = *chain.last().expect("chain is never empty");
        // A candidate must put an arrowhead on `curr`, so that `curr` is a
        // collider on the path.
        for d in self.arrowhead_neighbors(curr) {
            if on_path[d as usize] {
                continue;
            }
            if !self.adjacent(d, c) {
                // `d` is a legal source: the path is complete.
                chain.push(d);
                return true;
            }
            // Otherwise `d` can only be an interior vertex, which requires it
            // to be a parent of `c` and a collider on the path. The latter
            // needs an arrowhead at `d` too, so `d <-> curr`.
            if self.is_parent(d, c) && self.mark_at(d, curr) == Some(Mark::Arrow) {
                on_path[d as usize] = true;
                chain.push(d);
                if self.extend_collider_chain(chain, on_path, c) {
                    return true;
                }
                chain.pop();
                on_path[d as usize] = false;
            }
        }
        false
    }

    /// Find an uncovered potentially-directed path from `x` to `y`.
    ///
    /// See [`super::Pag::uncovered_pd_path`].
    fn uncovered_pd_path(
        &self,
        x: u32,
        y: u32,
        first: Option<u32>,
        last: Option<u32>,
        exclude: &[u32],
    ) -> Option<Vec<u32>> {
        let n = self.n();
        if x == y || x >= n || y >= n {
            return None;
        }
        if exclude.contains(&x) || exclude.contains(&y) {
            return None;
        }
        let mut on_path = vec![false; n as usize];
        on_path[x as usize] = true;
        // Excluded vertices are simply pre-marked as used, which keeps the
        // path off them without a second check in the inner loop.
        for &e in exclude {
            if e < n {
                on_path[e as usize] = true;
            }
        }
        let mut path = vec![x];
        if self.extend_pd_path(&mut path, &mut on_path, y, first, last) {
            return Some(path);
        }
        None
    }

    /// Find an uncovered circle path between `a` and `b`, not using the edge
    /// between them.
    ///
    /// Every edge on the returned path `[a, c, ..., d, b]` is `o-o`, every
    /// consecutive triple has non-adjacent ends, and additionally `c` is not
    /// adjacent to `b` and `d` is not adjacent to `a`, which is what R5
    /// requires of its witness.
    fn uncovered_circle_path(&self, a: u32, b: u32) -> Option<Vec<u32>> {
        let n = self.n();
        if a == b || a >= n || b >= n {
            return None;
        }
        for c in 0..n {
            if c == a || c == b || !self.is_circle_circle(a, c) || self.adjacent(b, c) {
                continue;
            }
            let mut on_path = vec![false; n as usize];
            on_path[a as usize] = true;
            on_path[b as usize] = true;
            on_path[c as usize] = true;
            let mut path = vec![a, c];
            if self.extend_circle_path(&mut path, &mut on_path, a, b, c) {
                return Some(path);
            }
        }
        None
    }

    /// Is the edge `i o-o j`?
    fn is_circle_circle(&self, i: u32, j: u32) -> bool {
        self.mark_at(i, j) == Some(Mark::Circle) && self.mark_at(j, i) == Some(Mark::Circle)
    }

    /// Extend the circle path in `path` toward `b`.
    fn extend_circle_path(
        &self,
        path: &mut Vec<u32>,
        on_path: &mut [bool],
        a: u32,
        b: u32,
        c: u32,
    ) -> bool {
        let depth = path.len();
        let curr = path[depth - 1];
        let prev = path[depth - 2];

        // Close the path at `b`, provided the last interior vertex is not
        // adjacent to `a` and the one before it is not adjacent to `b`.
        if curr != c
            && self.is_circle_circle(curr, b)
            && !self.adjacent(a, curr)
            && !self.adjacent(prev, b)
        {
            path.push(b);
            return true;
        }

        for next in 0..self.n() {
            if next == b || on_path[next as usize] || !self.is_circle_circle(curr, next) {
                continue;
            }
            if self.adjacent(prev, next) {
                continue; // uncovered
            }
            on_path[next as usize] = true;
            path.push(next);
            if self.extend_circle_path(path, on_path, a, b, c) {
                return true;
            }
            path.pop();
            on_path[next as usize] = false;
        }
        false
    }

    /// Extend the potentially-directed path in `path` toward `y`.
    fn extend_pd_path(
        &self,
        path: &mut Vec<u32>,
        on_path: &mut [bool],
        y: u32,
        first: Option<u32>,
        last: Option<u32>,
    ) -> bool {
        let depth = path.len();
        let curr = path[depth - 1];
        // The vertex two back, if any; it is what the uncovered condition
        // constrains against the vertex about to be appended.
        let prev = if depth >= 2 {
            Some(path[depth - 2])
        } else {
            None
        };

        for next in self.possible_children(curr) {
            // `path[1]` is pinned by `first`.
            if depth == 1 {
                if let Some(f) = first {
                    if next != f {
                        continue;
                    }
                }
            }
            // Uncovered: the triple just completed must have non-adjacent ends.
            if let Some(p) = prev {
                if self.adjacent(p, next) {
                    continue;
                }
            }
            if next == y {
                // `path[len - 2]` is pinned by `last`; after the push that
                // position holds `curr`.
                if let Some(l) = last {
                    if curr != l {
                        continue;
                    }
                }
                path.push(y);
                return true;
            }
            if on_path[next as usize] {
                continue;
            }
            on_path[next as usize] = true;
            path.push(next);
            if self.extend_pd_path(path, on_path, y, first, last) {
                return true;
            }
            path.pop();
            on_path[next as usize] = false;
        }
        false
    }
}

/// A dense, mutable partial mixed graph indexed by endpoint mark.
///
/// `mark[i * n + j]` is the mark at node `j` on the edge `{i, j}`; entries for
/// non-adjacent pairs are unused. This is the representation the orientation
/// rules mutate as they resolve circles, and it mirrors the `amat.pag`
/// convention, so a row/column pair maps straight onto that encoding.
#[derive(Debug, Clone)]
pub(super) struct Marks {
    n: u32,
    adj: Vec<bool>,
    mark: Vec<Mark>,
}

impl Marks {
    /// An edgeless graph on `n` nodes.
    pub(super) fn new(n: u32) -> Self {
        let len = (n as usize) * (n as usize);
        Self {
            n,
            adj: vec![false; len],
            mark: vec![Mark::Circle; len],
        }
    }

    #[inline]
    fn idx(&self, i: u32, j: u32) -> usize {
        (i as usize) * (self.n as usize) + (j as usize)
    }

    /// Add the edge `{i, j}` carrying `at_i` at `i` and `at_j` at `j`.
    pub(super) fn add_edge(&mut self, i: u32, j: u32, at_i: Mark, at_j: Mark) {
        let (a, b) = (self.idx(i, j), self.idx(j, i));
        self.adj[a] = true;
        self.adj[b] = true;
        // `mark[i][j]` is the mark at `j`.
        self.mark[a] = at_j;
        self.mark[b] = at_i;
    }

    /// Set the mark at `at` on the edge to `from`. Returns whether it changed.
    ///
    /// No-op returning `false` when the two are not adjacent, so a rule may
    /// fire blindly on a pair it has already checked.
    pub(super) fn set(&mut self, at: u32, from: u32, m: Mark) -> bool {
        let k = self.idx(from, at);
        if !self.adj[k] || self.mark[k] == m {
            return false;
        }
        self.mark[k] = m;
        true
    }

    /// Every edge, as `(i, j, mark at i, mark at j)` with `i < j`.
    pub(super) fn edges(&self) -> Vec<(u32, u32, Mark, Mark)> {
        let mut out = Vec::new();
        for i in 0..self.n {
            for j in (i + 1)..self.n {
                if self.adj[self.idx(i, j)] {
                    let at_i = self.mark[self.idx(j, i)];
                    let at_j = self.mark[self.idx(i, j)];
                    out.push((i, j, at_i, at_j));
                }
            }
        }
        out
    }
}

/// A MAG read as a mark graph: every endpoint is a definite tail or
/// arrowhead, never a circle. This is what lets the path searches and
/// the visibility test run unchanged on a MAG.
impl MarkGraph for Ag {
    #[inline]
    fn n(&self) -> u32 {
        Ag::n(self)
    }

    #[inline]
    fn adjacent(&self, i: u32, j: u32) -> bool {
        Ag::adjacent(self, i, j)
    }

    fn mark_at(&self, at: u32, from: u32) -> Option<Mark> {
        if self.parents_of(at).binary_search(&from).is_ok()
            || self.spouses_of(at).binary_search(&from).is_ok()
        {
            return Some(Mark::Arrow);
        }
        if self.children_of(at).binary_search(&from).is_ok()
            || self.undirected_of(at).binary_search(&from).is_ok()
        {
            return Some(Mark::Tail);
        }
        None
    }
}

impl MarkGraph for Marks {
    #[inline]
    fn n(&self) -> u32 {
        self.n
    }

    #[inline]
    fn adjacent(&self, i: u32, j: u32) -> bool {
        i < self.n && j < self.n && self.adj[self.idx(i, j)]
    }

    #[inline]
    fn mark_at(&self, at: u32, from: u32) -> Option<Mark> {
        if !self.adjacent(at, from) {
            return None;
        }
        Some(self.mark[self.idx(from, at)])
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn add_edge_records_both_endpoint_marks() {
        let mut m = Marks::new(3);
        m.add_edge(0, 1, Mark::Circle, Mark::Arrow); // 0 o-> 1
        assert_eq!(m.mark_at(0, 1), Some(Mark::Circle));
        assert_eq!(m.mark_at(1, 0), Some(Mark::Arrow));
        assert!(m.adjacent(0, 1) && m.adjacent(1, 0));
        assert_eq!(m.mark_at(0, 2), None);
        assert!(!m.adjacent(0, 2));
    }

    #[test]
    fn set_reports_change_and_ignores_non_adjacent() {
        let mut m = Marks::new(2);
        m.add_edge(0, 1, Mark::Circle, Mark::Circle);
        assert!(m.set(1, 0, Mark::Arrow));
        assert!(!m.set(1, 0, Mark::Arrow)); // idempotent
        assert_eq!(m.mark_at(1, 0), Some(Mark::Arrow));

        let mut empty = Marks::new(2);
        assert!(!empty.set(1, 0, Mark::Arrow));
    }

    #[test]
    fn edges_round_trips_marks() {
        let mut m = Marks::new(3);
        m.add_edge(0, 1, Mark::Tail, Mark::Arrow); // 0 --> 1
        m.add_edge(1, 2, Mark::Arrow, Mark::Arrow); // 1 <-> 2
        assert_eq!(
            m.edges(),
            vec![
                (0, 1, Mark::Tail, Mark::Arrow),
                (1, 2, Mark::Arrow, Mark::Arrow)
            ]
        );
    }

    #[test]
    fn derived_relations_agree_with_marks() {
        let mut m = Marks::new(3);
        m.add_edge(0, 1, Mark::Tail, Mark::Arrow); // 0 --> 1
        m.add_edge(1, 2, Mark::Arrow, Mark::Arrow); // 1 <-> 2
        assert!(m.is_parent(0, 1));
        assert!(!m.is_parent(1, 0));
        assert!(m.is_spouse(1, 2));
        assert_eq!(m.arrowhead_neighbors(1), vec![0, 2]);
        assert_eq!(m.possible_children(0), vec![1]);
        assert!(m.possible_children(1).is_empty());
    }
}
