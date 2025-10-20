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
pub mod pdag;
pub mod view;
pub use view::GraphView;
pub mod metrics;

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
        assert!(
            CaugiGraph::from_csr(
                vec![0, 2],
                vec![1],
                vec![0, 0],
                vec![0, 1],
                simple,
                snap.clone()
            )
            .is_err()
        );
        assert!(
            CaugiGraph::from_csr(
                vec![0, 2],
                vec![1, 0],
                vec![0],
                vec![0, 1],
                simple,
                snap.clone()
            )
            .is_err()
        );
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
}
