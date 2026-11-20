// SPDX-License-Identifier: MIT
//! Shared Meek closure helpers for CPDAG orientation.

use std::collections::{HashSet, VecDeque};

#[inline]
pub(crate) fn adjacent(
    a: usize,
    b: usize,
    und: &[HashSet<u32>],
    pa: &[HashSet<u32>],
    ch: &[HashSet<u32>],
) -> bool {
    und[a].contains(&(b as u32))
        || und[b].contains(&(a as u32))
        || pa[a].contains(&(b as u32))
        || ch[a].contains(&(b as u32))
        || pa[b].contains(&(a as u32))
        || ch[b].contains(&(a as u32))
}

#[inline]
pub(crate) fn orient(
    a: u32,
    b: u32,
    und: &mut [HashSet<u32>],
    pa: &mut [HashSet<u32>],
    ch: &mut [HashSet<u32>],
) {
    let ai = a as usize;
    let bi = b as usize;
    und[ai].remove(&b);
    und[bi].remove(&a);
    ch[ai].insert(b);
    pa[bi].insert(a);
}

#[inline]
fn try_orient(
    a: u32,
    b: u32,
    und: &mut [HashSet<u32>],
    pa: &mut [HashSet<u32>],
    ch: &mut [HashSet<u32>],
) -> bool {
    let ai = a as usize;
    if !und[ai].contains(&b) {
        return false;
    }
    if has_dir_path(ch, b, a) {
        return false;
    }
    orient(a, b, und, pa, ch);
    true
}

/// True if a directed path `src -> ... -> tgt` exists using only `ch`, or
/// `src == tgt`.
pub(crate) fn has_dir_path(ch: &[HashSet<u32>], src: u32, tgt: u32) -> bool {
    if src == tgt {
        return true;
    }
    let n = ch.len();
    let mut seen = vec![false; n];
    let mut q = VecDeque::new();
    q.push_back(src);
    while let Some(u) = q.pop_front() {
        if u == tgt {
            return true;
        }
        if std::mem::replace(&mut seen[u as usize], true) {
            continue;
        }
        for &v in &ch[u as usize] {
            if !seen[v as usize] {
                q.push_back(v);
            }
        }
    }
    false
}

/// True if orienting `u -> v` would create a new unshielded collider at `v`:
/// some other parent of `v` is not adjacent to `u`.
#[inline]
pub(crate) fn creates_new_unshielded_collider(
    u: usize,
    v: u32,
    und: &[HashSet<u32>],
    pa: &[HashSet<u32>],
    ch: &[HashSet<u32>],
) -> bool {
    for &p in &pa[v as usize] {
        if p as usize != u && !adjacent(u, p as usize, und, pa, ch) {
            return true;
        }
    }
    false
}

