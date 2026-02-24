// SPDX-License-Identifier: MIT
//! Minimal d-separator algorithm using Bayes-ball traversal for DAGs.

use super::Dag;
use crate::graph::alg::bitset;
use std::collections::{HashSet, VecDeque};

/// Direction of traversal in Bayes-ball algorithm.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
enum Direction {
    /// Arrived from a child (moving upward)
    Up,
    /// Arrived from a parent (moving downward)
    Down,
}

/// Validates that all node IDs are within bounds [0, n).
///
/// Returns `Err` with a descriptive message if any node ID is out of bounds.
fn validate_node_ids(nodes: &[u32], n: u32, context: &str) -> Result<(), String> {
    for &node in nodes {
        if node >= n {
            return Err(format!(
                "{}: node ID {} is out of bounds (graph has {} nodes)",
                context, node, n
            ));
        }
    }
    Ok(())
}

impl Dag {
    /// Bayes-ball d-connection traversal with optional ancestor restriction.
    ///
    /// Same as `d_connected` but optionally restricts the search to nodes
    /// in `ancestor_mask`. This is used by the minimal d-separator algorithm
    /// to implement the REACHABLE function from van der Zander & Liśkiewicz (2020).
    ///
    /// Implements the Bayes-ball algorithm with proper handling of conditioned nodes:
    /// - Conditioned nodes with arrival from parent (Down): can propagate to parents (chain)
    /// - Conditioned nodes with arrival from child (Up): blocked (cannot propagate)
    /// - This correctly implements the collider_if_in_Z condition from NetworkX:
    ///   `collider_if_in_Z = v not in z or (e and not f)` where e=True is Down, f=False is parent
    ///
    /// Parameters:
    /// - `start_set`: nodes to start the search from
    /// - `conditioning_set`: nodes being conditioned on
    /// - `ancestor_mask`: if Some, only visit nodes where mask[i] == true
    ///
    /// References:
    /// - van der Zander & Liśkiewicz (2020), UAI
    /// - NetworkX _reachable() and _pass() functions
    fn d_connected_restricted(
        &self,
        start_set: &[u32],
        conditioning_set: &[u32],
        ancestor_mask: Option<&[bool]>,
    ) -> Result<Vec<u32>, String> {
        let n = self.n();

        // Validate inputs
        validate_node_ids(start_set, n, "d_connected start_set")?;
        validate_node_ids(conditioning_set, n, "d_connected conditioning_set")?;

        let n = n as usize;

        // Build conditioning set mask
        let mut conditioned = vec![false; n];
        for &v in conditioning_set {
            conditioned[v as usize] = true;
        }

        // Track visited (node, direction) pairs to avoid revisiting
        // visited[node][0] = visited from Down, visited[node][1] = visited from Up
        let mut visited = vec![[false, false]; n];

        // Track which nodes we've reached (excluding start nodes themselves)
        let mut reached = vec![false; n];

        // Mark start nodes so we don't count them as reached
        let mut start_mask = vec![false; n];
        for &v in start_set {
            start_mask[v as usize] = true;
        }

        // BFS queue: (node, direction)
        let mut queue = VecDeque::new();

        // Initialize: add all start nodes with both directions
        // But don't mark them as "reached" - they are the source
        for &node in start_set {
            // Enqueue with Down direction (as if arriving from parents)
            if !visited[node as usize][0] {
                queue.push_back((node, Direction::Down));
                visited[node as usize][0] = true;
            }

            // Also enqueue with Up direction (as if arriving from children)
            if !visited[node as usize][1] {
                queue.push_back((node, Direction::Up));
                visited[node as usize][1] = true;
            }
        }

        while let Some((node, direction)) = queue.pop_front() {
            let node_idx = node as usize;
            let is_conditioned = conditioned[node_idx];

            if !is_conditioned {
                // Node is NOT conditioned
                match direction {
                    Direction::Down => {
                        // Arrived from parent: propagate to children (Down) only
                        // Do NOT propagate to parents (would activate unconditioned collider)

                        // Propagate to children with Down
                        for &child in self.children_of(node) {
                            let child_idx = child as usize;
                            // Skip if not in ancestor set (when restricted)
                            if let Some(mask) = ancestor_mask {
                                if !mask[child_idx] {
                                    continue;
                                }
                            }
                            if !visited[child_idx][0] {
                                visited[child_idx][0] = true;
                                if !start_mask[child_idx] {
                                    reached[child_idx] = true;
                                }
                                queue.push_back((child, Direction::Down));
                            }
                        }
                    }
                    Direction::Up => {
                        // Arrived from child at unconditioned node:
                        // - propagate to parents (Up)
                        // - bounce to children (Down) to handle forks
                        for &parent in self.parents_of(node) {
                            let parent_idx = parent as usize;
                            // Skip if not in ancestor set (when restricted)
                            if let Some(mask) = ancestor_mask {
                                if !mask[parent_idx] {
                                    continue;
                                }
                            }
                            if !visited[parent_idx][1] {
                                visited[parent_idx][1] = true;
                                if !start_mask[parent_idx] {
                                    reached[parent_idx] = true;
                                }
                                queue.push_back((parent, Direction::Up));
                            }
                        }

                        // Bounce to other children
                        for &child in self.children_of(node) {
                            let child_idx = child as usize;
                            // Skip if not in ancestor set (when restricted)
                            if let Some(mask) = ancestor_mask {
                                if !mask[child_idx] {
                                    continue;
                                }
                            }
                            if !visited[child_idx][0] {
                                visited[child_idx][0] = true;
                                if !start_mask[child_idx] {
                                    reached[child_idx] = true;
                                }
                                queue.push_back((child, Direction::Down));
                            }
                        }
                    }
                }
            } else {
                // Node IS conditioned
                match direction {
                    Direction::Down => {
                        // Arrived from parent at a CONDITIONED node (e=True in NetworkX)
                        // Can propagate to OTHER parents (f=False): represents chain through conditioned node
                        // (In NetworkX: e=True, v in z, f=False → collider_if_in_Z = (True and True) = True)
                        for &parent in self.parents_of(node) {
                            let parent_idx = parent as usize;
                            // Skip if not in ancestor set (when restricted)
                            if let Some(mask) = ancestor_mask {
                                if !mask[parent_idx] {
                                    continue;
                                }
                            }
                            if !visited[parent_idx][1] {
                                visited[parent_idx][1] = true;
                                if !start_mask[parent_idx] {
                                    reached[parent_idx] = true;
                                }
                                queue.push_back((parent, Direction::Up));
                            }
                        }
                    }
                    Direction::Up => {
                        // Arrived from child at a CONDITIONED node (e=False in NetworkX)
                        // CANNOT propagate anywhere - conditioned node blocks path from children
                        // (In NetworkX: e=False, v in z → collider_if_in_Z always False)
                    }
                }
            }
        }

        // Return all reached nodes
        Ok(bitset::collect_from_mask(&reached))
    }

