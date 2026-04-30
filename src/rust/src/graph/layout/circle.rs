// SPDX-License-Identifier: MIT
//! Circle graph layout.
//!
//! Places all nodes evenly along the perimeter of a circle.

use crate::graph::CaugiGraph;
use std::f64::consts::TAU;

/// Compute circle layout.
///
/// Nodes are placed at evenly-spaced angles on a circle of radius 0.5
/// centered at (0.5, 0.5). The first node is placed at the top (angle pi/2)
/// and subsequent nodes proceed counter-clockwise.
pub fn circle_layout(graph: &CaugiGraph) -> Result<Vec<(f64, f64)>, String> {
    let n = graph.n() as usize;

    if n == 0 {
        return Ok(Vec::new());
    }

    if n == 1 {
        return Ok(vec![(0.5, 0.5)]);
    }

    let mut coords = Vec::with_capacity(n);
    let radius = 0.5;
    let cx = 0.5;
    let cy = 0.5;
    let start = std::f64::consts::FRAC_PI_2;

    for i in 0..n {
        let theta = start + (i as f64) * TAU / (n as f64);
        let x = cx + radius * theta.cos();
        let y = cy + radius * theta.sin();
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

    fn make_graph(n: u32) -> Arc<CaugiGraph> {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(n, true, &reg);
        Arc::new(b.finalize().unwrap())
    }

    #[test]
    fn test_circle_empty() {
        let core = make_graph(0);
        let coords = circle_layout(&core).unwrap();
        assert!(coords.is_empty());
    }

    #[test]
    fn test_circle_single_node() {
        let core = make_graph(1);
        let coords = circle_layout(&core).unwrap();
        assert_eq!(coords, vec![(0.5, 0.5)]);
    }

    #[test]
    fn test_circle_basic() {
        let core = make_graph(4);
        let coords = circle_layout(&core).unwrap();
        assert_eq!(coords.len(), 4);

        // First node at top (0.5, 1.0)
        assert!((coords[0].0 - 0.5).abs() < 1e-9);
        assert!((coords[0].1 - 1.0).abs() < 1e-9);

        // All nodes on circle of radius 0.5 around (0.5, 0.5)
        for (x, y) in &coords {
            let dx = x - 0.5;
            let dy = y - 0.5;
            let r = (dx * dx + dy * dy).sqrt();
            assert!((r - 0.5).abs() < 1e-9, "radius {} not 0.5", r);
        }
    }

    #[test]
    fn test_circle_evenly_spaced() {
        let core = make_graph(6);
        let coords = circle_layout(&core).unwrap();

        // Compute angle differences between consecutive nodes
        let angles: Vec<f64> = coords
            .iter()
            .map(|(x, y)| (y - 0.5).atan2(x - 0.5))
            .collect();

        let expected_step = TAU / 6.0;
        for i in 0..coords.len() {
            let next = (i + 1) % coords.len();
            let mut diff = angles[next] - angles[i];
            while diff <= -std::f64::consts::PI {
                diff += TAU;
            }
            while diff > std::f64::consts::PI {
                diff -= TAU;
            }
            assert!(
                (diff.abs() - expected_step).abs() < 1e-9,
                "uneven spacing: {} vs {}",
                diff.abs(),
                expected_step
            );
        }
    }

    #[test]
    fn test_circle_normalized() {
        let core = make_graph(8);
        let coords = circle_layout(&core).unwrap();
        for &(x, y) in &coords {
            assert!((0.0..=1.0).contains(&x));
            assert!((0.0..=1.0).contains(&y));
        }
    }

    #[test]
    fn test_circle_deterministic() {
        let core = make_graph(5);
        let c1 = circle_layout(&core).unwrap();
        let c2 = circle_layout(&core).unwrap();
        assert_eq!(c1, c2);
    }
}
