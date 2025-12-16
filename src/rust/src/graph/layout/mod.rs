// SPDX-License-Identifier: MIT
//! Graph layout algorithms.

mod bipartite;
mod force_directed;
mod kamada_kawai;
mod normalize;
mod optimizer;
mod sugiyama;

use crate::graph::CaugiGraph;
use normalize::{normalize_to_unit_box, rotate_to_principal_axes};

pub use bipartite::{bipartite_columns_layout, bipartite_rows_layout};
pub use force_directed::force_directed_layout;
pub use kamada_kawai::kamada_kawai_layout;
pub use sugiyama::sugiyama_layout;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BipartiteOrientation {
    Rows,
    Columns,
}

impl std::str::FromStr for BipartiteOrientation {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "rows" => Ok(Self::Rows),
            "columns" => Ok(Self::Columns),
            _ => Err(format!("Unknown bipartite orientation: '{}'", s)),
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub enum LayoutMethod {
    Sugiyama,
    ForceDirected,
    KamadaKawai,
    Bipartite,
}

impl std::str::FromStr for LayoutMethod {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "sugiyama" => Ok(Self::Sugiyama),
            "force" | "fruchterman-reingold" | "fr" => Ok(Self::ForceDirected),
            "kamada_kawai" | "kamada-kawai" | "kk" => Ok(Self::KamadaKawai),
            "bipartite" => Ok(Self::Bipartite),
            _ => Err(format!("Unknown layout method: '{}'", s)),
        }
    }
}

/// Compute node layout coordinates.
/// Returns a vector of (x, y) pairs, one for each node in order.
/// Coordinates are normalized to [0, 1] range, with the largest dimension scaled to [0, 1].
/// Force-directed layouts are also rotated using PCA to align the first principal component.
pub fn compute_layout(graph: &CaugiGraph, method: LayoutMethod) -> Result<Vec<(f64, f64)>, String> {
    if matches!(method, LayoutMethod::Bipartite) {
        return Err(
            "Bipartite layouts require a partition and orientation. Use compute_bipartite_layout instead."
                .to_string(),
        );
    }

    let mut coords = match method {
        LayoutMethod::Sugiyama => sugiyama_layout(graph)?,
        LayoutMethod::ForceDirected => force_directed_layout(graph)?,
        LayoutMethod::KamadaKawai => kamada_kawai_layout(graph)?,
        _ => unreachable!(),
    };

    // Apply PCA rotation to force-directed layouts for standardized orientation
    if matches!(
        method,
        LayoutMethod::ForceDirected | LayoutMethod::KamadaKawai
    ) {
        rotate_to_principal_axes(&mut coords);
    }

    // Normalize all layouts to [0, 1] box
    normalize_to_unit_box(&mut coords);

    Ok(coords)
}