/// Apply iterative Meek closure (R1-R4) to a partially directed graph state.
///
/// `guard_new_colliders` enables an R1 safeguard that skips orientations
/// creating new unshielded colliders (pgmpy-aligned behavior).
pub(crate) fn apply_meek_closure(
    pa: &mut [HashSet<u32>],
    ch: &mut [HashSet<u32>],
    und: &mut [HashSet<u32>],
    guard_new_colliders: bool,
) {
    let n = pa.len();

    loop {
        let mut changed = false;

        // R1: a->b, b--c, a !~ c  =>  b->c
        for b in 0..n {
            if pa[b].is_empty() || und[b].is_empty() {
                continue;
            }
            let pb: Vec<u32> = pa[b].iter().copied().collect();
            let ubs: Vec<u32> = und[b].clone().into_iter().collect();
            'c_loop: for c in ubs {
                let ci = c as usize;
                for &a in &pb {
                    if !adjacent(a as usize, ci, und, pa, ch)
                        && (!guard_new_colliders
                            || !creates_new_unshielded_collider(b, c, und, pa, ch))
                    {
                        if try_orient(b as u32, c, und, pa, ch) {
                            changed = true;
                            continue 'c_loop;
                        }
                    }
                }
            }
        }

        // R2: a--b and ∃ w: a->w, w->b  =>  a->b
        for a in 0..n {
            let uab: Vec<u32> = und[a].clone().into_iter().collect();
            for b_u in uab {
                let b = b_u as usize;
                if ch[a].iter().any(|w| pa[b].contains(w)) {
                    if try_orient(a as u32, b_u, und, pa, ch) {
                        changed = true;
                        continue;
                    }
                }
                if ch[b].iter().any(|w| pa[a].contains(w)) {
                    if try_orient(b_u, a as u32, und, pa, ch) {
                        changed = true;
                    }
                }
            }
        }

        // R3: a--b and ∃ c,d: c->b, d->b, c !~ d, a--c, a--d  =>  a->b
        for a in 0..n {
            let uab: Vec<u32> = und[a].clone().into_iter().collect();
            for b_u in uab {
                let b = b_u as usize;
                let pb: Vec<u32> = pa[b].iter().copied().collect();
                'pairs: for i in 0..pb.len() {
                    for j in (i + 1)..pb.len() {
                        let c = pb[i] as usize;
                        let d = pb[j] as usize;
                        if !adjacent(c, d, und, pa, ch)
                            && und[a].contains(&pb[i])
                            && und[a].contains(&pb[j])
                        {
                            if try_orient(a as u32, b_u, und, pa, ch) {
                                changed = true;
                                break 'pairs;
                            }
                        }
                    }
                }
            }
        }

        // R4 (Meek 1995): a--b and ∃ c,d: a--c, c->d, d->b, c !~ b  =>  a->b
        for a in 0..n {
            let uab: Vec<u32> = und[a].clone().into_iter().collect();
            for b_u in uab {
                let b = b_u as usize;
                let fires = und[a].iter().any(|&c| {
                    let ci = c as usize;
                    c != b_u
                        && !adjacent(ci, b, und, pa, ch)
                        && ch[ci].iter().any(|d| pa[b].contains(d))
                });
                if fires && try_orient(a as u32, b_u, und, pa, ch) {
                    changed = true;
                }
            }
        }

        // Cycle avoidance: a--b and (a ⇒ b or b ⇒ a)  =>  orient along reachability
        for a in 0..n {
            let uab: Vec<u32> = und[a].clone().into_iter().collect();
            for b_u in uab {
                if has_dir_path(ch, a as u32, b_u) {
                    if try_orient(a as u32, b_u, und, pa, ch) {
                        changed = true;
                    }
                } else if has_dir_path(ch, b_u, a as u32) {
                    if try_orient(b_u, a as u32, und, pa, ch) {
                        changed = true;
                    }
                }
            }
        }

        if !changed {
            break;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    type Edges<'a> = &'a [(u32, u32)];
    type Pairs = Vec<(u32, u32)>;

    /// Close the state with `directed` and `undirected` edges on `n` nodes,
    /// returning its directed and undirected edges, each sorted.
    fn close(
        n: usize,
        directed: Edges,
        undirected: Edges,
        guard_new_colliders: bool,
    ) -> (Pairs, Pairs) {
        let mut pa = vec![HashSet::new(); n];
        let mut ch = vec![HashSet::new(); n];
        let mut und = vec![HashSet::new(); n];
        for &(a, b) in directed {
            orient(a, b, &mut und, &mut pa, &mut ch);
        }
        for &(a, b) in undirected {
            und[a as usize].insert(b);
            und[b as usize].insert(a);
        }
        apply_meek_closure(&mut pa, &mut ch, &mut und, guard_new_colliders);
        let edges = |sets: &[HashSet<u32>], keep: fn(u32, u32) -> bool| {
            let mut out: Pairs = (0..n as u32)
                .flat_map(|a| sets[a as usize].iter().map(move |&b| (a, b)))
                .filter(|&(a, b)| keep(a, b))
                .collect();
            out.sort_unstable();
            out
        };
        (edges(&ch, |_, _| true), edges(&und, |a, b| a < b))
    }

    #[test]
    fn closure_cases() {
        // (what, n, directed, undirected, guard, directed after, undirected after)
        let cases: [(&str, usize, Edges, Edges, bool, Edges, Edges); 3] = [
            (
                // `0 -> 1 -- 2 <- 3`: either orientation of `1 -- 2` adds a
                // collider, so the guard keeps R1 from orienting it.
                "R1 guarded against a new collider",
                4,
                &[(0, 1), (3, 2)],
                &[(1, 2)],
                true,
                &[(0, 1), (3, 2)],
                &[(1, 2)],
            ),
            (
                "R1 unguarded",
                4,
                &[(0, 1), (3, 2)],
                &[(1, 2)],
                false,
                &[(0, 1), (1, 2), (3, 2)],
                &[],
            ),
            (
                // R1 would orient `3 -> 0` against `0 -> 1 -> 2 -> 3`, so
                // cycle avoidance orients the edge along the path instead.
                "R1 blocked by a directed path",
                4,
                &[(0, 1), (1, 2), (2, 3)],
                &[(0, 3)],
                true,
                &[(0, 1), (0, 3), (1, 2), (2, 3)],
                &[],
            ),
        ];
        for (what, n, directed, undirected, guard, want_dir, want_und) in cases {
            let (got_dir, got_und) = close(n, directed, undirected, guard);
            assert_eq!(got_dir, want_dir, "{what}: directed edges");
            assert_eq!(got_und, want_und, "{what}: undirected edges");
        }
    }

    #[test]
    fn has_dir_path_follows_children_only() {
        let ch: Vec<HashSet<u32>> = vec![[1].into(), [2].into(), HashSet::new()];
        assert!(has_dir_path(&ch, 0, 2));
        assert!(has_dir_path(&ch, 1, 1));
        assert!(!has_dir_path(&ch, 2, 0));
    }
}
