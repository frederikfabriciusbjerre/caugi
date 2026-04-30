// SPDX-License-Identifier: MIT
//! Force-directed layout using the Fruchterman-Reingold (1991) algorithm.

use crate::graph::CaugiGraph;

pub fn force_directed_layout(graph: &CaugiGraph) -> Result<Vec<(f64, f64)>, String> {
    let n = graph.n() as usize;

    if n == 0 {
        return Ok(Vec::new());
    }
    if n == 1 {
        return Ok(vec![(0.0, 0.0)]);
    }

    // Frame and FR parameters. The exact scale is irrelevant: callers
    // PCA-rotate and normalize the output to the unit box.
    const W: f64 = 1000.0;
    const H: f64 = 1000.0;
    const ITERS: usize = 500;
    const EPS: f64 = 1e-9;

    let area = W * H;
    let k = (area / n as f64).sqrt();
    let k2 = k * k;
    let t0 = W / 10.0;

    // Deterministic circular initialization at radius 100 (matches the
    // pre-existing behaviour so determinism tests stay meaningful).
    let radius = 100.0;
    let mut pos: Vec<(f64, f64)> = (0..n)
        .map(|i| {
            let angle = 2.0 * std::f64::consts::PI * (i as f64) / (n as f64);
            (radius * angle.cos(), radius * angle.sin())
        })
        .collect();

    // Pre-collect a unique edge list from the CSR. Skip self-loops, the
    // mirrored half of symmetric edges, and the side != 0 storage of
    // directed edges (each pair is recorded twice in CSR: once on each side).
    let mut edges: Vec<(usize, usize)> = Vec::new();
    for i in 0..n {
        let range = graph.row_range(i as u32);
        for idx in range {
            let j = graph.col_index[idx] as usize;
            if i == j {
                continue;
            }
            let etype = graph.etype[idx];
            let spec = &graph.registry.specs[etype as usize];
            if spec.symmetric {
                if i > j {
                    continue;
                }
            } else if graph.side[idx] != 0 {
                continue;
            }
            edges.push((i, j));
        }
    }

    let mut disp = vec![(0.0, 0.0); n];

    for iter in 0..ITERS {
        for d in disp.iter_mut() {
            *d = (0.0, 0.0);
        }

        // Repulsive forces: every unordered pair contributes k^2 / d.
        for u in 0..n {
            for v in (u + 1)..n {
                let dx = pos[v].0 - pos[u].0;
                let dy = pos[v].1 - pos[u].1;
                let dist = (dx * dx + dy * dy).sqrt().max(EPS);
                let f = k2 / dist;
                let ux = dx / dist;
                let uy = dy / dist;
                disp[v].0 += ux * f;
                disp[v].1 += uy * f;
                disp[u].0 -= ux * f;
                disp[u].1 -= uy * f;
            }
        }

        // Attractive forces along edges: d^2 / k.
        for &(u, v) in &edges {
            let dx = pos[v].0 - pos[u].0;
            let dy = pos[v].1 - pos[u].1;
            let dist = (dx * dx + dy * dy).sqrt().max(EPS);
            let f = (dist * dist) / k;
            let ux = dx / dist;
            let uy = dy / dist;
            disp[v].0 -= ux * f;
            disp[v].1 -= uy * f;
            disp[u].0 += ux * f;
            disp[u].1 += uy * f;
        }

        // Cap each node's displacement by the current temperature.
        let t = t0 * (1.0 - (iter as f64) / (ITERS as f64));
        for i in 0..n {
            let (dx, dy) = disp[i];
            let dlen = (dx * dx + dy * dy).sqrt().max(EPS);
            let scale = dlen.min(t) / dlen;
            pos[i].0 += dx * scale;
            pos[i].1 += dy * scale;
        }
    }

    Ok(pos)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use std::sync::Arc;

    #[test]
    fn test_force_layout_empty_graph() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(0, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = force_directed_layout(&core);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), vec![]);
    }

    #[test]
    fn test_force_layout_single_node() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let b = GraphBuilder::new_with_registry(1, true, &reg);
        let core = Arc::new(b.finalize().unwrap());

        let result = force_directed_layout(&core);
        assert!(result.is_ok());
        let coords = result.unwrap();
        assert_eq!(coords.len(), 1);
        assert!(coords[0].0.is_finite());
        assert!(coords[0].1.is_finite());
    }

    #[test]
    fn test_force_layout_simple_dag() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        // Create A --> B --> C
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        let result = force_directed_layout(&core);
        assert!(result.is_ok());
        let coords = result.unwrap();
        assert_eq!(coords.len(), 3);

        // All coordinates should be finite
        for (x, y) in &coords {
            assert!(x.is_finite());
            assert!(y.is_finite());
        }
    }

    #[test]
    fn test_force_layout_with_undirected_edges() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();
        let cund = reg.code_of("---").unwrap();

        // Create A --> B --- C (force layout handles mixed edge types)
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cund).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        let result = force_directed_layout(&core);
        assert!(result.is_ok());
        let coords = result.unwrap();
        assert_eq!(coords.len(), 3);

        // All coordinates should be finite
        for (x, y) in &coords {
            assert!(x.is_finite());
            assert!(y.is_finite());
        }
    }

    #[test]
    fn test_force_layout_deterministic() {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let cdir = reg.code_of("-->").unwrap();

        // Create A --> B --> C
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, cdir).unwrap();
        b.add_edge(1, 2, cdir).unwrap();
        let core = Arc::new(b.finalize().unwrap());

        // Run layout twice
        let result1 = force_directed_layout(&core);
        let result2 = force_directed_layout(&core);

        assert!(result1.is_ok());
        assert!(result2.is_ok());

        let coords1 = result1.unwrap();
        let coords2 = result2.unwrap();

        // Should be identical (deterministic)
        assert_eq!(coords1, coords2);
    }
}
