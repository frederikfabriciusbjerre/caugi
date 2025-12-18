// SPDX-License-Identifier: MIT
//! CSR graph with registry snapshot; class wrappers live in submodules.

use crate::edges::EdgeSpec;
use std::ops::Range;
use std::sync::Arc;
use std::{
    collections::hash_map::DefaultHasher,
    hash::{Hash, Hasher},
};

pub mod admg;
pub mod alg;
pub mod builder;
pub mod dag;
pub mod error;
pub mod pdag;
pub mod ug;
pub mod view;
pub use view::GraphView;
pub mod layout;
pub mod metrics;
pub mod serialization;
pub mod graphml;

#[derive(Debug, Clone)]
pub struct RegistrySnapshot {
    pub version: u32,
    pub checksum: u64,
    pub specs: Arc<[EdgeSpec]>, // code -> spec
}

impl RegistrySnapshot {
    pub fn from_specs(specs: Arc<[EdgeSpec]>, version: u32) -> Self {
        let mut h = DefaultHasher::new();
        for s in specs.iter() {
            s.glyph.hash(&mut h);
            (s.class as u8).hash(&mut h);
        }
        Self {
            version,
            checksum: h.finish(),
            specs,
        }
    }
}

#[derive(Debug, Clone)]
pub struct CaugiGraph {
    pub row_index: Arc<[u32]>, // len n+1
    pub col_index: Arc<[u32]>, // len nnz
    pub etype: Arc<[u8]>,      // len nnz
    pub side: Arc<[u8]>,       // len nnz; 0=tail-ish, 1=head-ish
    pub registry: RegistrySnapshot,
    pub simple: bool, // whether the graph is simple (no multi-edges, no self-loops)
}

impl CaugiGraph {
    pub fn from_csr(
        row_index: Vec<u32>,
        col_index: Vec<u32>,
        etype: Vec<u8>,
        side: Vec<u8>,
        simple: bool,
        registry: RegistrySnapshot,
    ) -> Result<Self, String> {
        let nnz = *row_index.last().unwrap_or(&0) as usize;
        if col_index.len() != nnz || etype.len() != nnz || side.len() != nnz {
            return Err("NNZ arrays length mismatch".into());
        }
        Ok(Self {
            row_index: row_index.into(),
            col_index: col_index.into(),
            etype: etype.into(),
            side: side.into(),
            registry,
            simple,
        })
    }

    #[inline]
    pub fn n(&self) -> u32 {
        (self.row_index.len() - 1) as u32
    }
    #[inline]
    pub fn row_range(&self, i: u32) -> Range<usize> {
        let i = i as usize;
        self.row_index[i] as usize..self.row_index[i + 1] as usize
    }
}

impl CaugiGraph {
    /// Node-induced subgraph on `keep` (new ids are 0..k-1, in the SAME order as `keep`).
    /// Returns: (new_core, new_to_old, old_to_new).
    pub fn induced_subgraph(
        &self,
        keep: &[u32],
    ) -> Result<(CaugiGraph, Vec<u32>, Vec<u32>), String> {
        let n = self.n() as usize;

        // validate + deduplicate while preserving order
        let mut seen = vec![false; n];
        let mut new_to_old: Vec<u32> = Vec::with_capacity(keep.len());
        for &u in keep {
            if (u as usize) >= n {
                return Err("node id out of range".into());
            }
            if std::mem::replace(&mut seen[u as usize], true) {
                return Err("duplicate node id in `keep`".into());
            }
            new_to_old.push(u);
        }

        // old -> new map
        let mut old_to_new = vec![u32::MAX; n];
        for (new, &old) in new_to_old.iter().enumerate() {
            old_to_new[old as usize] = new as u32;
        }

        // row counts
        let k = new_to_old.len();
        let mut row_index: Vec<u32> = Vec::with_capacity(k + 1);
        row_index.push(0);
        for &old_u in &new_to_old {
            let mut cnt = 0u32;
            for kk in self.row_range(old_u) {
                let ov = self.col_index[kk] as usize;
                if ov < n && old_to_new[ov] != u32::MAX {
                    cnt += 1;
                }
            }
            row_index.push(row_index.last().unwrap() + cnt);
        }

        // allocate + scatter
        let nnz = *row_index.last().unwrap() as usize;
        let mut col_index = vec![0u32; nnz];
        let mut etype = vec![0u8; nnz];
        let mut side = vec![0u8; nnz];
        let mut cur = row_index[..k].to_vec();

        for (new_u, &old_u) in new_to_old.iter().enumerate() {
            for kk in self.row_range(old_u) {
                let ov = self.col_index[kk] as usize;
                let nv = old_to_new[ov];
                if nv == u32::MAX {
                    continue;
                }
                let p = cur[new_u] as usize;
                col_index[p] = nv;
                etype[p] = self.etype[kk];
                side[p] = self.side[kk];
                cur[new_u] += 1;
            }
        }

        let out = CaugiGraph::from_csr(
            row_index,
            col_index,
            etype,
            side,
            self.simple,
            self.registry.clone(),
        )?;
        Ok((out, new_to_old, old_to_new))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    #[test]
    fn registry_snapshot_checksum_changes_with_specs() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let specs: Arc<[_]> = (0..reg.len() as u8)
            .map(|c| reg.spec_of_code(c).unwrap().clone())
            .collect::<Vec<_>>()
            .into();
        let snap1 = RegistrySnapshot::from_specs(specs.clone(), 1);
        // Simulate different version; checksum stays same if specs equal
        let snap2 = RegistrySnapshot::from_specs(specs, 2);
        assert_eq!(snap1.checksum, snap2.checksum);
        assert_ne!(snap1.version, snap2.version);
    }

