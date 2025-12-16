// SPDX-License-Identifier: MIT
//! Bipartite graph layout.
//!
//! Places nodes in two parallel lines (rows or columns) with even spacing.

use crate::graph::CaugiGraph;

/// Compute bipartite layout with two rows (horizontal arrangement).
///
/// The first partition is placed in the top row (y=1) and the second partition
/// is placed in the bottom row (y=0). Nodes within each partition are evenly
/// spaced along the x-axis.
pub fn bipartite_rows_layout(
    graph: &CaugiGraph,
    partition: &[bool],
) -> Result<Vec<(f64, f64)>, String> {
    let n = graph.n() as usize;

    if partition.len() != n {
        return Err(format!(
            "Partition size {} does not match node count {}",
            partition.len(),
            n
        ));
    }

    // Count nodes in each partition
    let part1_count = partition.iter().filter(|&&p| p).count();
    let part0_count = n - part1_count;

    if part0_count == 0 || part1_count == 0 {
        return Err("Both partitions must be non-empty".to_string());
    }

    let mut coords = Vec::with_capacity(n);
    let mut part0_idx = 0;
    let mut part1_idx = 0;

    for &in_part1 in partition {
        let (x, y) = if in_part1 {
            // Top row
            let x = if part1_count == 1 {
                0.5
            } else {
                part1_idx as f64 / (part1_count - 1) as f64
            };
            part1_idx += 1;
            (x, 1.0)
        } else {
            // Bottom row
            let x = if part0_count == 1 {
                0.5
            } else {
                part0_idx as f64 / (part0_count - 1) as f64
            };
            part0_idx += 1;
            (x, 0.0)
        };
        coords.push((x, y));
    }

    Ok(coords)
}

/// Compute bipartite layout with two columns (vertical arrangement).
///
/// The first partition is placed in the left column (x=0) and the second partition
/// is placed in the right column (x=1). Nodes within each partition are evenly
/// spaced along the y-axis.
pub fn bipartite_columns_layout(
    graph: &CaugiGraph,
    partition: &[bool],
) -> Result<Vec<(f64, f64)>, String> {
    let n = graph.n() as usize;

    if partition.len() != n {
        return Err(format!(
            "Partition size {} does not match node count {}",
            partition.len(),
            n
        ));
    }

    // Count nodes in each partition
    let part1_count = partition.iter().filter(|&&p| p).count();
    let part0_count = n - part1_count;

    if part0_count == 0 || part1_count == 0 {
        return Err("Both partitions must be non-empty".to_string());
    }

    let mut coords = Vec::with_capacity(n);
    let mut part0_idx = 0;
    let mut part1_idx = 0;

    for &in_part1 in partition {
        let (x, y) = if in_part1 {
            // Right column
            let y = if part1_count == 1 {
                0.5
            } else {
                part1_idx as f64 / (part1_count - 1) as f64
            };
            part1_idx += 1;
            (1.0, y)
        } else {
            // Left column
            let y = if part0_count == 1 {
                0.5
            } else {
                part0_idx as f64 / (part0_count - 1) as f64
            };
            part0_idx += 1;
            (0.0, y)
        };
        coords.push((x, y));
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
    fn test_bipartite_rows_basic() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(4, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let partition = vec![false, false, true, true];
        let coords = bipartite_rows_layout(&core, &partition).unwrap();

        assert_eq!(coords.len(), 4);
        // First two nodes in bottom row
        assert_eq!(coords[0], (0.0, 0.0));
        assert_eq!(coords[1], (1.0, 0.0));
        // Last two nodes in top row
        assert_eq!(coords[2], (0.0, 1.0));
        assert_eq!(coords[3], (1.0, 1.0));
    }

    #[test]
    fn test_bipartite_columns_basic() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(4, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let partition = vec![false, false, true, true];
        let coords = bipartite_columns_layout(&core, &partition).unwrap();

        assert_eq!(coords.len(), 4);
        // First two nodes in left column
        assert_eq!(coords[0], (0.0, 0.0));
        assert_eq!(coords[1], (0.0, 1.0));
        // Last two nodes in right column
        assert_eq!(coords[2], (1.0, 0.0));
        assert_eq!(coords[3], (1.0, 1.0));
    }

    #[test]
    fn test_bipartite_single_node_per_partition() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(2, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let partition = vec![false, true];
        let coords_rows = bipartite_rows_layout(&core, &partition).unwrap();
        let coords_cols = bipartite_columns_layout(&core, &partition).unwrap();

        // Rows: centered horizontally
        assert_eq!(coords_rows[0], (0.5, 0.0));
        assert_eq!(coords_rows[1], (0.5, 1.0));

        // Columns: centered vertically
        assert_eq!(coords_cols[0], (0.0, 0.5));
        assert_eq!(coords_cols[1], (1.0, 0.5));
    }

    #[test]
    fn test_bipartite_uneven_partitions() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(5, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let partition = vec![false, false, false, true, true];
        let coords = bipartite_rows_layout(&core, &partition).unwrap();

        assert_eq!(coords.len(), 5);
        // Three nodes in bottom row
        assert_eq!(coords[0], (0.0, 0.0));
        assert_eq!(coords[1], (0.5, 0.0));
        assert_eq!(coords[2], (1.0, 0.0));
        // Two nodes in top row
        assert_eq!(coords[3], (0.0, 1.0));
        assert_eq!(coords[4], (1.0, 1.0));
    }

    #[test]
    fn test_bipartite_invalid_partition() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(4, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        // Wrong size - rows
        let result = bipartite_rows_layout(&core, &[false, false]);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Partition size 2 does not match node count 4"));

        // Wrong size - columns
        let result = bipartite_columns_layout(&core, &[false, false]);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Partition size 2 does not match node count 4"));

        // All in one partition (all false) - rows
        let result = bipartite_rows_layout(&core, &[false, false, false, false]);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Both partitions must be non-empty"));

        // All in one partition (all true) - rows
        let result = bipartite_rows_layout(&core, &[true, true, true, true]);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Both partitions must be non-empty"));

        // All in one partition (all false) - columns
        let result = bipartite_columns_layout(&core, &[false, false, false, false]);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Both partitions must be non-empty"));

        // All in one partition (all true) - columns
        let result = bipartite_columns_layout(&core, &[true, true, true, true]);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Both partitions must be non-empty"));
    }
}
