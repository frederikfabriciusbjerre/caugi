// SPDX-License-Identifier: MIT
//! A dense, mutable mark table: what the orientation rules resolve circles on.

use super::mark_graph::MarkGraph;
use crate::edges::Mark;

/// A dense, mutable partial mixed graph.
///
/// `mark[i * n + j]` is the mark at `j` on the edge `{i, j}`, the `amat.pag`
/// convention; entries for non-adjacent pairs are unused.
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

    /// A copy of `g`.
    pub(super) fn from_graph(g: &impl MarkGraph) -> Self {
        let mut m = Self::new(g.n());
        for i in 0..g.n() {
            for j in g.neighbors(i).into_iter().filter(|&j| i < j) {
                let at_i = g.mark_at(i, j).expect("adjacent");
                let at_j = g.mark_at(j, i).expect("adjacent");
                m.add_edge(i, j, at_i, at_j);
            }
        }
        m
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
        self.mark[a] = at_j;
        self.mark[b] = at_i;
    }

    /// Set the mark at `at` on the edge to `from`, returning whether it
    /// changed. A no-op on a non-adjacent pair.
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
                    out.push((i, j, self.mark[self.idx(j, i)], self.mark[self.idx(i, j)]));
                }
            }
        }
        out
    }
}

impl MarkGraph for Marks {
    #[inline]
    fn n(&self) -> u32 {
        self.n
    }

    fn neighbors(&self, i: u32) -> Vec<u32> {
        (0..self.n).filter(|&j| self.adj[self.idx(i, j)]).collect()
    }

    #[inline]
    fn mark_at(&self, at: u32, from: u32) -> Option<Mark> {
        if at >= self.n || from >= self.n || !self.adj[self.idx(from, at)] {
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
        assert_eq!(m.mark_at(0, 2), None);
        assert_eq!(m.neighbors(0), vec![1]);
    }

    #[test]
    fn set_reports_change_and_ignores_non_adjacent() {
        let mut m = Marks::new(2);
        m.add_edge(0, 1, Mark::Circle, Mark::Circle);
        assert!(m.set(1, 0, Mark::Arrow));
        assert!(!m.set(1, 0, Mark::Arrow));
        assert_eq!(m.mark_at(1, 0), Some(Mark::Arrow));
        assert!(!Marks::new(2).set(1, 0, Mark::Arrow));
    }

    #[test]
    fn edges_and_from_graph_round_trip() {
        let mut m = Marks::new(3);
        m.add_edge(0, 1, Mark::Tail, Mark::Arrow); // 0 --> 1
        m.add_edge(2, 1, Mark::Arrow, Mark::Arrow); // 1 <-> 2
        let want = vec![
            (0, 1, Mark::Tail, Mark::Arrow),
            (1, 2, Mark::Arrow, Mark::Arrow),
        ];
        assert_eq!(m.edges(), want);
        assert_eq!(Marks::from_graph(&m).edges(), want);
    }
}
