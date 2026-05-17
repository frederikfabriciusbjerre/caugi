//! Variable allocation for the constraint solver — class-aware.
//!
//! Layout per [`GraphClass`]:
//!   * For each allowed edge type:
//!       - asymmetric (`-->`): one boolean per ordered pair `(u, v)`,
//!         `u ≠ v`. `n·(n-1)` vars.
//!       - symmetric (`---`, `<->`): one boolean per unordered pair
//!         `{u, v}`, `u ≠ v`. `n·(n-1)/2` vars.
//!     Edge types are laid out in the order returned by
//!     [`GraphClass::edge_types`].
//!   * Reach variables (always allocated, even for `UG` to keep code
//!     paths uniform — they're unconstrained when no acyclicity is
//!     enforced): one per ordered pair `(u, v)` including diagonal.
//!     `n²` vars.
//!   * Auxiliary variables (Tseitin / cardinality / reach upper bound)
//!     are minted on demand via `fresh_aux`.
//!
//! Variable ids are 1-based (splr convention).

use rustc_hash::FxHashMap;

use super::class::GraphClass;

/// Per-edge-type layout metadata.
#[derive(Debug, Clone, Copy)]
struct EdgeTypeBlock {
    glyph: &'static str,
    base: i32,
    symmetric: bool,
}

#[derive(Debug, Clone)]
pub struct VarMap {
    nodes: Vec<String>,
    name_to_idx: FxHashMap<String, usize>,
    n: usize,
    class: GraphClass,
    next_var: i32,
    edge_blocks: Vec<EdgeTypeBlock>,
    reach_base: i32,
}

impl VarMap {
    pub fn new(nodes: Vec<String>, class: GraphClass) -> Self {
        let n = nodes.len();
        let name_to_idx: FxHashMap<String, usize> = nodes
            .iter()
            .enumerate()
            .map(|(i, s)| (s.clone(), i))
            .collect();

        let mut next: i32 = 1;
        let mut blocks = Vec::new();
        for (glyph, symmetric) in class.edge_types().iter().copied() {
            let count = if symmetric {
                n * n.saturating_sub(1) / 2
            } else {
                n * n.saturating_sub(1)
            };
            blocks.push(EdgeTypeBlock {
                glyph,
                base: next,
                symmetric,
            });
            next += count as i32;
        }

        let reach_base = next;
        next += (n * n) as i32;

        Self {
            nodes,
            name_to_idx,
            n,
            class,
            next_var: next,
            edge_blocks: blocks,
            reach_base,
        }
    }

    pub fn n(&self) -> usize {
        self.n
    }

    pub fn class(&self) -> GraphClass {
        self.class
    }

    pub fn idx_of(&self, name: &str) -> Option<usize> {
        self.name_to_idx.get(name).copied()
    }

    pub fn name_at(&self, idx: usize) -> &str {
        &self.nodes[idx]
    }

    pub fn nodes(&self) -> &[String] {
        &self.nodes
    }

    pub fn fresh_aux(&mut self) -> i32 {
        let v = self.next_var;
        self.next_var += 1;
        v
    }

    pub fn n_vars(&self) -> i32 {
        self.next_var - 1
    }

    /// Returns `true` if `etype` is one of the edge types this class
    /// admits.
    pub fn has_edge_type(&self, etype: &str) -> bool {
        self.edge_blocks.iter().any(|b| b.glyph == etype)
    }

    /// Edge-variable id for `(from, to, etype)`. For symmetric edge
    /// types the result is invariant under `(from, to)` swap.
    pub fn edge_var(&self, from: usize, to: usize, etype: &str) -> i32 {
        debug_assert!(from != to, "no self-loop variables in simple graphs");
        debug_assert!(from < self.n && to < self.n);
        let block = self
            .edge_blocks
            .iter()
            .find(|b| b.glyph == etype)
            .unwrap_or_else(|| panic!("class {:?} has no edge type `{}`", self.class, etype));
        let idx = if block.symmetric {
            unordered_pair_index(from, to, self.n)
        } else {
            ordered_pair_index(from, to, self.n)
        };
        block.base + idx as i32
    }

