// SPDX-License-Identifier: MIT
//! Graph layout algorithms.

mod force_directed;
mod kamada_kawai;
mod optimizer;
mod sugiyama;

use crate::graph::CaugiGraph;

pub use force_directed::force_directed_layout;
pub use kamada_kawai::kamada_kawai_layout;
pub use sugiyama::sugiyama_layout;

#[derive(Debug, Clone, Copy)]
pub enum LayoutMethod {
    Sugiyama,
    ForceDirected,
    KamadaKawai,
}

impl std::str::FromStr for LayoutMethod {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "sugiyama" => Ok(Self::Sugiyama),
            "force" => Ok(Self::ForceDirected),
            "kamada_kawai" | "kamada-kawai" | "kk" => Ok(Self::KamadaKawai),
            _ => Err(format!("Unknown layout method: '{}'", s)),
        }
    }
}

/// Compute node layout coordinates.
/// Returns a vector of (x, y) pairs, one for each node in order.
pub fn compute_layout(graph: &CaugiGraph, method: LayoutMethod) -> Result<Vec<(f64, f64)>, String> {
    match method {
        LayoutMethod::Sugiyama => sugiyama_layout(graph),
        LayoutMethod::ForceDirected => force_directed_layout(graph),
        LayoutMethod::KamadaKawai => kamada_kawai_layout(graph),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use std::sync::Arc;

    #[test]
    fn test_from_str_valid() {
        use std::str::FromStr;

        assert!(matches!(
            LayoutMethod::from_str("sugiyama"),
            Ok(LayoutMethod::Sugiyama)
        ));
        assert!(matches!(
            LayoutMethod::from_str("force"),
            Ok(LayoutMethod::ForceDirected)
        ));
        assert!(matches!(
            LayoutMethod::from_str("kamada_kawai"),
            Ok(LayoutMethod::KamadaKawai)
        ));
        assert!(matches!(
            LayoutMethod::from_str("kamada-kawai"),
            Ok(LayoutMethod::KamadaKawai)
        ));
        assert!(matches!(
            LayoutMethod::from_str("kk"),
            Ok(LayoutMethod::KamadaKawai)
        ));
    }

    #[test]
    fn test_from_str_invalid() {
        use std::str::FromStr;

        assert!(LayoutMethod::from_str("invalid").is_err());
        assert!(LayoutMethod::from_str("").is_err());
    }
}