    /// Computes a minimal d-separator for X and Y in the DAG.
    ///
    /// Given:
    /// - `xs`: source nodes
    /// - `ys`: target nodes
    /// - `include`: nodes that must be in the separator (default: empty)
    /// - `restrict`: nodes allowed in the separator (default: all nodes except X and Y)
    ///
    /// Returns:
    /// - `Some(Z)`: a minimal d-separator Z such that Z ⊆ restrict, include ⊆ Z,
    ///   and Z d-separates X from Y
    /// - `None`: if no valid separator exists within the restriction
    ///
    /// Algorithm:
    /// 1. Compute A = An(X ∪ Y ∪ I)
    /// 2. Work on induced subgraph G_A
    /// 3. Z0 = R ∩ (A \ (X ∪ Y))
    /// 4. X* = d_connected(X, Z0)
    /// 5. If X* ∩ Y ≠ ∅, return None
    /// 6. Z_X = (Z0 ∩ X*) ∪ I
    /// 7. Y* = d_connected(Y, Z_X)
    /// 8. Z = (Z_X ∩ Y*) ∪ I
    /// 9. Return Z
    pub fn minimal_d_separator(
        &self,
        xs: &[u32],
        ys: &[u32],
        include: &[u32],
        restrict: &[u32],
    ) -> Result<Option<Vec<u32>>, String> {
        let n = self.n();

        // Validate all node IDs are within bounds
        validate_node_ids(xs, n, "minimal_d_separator xs")?;
        validate_node_ids(ys, n, "minimal_d_separator ys")?;
        validate_node_ids(include, n, "minimal_d_separator include")?;
        validate_node_ids(restrict, n, "minimal_d_separator restrict")?;

        // Validate inputs
        if xs.is_empty() || ys.is_empty() {
            return Ok(None);
        }

        // Validate include ⊆ restrict (contract requirement)
        let restrict_set: HashSet<u32> = restrict.iter().copied().collect();
        for &inc_node in include {
            if !restrict_set.contains(&inc_node) {
                return Ok(None); // Cannot satisfy constraint
            }
        }

        let n = n as usize;

        // Step 1: Compute A = An(X ∪ Y ∪ I)
        let mut seeds = Vec::new();
        seeds.extend_from_slice(xs);
        seeds.extend_from_slice(ys);
        seeds.extend_from_slice(include);
        seeds.sort_unstable();
        seeds.dedup();

        let ancestor_mask = self.ancestors_mask(&seeds);

        // Step 2: Restrict computation to ancestral subgraph
        // (For simplicity, we'll work with masks; the algorithm doesn't need explicit subgraph)

        // Build HashSets for O(1) membership checks
        let xs_set: HashSet<u32> = xs.iter().copied().collect();
        let ys_set: HashSet<u32> = ys.iter().copied().collect();

        // Step 3: Z0 = R ∩ (A \ (X ∪ Y))
        let mut z0_mask = vec![false; n];
        for &r in restrict {
            let r_idx = r as usize;
            // r must be in ancestors, and not in X or Y
            if ancestor_mask[r_idx] && !xs_set.contains(&r) && !ys_set.contains(&r) {
                z0_mask[r_idx] = true;
            }
        }
        let z0 = bitset::collect_from_mask(&z0_mask);

        // Step 4: X* = d_connected(X, Z0) restricted to ancestors
        let x_star = self.d_connected_restricted(xs, &z0, Some(&ancestor_mask))?;

        // Convert x_star to HashSet for O(1) lookups
        let x_star_set: HashSet<u32> = x_star.iter().copied().collect();

        // Step 5: If X* ∩ Y ≠ ∅, return None
        for &y in ys {
            if x_star_set.contains(&y) {
                return Ok(None);
            }
        }

        // Step 6: Z_X = (Z0 ∩ X*) ∪ I
        let mut zx_mask = vec![false; n];
        // Add Z0 ∩ X*
        for &v in &z0 {
            if x_star_set.contains(&v) {
                zx_mask[v as usize] = true;
            }
        }
        // Add I
        for &v in include {
            zx_mask[v as usize] = true;
        }
        let zx = bitset::collect_from_mask(&zx_mask);

        // Step 7: Y* = d_connected(Y, Z_X) restricted to ancestors
        let y_star = self.d_connected_restricted(ys, &zx, Some(&ancestor_mask))?;

        // Convert y_star to HashSet for O(1) lookups
        let y_star_set: HashSet<u32> = y_star.iter().copied().collect();

        // Step 8: Z = (Z_X ∩ Y*) ∪ I
        let mut z_mask = vec![false; n];
        // Add Z_X ∩ Y*
        for &v in &zx {
            if y_star_set.contains(&v) {
                z_mask[v as usize] = true;
            }
        }
        // Add I
        for &v in include {
            z_mask[v as usize] = true;
        }

        // Step 9: Return Z
        Ok(Some(bitset::collect_from_mask(&z_mask)))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use std::sync::Arc;

    fn build_dag(edges: &[(u32, u32)], n: u32) -> Dag {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let directed = reg.code_of("-->").unwrap();
        let mut builder = GraphBuilder::new_with_registry(n, true, &reg);
        for &(from, to) in edges {
            builder.add_edge(from, to, directed).unwrap();
        }
        let core = Arc::new(builder.finalize().unwrap());
        Dag::new(core).unwrap()
    }

    #[test]
    fn d_connected_chain() {
        // Chain: 0 -> 1 -> 2
        let g = build_dag(&[(0, 1), (1, 2)], 3);

        // Without conditioning: 0 can reach 2
        let reachable = g.d_connected_restricted(&[0], &[], None).unwrap();
        assert!(
            reachable.contains(&2),
            "Chain: 0 should reach 2 without conditioning"
        );

        // Conditioning on 1: 0 cannot reach 2
        let reachable = g.d_connected_restricted(&[0], &[1], None).unwrap();
        assert!(
            !reachable.contains(&2),
            "Chain: 0 should not reach 2 when conditioning on 1"
        );
    }

    #[test]
    fn d_connected_fork() {
        // Fork: 0 -> 1, 0 -> 2
        let g = build_dag(&[(0, 1), (0, 2)], 3);

        // Without conditioning: 1 can reach 2
        let reachable = g.d_connected_restricted(&[1], &[], None).unwrap();
        assert!(
            reachable.contains(&2),
            "Fork: 1 should reach 2 without conditioning"
        );

        // Conditioning on 0: 1 cannot reach 2
        let reachable = g.d_connected_restricted(&[1], &[0], None).unwrap();
        assert!(
            !reachable.contains(&2),
            "Fork: 1 should not reach 2 when conditioning on 0"
        );
    }

    #[test]
    fn d_connected_collider() {
        // Collider: 0 -> 1 <- 2
        let g = build_dag(&[(0, 1), (2, 1)], 3);

        // Without conditioning: 0 cannot reach 2
        let reachable = g.d_connected_restricted(&[0], &[], None).unwrap();
        assert!(
            !reachable.contains(&2),
            "Collider: 0 should not reach 2 without conditioning"
        );

        // Conditioning on 1: 0 can reach 2 (collider activation)
        let reachable = g.d_connected_restricted(&[0], &[1], None).unwrap();
        assert!(
            reachable.contains(&2),
            "Collider: 0 should reach 2 when conditioning on 1"
        );
    }

    #[test]
    fn d_connected_empty_start() {
        let g = build_dag(&[(0, 1), (1, 2)], 3);
        let reachable = g.d_connected_restricted(&[], &[], None).unwrap();
        assert!(
            reachable.is_empty(),
            "Empty start set should return empty reachable set"
        );
    }

    #[test]
    fn minimal_d_separator_simple_chain() {
        // Chain: 0 -> 1 -> 2
        // Separator for 0 and 2: {1}
        let g = build_dag(&[(0, 1), (1, 2)], 3);
        let sep = g.minimal_d_separator(&[0], &[2], &[], &[1]).unwrap();
        assert!(sep.is_some());
        let sep = sep.unwrap();
        assert_eq!(sep, vec![1]);
    }

    #[test]
    fn minimal_d_separator_with_include() {
        // 0 -> 1 -> 2 -> 3
        // Separator for 0 and 3 with mandatory include {1, 2}
        let g = build_dag(&[(0, 1), (1, 2), (2, 3)], 4);
        let sep = g.minimal_d_separator(&[0], &[3], &[1, 2], &[1, 2]).unwrap();
        assert!(sep.is_some());
        let sep = sep.unwrap();
        assert!(
            sep.contains(&1) && sep.contains(&2),
            "Should include both mandatory nodes"
        );
    }

    #[test]
    fn minimal_d_separator_no_valid_separator() {
        // Direct edge: 0 -> 1
        // No separator possible within empty restrict set
        let g = build_dag(&[(0, 1)], 2);
        let sep = g.minimal_d_separator(&[0], &[1], &[], &[]).unwrap();
        assert!(
            sep.is_none(),
            "No separator should exist for direct edge with empty restrict"
        );
    }

    #[test]
    fn minimal_d_separator_fork_structure() {
        // Fork: 0 -> 1, 0 -> 2
        // Separator for 1 and 2: {0}
        let g = build_dag(&[(0, 1), (0, 2)], 3);
        let sep = g.minimal_d_separator(&[1], &[2], &[], &[0]).unwrap();
        assert!(sep.is_some());
        let sep = sep.unwrap();
        assert_eq!(sep, vec![0]);
    }

    #[test]
    fn minimal_d_separator_empty_inputs() {
        let g = build_dag(&[(0, 1)], 2);
        assert!(g
            .minimal_d_separator(&[], &[1], &[], &[])
            .unwrap()
            .is_none());
        assert!(g
            .minimal_d_separator(&[0], &[], &[], &[])
            .unwrap()
            .is_none());
    }

    #[test]
    fn minimal_d_separator_include_not_in_restrict() {
        // Test that include ⊆ restrict is enforced
        let g = build_dag(&[(0, 1), (1, 2)], 3);
        // Try to include node 2 but restrict to {0, 1}
        let sep = g.minimal_d_separator(&[0], &[2], &[2], &[0, 1]).unwrap();
        assert!(
            sep.is_none(),
            "Should return None when include is not subset of restrict"
        );
    }

    #[test]
    fn d_connected_bounds_check() {
        let g = build_dag(&[(0, 1)], 2);
        // Out-of-bounds start node
        assert!(g.d_connected_restricted(&[5], &[], None).is_err());
        // Out-of-bounds conditioning node
        assert!(g.d_connected_restricted(&[0], &[5], None).is_err());
    }

    #[test]
    fn minimal_d_separator_bounds_check() {
        let g = build_dag(&[(0, 1)], 2);
        // Out-of-bounds xs
        assert!(g.minimal_d_separator(&[5], &[1], &[], &[]).is_err());
        // Out-of-bounds ys
        assert!(g.minimal_d_separator(&[0], &[5], &[], &[]).is_err());
        // Out-of-bounds include
        assert!(g.minimal_d_separator(&[0], &[1], &[5], &[]).is_err());
        // Out-of-bounds restrict
        assert!(g.minimal_d_separator(&[0], &[1], &[], &[5]).is_err());
    }
}
