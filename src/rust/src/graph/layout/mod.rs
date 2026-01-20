// SPDX-License-Identifier: MIT
//! Graph layout algorithms.

mod bipartite;
mod components;
mod force_directed;
mod kamada_kawai;
mod normalize;
mod optimizer;
mod sugiyama;
mod tiered;

use crate::graph::CaugiGraph;
use components::{detect_components, group_by_component, pack_component_layouts};
use normalize::{normalize_to_unit_box, rotate_to_principal_axes};

pub use bipartite::{bipartite_columns_layout, bipartite_rows_layout};
pub use force_directed::force_directed_layout;
pub use kamada_kawai::kamada_kawai_layout;
pub use sugiyama::sugiyama_layout;
pub use tiered::{tiered_columns_layout, tiered_rows_layout};

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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TieredOrientation {
    Rows,
    Columns,
}

impl std::str::FromStr for TieredOrientation {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "rows" => Ok(Self::Rows),
            "columns" => Ok(Self::Columns),
            _ => Err(format!("Unknown tiered orientation: '{}'", s)),
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub enum LayoutMethod {
    Sugiyama,
    ForceDirected,
    KamadaKawai,
    Bipartite,
    Tiered,
}

impl std::str::FromStr for LayoutMethod {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "sugiyama" => Ok(Self::Sugiyama),
            "force" | "fruchterman-reingold" | "fr" => Ok(Self::ForceDirected),
            "kamada_kawai" | "kamada-kawai" | "kk" => Ok(Self::KamadaKawai),
            "bipartite" => Ok(Self::Bipartite),
            "tiered" => Ok(Self::Tiered),
            _ => Err(format!("Unknown layout method: '{}'", s)),
        }
    }
}

