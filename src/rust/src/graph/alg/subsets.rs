// SPDX-License-Identifier: MIT
//! Subset enumeration and manipulation utilities.

/// Remove non-minimal supersets in-place, keep inclusion-minimal sets only.
///
/// After this operation, the output contains only sets where no other set
/// in the collection is a proper subset.
pub fn prune_minimal(sets: &mut Vec<Vec<u32>>) {
    sets.iter_mut().for_each(|v| {
        v.sort_unstable();
        v.dedup();
    });
    sets.sort();
    let mut out: Vec<Vec<u32>> = Vec::new();
    'next: for z in sets.drain(..) {
        for s in &out {
            if s.iter().all(|v| z.binary_search(v).is_ok()) {
                continue 'next;
            }
        }
        out.retain(|s| !z.iter().all(|v| s.binary_search(v).is_ok()));
        out.push(z);
    }
    *sets = out;
}

/// Enumerate all `k`-subsets of `u` into `out` (lexicographic order).
///
/// # Arguments
/// * `u` - The set to enumerate subsets from
/// * `k` - The size of subsets to generate
/// * `start` - Starting index (for recursion, usually 0)
/// * `cur` - Current subset being built (for recursion, usually empty)
/// * `out` - Output vector to collect subsets
pub fn k_subsets(u: &[u32], k: usize, start: usize, cur: &mut Vec<u32>, out: &mut Vec<Vec<u32>>) {
    if cur.len() == k {
        out.push(cur.clone());
        return;
    }
    for i in start..u.len() {
        cur.push(u[i]);
        k_subsets(u, k, i + 1, cur, out);
        cur.pop();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn prune_minimal_skips_supersets_branch() {
        let mut sets = vec![vec![0], vec![0, 1]];
        prune_minimal(&mut sets);
        assert_eq!(sets, vec![vec![0]]);
    }

    #[test]
    fn prune_minimal_removes_existing_supersets_when_subset_arrives() {
        let mut sets = vec![vec![0, 1], vec![0]];
        prune_minimal(&mut sets);
        assert_eq!(sets, vec![vec![0]]);
    }

    #[test]
    fn prune_minimal_keeps_incomparable_sets() {
        let mut sets = vec![vec![0, 1], vec![1, 2], vec![0, 2]];
        prune_minimal(&mut sets);
        // All sets are incomparable, all should be kept
        assert_eq!(sets.len(), 3);
    }

    #[test]
    fn k_subsets_generates_all() {
        let u = vec![0, 1, 2, 3];
        let mut cur = vec![];
        let mut out = vec![];
        k_subsets(&u, 2, 0, &mut cur, &mut out);

        // C(4,2) = 6
        assert_eq!(out.len(), 6);
        assert!(out.contains(&vec![0, 1]));
        assert!(out.contains(&vec![0, 2]));
        assert!(out.contains(&vec![0, 3]));
        assert!(out.contains(&vec![1, 2]));
        assert!(out.contains(&vec![1, 3]));
        assert!(out.contains(&vec![2, 3]));
    }

    #[test]
    fn k_subsets_empty() {
        let u = vec![0, 1, 2];
        let mut cur = vec![];
        let mut out = vec![];
        k_subsets(&u, 0, 0, &mut cur, &mut out);

        // Only the empty set
        assert_eq!(out, vec![vec![] as Vec<u32>]);
    }
}
