// SPDX-License-Identifier: MIT
//! Connected component detection and layout packing utilities.

use crate::graph::CaugiGraph;
/// Returns a vector where component[i] is the component ID for node i.
pub fn detect_components(graph: &CaugiGraph) -> Vec<usize> {
    let n = graph.n() as usize;
    if n == 0 {
        return Vec::new();
    }

    let mut component = vec![usize::MAX; n];
    let mut current_component = 0;

    for start in 0..n {
        if component[start] != usize::MAX {
            continue;
        }

        // BFS to find all nodes in this component
        let mut queue = std::collections::VecDeque::new();
        queue.push_back(start);
        component[start] = current_component;

        while let Some(u) = queue.pop_front() {
            // Get outgoing edges
            let range = graph.row_range(u as u32);
            for idx in range {
                let v = graph.col_index[idx] as usize;
                if component[v] == usize::MAX {
                    component[v] = current_component;
                    queue.push_back(v);
                }
            }

            // For directed edges, also check incoming edges
            // We need to traverse the entire CSR to find edges pointing to u
            (0..n).for_each(|i| {
                if component[i] == usize::MAX {
                    let range = graph.row_range(i as u32);
                    for idx in range {
                        let j = graph.col_index[idx] as usize;
                        if j == u {
                            component[i] = current_component;
                            queue.push_back(i);
                        }
                    }
                }
            });
        }

        current_component += 1;
    }

    component
}

/// Group nodes by component.
/// Returns a vector of vectors, where each inner vector contains node indices in one component.
pub fn group_by_component(components: &[usize]) -> Vec<Vec<usize>> {
    if components.is_empty() {
        return Vec::new();
    }

    let num_components = components.iter().max().map(|&x| x + 1).unwrap_or(0);
    let mut groups = vec![Vec::new(); num_components];

    for (node, &comp) in components.iter().enumerate() {
        groups[comp].push(node);
    }

    groups
}

/// Bounding box for a component layout.
#[derive(Debug, Clone, Copy)]
struct BoundingBox {
    min_x: f64,
    max_x: f64,
    min_y: f64,
    max_y: f64,
}

impl BoundingBox {
    fn width(&self) -> f64 {
        self.max_x - self.min_x
    }

    fn height(&self) -> f64 {
        self.max_y - self.min_y
    }

    fn from_coords(coords: &[(f64, f64)]) -> Self {
        let mut bbox = BoundingBox {
            min_x: f64::INFINITY,
            max_x: f64::NEG_INFINITY,
            min_y: f64::INFINITY,
            max_y: f64::NEG_INFINITY,
        };

        for &(x, y) in coords {
            bbox.min_x = bbox.min_x.min(x);
            bbox.max_x = bbox.max_x.max(x);
            bbox.min_y = bbox.min_y.min(y);
            bbox.max_y = bbox.max_y.max(y);
        }

        bbox
    }
}

/// A component layout with its node indices and coordinates.
type ComponentLayout = (Vec<usize>, Vec<(f64, f64)>);

/// A component layout enriched with bounding box and area information.
type ComponentWithBBox = (Vec<usize>, Vec<(f64, f64)>, BoundingBox, f64);

