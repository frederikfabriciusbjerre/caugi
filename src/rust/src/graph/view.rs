use super::admg::Admg;
use super::ag::Ag;
use super::cpdag::Cpdag;
use super::dag::Dag;
use super::mpdag::Mpdag;
use super::pag::Pag;
use super::pdag::Pdag;
use super::ug::Ug;
use super::CaugiGraph;
use rustc_hash::FxHashSet;
use std::sync::Arc;

/// Mode for neighbor queries, specifying which edge types to include.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NeighborMode {
    /// All neighbors (union of all edge types)
    All,
    /// Ingoing directed edges (parents: edges pointing INTO the node)
    In,
    /// Outgoing directed edges (children: edges pointing OUT from the node)
    Out,
    /// Undirected edges only (`---`)
    Undirected,
    /// Bidirected edges only (`<->`, spouses in ADMG)
    Bidirected,
    /// Partial edges (circle endpoints: o-o, o->, --o)
    Partial,
}

impl NeighborMode {
    /// Parse mode from string, with alias support.
    pub fn from_str(s: &str) -> Result<Self, String> {
        match s.to_lowercase().as_str() {
            "all" => Ok(NeighborMode::All),
            "in" => Ok(NeighborMode::In),
            "out" => Ok(NeighborMode::Out),
            "undirected" => Ok(NeighborMode::Undirected),
            "bidirected" => Ok(NeighborMode::Bidirected),
            "partial" => Ok(NeighborMode::Partial),
            _ => Err(format!("Unknown neighbor mode: '{}'", s)),
        }
    }
}

#[derive(Debug, Clone)]
pub enum GraphView {
    Dag(Arc<Dag>),
    Pdag(Arc<Pdag>),
    Mpdag(Arc<Mpdag>),
    Cpdag(Arc<Cpdag>),
    Ug(Arc<Ug>),
    Admg(Arc<Admg>),
    Ag(Arc<Ag>),
    Pag(Arc<Pag>),
    Raw(Arc<CaugiGraph>),
}

impl GraphView {
    #[inline]
    pub fn core(&self) -> &CaugiGraph {
        match self {
            GraphView::Dag(d) => d.core_ref(),
            GraphView::Pdag(p) => p.core_ref(),
            GraphView::Mpdag(m) => m.as_pdag().core_ref(),
            GraphView::Cpdag(c) => c.as_pdag().core_ref(),
            GraphView::Ug(u) => u.core_ref(),
            GraphView::Admg(a) => a.core_ref(),
            GraphView::Ag(g) => g.core_ref(),
            GraphView::Pag(g) => g.core_ref(),
            GraphView::Raw(c) => c,
        }
    }

    #[inline]
    pub fn n(&self) -> u32 {
        match self {
            GraphView::Dag(g) => g.n(),
            GraphView::Pdag(g) => g.n(),
            GraphView::Mpdag(g) => g.n(),
            GraphView::Cpdag(g) => g.n(),
            GraphView::Ug(g) => g.n(),
            GraphView::Admg(g) => g.n(),
            GraphView::Ag(g) => g.n(),
            GraphView::Pag(g) => g.n(),
            GraphView::Raw(core) => core.n(),
        }
    }

    // ---- queries ----

    /// Get parents of node `i` (nodes with directed edges pointing INTO `i`),
    /// as `NeighborMode::In`.
    pub fn parents_of(&self, i: u32) -> Result<Vec<u32>, String> {
        self.neighbors_of(i, NeighborMode::In)
    }

    /// Get children of node `i` (nodes with directed edges pointing OUT from
    /// `i`), as `NeighborMode::Out`.
    pub fn children_of(&self, i: u32) -> Result<Vec<u32>, String> {
        self.neighbors_of(i, NeighborMode::Out)
    }

    /// Get undirected neighbors of node `i` (nodes connected via `---` edges).
    /// Note: For ADMG, use `bidirected_of` or `spouses_of` instead.
    pub fn undirected_of(&self, i: u32) -> Result<Vec<u32>, String> {
        if matches!(self, GraphView::Raw(_)) {
            return Err("undirected_of is not defined for UNKNOWN graphs; use neighbors(..., mode = 'undirected') instead".into());
        }
        self.neighbors_of(i, NeighborMode::Undirected)
    }

    /// Get bidirected neighbors of node `i` (nodes connected via `<->` edges, i.e., spouses).
    pub fn bidirected_of(&self, i: u32) -> Result<Vec<u32>, String> {
        if matches!(self, GraphView::Raw(_)) {
            return Err("bidirected_of is not defined for UNKNOWN graphs; use neighbors(..., mode = 'bidirected') instead".into());
        }
        self.neighbors_of(i, NeighborMode::Bidirected)
    }

    /// Get neighbors of node `i` filtered by mode.
    ///
    /// This method works for all graph types including Raw (UNKNOWN class).
    /// For typed graphs (DAG, PDAG, etc.), it delegates to optimized methods when possible.
    /// For Raw graphs, it iterates over CSR entries and filters by edge class.
    ///
    /// Use `NeighborMode::All` to get all neighbors regardless of edge type.
    ///
    /// A mode the class has no edges for, such as `Undirected` in a DAG, gives
    /// an empty result.
    pub fn neighbors_of(&self, i: u32, mode: NeighborMode) -> Result<Vec<u32>, String> {
        // Validate mode for graph type and dispatch to optimized methods
        match (self, mode) {
            // DAG: only in, out, all (no undirected, bidirected, or partial)
            (GraphView::Dag(g), NeighborMode::All) => Ok(g.neighbors_of(i).to_vec()),
            (GraphView::Dag(g), NeighborMode::In) => Ok(g.parents_of(i).to_vec()),
            (GraphView::Dag(g), NeighborMode::Out) => Ok(g.children_of(i).to_vec()),

            // PDAG: in, out, undirected, all (no bidirected or partial)
            (GraphView::Pdag(g), NeighborMode::All) => Ok(g.neighbors_of(i).to_vec()),
            (GraphView::Pdag(g), NeighborMode::In) => Ok(g.parents_of(i).to_vec()),
            (GraphView::Pdag(g), NeighborMode::Out) => Ok(g.children_of(i).to_vec()),
            (GraphView::Pdag(g), NeighborMode::Undirected) => Ok(g.undirected_of(i).to_vec()),
            (GraphView::Mpdag(m), NeighborMode::All) => Ok(m.as_pdag().neighbors_of(i).to_vec()),
            (GraphView::Mpdag(m), NeighborMode::In) => Ok(m.as_pdag().parents_of(i).to_vec()),
            (GraphView::Mpdag(m), NeighborMode::Out) => Ok(m.as_pdag().children_of(i).to_vec()),
            (GraphView::Mpdag(m), NeighborMode::Undirected) => {
                Ok(m.as_pdag().undirected_of(i).to_vec())
            }
            (GraphView::Cpdag(c), NeighborMode::All) => Ok(c.as_pdag().neighbors_of(i).to_vec()),
            (GraphView::Cpdag(c), NeighborMode::In) => Ok(c.as_pdag().parents_of(i).to_vec()),
            (GraphView::Cpdag(c), NeighborMode::Out) => Ok(c.as_pdag().children_of(i).to_vec()),
            (GraphView::Cpdag(c), NeighborMode::Undirected) => {
                Ok(c.as_pdag().undirected_of(i).to_vec())
            }

            // UG: only undirected, all (no in, out, bidirected, or partial)
            (GraphView::Ug(g), NeighborMode::All) => Ok(g.neighbors_of(i).to_vec()),
            (GraphView::Ug(g), NeighborMode::Undirected) => Ok(g.neighbors_of(i).to_vec()),

            // ADMG: in, out, bidirected (spouses), all (no undirected or partial)
            // A bow lists its other end among the parents or children and
            // among the spouses, so keep only the first.
            (GraphView::Admg(g), NeighborMode::All) => {
                let all = g.neighbors_of(i);
                let mut seen = FxHashSet::with_capacity_and_hasher(all.len(), Default::default());
                Ok(all.iter().copied().filter(|&v| seen.insert(v)).collect())
            }
            (GraphView::Admg(g), NeighborMode::In) => Ok(g.parents_of(i).to_vec()),
            (GraphView::Admg(g), NeighborMode::Out) => Ok(g.children_of(i).to_vec()),
            (GraphView::Admg(g), NeighborMode::Bidirected) => Ok(g.spouses_of(i).to_vec()),

            // AG: in, out, undirected, bidirected, all (no partial edges)
            (GraphView::Ag(g), NeighborMode::All) => Ok(g.neighbors_of(i).to_vec()),
            (GraphView::Ag(g), NeighborMode::In) => Ok(g.parents_of(i).to_vec()),
            (GraphView::Ag(g), NeighborMode::Out) => Ok(g.children_of(i).to_vec()),
            (GraphView::Ag(g), NeighborMode::Undirected) => Ok(g.undirected_of(i).to_vec()),
            (GraphView::Ag(g), NeighborMode::Bidirected) => Ok(g.spouses_of(i).to_vec()),

            // PAG: in, out, undirected, bidirected, partial, all
            (GraphView::Pag(g), NeighborMode::All) => Ok(g.neighbors_of(i).to_vec()),
            (GraphView::Pag(g), NeighborMode::In) => Ok(g.parents_of(i).to_vec()),
            (GraphView::Pag(g), NeighborMode::Out) => Ok(g.children_of(i).to_vec()),
            (GraphView::Pag(g), NeighborMode::Undirected) => Ok(g.undirected_of(i).to_vec()),
            (GraphView::Pag(g), NeighborMode::Bidirected) => Ok(g.spouses_of(i).to_vec()),
            (GraphView::Pag(g), NeighborMode::Partial) => Ok(g.partial_of(i)),

            // Raw (UNKNOWN): all modes allowed, iterate CSR
            (GraphView::Raw(_), _) => self.neighbors_mode_of_raw(i, mode),

            // A mode the class has no edges for matches nothing.
            _ => Ok(Vec::new()),
        }
    }

    /// Nodes reachable from `i` in an UNKNOWN graph by following directed
    /// edges backwards (`back`) or forwards, plus undirected edges either way
    /// when `undirected`; bidirected edges are never followed. Reads each
    /// edge's class, as the typed classes do, so custom registry edges behave
    /// like their built-in counterparts. Excludes `i` itself.
    fn reach_raw(&self, i: u32, back: bool, undirected: bool) -> Result<Vec<u32>, String> {
        use crate::edges::EdgeClass;

        let core = self.core();
        let mut seen = vec![false; core.n() as usize];
        seen[i as usize] = true;
        let mut stack = vec![i];
        while let Some(u) = stack.pop() {
            for k in core.row_range(u) {
                let step = match core.spec(k).class {
                    // An incoming arrow means the neighbour is a parent.
                    EdgeClass::Directed => core.is_incoming_arrow(k) == back,
                    EdgeClass::Undirected => undirected,
                    EdgeClass::Bidirected => false,
                    _ => {
                        return Err("ancestral relations are not defined for partially \
                                    directed edges (o-o, o->, --o)"
                            .into())
                    }
                };
                let v = core.col_index[k];
                if step && !std::mem::replace(&mut seen[v as usize], true) {
                    stack.push(v);
                }
            }
        }
        seen[i as usize] = false;
        Ok((0..core.n()).filter(|&v| seen[v as usize]).collect())
    }

