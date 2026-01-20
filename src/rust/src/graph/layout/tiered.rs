// SPDX-License-Identifier: MIT
//! Tiered graph layout.
//!
//! Places nodes in multiple parallel tiers (rows or columns) with even spacing.

use crate::graph::CaugiGraph;

/// Compute tiered layout with multiple rows (horizontal tiers).
///
/// Each tier is placed at a distinct y-coordinate, evenly distributed from 0 to 1.
/// Within each tier, nodes are evenly spaced along the x-axis.
///
/// # Arguments
/// * `graph` - The causal graph
/// * `tier_assignments` - Vector mapping each node index to its tier index (0-based)
/// * `num_tiers` - Total number of tiers
///
/// # Returns
/// Vector of (x, y) coordinates, one per node in node index order
pub fn tiered_rows_layout(
    graph: &CaugiGraph,
    tier_assignments: &[usize],
    num_tiers: usize,
) -> Result<Vec<(f64, f64)>, String> {
    let n = graph.n() as usize;

    if tier_assignments.len() != n {
        return Err(format!(
            "Tier assignment size {} does not match node count {}",
            tier_assignments.len(),
            n
        ));
    }

    if num_tiers == 0 {
        return Err("Number of tiers must be at least 1".to_string());
    }

    // Validate tier indices
    for &tier_idx in tier_assignments {
        if tier_idx >= num_tiers {
            return Err(format!(
                "Tier index {} exceeds number of tiers {}",
                tier_idx, num_tiers
            ));
        }
    }

    // Count nodes per tier
    let mut tier_counts = vec![0usize; num_tiers];
    for &tier_idx in tier_assignments {
        tier_counts[tier_idx] += 1;
    }

    // Check all tiers are non-empty
    for (tier_idx, &count) in tier_counts.iter().enumerate() {
        if count == 0 {
            return Err(format!("Tier {} is empty", tier_idx));
        }
    }

    // Track current index within each tier for spacing
    let mut tier_positions = vec![0usize; num_tiers];
    let mut coords = Vec::with_capacity(n);

    for &tier_idx in tier_assignments {
        let tier_count = tier_counts[tier_idx];
        let position = tier_positions[tier_idx];

        // Compute x coordinate (evenly spaced within tier)
        let x = if tier_count == 1 {
            0.5
        } else {
            position as f64 / (tier_count - 1) as f64
        };

        // Compute y coordinate (tier position from top=1 to bottom=0)
        let y = if num_tiers == 1 {
            0.5
        } else {
            1.0 - (tier_idx as f64 / (num_tiers - 1) as f64)
        };

        coords.push((x, y));
        tier_positions[tier_idx] += 1;
    }

    Ok(coords)
}