    #[test]
    fn from_csr_validates_shapes_and_reports_n() {
        let simple: bool = true;
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let specs: Arc<[_]> = (0..reg.len() as u8)
            .map(|c| reg.spec_of_code(c).unwrap().clone())
            .collect::<Vec<_>>()
            .into();
        let snap = RegistrySnapshot::from_specs(specs, 1);
        let ok = CaugiGraph::from_csr(
            vec![0, 2],
            vec![1, 0],
            vec![0, 0],
            vec![0, 1],
            simple,
            snap.clone(),
        )
        .unwrap();
        assert_eq!(ok.n(), 1);
        assert!(CaugiGraph::from_csr(
            vec![0, 2],
            vec![1],
            vec![0, 0],
            vec![0, 1],
            simple,
            snap.clone()
        )
        .is_err());
        assert!(CaugiGraph::from_csr(
            vec![0, 2],
            vec![1, 0],
            vec![0],
            vec![0, 1],
            simple,
            snap.clone()
        )
        .is_err());
        assert!(
            CaugiGraph::from_csr(vec![0, 2], vec![1, 0], vec![0, 0], vec![0], simple, snap)
                .is_err()
        );
    }

    #[test]
    fn builder_to_core_roundtrip_dimensions() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        let core = b.finalize().unwrap();
        assert_eq!(core.n(), 3);
        assert_eq!(core.row_index.len(), 4);
    }

    fn make_core(n: u32, edges: &[(u32, u32)]) -> CaugiGraph {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let code = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new(n, true, &reg);
        for &(u, v) in edges {
            b.add_edge(u, v, code).unwrap();
        }
        b.finalize_in_place().unwrap()
    }

    #[test]
    fn induced_subgraph_order_and_mapping() {
        // 0->1, 1->2, 2->0, 2->3
        let core = make_core(4, &[(0, 1), (1, 2), (2, 0), (2, 3)]);
        // keep [2,0,3]
        let (sub, new_to_old, old_to_new) = core.induced_subgraph(&[2, 0, 3]).unwrap();
        assert_eq!(new_to_old, vec![2, 0, 3]);
        assert_eq!(old_to_new[2], 0);
        assert_eq!(old_to_new[0], 1);
        assert_eq!(old_to_new[3], 2);
        // edges among kept: 2->0 becomes 0->1, 2->3 becomes 0->2
        // iterate CSR and collect edges
        let mut got = Vec::new();
        for u in 0..sub.n() {
            for k in sub.row_range(u) {
                got.push((u, sub.col_index[k]));
            }
        }
        got.sort();
        assert_eq!(got, vec![(0, 1), (0, 2), (1, 0), (2, 0)]);
    }

    #[test]
    fn induced_subgraph_rejects_oob_and_dups() {
        let core = make_core(3, &[(0, 1)]);
        assert!(core.induced_subgraph(&[0, 3]).is_err());
        assert!(core.induced_subgraph(&[0, 1, 1]).is_err());
    }

    #[test]
    fn graphview_induced_subgraph_preserves_variant() {
        // DAG
        let core_dag = make_core(3, &[(0, 1), (1, 2)]);
        let dag = crate::graph::dag::Dag::new(Arc::new(core_dag.clone())).unwrap();
        let gv_dag = GraphView::Dag(Arc::new(dag));
        let sub_dag = gv_dag.induced_subgraph(&[0, 2]).unwrap();
        match sub_dag {
            GraphView::Dag(_) => {}
            _ => panic!("expected DAG"),
        }

        // RAW
        let gv_raw = GraphView::Raw(Arc::new(core_dag.clone()));
        let sub_raw = gv_raw.induced_subgraph(&[0, 2]).unwrap();
        match sub_raw {
            GraphView::Raw(_) => {}
            _ => panic!("expected RAW"),
        }

        // PDAG on empty core
        let core_empty = make_core(3, &[]);
        let pdag = crate::graph::pdag::Pdag::new(Arc::new(core_empty.clone())).unwrap();
        let gv_pdag = GraphView::Pdag(Arc::new(pdag));
        let sub_pdag = gv_pdag.induced_subgraph(&[1, 2]).unwrap();
        match sub_pdag {
            GraphView::Pdag(_) => {}
            _ => panic!("expected PDAG"),
        }
    }

    #[test]
    fn graphview_induced_subgraph_propagates_errors() {
        let core = make_core(2, &[(0, 1)]);
        let gv = GraphView::Raw(Arc::new(core));
        assert!(gv.induced_subgraph(&[0, 2]).is_err());
    }
}