    /// Generic implementation for Raw graphs - iterates CSR and filters by edge class.
    fn neighbors_mode_of_raw(&self, i: u32, mode: NeighborMode) -> Result<Vec<u32>, String> {
        use crate::edges::{EdgeClass, Mark};

        let core = self.core();
        let mut result = Vec::new();

        for k in core.row_range(i) {
            let neighbor = core.col_index[k];
            let etype = core.etype[k];
            let my_position = core.side[k]; // 0 = tail position, 1 = head position

            let spec = &core.registry.specs[etype as usize];

            // Determine my mark and neighbor's mark based on position.
            // my_position == 0 means I'm at tail position (my mark = spec.tail, neighbor = spec.head)
            // my_position == 1 means I'm at head position (my mark = spec.head, neighbor = spec.tail)
            let (my_mark, neighbor_mark) = if my_position == 0 {
                (spec.tail, spec.head)
            } else {
                (spec.head, spec.tail)
            };

            // Determine whether to include this neighbor based on the mode.
            let include = match mode {
                NeighborMode::All => true,

                // A parent: an arrowhead here and a tail there.
                NeighborMode::In => my_mark == Mark::Arrow && neighbor_mark == Mark::Tail,

                // A child: a tail here and an arrowhead there.
                NeighborMode::Out => my_mark == Mark::Tail && neighbor_mark == Mark::Arrow,

                NeighborMode::Undirected => {
                    // Undirected: both ends have Tail marks
                    spec.class == EdgeClass::Undirected
                }

                NeighborMode::Bidirected => {
                    // Bidirected: both ends have Arrow marks
                    spec.class == EdgeClass::Bidirected
                }

                // A circle at either end.
                NeighborMode::Partial => my_mark == Mark::Circle || neighbor_mark == Mark::Circle,
            };

            if include {
                result.push(neighbor);
            }
        }

        // Parallel edges list a neighbour once per edge.
        result.sort_unstable();
        result.dedup();
        Ok(result)
    }

    pub fn ancestors_of(&self, i: u32) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(g) => Ok(g.ancestors_of(i)),
            GraphView::Pdag(g) => Ok(g.ancestors_of(i)),
            GraphView::Mpdag(m) => Ok(m.as_pdag().ancestors_of(i)),
            GraphView::Cpdag(c) => Ok(c.as_pdag().ancestors_of(i)),
            GraphView::Admg(g) => Ok(g.ancestors_of(i)),
            GraphView::Ag(g) => Ok(g.ancestors_of(i)),
            GraphView::Ug(_) => Ok(Vec::new()),
            GraphView::Pag(g) => Ok(g.ancestors_of(i)),
            GraphView::Raw(_) => self.reach_raw(i, true, false),
        }
    }
    pub fn descendants_of(&self, i: u32) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(g) => Ok(g.descendants_of(i)),
            GraphView::Pdag(g) => Ok(g.descendants_of(i)),
            GraphView::Mpdag(m) => Ok(m.as_pdag().descendants_of(i)),
            GraphView::Cpdag(c) => Ok(c.as_pdag().descendants_of(i)),
            GraphView::Admg(g) => Ok(g.descendants_of(i)),
            GraphView::Ag(g) => Ok(g.descendants_of(i)),
            GraphView::Ug(_) => Ok(Vec::new()),
            GraphView::Pag(g) => Ok(g.descendants_of(i)),
            GraphView::Raw(_) => self.reach_raw(i, false, false),
        }
    }
    pub fn anteriors_of(&self, i: u32) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(g) => Ok(g.anteriors_of(i)),
            GraphView::Pdag(g) => Ok(g.anteriors_of(i)),
            GraphView::Mpdag(m) => Ok(m.as_pdag().anteriors_of(i)),
            GraphView::Cpdag(c) => Ok(c.as_pdag().anteriors_of(i)),
            GraphView::Admg(g) => Ok(g.ancestors_of(i)),
            GraphView::Ag(g) => Ok(g.anteriors_of(i)),
            GraphView::Ug(g) => Ok(g.component_of(i)),
            GraphView::Pag(g) => Ok(g.anteriors_of(i)),
            GraphView::Raw(_) => self.reach_raw(i, true, true),
        }
    }
    pub fn posteriors_of(&self, i: u32) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(g) => Ok(g.posteriors_of(i)),
            GraphView::Pdag(g) => Ok(g.posteriors_of(i)),
            GraphView::Mpdag(m) => Ok(m.as_pdag().posteriors_of(i)),
            GraphView::Cpdag(c) => Ok(c.as_pdag().posteriors_of(i)),
            GraphView::Admg(g) => Ok(g.descendants_of(i)),
            GraphView::Ag(g) => Ok(g.posteriors_of(i)),
            GraphView::Ug(g) => Ok(g.component_of(i)),
            GraphView::Pag(g) => Ok(g.posteriors_of(i)),
            GraphView::Raw(_) => self.reach_raw(i, false, true),
        }
    }
    /// Is the directed edge `a --> b` visible (Zhang 2008, Def. 8)? The same
    /// criterion on a PAG gives definite visibility.
    pub fn is_visible_edge(&self, a: u32, b: u32) -> Result<bool, String> {
        match self {
            GraphView::Ag(_) | GraphView::Pag(_) => {
                Ok(super::pag::MarkedGraph::from_core(self.core())?.visible_edge(a, b))
            }
            _ => Err("is_visible_edge is only defined for MAGs and PAGs".into()),
        }
    }

    pub fn markov_blanket_of(&self, i: u32) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(g) => Ok(g.markov_blanket_of(i)),
            GraphView::Pdag(g) => Ok(g.markov_blanket_of(i)),
            GraphView::Mpdag(m) => Ok(m.as_pdag().markov_blanket_of(i)),
            GraphView::Cpdag(c) => Ok(c.as_pdag().markov_blanket_of(i)),
            GraphView::Ug(g) => Ok(g.markov_blanket_of(i)),
            GraphView::Admg(g) => Ok(g.markov_blanket_of(i)),
            GraphView::Ag(g) => Ok(g.markov_blanket_of(i)),
            GraphView::Pag(_) => Err("markov_blanket_of is not yet implemented for PAG".into()),
            GraphView::Raw(_) => Err("markov_blanket_of not implemented for UNKNOWN class".into()),
        }
    }
    pub fn exogenous_nodes(&self, undirected_as_parents: bool) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(g) => Ok(g.exogenous_nodes()),
            GraphView::Pdag(g) => Ok(g.exogenous_nodes(undirected_as_parents)),
            GraphView::Mpdag(m) => Ok(m.as_pdag().exogenous_nodes(undirected_as_parents)),
            GraphView::Cpdag(c) => Ok(c.as_pdag().exogenous_nodes(undirected_as_parents)),
            GraphView::Ug(g) => Ok(g.exogenous_nodes(undirected_as_parents)),
            GraphView::Admg(g) => Ok(g.exogenous_nodes()),
            GraphView::Ag(g) => {
                if undirected_as_parents {
                    Ok((0..g.n())
                        .filter(|&i| g.parents_of(i).is_empty() && g.undirected_of(i).is_empty())
                        .collect())
                } else {
                    Ok(g.exogenous_nodes())
                }
            }
            GraphView::Pag(g) => Ok((0..g.n())
                .filter(|&i| {
                    g.parents_of(i).is_empty()
                        && !(undirected_as_parents && !g.undirected_of(i).is_empty())
                })
                .collect()),
            GraphView::Raw(_) => Err("exogenous_nodes not implemented for UNKNOWN class".into()),
        }
    }

    /// Returns a topological ordering of the nodes.
    ///
    /// Only defined for DAGs. Returns all nodes in an order such that
    /// for every directed edge u -> v, u appears before v.
    pub fn topological_sort(&self) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(g) => Ok(g.topological_sort()),
            GraphView::Admg(_) => Err("topological_sort is only defined for DAGs".into()),
            GraphView::Pdag(_) => Err("topological_sort is only defined for DAGs".into()),
            GraphView::Mpdag(_) => Err("topological_sort is only defined for DAGs".into()),
            GraphView::Cpdag(_) => Err("topological_sort is only defined for DAGs".into()),
            GraphView::Ug(_) => Err("topological_sort is only defined for DAGs".into()),
            GraphView::Ag(_) => Err("topological_sort is only defined for DAGs".into()),
            GraphView::Pag(_) => Err("topological_sort is only defined for DAGs".into()),
            GraphView::Raw(_) => Err("topological_sort is only defined for DAGs".into()),
        }
    }

    // ---- ADMG-specific methods ----
    /// Get spouses of node `i` (nodes connected via bidirected edges).
    /// Only defined for ADMGs. For UNKNOWN graphs, use neighbors(..., mode = "bidirected").
    pub fn spouses_of(&self, i: u32) -> Result<Vec<u32>, String> {
        if matches!(self, GraphView::Raw(_)) {
            return Err("spouses_of is not defined for UNKNOWN graphs; use neighbors(..., mode = 'bidirected') instead".into());
        }
        self.neighbors_of(i, NeighborMode::Bidirected)
    }

    pub fn districts(&self) -> Result<Vec<Vec<u32>>, String> {
        match self {
            GraphView::Admg(g) => Ok(g.districts()),
            GraphView::Ag(g) => Ok(g.districts()),
            _ => Err("districts is only defined for ADMGs and AGs".into()),
        }
    }

    pub fn district_of(&self, i: u32) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Admg(g) => Ok(g.district_of(i)),
            GraphView::Ag(g) => Ok(g.district_of(i)),
            _ => Err("district_of is only defined for ADMGs and AGs".into()),
        }
    }

    pub fn m_separated(&self, xs: &[u32], ys: &[u32], z: &[u32]) -> Result<bool, String> {
        match self {
            GraphView::Admg(g) => Ok(g.m_separated(xs, ys, z)),
            GraphView::Dag(d) => Ok(d.d_separated(xs, ys, z)), // d-sep is m-sep for DAGs
            GraphView::Ag(g) => Ok(g.m_separated(xs, ys, z)),
            GraphView::Ug(g) => Ok(g.separated(xs, ys, z)),
            // Exact: every member MAG encodes the same m-separations.
            GraphView::Pag(g) => Ok(g.to_mag()?.m_separated(xs, ys, z)),
            _ => Err("m_separated is only defined for ADMGs, AGs, PAGs, DAGs, and UGs".into()),
        }
    }

    // ---- DAG-only methods ----
    pub fn d_separated(&self, xs: &[u32], ys: &[u32], z: &[u32]) -> Result<bool, String> {
        match self {
            GraphView::Dag(d) => Ok(d.d_separated(xs, ys, z)),
            _ => Err("d_separated is only defined for DAGs".into()),
        }
    }

    pub fn minimal_separator(
        &self,
        xs: &[u32],
        ys: &[u32],
        include: &[u32],
        restrict: &[u32],
    ) -> Result<Option<Vec<u32>>, String> {
        match self {
            GraphView::Dag(d) => d.minimal_d_separator(xs, ys, include, restrict),
            GraphView::Admg(a) => a.minimal_m_separator(xs, ys, include, restrict),
            GraphView::Ag(g) => g.minimal_m_separator(xs, ys, include, restrict),
            GraphView::Pag(g) => g.to_mag()?.minimal_m_separator(xs, ys, include, restrict),
            _ => Err("minimal_separator is only defined for DAGs, ADMGs, AGs, and PAGs".into()),
        }
    }

    pub fn adjustment_set_parents(&self, xs: &[u32], ys: &[u32]) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(d) => d.adjustment_set_parents(xs, ys),
            _ => Err("adjustment_set_parents is only defined for DAGs".into()),
        }
    }
    pub fn adjustment_set_backdoor(&self, xs: &[u32], ys: &[u32]) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(d) => d.adjustment_set_backdoor(xs, ys),
            _ => Err("adjustment_set_backdoor is only defined for DAGs".into()),
        }
    }
    pub fn adjustment_set_optimal(&self, xs: &[u32], ys: &[u32]) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(d) => d.adjustment_set_optimal(xs, ys),
            _ => Err("adjustment_set_optimal is only defined for DAGs".into()),
        }
    }
    pub fn is_valid_backdoor_set(&self, xs: &[u32], ys: &[u32], z: &[u32]) -> Result<bool, String> {
        match self {
            GraphView::Dag(d) => Ok(d.is_valid_backdoor_set(xs, ys, z)),
            _ => Err("is_valid_backdoor_set is only defined for DAGs".into()),
        }
    }
    pub fn all_backdoor_sets(
        &self,
        xs: &[u32],
        ys: &[u32],
        minimal: bool,
        max_size: u32,
    ) -> Result<Vec<Vec<u32>>, String> {
        match self {
            GraphView::Dag(d) => Ok(d.all_backdoor_sets(xs, ys, minimal, max_size)),
            _ => Err("all_backdoor_sets is only defined for DAGs".into()),
        }
    }

    // ---- ADMG adjustment methods ----
    pub fn is_valid_adjustment_set_admg(
        &self,
        xs: &[u32],
        ys: &[u32],
        z: &[u32],
    ) -> Result<bool, String> {
        match self {
            GraphView::Admg(g) => Ok(g.is_valid_adjustment_set(xs, ys, z)),
            _ => Err("is_valid_adjustment_set_admg is only defined for ADMGs".into()),
        }
    }

    pub fn all_adjustment_sets_admg(
        &self,
        xs: &[u32],
        ys: &[u32],
        minimal: bool,
        max_size: u32,
    ) -> Result<Vec<Vec<u32>>, String> {
        match self {
            GraphView::Admg(g) => Ok(g.all_adjustment_sets(xs, ys, minimal, max_size)),
            _ => Err("all_adjustment_sets_admg is only defined for ADMGs".into()),
        }
    }

    pub fn induced_subgraph(&self, keep: &[u32]) -> Result<GraphView, String> {
        let (core2, _new_to_old, _old_to_new) = self.core().induced_subgraph(keep)?;
        let gv = match self {
            GraphView::Dag(_) => {
                let d = super::dag::Dag::new(std::sync::Arc::new(core2))?;
                GraphView::Dag(std::sync::Arc::new(d))
            }
            GraphView::Pdag(_) => {
                let p = super::pdag::Pdag::new(std::sync::Arc::new(core2))?;
                GraphView::Pdag(std::sync::Arc::new(p))
            }
            GraphView::Mpdag(_) => {
                let p = super::pdag::Pdag::new(std::sync::Arc::new(core2))?;
                if p.is_meek_closed() {
                    let m = super::mpdag::Mpdag::from_closed_unchecked(p);
                    GraphView::Mpdag(std::sync::Arc::new(m))
                } else {
                    GraphView::Pdag(std::sync::Arc::new(p))
                }
            }
            GraphView::Cpdag(_) => {
                // Deleting nodes can break the CPDAG invariant (e.g. chordality
                // or strong protection). Downgrade to the strongest class the
                // residual graph still satisfies: CPDAG, else MPDAG, else PDAG.
                let p = super::pdag::Pdag::new(std::sync::Arc::new(core2))?;
                if p.is_cpdag() {
                    let m = super::mpdag::Mpdag::from_closed_unchecked(p);
                    let c = super::cpdag::Cpdag::from_valid_unchecked(m);
                    GraphView::Cpdag(std::sync::Arc::new(c))
                } else if p.is_meek_closed() {
                    let m = super::mpdag::Mpdag::from_closed_unchecked(p);
                    GraphView::Mpdag(std::sync::Arc::new(m))
                } else {
                    GraphView::Pdag(std::sync::Arc::new(p))
                }
            }
            GraphView::Ug(_) => {
                let u = super::ug::Ug::new(std::sync::Arc::new(core2))?;
                GraphView::Ug(std::sync::Arc::new(u))
            }
            GraphView::Admg(_) => {
                let a = super::admg::Admg::new(std::sync::Arc::new(core2))?;
                GraphView::Admg(std::sync::Arc::new(a))
            }
            GraphView::Ag(_) => {
                let g = super::ag::Ag::new(std::sync::Arc::new(core2))?;
                GraphView::Ag(std::sync::Arc::new(g))
            }
            GraphView::Pag(_) => {
                // An induced subgraph of a PAG need not be a PAG.
                let core2 = std::sync::Arc::new(core2);
                match Pag::new(std::sync::Arc::clone(&core2)) {
                    Ok(g) => GraphView::Pag(std::sync::Arc::new(g)),
                    Err(_) => GraphView::Raw(core2),
                }
            }
            GraphView::Raw(_) => GraphView::Raw(std::sync::Arc::new(core2)),
        };
        Ok(gv)
    }
}

