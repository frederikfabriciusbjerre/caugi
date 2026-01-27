// SPDX-License-Identifier: MIT
//! GraphBuilder: collects edges and emits class-agnostic CSR.

use std::collections::HashSet;
use std::sync::Arc;

use super::error::BuilderError;
use super::{CaugiGraph, RegistrySnapshot};
use crate::edges::{EdgeRegistry, EdgeSpec};

#[derive(Debug)]
pub struct GraphBuilder {
    n: u32,
    simple: bool,
    specs: Arc<[EdgeSpec]>,
    rows: Vec<Vec<HalfEdge>>,
    seen: HashSet<(u32, u32, u8, bool)>,
    pair_seen: HashSet<(u32, u32)>,
}

/// Encodes the position of this endpoint in the edge: 0 = tail position, 1 = head position.
/// For an edge added as `add_edge(u, v, etype)`, u is at tail position and v is at head position.
/// The actual mark at each position can be looked up from the EdgeSpec.
#[derive(Copy, Clone, Debug, Eq, PartialEq)]
enum Side {
    /// Tail position (first argument to add_edge)
    Tail,
    /// Head position (second argument to add_edge)
    Head,
}

impl Side {
    #[inline]
    fn as_u8(self) -> u8 {
        match self {
            Side::Tail => 0,
            Side::Head => 1,
        }
    }
}

#[derive(Copy, Clone, Debug, Eq, PartialEq)]
struct HalfEdge {
    nbr: u32,
    etype: u8,
    side: Side,
}

impl Ord for HalfEdge {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        (self.nbr, self.etype, self.side.as_u8()).cmp(&(other.nbr, other.etype, other.side.as_u8()))
    }
}
impl PartialOrd for HalfEdge {
    fn partial_cmp(&self, o: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(o))
    }
}

impl GraphBuilder {
    pub fn new(n: u32, simple: bool, reg: &EdgeRegistry) -> Self {
        Self::new_with_registry(n, simple, reg)
    }

    pub fn new_with_registry(n: u32, simple: bool, reg: &EdgeRegistry) -> Self {
        let specs: Arc<[EdgeSpec]> = (0..reg.len() as u8)
            .map(|c| reg.spec_of_code(c).unwrap().clone())
            .collect::<Vec<_>>()
            .into();
        let n_us = n as usize;
        Self {
            n,
            simple,
            specs,
            rows: vec![Vec::new(); n_us],
            seen: HashSet::new(),
            pair_seen: HashSet::new(),
        }
    }

    /// Create a new builder from an existing registry snapshot.
    /// This is more efficient when the snapshot already exists (e.g., in GraphSession).
    pub fn new_from_snapshot(n: u32, simple: bool, snapshot: Arc<RegistrySnapshot>) -> Self {
        let n_us = n as usize;
        Self {
            n,
            simple,
            specs: Arc::clone(&snapshot.specs),
            rows: vec![Vec::new(); n_us],
            seen: HashSet::new(),
            pair_seen: HashSet::new(),
        }
    }

    /// Add an edge to the graph.
    ///
    /// Returns a `String` error for FFI compatibility. Use `try_add_edge` for typed errors.
    pub fn add_edge(&mut self, u: u32, v: u32, etype: u8) -> Result<(), String> {
        self.try_add_edge(u, v, etype).map_err(|e| e.to_string())
    }

    /// Add an edge to the graph with typed error handling.
    pub fn try_add_edge(&mut self, u: u32, v: u32, etype: u8) -> Result<(), BuilderError> {
        if u >= self.n {
            return Err(BuilderError::NodeOutOfRange {
                node: u,
                max: self.n - 1,
            });
        }
        if v >= self.n {
            return Err(BuilderError::NodeOutOfRange {
                node: v,
                max: self.n - 1,
            });
        }
        if self.simple && u == v {
            return Err(BuilderError::SelfLoop { node: u });
        }

        let spec: EdgeSpec = self
            .specs
            .get(etype as usize)
            .cloned()
            .ok_or(BuilderError::InvalidEdgeCode { code: etype })?;

        if self.simple {
            let (a, b) = if u <= v { (u, v) } else { (v, u) };
            if !self.pair_seen.insert((a, b)) {
                return Err(BuilderError::ParallelEdge { from: a, to: b });
            }
        }

        let key = if spec.symmetric {
            let (a, b) = if u <= v { (u, v) } else { (v, u) };
            (a, b, etype, true)
        } else {
            (u, v, etype, false)
        };
        if !self.seen.insert(key) {
            return Err(BuilderError::DuplicateEdge {
                from: u,
                to: v,
                edge_type: etype,
            });
        }

        // Push halves based on position.
        // u is at tail position, v is at head position for this edge.
        self.push_half(u, v, etype, Side::Tail); // u sees itself at tail position
        self.push_half(v, u, etype, Side::Head); // v sees itself at head position
        Ok(())
    }

