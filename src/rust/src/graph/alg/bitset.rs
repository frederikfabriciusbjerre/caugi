// SPDX-License-Identifier: MIT
//! Bitset utilities for graph algorithms.

/// Collect ascending indices where `mask[i]` is `true`.
#[inline]
pub fn collect_from_mask(mask: &[bool]) -> Vec<u32> {
    let mut out = Vec::with_capacity(mask.len().min(64));
    for (i, &b) in mask.iter().enumerate() {
        if b {
            out.push(i as u32);
        }
    }
    out
}

/// Build a boolean membership mask for `nodes` over domain `[0, n)`.
#[inline]
pub fn mask_from(nodes: &[u32], n: u32) -> Vec<bool> {
    let mut m = vec![false; n as usize];
    for &v in nodes {
        m[v as usize] = true;
    }
    m
}

/// Ancestors mask of a seed set. `a[v] == true` iff `v ∈ An(seeds) ∪ seeds`.
///
/// # Arguments
/// * `seeds` - Initial seed nodes
/// * `parents_of` - Function that returns parents of a given node
/// * `n` - Total number of nodes in the graph
pub fn ancestors_mask<'a, F>(seeds: &[u32], parents_of: F, n: u32) -> Vec<bool>
where
    F: Fn(u32) -> &'a [u32],
{
    let mut a = vec![false; n as usize];
    let mut st = Vec::new();
    // Seed the stack with parents of unseen seeds.
    for &s in seeds {
        if !a[s as usize] {
            a[s as usize] = true;
            st.extend_from_slice(parents_of(s));
        }
    }
    // Climb parents until fixed point.
    while let Some(u) = st.pop() {
        let ui = u as usize;
        if a[ui] {
            continue;
        }
        a[ui] = true;
        st.extend_from_slice(parents_of(u));
    }
    a
}

/// Descendants mask of a seed set. `d[v] == true` iff `v ∈ De(seeds) ∪ seeds`.
///
/// # Arguments
/// * `seeds` - Initial seed nodes
/// * `children_of` - Function that returns children of a given node
/// * `n` - Total number of nodes in the graph
pub fn descendants_mask<'a, F>(seeds: &[u32], children_of: F, n: u32) -> Vec<bool>
where
    F: Fn(u32) -> &'a [u32],
{
    let mut d = vec![false; n as usize];
    let mut st = Vec::new();
    // Seed the stack with children of unseen seeds.
    for &s in seeds {
        if !d[s as usize] {
            d[s as usize] = true;
            st.extend_from_slice(children_of(s));
        }
    }
    // Descend through children until fixed point.
    while let Some(u) = st.pop() {
        let ui = u as usize;
        if d[ui] {
            continue;
        }
        d[ui] = true;
        st.extend_from_slice(children_of(u));
    }
    d
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn collect_from_mask_empty() {
        let mask = vec![false, false, false];
        assert_eq!(collect_from_mask(&mask), Vec::<u32>::new());
    }

    #[test]
    fn collect_from_mask_all() {
        let mask = vec![true, true, true];
        assert_eq!(collect_from_mask(&mask), vec![0, 1, 2]);
    }

    #[test]
    fn collect_from_mask_sparse() {
        let mask = vec![false, true, false, true, false];
        assert_eq!(collect_from_mask(&mask), vec![1, 3]);
    }

    #[test]
    fn mask_from_empty() {
        let m = mask_from(&[], 5);
        assert_eq!(m, vec![false, false, false, false, false]);
    }

    #[test]
    fn mask_from_some() {
        let m = mask_from(&[1, 3], 5);
        assert_eq!(m, vec![false, true, false, true, false]);
    }

    #[test]
    fn ancestors_mask_simple_chain() {
        // Mock graph: 2 -> 1 -> 0
        let parents_of = |n: u32| -> &[u32] {
            match n {
                0 => &[1],
                1 => &[2],
                2 => &[],
                _ => &[],
            }
        };

        let mask = ancestors_mask(&[0], parents_of, 3);
        // 0 and its ancestors {1, 2}
        assert_eq!(mask, vec![true, true, true]);

        // Hit the fallback branch in the mock closure.
        let mask2 = ancestors_mask(&[3], parents_of, 4);
        assert_eq!(mask2, vec![false, false, false, true]);
    }

    #[test]
    fn ancestors_mask_multiple_seeds() {
        // Mock graph: 3 -> 1, 2 -> 0
        let parents_of = |n: u32| -> &[u32] {
            match n {
                0 => &[2],
                1 => &[3],
                _ => &[],
            }
        };

        let mask = ancestors_mask(&[0, 1], parents_of, 4);
        // Seeds {0, 1} and their ancestors {2, 3}
        assert_eq!(mask, vec![true, true, true, true]);
    }

    #[test]
    fn ancestors_mask_diamond() {
        // Mock graph: 3 -> {1, 2} -> 0
        let p1 = [1, 2];
        let p3 = [3];
        let parents_of = |n: u32| -> &[u32] {
            match n {
                0 => &p1,
                1 => &p3,
                2 => &p3,
                _ => &[],
            }
        };

        let mask = ancestors_mask(&[0], parents_of, 4);
        // All nodes are ancestors or seed
        assert_eq!(mask, vec![true, true, true, true]);
    }

    #[test]
    fn descendants_mask_simple_chain() {
        // Mock graph: 0 -> 1 -> 2
        let children_of = |n: u32| -> &[u32] {
            match n {
                0 => &[1],
                1 => &[2],
                2 => &[],
                _ => &[],
            }
        };

        let mask = descendants_mask(&[0], children_of, 3);
        // 0 and its descendants {1, 2}
        assert_eq!(mask, vec![true, true, true]);

        // Hit the fallback branch in the mock closure.
        let mask2 = descendants_mask(&[3], children_of, 4);
        assert_eq!(mask2, vec![false, false, false, true]);
    }

    #[test]
    fn descendants_mask_multiple_seeds() {
        // Mock graph: 0 -> 2, 1 -> 3
        let children_of = |n: u32| -> &[u32] {
            match n {
                0 => &[2],
                1 => &[3],
                _ => &[],
            }
        };

        let mask = descendants_mask(&[0, 1], children_of, 4);
        // Seeds {0, 1} and their descendants {2, 3}
        assert_eq!(mask, vec![true, true, true, true]);
    }

    #[test]
    fn descendants_mask_diamond() {
        // Mock graph: 0 -> {1, 2} -> 3
        let c1 = [1, 2];
        let c3 = [3];
        let children_of = |n: u32| -> &[u32] {
            match n {
                0 => &c1,
                1 => &c3,
                2 => &c3,
                _ => &[],
            }
        };

        let mask = descendants_mask(&[0], children_of, 4);
        // All nodes are descendants or seed
        assert_eq!(mask, vec![true, true, true, true]);
    }
}