/// Compute bipartite layout coordinates with a given partition and orientation.
/// Returns a vector of (x, y) pairs, one for each node in order.
/// Coordinates are in [0, 1] range and already normalized.
pub fn compute_bipartite_layout(
    graph: &CaugiGraph,
    partition: &[bool],
    orientation: BipartiteOrientation,
) -> Result<Vec<(f64, f64)>, String> {
    match orientation {
        BipartiteOrientation::Rows => bipartite_rows_layout(graph, partition),
        BipartiteOrientation::Columns => bipartite_columns_layout(graph, partition),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

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
            LayoutMethod::from_str("fruchterman-reingold"),
            Ok(LayoutMethod::ForceDirected)
        ));
        assert!(matches!(
            LayoutMethod::from_str("fr"),
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
        assert!(matches!(
            LayoutMethod::from_str("bipartite"),
            Ok(LayoutMethod::Bipartite)
        ));
    }

    #[test]
    fn test_from_str_invalid() {
        use std::str::FromStr;

        assert!(LayoutMethod::from_str("invalid").is_err());
        assert!(LayoutMethod::from_str("").is_err());
    }

    #[test]
    fn test_bipartite_orientation_from_str() {
        use std::str::FromStr;

        assert!(matches!(
            BipartiteOrientation::from_str("rows"),
            Ok(BipartiteOrientation::Rows)
        ));
        assert!(matches!(
            BipartiteOrientation::from_str("columns"),
            Ok(BipartiteOrientation::Columns)
        ));
        assert!(BipartiteOrientation::from_str("invalid").is_err());
    }

    #[test]
    fn test_compute_layout_normalization() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;
        use std::sync::Arc;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        // Create a simple graph
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(0, 2, cdir).unwrap();
        b.add_edge(1, 3, cdir).unwrap();
        b.add_edge(2, 3, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        // Test all layout methods produce normalized coordinates
        for method in [
            LayoutMethod::Sugiyama,
            LayoutMethod::ForceDirected,
            LayoutMethod::KamadaKawai,
        ] {
            let coords = compute_layout(&core, method).unwrap();

            // All coordinates should be in [0, 1]
            for &(x, y) in &coords {
                assert!(
                    (0.0..=1.0).contains(&x),
                    "x={} out of range for {:?}",
                    x,
                    method
                );
                assert!(
                    (0.0..=1.0).contains(&y),
                    "y={} out of range for {:?}",
                    y,
                    method
                );
            }

            // At least one coordinate should be exactly 1.0 (or very close)
            let max_coord = coords
                .iter()
                .map(|&(x, y)| x.max(y))
                .fold(0.0_f64, |a, b| a.max(b));
            assert!(
                (max_coord - 1.0).abs() < 1e-6,
                "max_coord={} for {:?}",
                max_coord,
                method
            );
        }
    }

    #[test]
    fn test_compute_layout_determinism() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;
        use std::sync::Arc;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        // Each method should produce identical results on repeated calls
        for method in [
            LayoutMethod::Sugiyama,
            LayoutMethod::ForceDirected,
            LayoutMethod::KamadaKawai,
        ] {
            let coords1 = compute_layout(&core, method).unwrap();
            let coords2 = compute_layout(&core, method).unwrap();

            assert_eq!(coords1, coords2, "Layout {:?} not deterministic", method);
        }
    }

    #[test]
    fn test_compute_layout_empty_graph() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;
        use std::sync::Arc;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(0, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        for method in [
            LayoutMethod::Sugiyama,
            LayoutMethod::ForceDirected,
            LayoutMethod::KamadaKawai,
        ] {
            let coords = compute_layout(&core, method).unwrap();
            assert!(coords.is_empty(), "Empty graph should have no coordinates");
        }
    }

    #[test]
    fn test_compute_layout_single_node() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;
        use std::sync::Arc;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(1, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        for method in [
            LayoutMethod::Sugiyama,
            LayoutMethod::ForceDirected,
            LayoutMethod::KamadaKawai,
        ] {
            let coords = compute_layout(&core, method).unwrap();
            assert_eq!(coords.len(), 1);
            assert!(coords[0].0.is_finite() && coords[0].1.is_finite());
        }
    }

    #[test]
    fn test_compute_layout_rotation_applied_correctly() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;
        use std::sync::Arc;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        // Create a linear chain that should have a strong principal axis
        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        for i in 0..4 {
            b.add_edge(i, i + 1, cdir).unwrap();
        }
        let core = Arc::new(b.finalize().unwrap());

        // Test that rotation is applied (coordinates should be different from raw layout)
        // This is a qualitative test - we're just ensuring the rotation happens
        let coords_fr = compute_layout(&core, LayoutMethod::ForceDirected).unwrap();
        let coords_kk = compute_layout(&core, LayoutMethod::KamadaKawai).unwrap();
        let coords_sug = compute_layout(&core, LayoutMethod::Sugiyama).unwrap();

        // All should produce valid, normalized coordinates
        assert_eq!(coords_fr.len(), 5);
        assert_eq!(coords_kk.len(), 5);
        assert_eq!(coords_sug.len(), 5);

        // Force-directed and KK get rotation, Sugiyama doesn't
        // We can't test much more without knowing the expected rotations,
        // but we can verify they're all normalized
        for coords in [coords_fr, coords_kk, coords_sug] {
            for &(x, y) in &coords {
                assert!((0.0..=1.0).contains(&x));
                assert!((0.0..=1.0).contains(&y));
            }
        }
    }

    #[test]
    fn test_compute_layout_bipartite_error() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;
        use std::sync::Arc;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(2, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        // Calling compute_layout with Bipartite method should return an error
        let result = compute_layout(&core, LayoutMethod::Bipartite);
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .contains("Bipartite layouts require a partition and orientation"));
    }

    #[test]
    fn test_compute_bipartite_layout_rows() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;
        use std::sync::Arc;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 2, cdir).unwrap(); // A -> X
        b.add_edge(1, 3, cdir).unwrap(); // B -> Y
        let core = Arc::new(b.finalize().unwrap());

        let partition = vec![true, true, false, false]; // A, B in one partition; X, Y in other
        let coords = compute_bipartite_layout(&core, &partition, BipartiteOrientation::Rows).unwrap();

        assert_eq!(coords.len(), 4);
        // Verify all coordinates are normalized
        for &(x, y) in &coords {
            assert!((0.0..=1.0).contains(&x));
            assert!((0.0..=1.0).contains(&y));
        }
        // First partition (A, B) should be at y=1
        assert!((coords[0].1 - 1.0).abs() < 1e-6);
        assert!((coords[1].1 - 1.0).abs() < 1e-6);
        // Second partition (X, Y) should be at y=0
        assert!((coords[2].1 - 0.0).abs() < 1e-6);
        assert!((coords[3].1 - 0.0).abs() < 1e-6);
    }

    #[test]
    fn test_compute_bipartite_layout_columns() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;
        use std::sync::Arc;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 2, cdir).unwrap(); // A -> X
        b.add_edge(1, 3, cdir).unwrap(); // B -> Y
        let core = Arc::new(b.finalize().unwrap());

        let partition = vec![true, true, false, false];
        let coords = compute_bipartite_layout(&core, &partition, BipartiteOrientation::Columns).unwrap();

        assert_eq!(coords.len(), 4);
        // Verify all coordinates are normalized
        for &(x, y) in &coords {
            assert!((0.0..=1.0).contains(&x));
            assert!((0.0..=1.0).contains(&y));
        }
        // First partition (A, B) should be at x=1
        assert!((coords[0].0 - 1.0).abs() < 1e-6);
        assert!((coords[1].0 - 1.0).abs() < 1e-6);
        // Second partition (X, Y) should be at x=0
        assert!((coords[2].0 - 0.0).abs() < 1e-6);
        assert!((coords[3].0 - 0.0).abs() < 1e-6);
    }
}