impl GraphView {
    /// Convert to a CPDAG (essential graph of the Markov equivalence class).
    ///
    /// Only defined for DAGs and CPDAGs (the latter is a fixed point). For
    /// PDAGs/MPDAGs, a true `to_cpdag` would require extending the PDAG to a
    /// consistent DAG (Dor-Tarsi) and then computing that DAG's CPDAG, which is
    /// not yet implemented. Use `to_mpdag` instead to apply Meek closure.
    pub fn to_cpdag(&self) -> Result<GraphView, String> {
        match self {
            GraphView::Dag(d) => {
                let c = d.to_cpdag()?;
                Ok(GraphView::Cpdag(std::sync::Arc::new(c)))
            }
            GraphView::Cpdag(c) => Ok(GraphView::Cpdag(std::sync::Arc::clone(c))),
            _ => Err("to_cpdag is only defined for DAGs".into()),
        }
    }

    /// One consistent DAG extension, by Dor and Tarsi's algorithm.
    ///
    /// Defined for PDAGs, MPDAGs and CPDAGs. A DAG is returned unchanged --
    /// it is its own extension.
    pub fn dag_extension(&self) -> Result<GraphView, String> {
        let dag = match self {
            GraphView::Dag(d) => return Ok(GraphView::Dag(std::sync::Arc::clone(d))),
            GraphView::Pdag(p) => p.dag_extension()?,
            GraphView::Mpdag(m) => m.as_pdag().dag_extension()?,
            GraphView::Cpdag(c) => c.as_pdag().dag_extension()?,
            _ => return Err("a DAG extension is only defined for PDAGs, MPDAGs and CPDAGs".into()),
        };
        Ok(GraphView::Dag(std::sync::Arc::new(dag)))
    }

    /// Apply Meek closure and return an MPDAG.
    ///
    /// Defined for DAGs (delegates to `to_cpdag` since a CPDAG is an MPDAG),
    /// PDAGs (applies Meek closure), MPDAGs (identity), and CPDAGs (downgrade,
    /// since every CPDAG is an MPDAG).
    pub fn to_mpdag(&self) -> Result<GraphView, String> {
        match self {
            GraphView::Dag(d) => {
                let c = d.to_cpdag()?;
                Ok(GraphView::Mpdag(std::sync::Arc::new(c.into_mpdag())))
            }
            GraphView::Pdag(p) => {
                let m = p.to_mpdag()?;
                Ok(GraphView::Mpdag(std::sync::Arc::new(m)))
            }
            GraphView::Mpdag(m) => Ok(GraphView::Mpdag(std::sync::Arc::clone(m))),
            GraphView::Cpdag(c) => Ok(GraphView::Mpdag(std::sync::Arc::new(c.as_mpdag().clone()))),
            _ => Err("to_mpdag is only defined for DAGs, PDAGs, and MPDAGs".into()),
        }
    }

    /// A MAG from the Markov equivalence class this PAG represents.
    pub fn pag_to_mag(&self) -> Result<GraphView, String> {
        match self {
            GraphView::Pag(g) => Ok(GraphView::Ag(Arc::new(g.to_mag()?))),
            _ => Err("pag_to_mag is only defined for PAGs".into()),
        }
    }

    /// The PAG of this MAG's Markov equivalence class.
    ///
    /// Maximality is checked here, since the construction assumes it.
    pub fn mag_to_pag(&self) -> Result<GraphView, String> {
        match self {
            GraphView::Ag(g) => {
                if !g.is_mag() {
                    return Err("mag_to_pag requires a maximal ancestral graph; this \
                                ancestral graph is not maximal"
                        .into());
                }
                Ok(GraphView::Pag(Arc::new(Pag::from_mag(g)?)))
            }
            _ => Err("mag_to_pag is only defined for MAGs (class 'AG')".into()),
        }
    }

    /// The skeleton: every edge becomes `---`, whatever its class, and
    /// parallel edges and self-loops collapse.
    pub fn skeleton(&self) -> Result<GraphView, String> {
        let core = self.core();
        let adj: Vec<Vec<u32>> = (0..core.n())
            .map(|u| {
                let mut nbrs: Vec<u32> = core
                    .row_range(u)
                    .map(|k| core.col_index[k])
                    .filter(|&v| v != u)
                    .collect();
                nbrs.sort_unstable();
                nbrs.dedup();
                nbrs
            })
            .collect();
        let ug = super::alg::csr::build_ug_core_from_adj(core, &adj)?;
        Ok(GraphView::Ug(Arc::new(Ug::new(Arc::new(ug))?)))
    }

    pub fn moralize(&self) -> Result<GraphView, String> {
        match self {
            GraphView::Dag(d) => {
                let ug = d.moralize()?;
                Ok(GraphView::Ug(Arc::new(ug)))
            }
            _ => Err("moralize is only defined for DAGs".into()),
        }
    }

    /// Project out latent variables from a DAG to produce an ADMG.
    ///
    /// Uses vertex elimination: for each latent vertex v, adds directed edges
    /// from Pa(v) to Ch(v), bidirected edges from Sib(v) to Ch(v), and
    /// bidirected edges among pairs of Ch(v), then removes v.
    ///
    /// Note: The result may have both directed and bidirected edges between
    /// the same pair of nodes (e.g., X → Y and X ↔ Y), which is valid in ADMGs.
    ///
    /// # Arguments
    /// * `latents` - Slice of node indices to project out (0-indexed)
    ///
    /// # Returns
    /// An ADMG `GraphView` containing only the observed (non-latent) nodes.
    pub fn latent_project(&self, latents: &[u32]) -> Result<GraphView, String> {
        match self {
            GraphView::Dag(d) => {
                let admg = d.latent_project(latents)?;
                Ok(GraphView::Admg(Arc::new(admg)))
            }
            _ => Err("latent_project is only defined for DAGs".into()),
        }
    }

    pub fn exogenize(&self, nodes: &[u32]) -> Result<GraphView, String> {
        match self {
            GraphView::Dag(d) => {
                let out = d.exogenize(nodes)?;
                Ok(GraphView::Dag(Arc::new(out)))
            }
            _ => Err("exogenize is only defined for DAGs".into()),
        }
    }

    pub fn normalize_latent_structure(
        &self,
        latents: &[u32],
    ) -> Result<(GraphView, Vec<u32>), String> {
        match self {
            GraphView::Dag(d) => {
                let (out, kept_old) = d.normalize_latent_structure(latents)?;
                Ok((GraphView::Dag(Arc::new(out)), kept_old))
            }
            _ => Err("normalize_latent_structure is only defined for DAGs".into()),
        }
    }