/// Pack multiple component layouts into a single layout.
/// Components are arranged in a grid with target aspect ratio (width / height).
/// Returns combined coordinates for all nodes in original order.
///
/// # Aspect Ratio
/// - `1.0` = square grid (e.g., 9 components → 3×3)
/// - `2.0` = prefer 2:1 width:height (e.g., 6 components → 3×2)
/// - `0.5` = prefer 1:2 width:height (e.g., 6 components → 2×3)
/// - `f64::INFINITY` = single row (horizontal)
/// - `0.0` = single column (vertical)
pub fn pack_component_layouts(
    component_layouts: Vec<ComponentLayout>,
    padding: f64,
    aspect_ratio: f64,
) -> Vec<(f64, f64)> {
    if component_layouts.is_empty() {
        return Vec::new();
    }

    // Single component - no packing needed
    if component_layouts.len() == 1 {
        let (nodes, coords) = &component_layouts[0];
        let bbox = BoundingBox::from_coords(coords);
        let mut result = vec![(0.0, 0.0); coords.len()];
        for (i, &node_id) in nodes.iter().enumerate() {
            let (x, y) = coords[i];
            result[node_id] = (x - bbox.min_x, y - bbox.min_y);
        }
        return result;
    }

    let total_nodes = component_layouts.iter().map(|(nodes, _)| nodes.len()).sum();

    // Compute bounding boxes and sort by size (largest first)
    let mut components_with_bbox: Vec<ComponentWithBBox> = component_layouts
        .into_iter()
        .map(|(nodes, coords)| {
            let bbox = BoundingBox::from_coords(&coords);
            let area = bbox.width() * bbox.height();
            (nodes, coords, bbox, area)
        })
        .collect();

    components_with_bbox.sort_by(|a, b| b.3.partial_cmp(&a.3).unwrap_or(std::cmp::Ordering::Equal));

    // Calculate grid dimensions based on aspect ratio
    let num_components = components_with_bbox.len();
    let (cols, rows) = if aspect_ratio.is_infinite() {
        // Horizontal: single row
        (num_components, 1)
    } else if aspect_ratio == 0.0 {
        // Vertical: single column
        (1, num_components)
    } else {
        // Grid with target aspect ratio
        // aspect_ratio = width / height = cols / rows
        // We want cols * rows >= num_components
        // And cols / rows ≈ aspect_ratio
        // So cols ≈ sqrt(num_components * aspect_ratio)
        let cols = ((num_components as f64) * aspect_ratio).sqrt().ceil() as usize;
        let cols = cols.max(1); // Ensure at least 1 column
        let rows = num_components.div_ceil(cols);
        (cols, rows)
    };

    // Calculate cell sizes (max width/height in each column/row)
    let mut col_widths = vec![0.0_f64; cols];
    let mut row_heights = vec![0.0_f64; rows];

    for (idx, (_, _, bbox, _)) in components_with_bbox.iter().enumerate() {
        let col = idx % cols;
        let row = idx / cols;
        col_widths[col] = col_widths[col].max(bbox.width());
        row_heights[row] = row_heights[row].max(bbox.height());
    }

    // Calculate cell positions (cumulative with padding)
    let mut col_positions = vec![0.0_f64; cols];
    let mut row_positions = vec![0.0_f64; rows];

    for i in 1..cols {
        col_positions[i] = col_positions[i - 1] + col_widths[i - 1] + padding;
    }

    for i in 1..rows {
        row_positions[i] = row_positions[i - 1] + row_heights[i - 1] + padding;
    }

    let mut result = vec![(0.0, 0.0); total_nodes];

    for (idx, (nodes, coords, bbox, _)) in components_with_bbox.into_iter().enumerate() {
        let col = idx % cols;
        let row = idx / cols;

        // Center component within its cell
        let cell_x = col_positions[col];
        let cell_y = row_positions[row];
        let x_center_offset = (col_widths[col] - bbox.width()) / 2.0;
        let y_center_offset = (row_heights[row] - bbox.height()) / 2.0;

        for (i, &node_id) in nodes.iter().enumerate() {
            let (x, y) = coords[i];
            result[node_id] = (
                x - bbox.min_x + cell_x + x_center_offset,
                y - bbox.min_y + cell_y + y_center_offset,
            );
        }
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use std::sync::Arc;

    #[test]
    fn test_detect_components_single() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        // Single connected component: A --> B --> C
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        let components = detect_components(&core);
        assert_eq!(components.len(), 3);
        assert_eq!(components[0], components[1]);
        assert_eq!(components[1], components[2]);
    }

    #[test]
    fn test_detect_components_multiple() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        // Two components: A --> B and C --> D
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(2, 3, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        let components = detect_components(&core);
        assert_eq!(components.len(), 4);
        assert_eq!(components[0], components[1]);
        assert_eq!(components[2], components[3]);
        assert_ne!(components[0], components[2]);
    }

    #[test]
    fn test_detect_components_isolated_nodes() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        // A --> B, C (isolated), D (isolated)
        let mut b = GraphBuilder::new_with_registry(4, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        let components = detect_components(&core);
        assert_eq!(components.len(), 4);
        assert_eq!(components[0], components[1]);
        assert_ne!(components[0], components[2]);
        assert_ne!(components[0], components[3]);
        assert_ne!(components[2], components[3]);
    }

    #[test]
    fn test_detect_components_empty() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(0, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let components = detect_components(&core);
        assert!(components.is_empty());
    }

    #[test]
    fn test_group_by_component() {
        let components = vec![0, 0, 1, 1, 2];
        let groups = group_by_component(&components);

        assert_eq!(groups.len(), 3);
        assert_eq!(groups[0], vec![0, 1]);
        assert_eq!(groups[1], vec![2, 3]);
        assert_eq!(groups[2], vec![4]);
    }

    #[test]
    fn test_group_by_component_empty() {
        let components: Vec<usize> = vec![];
        let groups = group_by_component(&components);
        assert!(groups.is_empty());
    }

    #[test]
    fn test_pack_component_layouts() {
        // Two components with simple coordinates (will be packed in 2 columns, 1 row)
        let comp1 = (vec![0, 1], vec![(0.0, 0.0), (1.0, 1.0)]);
        let comp2 = (vec![2, 3], vec![(0.0, 0.0), (1.0, 1.0)]);

        let result = pack_component_layouts(vec![comp1, comp2], 0.5, 1.0);

        assert_eq!(result.len(), 4);
        // All coordinates should be finite and non-negative
        for &(x, y) in &result {
            assert!(x.is_finite() && x >= 0.0);
            assert!(y.is_finite() && y >= 0.0);
        }
        // Components should be separated (second component has larger x coords)
        assert!(result[2].0 > result[1].0);
    }

    #[test]
    fn test_pack_component_layouts_grid() {
        // Four components should be arranged in a 2x2 grid
        let comp1 = (vec![0, 1], vec![(0.0, 0.0), (1.0, 1.0)]);
        let comp2 = (vec![2, 3], vec![(0.0, 0.0), (1.0, 1.0)]);
        let comp3 = (vec![4, 5], vec![(0.0, 0.0), (1.0, 1.0)]);
        let comp4 = (vec![6, 7], vec![(0.0, 0.0), (1.0, 1.0)]);

        let result = pack_component_layouts(vec![comp1, comp2, comp3, comp4], 0.5, 1.0);

        assert_eq!(result.len(), 8);
        // All coordinates should be valid
        for &(x, y) in &result {
            assert!(x.is_finite());
            assert!(y.is_finite());
        }
        // Should have components in both x and y dimensions
        let max_x = result.iter().map(|&(x, _)| x).fold(0.0, f64::max);
        let max_y = result.iter().map(|&(_, y)| y).fold(0.0, f64::max);
        assert!(max_x > 0.0);
        assert!(max_y > 0.0);
    }

    #[test]
    fn test_pack_component_layouts_empty() {
        let result = pack_component_layouts(vec![], 0.5, 1.0);
        assert!(result.is_empty());
    }

    #[test]
    fn test_pack_component_layouts_single() {
        let comp = (vec![0, 1, 2], vec![(0.0, 0.0), (1.0, 0.5), (0.5, 1.0)]);
        let result = pack_component_layouts(vec![comp], 0.5, 1.0);

        assert_eq!(result.len(), 3);
        assert_eq!(result[0], (0.0, 0.0));
        assert_eq!(result[1], (1.0, 0.5));
        assert_eq!(result[2], (0.5, 1.0));
    }

    #[test]
    fn test_pack_horizontal() {
        let comp1 = (vec![0, 1], vec![(0.0, 0.0), (1.0, 1.0)]);
        let comp2 = (vec![2, 3], vec![(0.0, 0.0), (1.0, 1.0)]);

        let result = pack_component_layouts(vec![comp1, comp2], 0.5, f64::INFINITY);

        assert_eq!(result.len(), 4);
        // Should be in a single row (similar y values)
        let y_vals: Vec<f64> = result.iter().map(|&(_, y)| y).collect();
        let y_range = y_vals.iter().fold(0.0_f64, |a, &b| a.max(b))
            - y_vals.iter().fold(f64::INFINITY, |a, &b| a.min(b));
        assert!(y_range <= 1.1); // Allow some tolerance
    }

    #[test]
    fn test_pack_vertical() {
        let comp1 = (vec![0, 1], vec![(0.0, 0.0), (1.0, 1.0)]);
        let comp2 = (vec![2, 3], vec![(0.0, 0.0), (1.0, 1.0)]);

        let result = pack_component_layouts(vec![comp1, comp2], 0.5, 0.0);

        assert_eq!(result.len(), 4);
        // Should be in a single column (similar x values)
        let x_vals: Vec<f64> = result.iter().map(|&(x, _)| x).collect();
        let x_range = x_vals.iter().fold(0.0_f64, |a, &b| a.max(b))
            - x_vals.iter().fold(f64::INFINITY, |a, &b| a.min(b));
        assert!(x_range <= 1.1); // Allow some tolerance
    }
}