/// Compute tiered layout with multiple columns (vertical tiers).
///
/// Each tier is placed at a distinct x-coordinate, evenly distributed from 0 to 1.
/// Within each tier, nodes are evenly spaced along the y-axis.
///
/// # Arguments
/// * `graph` - The causal graph
/// * `tier_assignments` - Vector mapping each node index to its tier index (0-based)
/// * `num_tiers` - Total number of tiers
///
/// # Returns
/// Vector of (x, y) coordinates, one per node in node index order
pub fn tiered_columns_layout(
    graph: &CaugiGraph,
    tier_assignments: &[usize],
    num_tiers: usize,
) -> Result<Vec<(f64, f64)>, String> {
    let n = graph.n() as usize;

    if tier_assignments.len() != n {
        return Err(format!(
            "Tier assignment size {} does not match node count {}",
            tier_assignments.len(),
            n
        ));
    }

    if num_tiers == 0 {
        return Err("Number of tiers must be at least 1".to_string());
    }

    // Validate tier indices
    for &tier_idx in tier_assignments {
        if tier_idx >= num_tiers {
            return Err(format!(
                "Tier index {} exceeds number of tiers {}",
                tier_idx, num_tiers
            ));
        }
    }

    // Count nodes per tier
    let mut tier_counts = vec![0usize; num_tiers];
    for &tier_idx in tier_assignments {
        tier_counts[tier_idx] += 1;
    }

    // Check all tiers are non-empty
    for (tier_idx, &count) in tier_counts.iter().enumerate() {
        if count == 0 {
            return Err(format!("Tier {} is empty", tier_idx));
        }
    }

    // Track current index within each tier for spacing
    let mut tier_positions = vec![0usize; num_tiers];
    let mut coords = Vec::with_capacity(n);

    for &tier_idx in tier_assignments {
        let tier_count = tier_counts[tier_idx];
        let position = tier_positions[tier_idx];

        // Compute x coordinate (tier position from left=0 to right=1)
        let x = if num_tiers == 1 {
            0.5
        } else {
            tier_idx as f64 / (num_tiers - 1) as f64
        };

        // Compute y coordinate (evenly spaced within tier)
        let y = if tier_count == 1 {
            0.5
        } else {
            position as f64 / (tier_count - 1) as f64
        };

        coords.push((x, y));
        tier_positions[tier_idx] += 1;
    }

    Ok(coords)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use std::sync::Arc;

    #[test]
    fn test_tiered_rows_basic() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(4, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        // Two tiers: nodes 0,1 in tier 0, nodes 2,3 in tier 1
        let tier_assignments = vec![0, 0, 1, 1];
        let coords = tiered_rows_layout(&core, &tier_assignments, 2).unwrap();

        assert_eq!(coords.len(), 4);
        // Tier 0 (top row, y=1)
        assert_eq!(coords[0], (0.0, 1.0));
        assert_eq!(coords[1], (1.0, 1.0));
        // Tier 1 (bottom row, y=0)
        assert_eq!(coords[2], (0.0, 0.0));
        assert_eq!(coords[3], (1.0, 0.0));
    }

    #[test]
    fn test_tiered_columns_basic() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(4, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let tier_assignments = vec![0, 0, 1, 1];
        let coords = tiered_columns_layout(&core, &tier_assignments, 2).unwrap();

        assert_eq!(coords.len(), 4);
        // Tier 0 (left column, x=0)
        assert_eq!(coords[0], (0.0, 0.0));
        assert_eq!(coords[1], (0.0, 1.0));
        // Tier 1 (right column, x=1)
        assert_eq!(coords[2], (1.0, 0.0));
        assert_eq!(coords[3], (1.0, 1.0));
    }

    #[test]
    fn test_tiered_three_tiers() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(6, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        // Three tiers with 2 nodes each
        let tier_assignments = vec![0, 0, 1, 1, 2, 2];
        let coords = tiered_rows_layout(&core, &tier_assignments, 3).unwrap();

        assert_eq!(coords.len(), 6);
        // Tier 0 (y=1.0)
        assert_eq!(coords[0].1, 1.0);
        assert_eq!(coords[1].1, 1.0);
        // Tier 1 (y=0.5)
        assert_eq!(coords[2].1, 0.5);
        assert_eq!(coords[3].1, 0.5);
        // Tier 2 (y=0.0)
        assert_eq!(coords[4].1, 0.0);
        assert_eq!(coords[5].1, 0.0);
    }

    #[test]
    fn test_tiered_uneven_tiers() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(5, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        // Uneven: 3 nodes in tier 0, 2 nodes in tier 1
        let tier_assignments = vec![0, 0, 0, 1, 1];
        let coords = tiered_rows_layout(&core, &tier_assignments, 2).unwrap();

        assert_eq!(coords.len(), 5);
        // Tier 0: three nodes evenly spaced
        assert_eq!(coords[0], (0.0, 1.0));
        assert_eq!(coords[1], (0.5, 1.0));
        assert_eq!(coords[2], (1.0, 1.0));
        // Tier 1: two nodes
        assert_eq!(coords[3], (0.0, 0.0));
        assert_eq!(coords[4], (1.0, 0.0));
    }

    #[test]
    fn test_tiered_single_node_per_tier() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(2, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let tier_assignments = vec![0, 1];
        let coords_rows = tiered_rows_layout(&core, &tier_assignments, 2).unwrap();
        let coords_cols = tiered_columns_layout(&core, &tier_assignments, 2).unwrap();

        // Rows: centered horizontally
        assert_eq!(coords_rows[0], (0.5, 1.0));
        assert_eq!(coords_rows[1], (0.5, 0.0));

        // Columns: centered vertically
        assert_eq!(coords_cols[0], (0.0, 0.5));
        assert_eq!(coords_cols[1], (1.0, 0.5));
    }

    #[test]
    fn test_tiered_single_tier() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(3, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let tier_assignments = vec![0, 0, 0];
        let coords_rows = tiered_rows_layout(&core, &tier_assignments, 1).unwrap();
        let coords_cols = tiered_columns_layout(&core, &tier_assignments, 1).unwrap();

        // Rows: all at y=0.5, evenly spaced in x
        assert_eq!(coords_rows[0], (0.0, 0.5));
        assert_eq!(coords_rows[1], (0.5, 0.5));
        assert_eq!(coords_rows[2], (1.0, 0.5));

        // Columns: all at x=0.5, evenly spaced in y
        assert_eq!(coords_cols[0], (0.5, 0.0));
        assert_eq!(coords_cols[1], (0.5, 0.5));
        assert_eq!(coords_cols[2], (0.5, 1.0));
    }

    #[test]
    fn test_tiered_invalid_tier_assignment_size() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(4, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = tiered_rows_layout(&core, &[0, 0], 2);
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .contains("Tier assignment size 2 does not match node count 4"));
    }

    #[test]
    fn test_tiered_tier_index_out_of_range() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(2, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = tiered_rows_layout(&core, &[0, 5], 2);
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .contains("Tier index 5 exceeds number of tiers 2"));
    }

    #[test]
    fn test_tiered_empty_tier() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(2, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        // Both nodes in tier 0, tier 1 is empty
        let result = tiered_rows_layout(&core, &[0, 0], 2);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Tier 1 is empty"));
    }

    #[test]
    fn test_tiered_zero_tiers() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(1, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = tiered_rows_layout(&core, &[0], 0);
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .contains("Number of tiers must be at least 1"));
    }
}