    /// Proper backdoor graph for Xs → Ys. Defined for DAG only.
    pub fn proper_backdoor_graph(&self, xs: &[u32], ys: &[u32]) -> Result<GraphView, String> {
        match self {
            GraphView::Dag(d) => {
                let core = d.proper_backdoor_core(xs, ys)?;
                let dag = super::dag::Dag::new(Arc::new(core))?;
                Ok(GraphView::Dag(Arc::new(dag)))
            }
            _ => Err("proper_backdoor_graph is only defined for DAGs".into()),
        }
    }

    /// Moral graph of the ancestral subgraph of seeds. Defined for DAG only.
    pub fn moral_of_ancestors(&self, seeds: &[u32]) -> Result<GraphView, String> {
        match self {
            GraphView::Dag(d) => {
                use crate::graph::alg::{bitset, csr, moral};
                let mask = bitset::ancestors_mask(seeds, |u| d.parents_of(u), d.n());
                let adj = moral::moral_adj(d.n(), |u| d.parents_of(u), &mask);
                let core = csr::build_ug_core_from_adj(d.core_ref(), &adj)?;
                let ug = super::ug::Ug::new(Arc::new(core))?;
                Ok(GraphView::Ug(Arc::new(ug)))
            }
            _ => Err("moral_of_ancestors is only defined for DAGs".into()),
        }
    }

    /// Ancestral reduction induced on seeds. Defined for DAG, PDAG, and ADMG.
    pub fn ancestral_reduction(&self, seeds: &[u32]) -> Result<GraphView, String> {
        match self {
            GraphView::Dag(d) => {
                use crate::graph::alg::bitset;
                let mask = bitset::ancestors_mask(seeds, |u| d.parents_of(u), d.n());
                let keep = bitset::collect_from_mask(&mask);
                self.induced_subgraph(&keep)
            }
            GraphView::Pdag(p) => {
                use crate::graph::alg::bitset;
                let mask = bitset::ancestors_mask(seeds, |u| p.parents_of(u), p.n());
                let keep = bitset::collect_from_mask(&mask);
                self.induced_subgraph(&keep)
            }
            GraphView::Mpdag(m) => {
                use crate::graph::alg::bitset;
                let p = m.as_pdag();
                let mask = bitset::ancestors_mask(seeds, |u| p.parents_of(u), p.n());
                let keep = bitset::collect_from_mask(&mask);
                self.induced_subgraph(&keep)
            }
            GraphView::Cpdag(c) => {
                use crate::graph::alg::bitset;
                let p = c.as_pdag();
                let mask = bitset::ancestors_mask(seeds, |u| p.parents_of(u), p.n());
                let keep = bitset::collect_from_mask(&mask);
                self.induced_subgraph(&keep)
            }
            GraphView::Admg(a) => {
                use crate::graph::alg::bitset;
                let mask = bitset::ancestors_mask(seeds, |u| a.parents_of(u), a.n());
                let keep = bitset::collect_from_mask(&mask);
                self.induced_subgraph(&keep)
            }
            GraphView::Ag(g) => {
                use crate::graph::alg::bitset;
                let mask = bitset::ancestors_mask(seeds, |u| g.parents_of(u), g.n());
                let keep = bitset::collect_from_mask(&mask);
                self.induced_subgraph(&keep)
            }
            _ => Err("ancestral_reduction is only defined for DAGs, PDAGs, ADMGs, and AGs".into()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    #[test]
    fn graphview_dispatch_dag_pdag_raw() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let cdir = r.code_of("-->").unwrap();
        let cund = r.code_of("---").unwrap();

        // DAG core: 0->1, 0->2
        let mut bd = GraphBuilder::new_with_registry(3, true, &r);
        bd.add_edge(0, 1, cdir).unwrap();
        bd.add_edge(0, 2, cdir).unwrap();
        let dag_core = Arc::new(bd.finalize().unwrap());
        let dag = Arc::new(Dag::new(dag_core.clone()).unwrap());
        let v_dag = GraphView::Dag(dag);
        assert_eq!(v_dag.n(), 3);
        assert_eq!(v_dag.parents_of(1).unwrap(), vec![0]);
        assert_eq!(v_dag.children_of(0).unwrap(), vec![1, 2]);
        assert_eq!(
            v_dag.neighbors_of(0, NeighborMode::All).unwrap(),
            vec![1, 2]
        );
        assert_eq!(v_dag.descendants_of(0).unwrap(), vec![1, 2]);
        assert_eq!(v_dag.ancestors_of(2).unwrap(), vec![0]);
        assert!(v_dag.undirected_of(0).unwrap().is_empty());
        let v_dag_core = v_dag.core();
        assert_eq!(v_dag_core.n(), 3);

        // PDAG core: 0->1, 1---2
        let mut bp = GraphBuilder::new_with_registry(4, true, &r);
        bp.add_edge(0, 1, cdir).unwrap();
        bp.add_edge(1, 2, cund).unwrap();
        bp.add_edge(1, 3, cdir).unwrap();
        let pdag_core = Arc::new(bp.finalize().unwrap());
        let pdag = Arc::new(Pdag::new(pdag_core.clone()).unwrap());
        let v_pdag = GraphView::Pdag(pdag);
        assert_eq!(v_pdag.n(), 4);
        assert_eq!(v_pdag.parents_of(1).unwrap(), vec![0]);
        assert_eq!(v_pdag.children_of(0).unwrap(), vec![1]);
        assert_eq!(v_pdag.undirected_of(1).unwrap(), vec![2]);
        assert_eq!(
            v_pdag.neighbors_of(1, NeighborMode::All).unwrap(),
            vec![0, 2, 3]
        );
        assert_eq!(v_pdag.descendants_of(0).unwrap(), vec![1, 3]);
        assert_eq!(v_pdag.ancestors_of(3).unwrap(), vec![0, 1]);
        let v_pdag_core = v_pdag.core();
        assert_eq!(v_pdag_core.n(), 4);

        // On a raw view, parents and children read the endpoints; the other
        // semantic wrappers error for UNKNOWN graphs
        let v_raw = GraphView::Raw(pdag_core);
        assert_eq!(v_raw.n(), 4);
        assert_eq!(v_raw.parents_of(1).unwrap(), vec![0]);
        assert_eq!(v_raw.children_of(0).unwrap(), vec![1]);
        assert!(v_raw.undirected_of(1).is_err());

        // neighbors_of still works
        assert_eq!(v_raw.neighbors_of(0, NeighborMode::All).unwrap(), vec![1]);
        assert_eq!(v_raw.neighbors_of(1, NeighborMode::In).unwrap(), vec![0]);
        assert_eq!(v_raw.neighbors_of(0, NeighborMode::Out).unwrap(), vec![1]);
        assert_eq!(
            v_raw.neighbors_of(1, NeighborMode::Undirected).unwrap(),
            vec![2]
        );

        let v_raw_core = v_raw.core();
        assert_eq!(v_raw_core.n(), 4);
    }

    #[test]
    fn graphview_mb_dispatch() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(4, true, &r);
        b.add_edge(2, 1, d).unwrap();
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(0, 3, d).unwrap();
        let dag = Arc::new(Dag::new(Arc::new(b.finalize_in_place().unwrap())).unwrap());
        let v = GraphView::Dag(dag);
        assert_eq!(v.markov_blanket_of(0).unwrap(), vec![1, 2, 3]);

        // Pdag:
        let mut b = GraphBuilder::new_with_registry(4, true, &r);
        let u = r.code_of("---").unwrap();
        b.add_edge(2, 1, d).unwrap();
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(0, 3, d).unwrap();
        b.add_edge(1, 3, u).unwrap();
        let pdag = Arc::new(Pdag::new(Arc::new(b.finalize_in_place().unwrap())).unwrap());

        let v = GraphView::Pdag(pdag);
        assert_eq!(v.markov_blanket_of(0).unwrap(), vec![1, 2, 3]);

        // Raw view uses UNKNOWN class fallbacks
        let v = GraphView::Raw(Arc::new(b.finalize().unwrap()));
        assert_eq!(
            v.markov_blanket_of(0).unwrap_err(),
            "markov_blanket_of not implemented for UNKNOWN class"
        );
    }

    #[test]
    fn exogenous_nodes_dag_pdag() {
        use crate::{edges::EdgeRegistry, graph::builder::GraphBuilder};
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let u = r.code_of("---").unwrap();

        // DAG: 0->1, 0->2  => exogenous {0,3}
        let mut b = GraphBuilder::new_with_registry(4, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(0, 2, d).unwrap();
        let v = GraphView::Dag(Arc::new(Dag::new(Arc::new(b.finalize().unwrap())).unwrap()));
        assert_eq!(v.exogenous_nodes(false).unwrap(), vec![0, 3]);

        // PDAG: 0->1, 1--2 => exogenous {0,2,3} if undirected ignored; {0,3} if counted
        let mut b = GraphBuilder::new_with_registry(4, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, u).unwrap();
        let v = GraphView::Pdag(Arc::new(
            Pdag::new(Arc::new(b.finalize().unwrap())).unwrap(),
        ));
        assert_eq!(v.exogenous_nodes(false).unwrap(), vec![0, 2, 3]);
        assert_eq!(v.exogenous_nodes(true).unwrap(), vec![0, 3]);
    }
    #[test]
    fn graphview_dag_adjustment_and_dsep_dispatch() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();

        // DAG: 0:L -> 1:A -> 2:Y and 0:L -> 2:Y (classic confounder)
        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        b.add_edge(0, 2, d).unwrap();
        let v = GraphView::Dag(Arc::new(Dag::new(Arc::new(b.finalize().unwrap())).unwrap()));

        // d-sep: X=1, Y=2 is not separated unconditionally; conditioning on 0 separates them
        assert_eq!(v.d_separated(&[1], &[2], &[]).unwrap(), false);
        assert_eq!(v.d_separated(&[0], &[2], &[0]).unwrap(), true);

        // adjustment sets (parents/backdoor/optimal) all return {0}
        assert_eq!(v.adjustment_set_parents(&[1], &[2]).unwrap(), vec![0]);
        assert_eq!(v.adjustment_set_backdoor(&[1], &[2]).unwrap(), vec![0]);
        assert_eq!(v.adjustment_set_optimal(&[1], &[2]).unwrap(), vec![0]);

        // backdoor validity + enumeration
        assert_eq!(v.is_valid_backdoor_set(&[1], &[2], &[0]).unwrap(), true);
        assert_eq!(v.is_valid_backdoor_set(&[1], &[2], &[]).unwrap(), false);
        assert_eq!(
            v.all_backdoor_sets(&[1], &[2], true, 5).unwrap(),
            vec![vec![0]]
        );
    }

    // --- d-sep simple chain to hit both true/false via GraphView::Dag ---
    #[test]
    fn graphview_dag_dsep_chain_true_false() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();

        // 0 -> 1 -> 2
        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let v = GraphView::Dag(Arc::new(Dag::new(Arc::new(b.finalize().unwrap())).unwrap()));

        // Unblocked path 0—1—2 => not separated
        assert_eq!(v.d_separated(&[0], &[2], &[]).unwrap(), false);
        // Condition on middle node blocks it
        assert_eq!(v.d_separated(&[0], &[2], &[1]).unwrap(), true);
    }

    // --- PDAG and RAW: all DAG-only methods must return errors ---
    #[test]
    fn graphview_pdag_and_raw_dagonly_methods_error() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let u = r.code_of("---").unwrap();

        // Build a small PDAG: 0->1, 1---2
        let mut bp = GraphBuilder::new_with_registry(3, true, &r);
        bp.add_edge(0, 1, d).unwrap();
        bp.add_edge(1, 2, u).unwrap();
        let pdag_core = Arc::new(bp.finalize().unwrap());
        let vp = GraphView::Pdag(Arc::new(Pdag::new(pdag_core.clone()).unwrap()));
        let vr = GraphView::Raw(pdag_core);

