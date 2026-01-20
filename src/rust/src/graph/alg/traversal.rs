// SPDX-License-Identifier: MIT
//! Generic graph traversal algorithms.
//!
//! These functions provide reusable traversal patterns that work with any graph type
//! by accepting closures for accessing neighbors.

use super::bitset;

/// Compute ancestors of a single node using iterative DFS.
///
/// # Arguments
/// * `n` - Total number of nodes in the graph
/// * `i` - The node to find ancestors of
/// * `parents_of` - Function returning parents of a given node
///
/// Returns a sorted vector of ancestor node indices (not including `i` itself).
pub fn ancestors_of<'a, F>(n: u32, i: u32, parents_of: F) -> Vec<u32>
where
    F: Fn(u32) -> &'a [u32],
{
    let n = n as usize;
    let mut seen = vec![false; n];
    let mut stack: Vec<u32> = parents_of(i).to_vec();
    while let Some(u) = stack.pop() {
        let ui = u as usize;
        if std::mem::replace(&mut seen[ui], true) {
            continue;
        }
        stack.extend_from_slice(parents_of(u));
    }
    bitset::collect_from_mask(&seen)
}

/// Compute descendants of a single node using iterative DFS.
///
/// # Arguments
/// * `n` - Total number of nodes in the graph
/// * `i` - The node to find descendants of
/// * `children_of` - Function returning children of a given node
///
/// Returns a sorted vector of descendant node indices (not including `i` itself).
pub fn descendants_of<'a, F>(n: u32, i: u32, children_of: F) -> Vec<u32>
where
    F: Fn(u32) -> &'a [u32],
{
    let n = n as usize;
    let mut seen = vec![false; n];
    let mut stack: Vec<u32> = children_of(i).to_vec();
    while let Some(u) = stack.pop() {
        let ui = u as usize;
        if std::mem::replace(&mut seen[ui], true) {
            continue;
        }
        stack.extend_from_slice(children_of(u));
    }
    bitset::collect_from_mask(&seen)
}

/// Compute anteriors of a single node using iterative DFS.
///
/// The anterior set (Richardson and Spirtes, 2002) includes all nodes reachable
/// by following paths where every edge is either undirected or directed toward
/// the target node.
///
/// # Arguments
/// * `n` - Total number of nodes in the graph
/// * `i` - The node to find anteriors of
/// * `parents_of` - Function returning parents of a given node (directed edges pointing in)
/// * `undirected_of` - Function returning undirected neighbors of a given node
///
/// Returns a sorted vector of anterior node indices (not including `i` itself).
pub fn anteriors_of<'a, F, G>(n: u32, i: u32, parents_of: F, undirected_of: G) -> Vec<u32>
where
    F: Fn(u32) -> &'a [u32],
    G: Fn(u32) -> &'a [u32],
{
    let n = n as usize;
    let mut seen = vec![false; n];
    let mut stack: Vec<u32> = Vec::new();

    // Mark i as seen so it won't be included in the result
    seen[i as usize] = true;

    // Initialize with parents and undirected neighbors of i
    stack.extend_from_slice(parents_of(i));
    stack.extend_from_slice(undirected_of(i));

    while let Some(u) = stack.pop() {
        let ui = u as usize;
        if std::mem::replace(&mut seen[ui], true) {
            continue;
        }
        // Continue traversing via parents and undirected neighbors
        stack.extend_from_slice(parents_of(u));
        stack.extend_from_slice(undirected_of(u));
    }
    // Reset i's flag before collecting so it's not included
    seen[i as usize] = false;
    bitset::collect_from_mask(&seen)
}