    /// Reach-variable id for "there is a directed path from `from` to
    /// `to`" (length ≥ 1). For `UG` reach vars exist but the
    /// invariants don't force them either way.
    pub fn reach_var(&self, from: usize, to: usize) -> i32 {
        debug_assert!(from < self.n && to < self.n);
        self.reach_base + (from * self.n + to) as i32
    }

    /// Iterate over every directed-edge variable (if any), yielding
    /// `(from, to, var)` triples.
    pub fn iter_directed_edges(&self) -> Box<dyn Iterator<Item = (usize, usize, i32)> + '_> {
        if !self.has_edge_type("-->") {
            return Box::new(std::iter::empty());
        }
        let n = self.n;
        Box::new((0..n).flat_map(move |from| {
            (0..n)
                .filter(move |to| *to != from)
                .map(move |to| (from, to, self.edge_var(from, to, "-->")))
        }))
    }

    /// Iterate over every edge variable of every allowed type. For
    /// symmetric types each variable is yielded once per unordered
    /// pair (with `from < to`). The triple is
    /// `(from, to, etype, var)`.
    pub fn iter_all_edges(&self) -> impl Iterator<Item = (usize, usize, &'static str, i32)> + '_ {
        let n = self.n;
        self.edge_blocks.iter().flat_map(move |block| {
            let glyph = block.glyph;
            let symmetric = block.symmetric;
            (0..n).flat_map(move |from| {
                (0..n).filter_map(move |to| {
                    if from == to {
                        return None;
                    }
                    if symmetric && to < from {
                        return None;
                    }
                    Some((from, to, glyph, self.edge_var(from, to, glyph)))
                })
            })
        })
    }
}

fn ordered_pair_index(from: usize, to: usize, n: usize) -> usize {
    from * (n - 1) + if to > from { to - 1 } else { to }
}

fn unordered_pair_index(from: usize, to: usize, n: usize) -> usize {
    let (lo, hi) = if from < to { (from, to) } else { (to, from) };
    // Linear index into upper triangle (lo, hi), lo < hi.
    //   For each row r < lo, the row contributes (n - r - 1) entries.
    //   Then within row lo, offset is (hi - lo - 1).
    let prefix: usize = (0..lo).map(|r| n - r - 1).sum();
    prefix + (hi - lo - 1)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dag_layout_is_dense_and_unique() {
        let vm = VarMap::new(vec!["A".into(), "B".into(), "C".into()], GraphClass::Dag);
        let mut seen = std::collections::HashSet::new();
        for u in 0..3 {
            for v in 0..3 {
                if u == v {
                    continue;
                }
                let var = vm.edge_var(u, v, "-->");
                assert!(seen.insert(var), "duplicate var for ({}, {})", u, v);
            }
        }
        assert_eq!(seen.len(), 6);
    }

    #[test]
    fn ug_var_symmetric() {
        let vm = VarMap::new(vec!["A".into(), "B".into(), "C".into()], GraphClass::Ug);
        assert_eq!(vm.edge_var(0, 1, "---"), vm.edge_var(1, 0, "---"));
        assert_eq!(vm.edge_var(0, 2, "---"), vm.edge_var(2, 0, "---"));
        // Distinct unordered pairs get distinct vars.
        assert_ne!(vm.edge_var(0, 1, "---"), vm.edge_var(0, 2, "---"));
    }

    #[test]
    fn pdag_has_both_blocks() {
        let vm = VarMap::new(vec!["A".into(), "B".into(), "C".into()], GraphClass::Pdag);
        // Directed: ordered pair, asymmetric.
        assert_ne!(vm.edge_var(0, 1, "-->"), vm.edge_var(1, 0, "-->"));
        // Undirected: symmetric.
        assert_eq!(vm.edge_var(0, 1, "---"), vm.edge_var(1, 0, "---"));
        // Directed and undirected blocks don't collide.
        assert_ne!(vm.edge_var(0, 1, "-->"), vm.edge_var(0, 1, "---"));
    }
}
