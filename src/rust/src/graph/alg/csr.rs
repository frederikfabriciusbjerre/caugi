// SPDX-License-Identifier: MIT
//! CSR graph manipulation utilities.

use crate::edges::EdgeClass;
use crate::graph::CaugiGraph;

/// Build an undirected graph core from adjacency lists.
///
/// # Arguments
/// * `core` - Original core for registry and metadata
/// * `adj` - Adjacency lists (assumes symmetric undirected edges)
pub fn build_ug_core_from_adj(core: &CaugiGraph, adj: &[Vec<u32>]) -> Result<CaugiGraph, String> {
    let n = adj.len();
    let registry = core.registry.clone();

    // Find undirected edge code
    let und_code = undirected_code(&registry)?;

    // Count edges per row
    let mut row_index = Vec::with_capacity(n + 1);
    row_index.push(0u32);
    for i in 0..n {
        row_index.push(row_index[i] + adj[i].len() as u32);
    }

    // Allocate edge arrays
    let nnz = *row_index.last().unwrap() as usize;
    let mut col_index = vec![0u32; nnz];
    let etype = vec![und_code; nnz];
    let side = vec![0u8; nnz];

    // Fill arrays
    let mut cur = row_index[..n].to_vec();
    for i in 0..n {
        for &v in &adj[i] {
            let p = cur[i] as usize;
            col_index[p] = v;
            cur[i] += 1;
        }
    }

    CaugiGraph::from_csr(row_index, col_index, etype, side, core.simple, registry)
}

/// Find an undirected edge code in the registry.
pub fn undirected_code(registry: &crate::graph::RegistrySnapshot) -> Result<u8, String> {
    for (i, s) in registry.specs.iter().enumerate() {
        if matches!(s.class, EdgeClass::Undirected) {
            if s.glyph == "---" {
                return Ok(i as u8);
            }
        }
    }
    // Fallback: any undirected
    for (i, s) in registry.specs.iter().enumerate() {
        if matches!(s.class, EdgeClass::Undirected) {
            return Ok(i as u8);
        }
    }
    Err("No undirected edge spec in registry".into())
}

/// Filter edges from a graph based on a predicate.
///
/// # Arguments
/// * `core` - Source graph
/// * `keep` - Predicate function: `(row_u, edge_index, core) -> bool`
pub fn filter_edges<F>(core: &CaugiGraph, mut keep: F) -> Result<CaugiGraph, String>
where
    F: FnMut(u32, usize, &CaugiGraph) -> bool,
{
    let n = core.n() as usize;

    // First pass: count edges kept per row to form row_index.
    let mut idx = vec![0u32; n + 1];
    for u in 0..core.n() {
        let mut cnt = 0u32;
        for k in core.row_range(u) {
            if keep(u, k, core) {
                cnt += 1;
            }
        }
        idx[u as usize + 1] = idx[u as usize] + cnt;
    }

    // Allocate exact sizes.
    let nnz = idx[n] as usize;
    let mut col = vec![0u32; nnz];
    let mut ety = vec![0u8; nnz];
    let mut side = vec![0u8; nnz];

    // Second pass: scatter kept edges.
    let mut cur = idx[..n].to_vec();
    for u in 0..core.n() {
        for k in core.row_range(u) {
            if !keep(u, k, core) {
                continue;
            }
            let p = cur[u as usize] as usize;
            col[p] = core.col_index[k];
            ety[p] = core.etype[k];
            side[p] = core.side[k];
            cur[u as usize] += 1;
        }
    }

    CaugiGraph::from_csr(idx, col, ety, side, core.simple, core.registry.clone())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::{EdgeClass, EdgeRegistry, EdgeSpec, Mark};
    use crate::graph::builder::GraphBuilder;

    fn make_test_core() -> CaugiGraph {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cdir).unwrap();
        b.finalize().unwrap()
    }

    #[test]
    fn filter_edges_keep_all() {
        let core = make_test_core();
        let filtered = filter_edges(&core, |_u, _k, _c| true).unwrap();

        assert_eq!(filtered.n(), core.n());
        assert_eq!(filtered.row_index.len(), core.row_index.len());
        assert_eq!(filtered.col_index.len(), core.col_index.len());
    }

    #[test]
    fn filter_edges_keep_none() {
        let core = make_test_core();
        let filtered = filter_edges(&core, |_u, _k, _c| false).unwrap();

        assert_eq!(filtered.n(), 3);
        // All row_index entries should be 0 (no edges)
        for i in 0..=3 {
            assert_eq!(filtered.row_index[i], 0);
        }
    }

    #[test]
    fn filter_edges_selective() {
        let core = make_test_core();
        // Keep only edges from node 0
        let filtered = filter_edges(&core, |u, _k, _c| u == 0).unwrap();

        assert_eq!(filtered.n(), 3);
        // Node 0 should have 1 edge, others 0
        assert_eq!(filtered.row_index[1], 1); // cumulative after row 0
        assert_eq!(filtered.row_index[2], 1); // no edges in row 1
        assert_eq!(filtered.row_index[3], 1); // no edges in row 2
    }

    #[test]
    fn build_ug_core_from_adj_simple() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        let core = b.finalize().unwrap();

        // Build UG from adjacency: 0-1, 1-2
        let adj = vec![vec![1], vec![0, 2], vec![1]];
        let ug_core = build_ug_core_from_adj(&core, &adj).unwrap();

        assert_eq!(ug_core.n(), 3);
        // Check edges
        let r0 = ug_core.row_range(0);
        assert_eq!(r0.len(), 1);
        assert_eq!(ug_core.col_index[r0.start], 1);
    }

    #[test]
    fn undirected_code_finds_standard() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let snap = crate::graph::RegistrySnapshot::from_specs(
            (0..reg.len() as u8)
                .map(|c| reg.spec_of_code(c).unwrap().clone())
                .collect::<Vec<_>>()
                .into(),
            1,
        );

        let code = undirected_code(&snap).unwrap();
        let spec = &snap.specs[code as usize];
        assert_eq!(spec.class, EdgeClass::Undirected);
    }

    #[test]
    fn undirected_code_fallback_and_missing_error() {
        // Fallback path: no standard '---' glyph, but an undirected spec exists.
        let mut reg = EdgeRegistry::new();
        reg.register(EdgeSpec {
            glyph: "u".to_string(),
            tail: Mark::Tail,
            head: Mark::Tail,
            symmetric: true,
            class: EdgeClass::Undirected,
        })
        .unwrap();
        let snap = crate::graph::RegistrySnapshot::from_specs(
            (0..reg.len() as u8)
                .map(|c| reg.spec_of_code(c).unwrap().clone())
                .collect::<Vec<_>>()
                .into(),
            1,
        );
        let code = undirected_code(&snap).unwrap();
        assert_eq!(code, 0);

        // Error path: no undirected spec at all.
        let mut reg2 = EdgeRegistry::new();
        reg2.register(EdgeSpec {
            glyph: "d".to_string(),
            tail: Mark::Tail,
            head: Mark::Arrow,
            symmetric: false,
            class: EdgeClass::Directed,
        })
        .unwrap();
        let snap2 = crate::graph::RegistrySnapshot::from_specs(
            (0..reg2.len() as u8)
                .map(|c| reg2.spec_of_code(c).unwrap().clone())
                .collect::<Vec<_>>()
                .into(),
            1,
        );
        let err = undirected_code(&snap2).unwrap_err();
        assert!(err.contains("No undirected edge spec in registry"));
    }
}