/// Compute DAG-style Markov blanket of a single node.
///
/// The Markov blanket consists of: Pa(i) ∪ Ch(i) ∪ (⋃ Pa(c) \ {i} : c∈Ch(i))
///
/// # Arguments
/// * `n` - Total number of nodes in the graph
/// * `i` - The node to find the Markov blanket of
/// * `parents_of` - Function returning parents of a given node
/// * `children_of` - Function returning children of a given node
///
/// Returns a sorted vector of node indices in the Markov blanket (not including `i` itself).
pub fn markov_blanket_dag<'a, F, G>(n: u32, i: u32, parents_of: F, children_of: G) -> Vec<u32>
where
    F: Fn(u32) -> &'a [u32],
    G: Fn(u32) -> &'a [u32],
{
    let n = n as usize;
    let mut m = vec![false; n];

    // Parents
    for &p in parents_of(i) {
        m[p as usize] = true;
    }

    // Children
    for &c in children_of(i) {
        m[c as usize] = true;
        // Co-parents of children
        for &p in parents_of(c) {
            if p != i {
                m[p as usize] = true;
            }
        }
    }

    m[i as usize] = false; // exclude self
    bitset::collect_from_mask(&m)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ancestors_of_simple_chain() {
        // Graph: 2 -> 1 -> 0
        let parents_of = |n: u32| -> &[u32] {
            match n {
                0 => &[1],
                1 => &[2],
                _ => &[],
            }
        };

        assert_eq!(ancestors_of(3, 0, parents_of), vec![1, 2]);
        assert_eq!(ancestors_of(3, 1, parents_of), vec![2]);
        assert_eq!(ancestors_of(3, 2, parents_of), Vec::<u32>::new());
    }

    #[test]
    fn descendants_of_simple_chain() {
        // Graph: 0 -> 1 -> 2
        let children_of = |n: u32| -> &[u32] {
            match n {
                0 => &[1],
                1 => &[2],
                _ => &[],
            }
        };

        assert_eq!(descendants_of(3, 0, children_of), vec![1, 2]);
        assert_eq!(descendants_of(3, 1, children_of), vec![2]);
        assert_eq!(descendants_of(3, 2, children_of), Vec::<u32>::new());
    }

    #[test]
    fn markov_blanket_dag_v_structure() {
        // Graph: 2 -> 1 <- 0 -> 3
        let p1 = [0, 2];
        let parents_of = |n: u32| -> &[u32] {
            match n {
                1 => &p1,
                3 => &[0],
                _ => &[],
            }
        };
        let c0 = [1, 3];
        let children_of = |n: u32| -> &[u32] {
            match n {
                0 => &c0,
                2 => &[1],
                _ => &[],
            }
        };

        // MB(0) = pa(0)=∅, ch(0)={1,3}, spouses via 1={2}
        assert_eq!(
            markov_blanket_dag(4, 0, parents_of, children_of),
            vec![1, 2, 3]
        );
    }

    #[test]
    fn anteriors_of_pdag_mixed() {
        // PDAG: 0 -> 1 --- 2, 1 -> 3
        // Parents: 1 has parent 0, 3 has parent 1
        // Undirected: 1 --- 2
        let parents_of = |n: u32| -> &[u32] {
            match n {
                1 => &[0],
                3 => &[1],
                _ => &[],
            }
        };
        let u1 = [2];
        let u2 = [1];
        let undirected_of = |n: u32| -> &[u32] {
            match n {
                1 => &u1,
                2 => &u2,
                _ => &[],
            }
        };

        // Anteriors of 0: none (no parents, no undirected neighbors)
        assert_eq!(
            anteriors_of(4, 0, parents_of, undirected_of),
            Vec::<u32>::new()
        );
        // Anteriors of 1: 0 (parent) and 2 (undirected)
        assert_eq!(anteriors_of(4, 1, parents_of, undirected_of), vec![0, 2]);
        // Anteriors of 2: 1 (undirected) -> 0 (parent of 1)
        assert_eq!(anteriors_of(4, 2, parents_of, undirected_of), vec![0, 1]);
        // Anteriors of 3: 1 (parent) -> 0 (parent of 1), 2 (undirected of 1)
        assert_eq!(anteriors_of(4, 3, parents_of, undirected_of), vec![0, 1, 2]);
    }

    #[test]
    fn anteriors_of_undirected_cycle() {
        // PDAG with undirected triangle: 0 --- 1 --- 2 --- 0
        let u0 = [1, 2];
        let u1 = [0, 2];
        let u2 = [0, 1];
        let parents_of = |_: u32| -> &[u32] { &[] };
        let undirected_of = |n: u32| -> &[u32] {
            match n {
                0 => &u0,
                1 => &u1,
                2 => &u2,
                _ => &[],
            }
        };

        // All nodes can reach all others via undirected edges
        assert_eq!(anteriors_of(3, 0, parents_of, undirected_of), vec![1, 2]);
        assert_eq!(anteriors_of(3, 1, parents_of, undirected_of), vec![0, 2]);
        assert_eq!(anteriors_of(3, 2, parents_of, undirected_of), vec![0, 1]);
    }
}