        // d_separated
        assert_eq!(
            vp.d_separated(&[0], &[2], &[]).unwrap_err(),
            "d_separated is only defined for DAGs"
        );
        assert_eq!(
            vr.d_separated(&[0], &[2], &[]).unwrap_err(),
            "d_separated is only defined for DAGs"
        );

        // adjustment_set_parents
        assert_eq!(
            vp.adjustment_set_parents(&[0], &[1]).unwrap_err(),
            "adjustment_set_parents is only defined for DAGs"
        );
        assert_eq!(
            vr.adjustment_set_parents(&[0], &[1]).unwrap_err(),
            "adjustment_set_parents is only defined for DAGs"
        );

        // adjustment_set_backdoor
        assert_eq!(
            vp.adjustment_set_backdoor(&[0], &[1]).unwrap_err(),
            "adjustment_set_backdoor is only defined for DAGs"
        );
        assert_eq!(
            vr.adjustment_set_backdoor(&[0], &[1]).unwrap_err(),
            "adjustment_set_backdoor is only defined for DAGs"
        );

        // adjustment_set_optimal
        assert_eq!(
            vp.adjustment_set_optimal(&[0], &[1]).unwrap_err(),
            "adjustment_set_optimal is only defined for DAGs"
        );
        assert_eq!(
            vr.adjustment_set_optimal(&[0], &[1]).unwrap_err(),
            "adjustment_set_optimal is only defined for DAGs"
        );

        // is_valid_backdoor_set
        assert_eq!(
            vp.is_valid_backdoor_set(&[0], &[1], &[]).unwrap_err(),
            "is_valid_backdoor_set is only defined for DAGs"
        );
        assert_eq!(
            vr.is_valid_backdoor_set(&[0], &[1], &[]).unwrap_err(),
            "is_valid_backdoor_set is only defined for DAGs"
        );