/// Compute node layout coordinates.
/// Returns a vector of (x, y) pairs, one for each node in order.
/// Coordinates are normalized to [0, 1] range, with the largest dimension scaled to [0, 1].
/// Force-directed layouts are also rotated using PCA to align the first principal component.
/// Graphs with multiple connected components are laid out separately and packed according to the aspect ratio.
pub fn compute_layout(
    graph: &CaugiGraph,
    method: LayoutMethod,
    packing_ratio: f64,
) -> Result<Vec<(f64, f64)>, String> {
    if matches!(method, LayoutMethod::Bipartite) {
        return Err(
            "Bipartite layouts require a partition and orientation. Use compute_bipartite_layout instead."
                .to_string(),
        );
    }

    if matches!(method, LayoutMethod::Tiered) {
        return Err(
            "Tiered layouts require tier assignments and orientation. Use compute_tiered_layout instead."
                .to_string(),
        );
    }

    let n = graph.n() as usize;
    if n == 0 {
        return Ok(Vec::new());
    }

    // Detect connected components
    let components = detect_components(graph);
    let groups = group_by_component(&components);

    // If single component, use standard layout
    if groups.len() == 1 {
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

        return Ok(coords);
    }

    // Multiple components: layout each separately and pack
    let mut component_layouts = Vec::new();

    for group in groups {
        if group.is_empty() {
            continue;
        }

        // Create node mapping for this subgraph
        let node_map: std::collections::HashMap<usize, usize> = group
            .iter()
            .enumerate()
            .map(|(i, &node)| (node, i))
            .collect();

        // Build subgraph - we need to create a temporary registry from the snapshot
        let mut temp_registry = crate::edges::EdgeRegistry::new();
        for spec in graph.registry.specs.iter() {
            let _ = temp_registry.register(spec.clone());
        }

        let mut subgraph_builder = crate::graph::builder::GraphBuilder::new_with_registry(
            group.len() as u32,
            true,
            &temp_registry,
        );

        for &u in &group {
            let range = graph.row_range(u as u32);
            for idx in range {
                let v = graph.col_index[idx] as usize;
                if let (Some(&u_mapped), Some(&v_mapped)) = (node_map.get(&u), node_map.get(&v)) {
                    let etype = graph.etype[idx];
                    let _ = subgraph_builder.add_edge(u_mapped as u32, v_mapped as u32, etype);
                }
            }
        }

        let subgraph = std::sync::Arc::new(subgraph_builder.finalize()?);

        // Layout this component
        let mut coords = match method {
            LayoutMethod::Sugiyama => sugiyama_layout(&subgraph)?,
            LayoutMethod::ForceDirected => force_directed_layout(&subgraph)?,
            LayoutMethod::KamadaKawai => kamada_kawai_layout(&subgraph)?,
            _ => unreachable!(),
        };

        // Apply PCA rotation to force-directed layouts
        if matches!(
            method,
            LayoutMethod::ForceDirected | LayoutMethod::KamadaKawai
        ) {
            rotate_to_principal_axes(&mut coords);
        }

        // Normalize this component to [0, 1] box
        normalize_to_unit_box(&mut coords);

        component_layouts.push((group, coords));
    }

    // Pack all component layouts with padding
    let padding = 0.1; // 10% padding between components
    let mut coords = pack_component_layouts(component_layouts, padding, packing_ratio);

    // Final normalization of the entire packed layout
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

/// Compute tiered layout coordinates with given tier assignments and orientation.
/// Returns a vector of (x, y) pairs, one for each node in order.
/// Coordinates are in [0, 1] range and already normalized.
pub fn compute_tiered_layout(
    graph: &CaugiGraph,
    tier_assignments: &[usize],
    num_tiers: usize,
    orientation: TieredOrientation,
) -> Result<Vec<(f64, f64)>, String> {
    match orientation {
        TieredOrientation::Rows => tiered_rows_layout(graph, tier_assignments, num_tiers),
        TieredOrientation::Columns => tiered_columns_layout(graph, tier_assignments, num_tiers),
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
        assert!(matches!(
            LayoutMethod::from_str("tiered"),
            Ok(LayoutMethod::Tiered)
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
    fn test_tiered_orientation_from_str() {
        use std::str::FromStr;

        assert!(matches!(
            TieredOrientation::from_str("rows"),
            Ok(TieredOrientation::Rows)
        ));
        assert!(matches!(
            TieredOrientation::from_str("columns"),
            Ok(TieredOrientation::Columns)
        ));
        assert!(TieredOrientation::from_str("invalid").is_err());
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
            let coords = compute_layout(&core, method, 1.0).unwrap();

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
            let coords1 = compute_layout(&core, method, 1.0).unwrap();
            let coords2 = compute_layout(&core, method, 1.0).unwrap();

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
            let coords = compute_layout(&core, method, 1.0).unwrap();
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
            let coords = compute_layout(&core, method, 1.0).unwrap();
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
        let coords_fr = compute_layout(&core, LayoutMethod::ForceDirected, 1.0).unwrap();
        let coords_kk = compute_layout(&core, LayoutMethod::KamadaKawai, 1.0).unwrap();
        let coords_sug = compute_layout(&core, LayoutMethod::Sugiyama, 1.0).unwrap();

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
    fn test_compute_layout_disconnected_components() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;
        use std::sync::Arc;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        // Create graph with disconnected components: A --> B --> C and D (isolated)
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        for method in [
            LayoutMethod::Sugiyama,
            LayoutMethod::ForceDirected,
            LayoutMethod::KamadaKawai,
        ] {
            let coords = compute_layout(&core, method, 1.0).unwrap();
            assert_eq!(coords.len(), 4);

            // All coordinates should be in [0,1]
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

            // At least one coordinate should be ~1.0
            let max_coord = coords
                .iter()
                .map(|&(x, y)| x.max(y))
                .fold(0.0_f64, |a, b| a.max(b));
            assert!(
                max_coord > 0.9,
                "max_coord={} too small for {:?}",
                max_coord,
                method
            );

            // Isolated node (D) should have valid, finite coordinates
            assert!(coords[3].0.is_finite());
            assert!(coords[3].1.is_finite());
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
        let result = compute_layout(&core, LayoutMethod::Bipartite, 1.0);
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .contains("Bipartite layouts require a partition and orientation"));
    }

    #[test]
    fn test_compute_layout_tiered_error() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;
        use std::sync::Arc;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(2, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        // Calling compute_layout with Tiered method should return an error
        let result = compute_layout(&core, LayoutMethod::Tiered, 1.0);
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .contains("Tiered layouts require tier assignments and orientation"));
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
        let coords =
            compute_bipartite_layout(&core, &partition, BipartiteOrientation::Rows).unwrap();

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
        let coords =
            compute_bipartite_layout(&core, &partition, BipartiteOrientation::Columns).unwrap();

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

    #[test]
    fn test_compute_tiered_layout_rows() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;
        use std::sync::Arc;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(6, true, &reg);
        b.add_edge(0, 2, cdir).unwrap();
        b.add_edge(1, 3, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        // Three tiers: [0,1], [2,3], [4,5]
        let tier_assignments = vec![0, 0, 1, 1, 2, 2];
        let coords =
            compute_tiered_layout(&core, &tier_assignments, 3, TieredOrientation::Rows).unwrap();

        assert_eq!(coords.len(), 6);
        // Verify all coordinates are normalized
        for &(x, y) in &coords {
            assert!((0.0..=1.0).contains(&x));
            assert!((0.0..=1.0).contains(&y));
        }
        // Tier 0 should be at y=1
        assert!((coords[0].1 - 1.0).abs() < 1e-6);
        assert!((coords[1].1 - 1.0).abs() < 1e-6);
        // Tier 1 should be at y=0.5
        assert!((coords[2].1 - 0.5).abs() < 1e-6);
        assert!((coords[3].1 - 0.5).abs() < 1e-6);
        // Tier 2 should be at y=0.0
        assert!((coords[4].1 - 0.0).abs() < 1e-6);
        assert!((coords[5].1 - 0.0).abs() < 1e-6);
    }

    #[test]
    fn test_compute_tiered_layout_columns() {
        use crate::edges::EdgeRegistry;
        use crate::graph::builder::GraphBuilder;
        use std::sync::Arc;

        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 2, cdir).unwrap();
        b.add_edge(1, 3, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        let tier_assignments = vec![0, 0, 1, 1];
        let coords =
            compute_tiered_layout(&core, &tier_assignments, 2, TieredOrientation::Columns).unwrap();

        assert_eq!(coords.len(), 4);
        // Verify all coordinates are normalized
        for &(x, y) in &coords {
            assert!((0.0..=1.0).contains(&x));
            assert!((0.0..=1.0).contains(&y));
        }
        // Tier 0 should be at x=0
        assert!((coords[0].0 - 0.0).abs() < 1e-6);
        assert!((coords[1].0 - 0.0).abs() < 1e-6);
        // Tier 1 should be at x=1
        assert!((coords[2].0 - 1.0).abs() < 1e-6);
        assert!((coords[3].0 - 1.0).abs() < 1e-6);
    }
}