    fn push_half(&mut self, from: u32, to: u32, etype: u8, position: Side) {
        self.rows[from as usize].push(HalfEdge {
            nbr: to,
            etype,
            side: position,
        });
    }

    pub fn finalize(mut self) -> Result<CaugiGraph, String> {
        self.take_and_build()
    }

    pub fn finalize_in_place(&mut self) -> Result<CaugiGraph, String> {
        self.take_and_build()
    }

    fn take_and_build(&mut self) -> Result<CaugiGraph, String> {
        let rows = std::mem::take(&mut self.rows);
        let seen = std::mem::take(&mut self.seen);
        let _pair = std::mem::take(&mut self.pair_seen);
        self.build_from_rows(rows, seen)
    }

    fn build_from_rows(
        &mut self,
        mut rows: Vec<Vec<HalfEdge>>,
        _seen: HashSet<(u32, u32, u8, bool)>,
    ) -> Result<CaugiGraph, String> {
        let n = self.n as usize;

        for row in &mut rows {
            row.sort_unstable(); // uses Ord on HalfEdge
            if self.simple
                && row
                    .windows(2)
                    .any(|w| w[0].nbr == w[1].nbr && w[0].etype == w[1].etype)
            {
                return Err(format!("parallel edge duplicate in row {:?}", row));
            }
        }

        let mut row_index = Vec::with_capacity(n + 1);
        row_index.push(0);
        for row in &rows {
            row_index.push(row_index.last().unwrap() + row.len() as u32);
        }

        let nnz = *row_index.last().unwrap() as usize;
        let mut col = vec![0u32; nnz];
        let mut ety = vec![0u8; nnz];
        let mut side = vec![0u8; nnz];

        for (i, row) in rows.iter().enumerate() {
            let mut k = row_index[i] as usize;
            for h in row {
                col[k] = h.nbr;
                ety[k] = h.etype;
                side[k] = match h.side {
                    Side::Tail => 0,
                    Side::Head => 1,
                }; // todo: change to use Side::Tail and Side::Head instead of magic numbers
                k += 1;
            }
        }

        let snap = RegistrySnapshot::from_specs(self.specs.clone(), 1);
        CaugiGraph::from_csr(row_index, col, ety, side, self.simple, snap)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;

    fn reg() -> EdgeRegistry {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        r
    }

    #[test]
    fn add_and_finalize_basic() {
        let r = reg();
        let cdir = r.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cdir).unwrap();
        let g = b.finalize().unwrap();
        assert_eq!(g.n(), 3);
        // row 0 has one out half-edge
        let rr0 = g.row_range(0);
        assert_eq!(rr0.len(), 1);
        assert_eq!(g.col_index[rr0.start], 1);
        // side=0 from tail at 0, side=1 from head at 1
        let rr1 = g.row_range(1);
        assert_eq!(g.side[rr0.start], 0);
        assert!(rr1.len() >= 1);
    }

    #[test]
    fn finalize_in_place_ok() {
        let r = reg();
        let cdir = r.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(2, true, &r);
        b.add_edge(0, 1, cdir).unwrap();
        let g = b.finalize_in_place().unwrap();
        assert_eq!(g.n(), 2);
    }

    #[test]
    fn finalize_in_place_parallel_duplicate_row_error() {
        let r = reg();
        let cdir = r.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(2, true, &r);
        // Manually craft duplicate entries
        b.rows[0].push(HalfEdge {
            nbr: 1,
            etype: cdir,
            side: Side::Tail,
        });
        b.rows[0].push(HalfEdge {
            nbr: 1,
            etype: cdir,
            side: Side::Head,
        }); // same nbr+etype, different side
        let err = b.finalize_in_place().unwrap_err();
        assert!(err.contains("parallel edge duplicate in row"));
    }

    #[test]
    fn simple_graph_blocks_parallel_and_self_loop() {
        let r = reg();
        let cdir = r.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(2, true, &r);
        assert!(b.add_edge(0, 0, cdir).is_err()); // self-loop
        b.add_edge(0, 1, cdir).unwrap();
        assert!(b.add_edge(0, 1, cdir).is_err()); // parallel same type
    }

    #[test]
    fn duplicate_edge_rejected_even_if_asymmetric() {
        let r = reg();
        let cdir = r.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, false, &r);
        b.add_edge(0, 1, cdir).unwrap();
        assert!(b.add_edge(0, 1, cdir).is_err()); // exact duplicate
    }

    #[test]
    fn invalid_node_or_code() {
        let r = reg();
        let bad_code = 200;
        let mut b = GraphBuilder::new_with_registry(2, false, &r);
        assert!(b.add_edge(0, 2, bad_code).is_err()); // node out of range takes precedence
                                                      // valid nodes but bad code
        assert!(b.add_edge(0, 1, bad_code).is_err());
    }
}