        // all_backdoor_sets
        assert_eq!(
            vp.all_backdoor_sets(&[0], &[1], true, 5).unwrap_err(),
            "all_backdoor_sets is only defined for DAGs"
        );
        assert_eq!(
            vr.all_backdoor_sets(&[0], &[1], true, 5).unwrap_err(),
            "all_backdoor_sets is only defined for DAGs"
        );
    }

    #[test]
    fn graphview_dispatch_for_ag_admg_ug_and_raw_error_paths() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let u = r.code_of("---").unwrap();
        let bi = r.code_of("<->").unwrap();

        // UG: 0---1---2
        let mut bu = GraphBuilder::new_with_registry(3, true, &r);
        bu.add_edge(0, 1, u).unwrap();
        bu.add_edge(1, 2, u).unwrap();
        let v_ug = GraphView::Ug(Arc::new(Ug::new(Arc::new(bu.finalize().unwrap())).unwrap()));

        // ADMG: 0->1, 1->2, 0<->2
        let mut ba = GraphBuilder::new_with_registry(3, true, &r);
        ba.add_edge(0, 1, d).unwrap();
        ba.add_edge(1, 2, d).unwrap();
        ba.add_edge(0, 2, bi).unwrap();
        let v_admg = GraphView::Admg(Arc::new(
            Admg::new(Arc::new(ba.finalize().unwrap())).unwrap(),
        ));

        // AG: 0->1->2 and disjoint undirected edge 3---4
        let mut bg = GraphBuilder::new_with_registry(5, true, &r);
        bg.add_edge(0, 1, d).unwrap();
        bg.add_edge(1, 2, d).unwrap();
        bg.add_edge(3, 4, u).unwrap();
        let ag_core = Arc::new(bg.finalize().unwrap());
        let v_ag = GraphView::Ag(Arc::new(Ag::new(ag_core.clone()).unwrap()));

        // Raw UNKNOWN view
        let v_raw = GraphView::Raw(ag_core);

        // core() + n() dispatch for UG/ADMG/AG
        assert_eq!(v_ug.core().n(), 3);
        assert_eq!(v_ug.n(), 3);
        assert_eq!(v_admg.core().n(), 3);
        assert_eq!(v_admg.n(), 3);
        assert_eq!(v_ag.core().n(), 5);
        assert_eq!(v_ag.n(), 5);

        // ancestors/descendants dispatch
        assert_eq!(v_admg.ancestors_of(2).unwrap(), vec![0, 1]);
        assert_eq!(v_admg.descendants_of(0).unwrap(), vec![1, 2]);
        assert_eq!(v_ag.ancestors_of(2).unwrap(), vec![0, 1]);
        assert_eq!(v_ag.descendants_of(0).unwrap(), vec![1, 2]);
        assert!(v_ug.ancestors_of(0).unwrap().is_empty());
        assert!(v_ug.descendants_of(0).unwrap().is_empty());
        assert_eq!(v_raw.ancestors_of(2).unwrap(), vec![0, 1]);
        assert_eq!(v_raw.descendants_of(0).unwrap(), vec![1, 2]);

        // anteriors/posteriors dispatch: ADMG gives ancestors/descendants,
        // UG the connected component, Raw reads the edge classes.
        assert!(v_admg.anteriors_of(0).unwrap().is_empty());
        assert_eq!(v_admg.posteriors_of(0).unwrap(), vec![1, 2]);
        assert_eq!(v_ag.anteriors_of(2).unwrap(), vec![0, 1]);
        assert_eq!(v_ag.posteriors_of(0).unwrap(), vec![1, 2]);
        assert_eq!(v_ug.anteriors_of(0).unwrap(), vec![1, 2]);
        assert_eq!(v_ug.posteriors_of(2).unwrap(), vec![0, 1]);
        assert!(!v_ug.m_separated(&[0], &[2], &[]).unwrap());
        assert!(v_ug.m_separated(&[0], &[2], &[1]).unwrap());
        assert_eq!(v_raw.anteriors_of(4).unwrap(), vec![3]);
        assert_eq!(v_raw.posteriors_of(0).unwrap(), vec![1, 2]);

        // markov blanket and neighbors all-mode dispatch
        assert_eq!(v_ug.markov_blanket_of(1).unwrap(), vec![0, 2]);
        let mb_admg = v_admg.markov_blanket_of(1).unwrap();
        assert!(mb_admg.contains(&0));
        assert!(!mb_admg.is_empty());
        let mb_ag = v_ag.markov_blanket_of(1).unwrap();
        assert!(mb_ag.contains(&0));
        assert!(!mb_ag.is_empty());
        assert_eq!(v_ag.neighbors_of(1, NeighborMode::All).unwrap(), vec![0, 2]);

        // exogenous nodes dispatch for UG/ADMG/AG + Raw error
        assert_eq!(v_ug.exogenous_nodes(false).unwrap(), vec![0, 1, 2]);
        assert!(v_ug.exogenous_nodes(true).unwrap().is_empty());
        assert_eq!(v_admg.exogenous_nodes(false).unwrap(), vec![0]);
        assert_eq!(v_ag.exogenous_nodes(false).unwrap(), vec![0, 3, 4]);
        assert_eq!(v_ag.exogenous_nodes(true).unwrap(), vec![0]);
        assert_eq!(
            v_raw.exogenous_nodes(false).unwrap_err(),
            "exogenous_nodes not implemented for UNKNOWN class"
        );
    }

    #[test]
    fn graphview_non_dag_specialized_methods_dispatch_and_errors() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let u = r.code_of("---").unwrap();
        let bi = r.code_of("<->").unwrap();

        // DAG for "only defined for ADMG" error checks.
        let mut bd = GraphBuilder::new_with_registry(3, true, &r);
        bd.add_edge(0, 1, d).unwrap();
        bd.add_edge(1, 2, d).unwrap();
        let v_dag = GraphView::Dag(Arc::new(
            Dag::new(Arc::new(bd.finalize().unwrap())).unwrap(),
        ));

        // PDAG: 0->1---2
        let mut bp = GraphBuilder::new_with_registry(3, true, &r);
        bp.add_edge(0, 1, d).unwrap();
        bp.add_edge(1, 2, u).unwrap();
        let pdag_core = Arc::new(bp.finalize().unwrap());
        let v_pdag = GraphView::Pdag(Arc::new(Pdag::new(pdag_core.clone()).unwrap()));
        let v_raw = GraphView::Raw(pdag_core);

        // AG with two districts: {0,1} and {2}
        let mut bg = GraphBuilder::new_with_registry(3, true, &r);
        bg.add_edge(0, 1, bi).unwrap();
        let v_ag = GraphView::Ag(Arc::new(Ag::new(Arc::new(bg.finalize().unwrap())).unwrap()));

        // ADMG for m-separation dispatch
        let mut ba = GraphBuilder::new_with_registry(3, true, &r);
        ba.add_edge(0, 1, d).unwrap();
        ba.add_edge(1, 2, d).unwrap();
        let v_admg = GraphView::Admg(Arc::new(
            Admg::new(Arc::new(ba.finalize().unwrap())).unwrap(),
        ));

        // UG for topological_sort error branch
        let mut bu = GraphBuilder::new_with_registry(2, true, &r);
        bu.add_edge(0, 1, u).unwrap();
        let v_ug = GraphView::Ug(Arc::new(Ug::new(Arc::new(bu.finalize().unwrap())).unwrap()));

        // topological_sort non-DAG branches
        assert_eq!(
            v_admg.topological_sort().unwrap_err(),
            "topological_sort is only defined for DAGs"
        );
        assert_eq!(
            v_pdag.topological_sort().unwrap_err(),
            "topological_sort is only defined for DAGs"
        );
        assert_eq!(
            v_ug.topological_sort().unwrap_err(),
            "topological_sort is only defined for DAGs"
        );
        assert_eq!(
            v_ag.topological_sort().unwrap_err(),
            "topological_sort is only defined for DAGs"
        );
        assert_eq!(
            v_raw.topological_sort().unwrap_err(),
            "topological_sort is only defined for DAGs"
        );

        // districts / district_of dispatch
        assert_eq!(v_ag.districts().unwrap(), vec![vec![0, 1], vec![2]]);
        assert_eq!(v_ag.district_of(0).unwrap(), vec![0, 1]);
        assert_eq!(
            v_dag.districts().unwrap_err(),
            "districts is only defined for ADMGs and AGs"
        );
        assert_eq!(
            v_dag.district_of(0).unwrap_err(),
            "district_of is only defined for ADMGs and AGs"
        );

        // m-separation dispatch + error branch
        assert_eq!(v_admg.m_separated(&[0], &[2], &[]).unwrap(), false);
        assert_eq!(v_ag.m_separated(&[0], &[1], &[]).unwrap(), false);
        assert_eq!(
            v_pdag.m_separated(&[0], &[2], &[]).unwrap_err(),
            "m_separated is only defined for ADMGs, AGs, PAGs, DAGs, and UGs"
        );
        assert_eq!(v_pdag.anteriors_of(1).unwrap(), vec![0, 2]);
        assert_eq!(v_pdag.posteriors_of(1).unwrap(), vec![2]);

        // ADMG-only adjustment methods error branches
        assert_eq!(
            v_dag
                .is_valid_adjustment_set_admg(&[0], &[2], &[])
                .unwrap_err(),
            "is_valid_adjustment_set_admg is only defined for ADMGs"
        );
        assert_eq!(
            v_dag
                .all_adjustment_sets_admg(&[0], &[2], true, 2)
                .unwrap_err(),
            "all_adjustment_sets_admg is only defined for ADMGs"
        );

        // Pdag -> MPDAG via meek closure
        let cp = v_pdag.to_mpdag().unwrap();
        assert!(matches!(cp, GraphView::Mpdag(_)));
        // to_cpdag is DAG-only
        assert_eq!(
            v_pdag.to_cpdag().unwrap_err(),
            "to_cpdag is only defined for DAGs"
        );

        // DAG-only transform helpers error branches on non-DAG
        assert_eq!(
            v_pdag.proper_backdoor_graph(&[0], &[1]).unwrap_err(),
            "proper_backdoor_graph is only defined for DAGs"
        );
        assert_eq!(
            v_ag.moral_of_ancestors(&[0]).unwrap_err(),
            "moral_of_ancestors is only defined for DAGs"
        );
    }

    #[test]
    fn graphview_induced_subgraph_and_ancestral_reduction_non_dag_variants() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let u = r.code_of("---").unwrap();
        let bi = r.code_of("<->").unwrap();

        // UG branch in induced_subgraph + ancestral_reduction error branch.
        let mut bug = GraphBuilder::new_with_registry(3, true, &r);
        bug.add_edge(0, 1, u).unwrap();
        bug.add_edge(1, 2, u).unwrap();
        let v_ug = GraphView::Ug(Arc::new(
            Ug::new(Arc::new(bug.finalize().unwrap())).unwrap(),
        ));
        let ug_sub = v_ug.induced_subgraph(&[0, 1]).unwrap();
        assert!(matches!(ug_sub, GraphView::Ug(_)));
        assert_eq!(
            v_ug.ancestral_reduction(&[0]).unwrap_err(),
            "ancestral_reduction is only defined for DAGs, PDAGs, ADMGs, and AGs"
        );

        // PDAG branch in ancestral_reduction.
        let mut bp = GraphBuilder::new_with_registry(3, true, &r);
        bp.add_edge(0, 1, d).unwrap();
        bp.add_edge(1, 2, u).unwrap();
        let v_pdag = GraphView::Pdag(Arc::new(
            Pdag::new(Arc::new(bp.finalize().unwrap())).unwrap(),
        ));
        let p_red = v_pdag.ancestral_reduction(&[1]).unwrap();
        assert!(matches!(p_red, GraphView::Pdag(_)));

        // ADMG branch in induced_subgraph + ancestral_reduction.
        let mut ba = GraphBuilder::new_with_registry(3, true, &r);
        ba.add_edge(0, 1, d).unwrap();
        ba.add_edge(1, 2, d).unwrap();
        ba.add_edge(0, 2, bi).unwrap();
        let v_admg = GraphView::Admg(Arc::new(
            Admg::new(Arc::new(ba.finalize().unwrap())).unwrap(),
        ));
        let a_sub = v_admg.induced_subgraph(&[1, 2]).unwrap();
        assert!(matches!(a_sub, GraphView::Admg(_)));
        let a_red = v_admg.ancestral_reduction(&[2]).unwrap();
        assert!(matches!(a_red, GraphView::Admg(_)));

        // AG branch in induced_subgraph + ancestral_reduction.
        let mut bg = GraphBuilder::new_with_registry(4, true, &r);
        bg.add_edge(0, 1, d).unwrap();
        bg.add_edge(1, 2, d).unwrap();
        bg.add_edge(2, 3, bi).unwrap();
        let v_ag = GraphView::Ag(Arc::new(Ag::new(Arc::new(bg.finalize().unwrap())).unwrap()));
        let g_sub = v_ag.induced_subgraph(&[0, 1, 2]).unwrap();
        assert!(matches!(g_sub, GraphView::Ag(_)));
        let g_red = v_ag.ancestral_reduction(&[2]).unwrap();
        assert!(matches!(g_red, GraphView::Ag(_)));
    }

    #[test]
    fn graphview_proper_backdoor_graph_public() {
        // Build L→A→Y with L→Y (classic confounder)
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // 0:L, 1:A, 2:Y
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap(); // L->A
        b.add_edge(1, 2, d).unwrap(); // A->Y
        b.add_edge(0, 2, d).unwrap(); // L->Y
        let dag = Arc::new(Dag::new(Arc::new(b.finalize().unwrap())).unwrap());
        let v = GraphView::Dag(dag);

        // Get proper backdoor graph for A → Y
        let pbg = v.proper_backdoor_graph(&[1], &[2]).unwrap();

        // In the proper backdoor graph, A->Y edge should be removed
        assert!(matches!(pbg, GraphView::Dag(_)));
        // Y should only have L as parent
        assert_eq!(pbg.parents_of(2).unwrap(), vec![0]);
        // A and Y should NOT be d-separated without conditioning
        // (backdoor path A <- L -> Y remains)
        assert!(!pbg.d_separated(&[1], &[2], &[]).unwrap());
    }

    #[test]
    fn graphview_moral_of_ancestors_public() {
        // Build L→A→Y with L→Y
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        // 0:L, 1:A, 2:Y
        let mut b = GraphBuilder::new_with_registry(3, true, &reg);
        b.add_edge(0, 1, d).unwrap(); // L->A
        b.add_edge(1, 2, d).unwrap(); // A->Y
        b.add_edge(0, 2, d).unwrap(); // L->Y
        let dag = Arc::new(Dag::new(Arc::new(b.finalize().unwrap())).unwrap());
        let v = GraphView::Dag(dag);

        // Get moral graph of ancestors of {A, Y}
        let moral = v.moral_of_ancestors(&[1, 2]).unwrap();

        // Should be a UG with all three nodes
        assert!(matches!(moral, GraphView::Ug(_)));
        assert_eq!(moral.n(), 3);
        // L should be adjacent to A (parent of A)
        // L should be adjacent to Y (parent of Y)
        // A should be adjacent to Y (A->Y in original, also married via Y)
        let mut l_nb = moral.undirected_of(0).unwrap();
        l_nb.sort();
        assert_eq!(l_nb, vec![1, 2]);
    }

    #[test]
    fn graphview_ancestral_reduction_public() {
        // Build larger DAG: 0->1->2, 3->4 (3,4 are distractors)
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let d = reg.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(5, true, &reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        b.add_edge(3, 4, d).unwrap();
        let dag = Arc::new(Dag::new(Arc::new(b.finalize().unwrap())).unwrap());
        let v = GraphView::Dag(dag);

        // Ancestral reduction on {1, 2}
        let reduced = v.ancestral_reduction(&[1, 2]).unwrap();

        // Should only contain An({1,2}) ∪ {1,2} = {0,1,2}
        assert!(matches!(reduced, GraphView::Dag(_)));
        assert_eq!(reduced.n(), 3); // nodes {0,1,2}
    }

    #[test]
    fn graphview_skeleton_from_dag_and_pdag_and_errors() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let u = r.code_of("---").unwrap();

        // DAG: 0->1, 1->2  ⇒ skeleton neighbors {0:[1], 1:[0,2], 2:[1]}
        let mut bd = GraphBuilder::new_with_registry(3, true, &r);
        bd.add_edge(0, 1, d).unwrap();
        bd.add_edge(1, 2, d).unwrap();
        let v_dag = GraphView::Dag(Arc::new(
            Dag::new(Arc::new(bd.finalize().unwrap())).unwrap(),
        ));
        let ug_gv = v_dag.skeleton().unwrap();
        assert!(matches!(ug_gv, GraphView::Ug(_)));
        assert_eq!(ug_gv.undirected_of(0).unwrap(), vec![1]);
        assert_eq!(ug_gv.undirected_of(1).unwrap(), vec![0, 2]);
        assert_eq!(ug_gv.undirected_of(2).unwrap(), vec![1]);

        // PDAG: 0->1, 1--2  ⇒ skeleton neighbors {0:[1], 1:[0,2], 2:[1]}
        let mut bp = GraphBuilder::new_with_registry(3, true, &r);
        bp.add_edge(0, 1, d).unwrap();
        bp.add_edge(1, 2, u).unwrap();
        let v_pdag = GraphView::Pdag(Arc::new(
            Pdag::new(Arc::new(bp.finalize().unwrap())).unwrap(),
        ));
        let ug2_gv = v_pdag.skeleton().unwrap();
        assert!(matches!(ug2_gv, GraphView::Ug(_)));
        assert_eq!(ug2_gv.undirected_of(0).unwrap(), vec![1]);
        assert_eq!(ug2_gv.undirected_of(1).unwrap(), vec![0, 2]);
        assert_eq!(ug2_gv.undirected_of(2).unwrap(), vec![1]);

        // UNKNOWN: 0 --> 1, the bow 0 <-> 1, 1 o-> 2 and the self-loop 2 --> 2
        // become 0 --- 1 --- 2.
        let (bi, po) = (r.code_of("<->").unwrap(), r.code_of("o->").unwrap());
        let mut bu = GraphBuilder::new_with_registry(3, false, &r);
        bu.add_edge(0, 1, d).unwrap();
        bu.add_edge(0, 1, bi).unwrap();
        bu.add_edge(1, 2, po).unwrap();
        bu.add_edge(2, 2, d).unwrap();
        let v_raw = GraphView::Raw(Arc::new(bu.finalize().unwrap()));
        let ug3_gv = v_raw.skeleton().unwrap();
        assert_eq!(ug3_gv.undirected_of(1).unwrap(), vec![0, 2]);
        assert_eq!(ug3_gv.undirected_of(2).unwrap(), vec![1]);
    }

    #[test]
    fn graphview_moralize_from_dag_and_errors() {
        use crate::graph::ug::Ug;
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let u = r.code_of("---").unwrap();

        // Moralize v-structure: 0->2<-1  ⇒ marry parents ⇒ UG edges {0-2,1-2,0-1}
        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 2, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let v_dag = GraphView::Dag(Arc::new(Dag::new(Arc::new(b.finalize().unwrap())).unwrap()));
        let ug_gv = v_dag.moralize().unwrap();
        assert!(matches!(ug_gv, GraphView::Ug(_)));
        assert_eq!(ug_gv.undirected_of(0).unwrap(), vec![1, 2]);
        assert_eq!(ug_gv.undirected_of(1).unwrap(), vec![0, 2]);
        assert_eq!(ug_gv.undirected_of(2).unwrap(), vec![0, 1]);

        // PDAG: moralize() must error
        let mut bp = GraphBuilder::new_with_registry(2, true, &r);
        bp.add_edge(0, 1, d).unwrap();
        let v_pdag = GraphView::Pdag(Arc::new(
            Pdag::new(Arc::new(bp.finalize().unwrap())).unwrap(),
        ));
        assert_eq!(
            v_pdag.moralize().unwrap_err(),
            "moralize is only defined for DAGs"
        );

        // UG: moralize() must error
        let mut bu = GraphBuilder::new_with_registry(2, true, &r);
        bu.add_edge(0, 1, u).unwrap();
        let v_ug = GraphView::Ug(Arc::new(Ug::new(Arc::new(bu.finalize().unwrap())).unwrap()));
        assert_eq!(
            v_ug.moralize().unwrap_err(),
            "moralize is only defined for DAGs"
        );
    }

    #[test]
    fn neighbor_mode_from_str_parses_correctly() {
        assert_eq!(NeighborMode::from_str("all").unwrap(), NeighborMode::All);
        assert_eq!(NeighborMode::from_str("ALL").unwrap(), NeighborMode::All);
        assert_eq!(NeighborMode::from_str("in").unwrap(), NeighborMode::In);
        assert_eq!(NeighborMode::from_str("IN").unwrap(), NeighborMode::In);
        assert_eq!(NeighborMode::from_str("out").unwrap(), NeighborMode::Out);
        assert_eq!(NeighborMode::from_str("OUT").unwrap(), NeighborMode::Out);
        assert_eq!(
            NeighborMode::from_str("undirected").unwrap(),
            NeighborMode::Undirected
        );
        assert_eq!(
            NeighborMode::from_str("bidirected").unwrap(),
            NeighborMode::Bidirected
        );
        assert_eq!(
            NeighborMode::from_str("partial").unwrap(),
            NeighborMode::Partial
        );
        assert!(NeighborMode::from_str("invalid").is_err());
    }

    #[test]
    fn neighbors_mode_of_dag() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();

        // 0 -> 1, 0 -> 2
        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(0, 2, d).unwrap();
        let v = GraphView::Dag(Arc::new(Dag::new(Arc::new(b.finalize().unwrap())).unwrap()));

        // Node 0: has children 1,2 (out), no parents (in)
        assert_eq!(v.neighbors_of(0, NeighborMode::All).unwrap(), vec![1, 2]);
        assert_eq!(
            v.neighbors_of(0, NeighborMode::In).unwrap(),
            Vec::<u32>::new()
        );
        assert_eq!(v.neighbors_of(0, NeighborMode::Out).unwrap(), vec![1, 2]);
        // DAG doesn't have undirected or partial edges - should error
        assert!(v
            .neighbors_of(0, NeighborMode::Undirected)
            .unwrap()
            .is_empty());
        assert!(v.neighbors_of(0, NeighborMode::Partial).unwrap().is_empty());

        // Node 1: has parent 0 (in), no children (out)
        assert_eq!(v.neighbors_of(1, NeighborMode::All).unwrap(), vec![0]);
        assert_eq!(v.neighbors_of(1, NeighborMode::In).unwrap(), vec![0]);
        assert_eq!(
            v.neighbors_of(1, NeighborMode::Out).unwrap(),
            Vec::<u32>::new()
        );
    }

    #[test]
    fn neighbors_mode_of_pdag() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let u = r.code_of("---").unwrap();

        // 0 -> 1, 1 --- 2
        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, u).unwrap();
        let v = GraphView::Pdag(Arc::new(
            Pdag::new(Arc::new(b.finalize().unwrap())).unwrap(),
        ));

        // Node 1: parent 0 (in), undirected 2
        assert_eq!(v.neighbors_of(1, NeighborMode::In).unwrap(), vec![0]);
        assert_eq!(
            v.neighbors_of(1, NeighborMode::Out).unwrap(),
            Vec::<u32>::new()
        );
        assert_eq!(
            v.neighbors_of(1, NeighborMode::Undirected).unwrap(),
            vec![2]
        );
        // PDAG doesn't have partial edges - should error
        assert!(v.neighbors_of(1, NeighborMode::Partial).unwrap().is_empty());
    }

    #[test]
    fn neighbors_mode_of_raw_mixed_edges() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let u = r.code_of("---").unwrap();
        let bi = r.code_of("<->").unwrap();
        let po = r.code_of("o->").unwrap();
        let oo = r.code_of("o-o").unwrap();
        let to = r.code_of("--o").unwrap();

        // 0 --> 1, 1 --- 2, 1 <-> 3, 1 o-> 4, 1 o-o 5, 1 --> 6, 1 --o 7, and the
        // bow 0 <-> 1 next to 0 --> 1.
        let mut b = GraphBuilder::new_with_registry(8, false, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, u).unwrap();
        b.add_edge(1, 3, bi).unwrap();
        b.add_edge(1, 4, po).unwrap();
        b.add_edge(1, 5, oo).unwrap();
        b.add_edge(1, 6, d).unwrap();
        b.add_edge(1, 7, to).unwrap();
        b.add_edge(0, 1, bi).unwrap();
        let v = GraphView::Raw(Arc::new(b.finalize().unwrap()));
        let of = |i, mode| v.neighbors_of(i, mode).unwrap();

        // The bow gives node 0 once.
        assert_eq!(of(1, NeighborMode::All), vec![0, 2, 3, 4, 5, 6, 7]);
        // `in` needs an arrowhead here and a tail there, `out` the reverse, so
        // neither counts <-> or the edges with a circle.
        assert_eq!(of(1, NeighborMode::In), vec![0]);
        assert_eq!(of(1, NeighborMode::Out), vec![6]);
        assert_eq!(of(1, NeighborMode::Undirected), vec![2]);
        assert_eq!(of(1, NeighborMode::Bidirected), vec![0, 3]);
        // `partial` takes a circle at either end, so 1 --o 7 counts from 1
        // and 1 o-> 4 counts from 4.
        assert_eq!(of(1, NeighborMode::Partial), vec![4, 5, 7]);
        assert!(of(4, NeighborMode::In).is_empty());
        assert_eq!(of(4, NeighborMode::Partial), vec![1]);
        assert_eq!(of(7, NeighborMode::Partial), vec![1]);
    }

    #[test]
    fn neighbors_mode_of_raw_directed_only() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();

        // Simple graph: 0 -> 1 -> 2
        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let core = Arc::new(b.finalize().unwrap());
        let v = GraphView::Raw(core);

        // Node 1: parent 0 (in), child 2 (out)
        assert_eq!(v.neighbors_of(1, NeighborMode::In).unwrap(), vec![0]);
        assert_eq!(v.neighbors_of(1, NeighborMode::Out).unwrap(), vec![2]);
        assert_eq!(v.neighbors_of(1, NeighborMode::All).unwrap().len(), 2);
    }

    #[test]
    fn neighbors_mode_of_ug() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let u = r.code_of("---").unwrap();

        // Graph: 0 --- 1 --- 2
        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(1, 2, u).unwrap();
        let v = GraphView::Ug(Arc::new(Ug::new(Arc::new(b.finalize().unwrap())).unwrap()));

        // UG only allows undirected and all modes
        assert_eq!(
            v.neighbors_of(1, NeighborMode::Undirected).unwrap(),
            vec![0, 2]
        );
        assert_eq!(v.neighbors_of(1, NeighborMode::All).unwrap(), vec![0, 2]);

        // Invalid modes for UG should error
        assert!(v.neighbors_of(1, NeighborMode::In).unwrap().is_empty());
        assert!(v.neighbors_of(1, NeighborMode::Out).unwrap().is_empty());
        assert!(v.neighbors_of(1, NeighborMode::Partial).unwrap().is_empty());
    }

    #[test]
    fn neighbors_mode_of_admg() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let bi = r.code_of("<->").unwrap();

        // Graph: 0 -> 1, 1 <-> 2, 0 <-> 2
        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, bi).unwrap();
        b.add_edge(0, 2, bi).unwrap();
        let v = GraphView::Admg(Arc::new(
            Admg::new(Arc::new(b.finalize().unwrap())).unwrap(),
        ));

        // Node 1: parent 0 (in), spouse 2 (bidirected), no children (out)
        assert_eq!(v.neighbors_of(1, NeighborMode::In).unwrap(), vec![0]);
        assert_eq!(
            v.neighbors_of(1, NeighborMode::Out).unwrap(),
            Vec::<u32>::new()
        );
        assert_eq!(
            v.neighbors_of(1, NeighborMode::Bidirected).unwrap(),
            vec![2]
        ); // spouses

        // All neighbors
        let all = v.neighbors_of(1, NeighborMode::All).unwrap();
        assert_eq!(all.len(), 2);
        assert!(all.contains(&0));
        assert!(all.contains(&2));

        // ADMG doesn't have undirected or partial edges - should error
        assert!(v
            .neighbors_of(1, NeighborMode::Undirected)
            .unwrap()
            .is_empty());
        assert!(v.neighbors_of(1, NeighborMode::Partial).unwrap().is_empty());

        // Node 0: no parents, child 1, spouse 2
        assert_eq!(
            v.neighbors_of(0, NeighborMode::In).unwrap(),
            Vec::<u32>::new()
        );
        assert_eq!(v.neighbors_of(0, NeighborMode::Out).unwrap(), vec![1]);
        assert_eq!(
            v.neighbors_of(0, NeighborMode::Bidirected).unwrap(),
            vec![2]
        );
    }

    #[test]
    fn neighbors_mode_of_ag() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let bi = r.code_of("<->").unwrap();
        let u = r.code_of("---").unwrap();

        // Graph: 0 -> 1, 2 <-> 3, 4 --- 5
        let mut b = GraphBuilder::new_with_registry(6, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(2, 3, bi).unwrap();
        b.add_edge(4, 5, u).unwrap();
        let v = GraphView::Ag(Arc::new(Ag::new(Arc::new(b.finalize().unwrap())).unwrap()));

        // Directed part
        assert_eq!(v.neighbors_of(1, NeighborMode::In).unwrap(), vec![0]);
        assert_eq!(v.neighbors_of(0, NeighborMode::Out).unwrap(), vec![1]);

        // Bidirected part
        assert_eq!(
            v.neighbors_of(2, NeighborMode::Bidirected).unwrap(),
            vec![3]
        );
        assert_eq!(
            v.neighbors_of(3, NeighborMode::Bidirected).unwrap(),
            vec![2]
        );

        // Undirected part
        assert_eq!(
            v.neighbors_of(4, NeighborMode::Undirected).unwrap(),
            vec![5]
        );
        assert_eq!(
            v.neighbors_of(5, NeighborMode::Undirected).unwrap(),
            vec![4]
        );

        // Partial should error
        assert!(v.neighbors_of(0, NeighborMode::Partial).unwrap().is_empty());
    }

    #[test]
    fn thin_wrappers_dag() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();

        // Graph: 0 -> 1 -> 2
        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let v = GraphView::Dag(Arc::new(Dag::new(Arc::new(b.finalize().unwrap())).unwrap()));

        // Test thin wrappers
        assert_eq!(v.parents_of(1).unwrap(), vec![0]);
        assert_eq!(v.children_of(1).unwrap(), vec![2]);
        assert_eq!(v.neighbors_of(1, NeighborMode::All).unwrap(), vec![0, 2]);

        // undirected_of should error for DAG
        assert!(v.undirected_of(1).unwrap().is_empty());

        // spouses_of should error for DAG
        assert!(v.spouses_of(1).unwrap().is_empty());
    }

    #[test]
    fn thin_wrappers_pdag() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let u = r.code_of("---").unwrap();

        // Graph: 0 -> 1 --- 2
        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, u).unwrap();
        let v = GraphView::Pdag(Arc::new(
            Pdag::new(Arc::new(b.finalize().unwrap())).unwrap(),
        ));

        // Test thin wrappers
        assert_eq!(v.parents_of(1).unwrap(), vec![0]);
        assert_eq!(v.children_of(1).unwrap(), Vec::<u32>::new());
        assert_eq!(v.undirected_of(1).unwrap(), vec![2]);
        assert_eq!(v.neighbors_of(1, NeighborMode::All).unwrap(), vec![0, 2]);

        // spouses_of should error for PDAG
        assert!(v.spouses_of(1).unwrap().is_empty());
    }

    #[test]
    fn thin_wrappers_ug() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let u = r.code_of("---").unwrap();

        // Graph: 0 --- 1 --- 2
        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 1, u).unwrap();
        b.add_edge(1, 2, u).unwrap();
        let v = GraphView::Ug(Arc::new(Ug::new(Arc::new(b.finalize().unwrap())).unwrap()));

        // Test thin wrappers
        assert_eq!(v.undirected_of(1).unwrap(), vec![0, 2]);
        assert_eq!(v.neighbors_of(1, NeighborMode::All).unwrap(), vec![0, 2]);

        // parents_of and children_of should error for UG
        assert!(v.parents_of(1).unwrap().is_empty());
        assert!(v.children_of(1).unwrap().is_empty());

        // spouses_of should error for UG
        assert!(v.spouses_of(1).unwrap().is_empty());
    }

    #[test]
    fn thin_wrappers_admg() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let bi = r.code_of("<->").unwrap();

        // Graph: 0 -> 1 <-> 2
        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, bi).unwrap();
        let v = GraphView::Admg(Arc::new(
            Admg::new(Arc::new(b.finalize().unwrap())).unwrap(),
        ));

        // Test thin wrappers
        assert_eq!(v.parents_of(1).unwrap(), vec![0]);
        assert_eq!(v.children_of(1).unwrap(), Vec::<u32>::new());
        assert_eq!(v.bidirected_of(1).unwrap(), vec![2]);
        assert_eq!(v.spouses_of(1).unwrap(), vec![2]);

        // undirected_of should error for ADMG
        assert!(v.undirected_of(1).unwrap().is_empty());

        let all = v.neighbors_of(1, NeighborMode::All).unwrap();
        assert_eq!(all.len(), 2);
        assert!(all.contains(&0));
        assert!(all.contains(&2));
    }

    #[test]
    fn thin_wrappers_raw() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let u = r.code_of("---").unwrap();
        let bi = r.code_of("<->").unwrap();

        // Graph: 0 -> 1, 1 --- 2, 1 <-> 3
        // Edge marks:
        // 0 -> 1: tail at 0, arrow at 1
        // 1 --- 2: tail at 1, tail at 2
        // 1 <-> 3: arrow at 1, arrow at 3
        let mut b = GraphBuilder::new_with_registry(4, false, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, u).unwrap();
        b.add_edge(1, 3, bi).unwrap();
        let v = GraphView::Raw(Arc::new(b.finalize().unwrap()));

        // Parents and children read the endpoints; the other semantic wrappers
        // error for UNKNOWN graphs
        assert_eq!(v.parents_of(1).unwrap(), vec![0]);
        assert!(v.children_of(1).unwrap().is_empty());
        assert!(v.undirected_of(1).is_err());
        assert!(v.bidirected_of(1).is_err());
        assert!(v.spouses_of(1).is_err());

        // But neighbors_of works with explicit mode
        let all = v.neighbors_of(1, NeighborMode::All).unwrap();
        assert_eq!(all.len(), 3);
        assert!(all.contains(&0));
        assert!(all.contains(&2));
        assert!(all.contains(&3));

        // neighbors_of allows explicit mode selection; 1 <-> 3 has no tail at
        // 3, so 3 is not a parent.
        assert_eq!(v.neighbors_of(1, NeighborMode::In).unwrap(), vec![0]);

        assert_eq!(
            v.neighbors_of(1, NeighborMode::Undirected).unwrap(),
            vec![2]
        );
        assert_eq!(
            v.neighbors_of(1, NeighborMode::Bidirected).unwrap(),
            vec![3]
        );
    }

    #[test]
    fn raw_partially_directed_edges() {
        // Test o-> edge specifically: A o-> B
        // A (tail position): Circle mark
        // B (head position): Arrow mark
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let po = r.code_of("o->").unwrap();

        let mut b = GraphBuilder::new_with_registry(2, false, &r);
        b.add_edge(0, 1, po).unwrap(); // A o-> B (0 o-> 1)
        let v = GraphView::Raw(Arc::new(b.finalize().unwrap()));

        // From A's perspective (side 0): my_mark = Circle, neighbor_mark = Arrow
        assert!(v.neighbors_of(0, NeighborMode::In).unwrap().is_empty()); // A has no Arrow
        assert!(v.neighbors_of(0, NeighborMode::Out).unwrap().is_empty()); // A has no Tail
        assert!(v
            .neighbors_of(0, NeighborMode::Undirected)
            .unwrap()
            .is_empty()); // A has no Tail
        assert!(v
            .neighbors_of(0, NeighborMode::Bidirected)
            .unwrap()
            .is_empty()); // Not both Arrow
        assert_eq!(v.neighbors_of(0, NeighborMode::Partial).unwrap(), vec![1]); // A has Circle

        // From B's perspective (side 1): my_mark = Arrow, neighbor_mark = Circle
        assert!(v.neighbors_of(1, NeighborMode::In).unwrap().is_empty()); // A has no Tail
        assert!(v.neighbors_of(1, NeighborMode::Out).unwrap().is_empty()); // A has no Arrow
        assert!(v
            .neighbors_of(1, NeighborMode::Undirected)
            .unwrap()
            .is_empty()); // B has no Tail
        assert!(v
            .neighbors_of(1, NeighborMode::Bidirected)
            .unwrap()
            .is_empty()); // Not both Arrow
        assert_eq!(v.neighbors_of(1, NeighborMode::Partial).unwrap(), vec![0]); // A has Circle
    }

    #[test]
    fn raw_partially_undirected_edges() {
        // Test --o edge: A --o B
        // A (tail position): Tail mark
        // B (head position): Circle mark
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let ou = r.code_of("--o").unwrap();

        let mut b = GraphBuilder::new_with_registry(2, false, &r);
        b.add_edge(0, 1, ou).unwrap(); // A --o B (0 --o 1)
        let v = GraphView::Raw(Arc::new(b.finalize().unwrap()));

        // From A's perspective (side 0): my_mark = Tail, neighbor_mark = Circle
        assert!(v.neighbors_of(0, NeighborMode::In).unwrap().is_empty()); // A has no Arrow
        assert!(v.neighbors_of(0, NeighborMode::Out).unwrap().is_empty()); // B has no Arrow
                                                                           // Undirected requires BOTH to have Tail, but B has Circle, so empty
        assert!(v
            .neighbors_of(0, NeighborMode::Undirected)
            .unwrap()
            .is_empty());
        assert!(v
            .neighbors_of(0, NeighborMode::Bidirected)
            .unwrap()
            .is_empty());
        assert_eq!(v.neighbors_of(0, NeighborMode::Partial).unwrap(), vec![1]); // B has Circle

        // From B's perspective (side 1): my_mark = Circle, neighbor_mark = Tail
        assert!(v.neighbors_of(1, NeighborMode::In).unwrap().is_empty()); // B has no Arrow
        assert!(v.neighbors_of(1, NeighborMode::Out).unwrap().is_empty()); // A has no Arrow
        assert!(v
            .neighbors_of(1, NeighborMode::Undirected)
            .unwrap()
            .is_empty()); // B has Circle, not Tail
        assert!(v
            .neighbors_of(1, NeighborMode::Bidirected)
            .unwrap()
            .is_empty());
        assert_eq!(v.neighbors_of(1, NeighborMode::Partial).unwrap(), vec![0]); // B has Circle
    }

    #[test]
    fn raw_all_partial_edge_types() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let oo = r.code_of("o-o").unwrap();
        let po = r.code_of("o->").unwrap();
        let op = r.code_of("--o").unwrap();

        // Graph with all partial edge types: 0 o-o 1, 1 o-> 2, 2 --o 3
        // Edge marks:
        // o-o: tail = Circle, head = Circle (both have Circle)
        // o->: tail = Circle, head = Arrow (tail has Circle, head has Arrow)
        // --o: tail = Tail, head = Circle (tail has Tail, head has Circle)
        let mut b = GraphBuilder::new_with_registry(4, false, &r);
        b.add_edge(0, 1, oo).unwrap(); // 0 o-o 1: both have Circle
        b.add_edge(1, 2, po).unwrap(); // 1 o-> 2: 1 has Circle, 2 has Arrow
        b.add_edge(2, 3, op).unwrap(); // 2 --o 3: 2 has Tail, 3 has Circle
        let v = GraphView::Raw(Arc::new(b.finalize().unwrap()));

        // Test partial mode: returns neighbors joined by a Circle mark at either end
        // Node 0: position 0 in o-o, so my_mark = Circle -> returns 1
        assert_eq!(v.neighbors_of(0, NeighborMode::Partial).unwrap(), vec![1]);

        // Node 1: position 1 in o-o (Circle) and position 0 in o-> (Circle)
        let p1 = v.neighbors_of(1, NeighborMode::Partial).unwrap();
        assert_eq!(p1.len(), 2);
        assert!(p1.contains(&0)); // from o-o (Circle at position 1)
        assert!(p1.contains(&2)); // from o-> (Circle at position 0)

        // Node 2: Arrow in o-> and Tail in --o, but the other ends have Circles
        assert_eq!(
            v.neighbors_of(2, NeighborMode::Partial).unwrap(),
            vec![1, 3]
        );

        // Node 3: position 1 in --o (Circle) -> returns 2
        assert_eq!(v.neighbors_of(3, NeighborMode::Partial).unwrap(), vec![2]);

        // In and out need a Tail at one end and an Arrow at the other, so no
        // edge here has a parent or child: o-> has a Circle where the Tail
        // would be.
        assert!(v.neighbors_of(2, NeighborMode::In).unwrap().is_empty());
        assert!(v.neighbors_of(1, NeighborMode::In).unwrap().is_empty());
        assert!(v.neighbors_of(1, NeighborMode::Out).unwrap().is_empty());
        assert!(v.neighbors_of(2, NeighborMode::Out).unwrap().is_empty());

        // Undirected mode: returns neighbors where BOTH nodes have Tail mark
        // Node 2: position 0 in --o, my_mark = Tail, but neighbor 3's mark = Circle
        // So undirected is empty (--o is not a truly undirected edge)
        assert!(v
            .neighbors_of(2, NeighborMode::Undirected)
            .unwrap()
            .is_empty());
    }

    #[test]
    fn neighbor_mode_from_str() {
        assert_eq!(NeighborMode::from_str("in").unwrap(), NeighborMode::In);
        assert_eq!(NeighborMode::from_str("IN").unwrap(), NeighborMode::In);
        assert_eq!(NeighborMode::from_str("out").unwrap(), NeighborMode::Out);
        assert_eq!(NeighborMode::from_str("OUT").unwrap(), NeighborMode::Out);
        assert_eq!(
            NeighborMode::from_str("undirected").unwrap(),
            NeighborMode::Undirected
        );
        assert_eq!(
            NeighborMode::from_str("bidirected").unwrap(),
            NeighborMode::Bidirected
        );
        assert_eq!(
            NeighborMode::from_str("partial").unwrap(),
            NeighborMode::Partial
        );
        assert_eq!(NeighborMode::from_str("all").unwrap(), NeighborMode::All);

        // Case insensitive
        assert_eq!(NeighborMode::from_str("IN").unwrap(), NeighborMode::In);
        assert_eq!(
            NeighborMode::from_str("BIDIRECTED").unwrap(),
            NeighborMode::Bidirected
        );

        // Invalid mode should error
        assert!(NeighborMode::from_str("invalid").is_err());
    }

    #[test]
    fn raw_bidirected_mode() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let bi = r.code_of("<->").unwrap();

        // Graph: 0 -> 1 <-> 2
        let mut b = GraphBuilder::new_with_registry(3, false, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, bi).unwrap();
        let v = GraphView::Raw(Arc::new(b.finalize().unwrap()));

        // Bidirected mode only returns <-> edges
        assert!(v
            .neighbors_of(0, NeighborMode::Bidirected)
            .unwrap()
            .is_empty());
        assert_eq!(
            v.neighbors_of(1, NeighborMode::Bidirected).unwrap(),
            vec![2]
        );
        assert_eq!(
            v.neighbors_of(2, NeighborMode::Bidirected).unwrap(),
            vec![1]
        );
    }
}
