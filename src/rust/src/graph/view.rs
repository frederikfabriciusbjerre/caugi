use super::admg::Admg;
use super::ag::Ag;
use super::dag::Dag;
use super::pdag::Pdag;
use super::ug::Ug;
use super::CaugiGraph;
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
    Ug(Arc<Ug>),
    Admg(Arc<Admg>),
    Ag(Arc<Ag>),
    Raw(Arc<CaugiGraph>),
}

impl GraphView {
    #[inline]
    pub fn core(&self) -> &CaugiGraph {
        match self {
            GraphView::Dag(d) => d.core_ref(),
            GraphView::Pdag(p) => p.core_ref(),
            GraphView::Ug(u) => u.core_ref(),
            GraphView::Admg(a) => a.core_ref(),
            GraphView::Ag(g) => g.core_ref(),
            GraphView::Raw(c) => c,
        }
    }

    #[inline]
    pub fn n(&self) -> u32 {
        match self {
            GraphView::Dag(g) => g.n(),
            GraphView::Pdag(g) => g.n(),
            GraphView::Ug(g) => g.n(),
            GraphView::Admg(g) => g.n(),
            GraphView::Ag(g) => g.n(),
            GraphView::Raw(core) => core.n(),
        }
    }

    // ---- queries ----

    /// Get parents of node `i` (nodes with directed edges pointing INTO `i`)..
    pub fn parents_of(&self, i: u32) -> Result<Vec<u32>, String> {
        if matches!(self, GraphView::Raw(_)) {
            return Err("parents_of is not defined for UNKNOWN graphs; use neighbors(..., mode = 'in') instead".into());
        }
        self.neighbors_of(i, NeighborMode::In)
    }

    /// Get children of node `i` (nodes with directed edges pointing OUT from `i`).
    pub fn children_of(&self, i: u32) -> Result<Vec<u32>, String> {
        if matches!(self, GraphView::Raw(_)) {
            return Err("children_of is not defined for UNKNOWN graphs; use neighbors(..., mode = 'out') instead".into());
        }
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
    /// Mode restrictions per graph type:
    /// - DAG: in, out, all (no undirected or partial edges exist)
    /// - PDAG: in, out, undirected, all (no partial edges exist)
    /// - UG: undirected, all (no directed or partial edges exist)
    /// - ADMG: in, out, undirected (bidirected/spouses), all (no partial edges exist)
    /// - AG: in, out, undirected, bidirected, all (no partial edges exist)
    /// - UNKNOWN (Raw): all modes allowed
    pub fn neighbors_of(&self, i: u32, mode: NeighborMode) -> Result<Vec<u32>, String> {
        // Validate mode for graph type and dispatch to optimized methods
        match (self, mode) {
            // DAG: only in, out, all (no undirected, bidirected, or partial)
            (GraphView::Dag(g), NeighborMode::All) => Ok(g.neighbors_of(i).to_vec()),
            (GraphView::Dag(g), NeighborMode::In) => Ok(g.parents_of(i).to_vec()),
            (GraphView::Dag(g), NeighborMode::Out) => Ok(g.children_of(i).to_vec()),
            (GraphView::Dag(_), NeighborMode::Undirected) => {
                Err("mode 'undirected' not valid for DAG (no undirected edges)".into())
            }
            (GraphView::Dag(_), NeighborMode::Bidirected) => {
                Err("mode 'bidirected' not valid for DAG (no bidirected edges)".into())
            }
            (GraphView::Dag(_), NeighborMode::Partial) => {
                Err("mode 'partial' not valid for DAG (no partial edges)".into())
            }

            // PDAG: in, out, undirected, all (no bidirected or partial)
            (GraphView::Pdag(g), NeighborMode::All) => Ok(g.neighbors_of(i).to_vec()),
            (GraphView::Pdag(g), NeighborMode::In) => Ok(g.parents_of(i).to_vec()),
            (GraphView::Pdag(g), NeighborMode::Out) => Ok(g.children_of(i).to_vec()),
            (GraphView::Pdag(g), NeighborMode::Undirected) => Ok(g.undirected_of(i).to_vec()),
            (GraphView::Pdag(_), NeighborMode::Bidirected) => {
                Err("mode 'bidirected' not valid for PDAG (no bidirected edges)".into())
            }
            (GraphView::Pdag(_), NeighborMode::Partial) => {
                Err("mode 'partial' not valid for PDAG (no partial edges)".into())
            }

            // UG: only undirected, all (no in, out, bidirected, or partial)
            (GraphView::Ug(g), NeighborMode::All) => Ok(g.neighbors_of(i).to_vec()),
            (GraphView::Ug(_), NeighborMode::In) => {
                Err("mode 'in' (parents) not defined for UG".into())
            }
            (GraphView::Ug(_), NeighborMode::Out) => {
                Err("mode 'out' (children) not defined for UG".into())
            }
            (GraphView::Ug(g), NeighborMode::Undirected) => Ok(g.neighbors_of(i).to_vec()),
            (GraphView::Ug(_), NeighborMode::Bidirected) => {
                Err("mode 'bidirected' not valid for UG (no bidirected edges)".into())
            }
            (GraphView::Ug(_), NeighborMode::Partial) => {
                Err("mode 'partial' not valid for UG (no partial edges)".into())
            }

            // ADMG: in, out, bidirected (spouses), all (no undirected or partial)
            (GraphView::Admg(g), NeighborMode::All) => Ok(g.neighbors_of(i).to_vec()),
            (GraphView::Admg(g), NeighborMode::In) => Ok(g.parents_of(i).to_vec()),
            (GraphView::Admg(g), NeighborMode::Out) => Ok(g.children_of(i).to_vec()),
            (GraphView::Admg(_), NeighborMode::Undirected) => {
                Err("mode 'undirected' not valid for ADMG (no undirected edges)".into())
            }
            (GraphView::Admg(g), NeighborMode::Bidirected) => Ok(g.spouses_of(i).to_vec()),
            (GraphView::Admg(_), NeighborMode::Partial) => {
                Err("mode 'partial' not valid for ADMG (no partial edges)".into())
            }

            // AG: in, out, undirected, bidirected, all (no partial edges)
            (GraphView::Ag(g), NeighborMode::All) => Ok(g.neighbors_of(i).to_vec()),
            (GraphView::Ag(g), NeighborMode::In) => Ok(g.parents_of(i).to_vec()),
            (GraphView::Ag(g), NeighborMode::Out) => Ok(g.children_of(i).to_vec()),
            (GraphView::Ag(g), NeighborMode::Undirected) => Ok(g.undirected_of(i).to_vec()),
            (GraphView::Ag(g), NeighborMode::Bidirected) => Ok(g.spouses_of(i).to_vec()),
            (GraphView::Ag(_), NeighborMode::Partial) => {
                Err("mode 'partial' not valid for AG (no partial edges)".into())
            }

            // Raw (UNKNOWN): all modes allowed, iterate CSR
            (GraphView::Raw(_), _) => self.neighbors_mode_of_raw(i, mode),
        }
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

                NeighborMode::In => {
                    // Ingoing: I have an Arrow mark (something points INTO me)
                    my_mark == Mark::Arrow
                }

                NeighborMode::Out => {
                    // Outgoing: neighbor has Arrow mark (something points INTO neighbor)
                    neighbor_mark == Mark::Arrow
                }

                NeighborMode::Undirected => {
                    // Undirected: both ends have Tail marks
                    spec.class == EdgeClass::Undirected
                }

                NeighborMode::Bidirected => {
                    // Bidirected: both ends have Arrow marks
                    spec.class == EdgeClass::Bidirected
                }

                NeighborMode::Partial => {
                    // Partial: I have Circle mark
                    my_mark == Mark::Circle
                }
            };

            if include {
                result.push(neighbor);
            }
        }

        Ok(result)
    }

    pub fn ancestors_of(&self, i: u32) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(g) => Ok(g.ancestors_of(i)),
            GraphView::Pdag(g) => Ok(g.ancestors_of(i)),
            GraphView::Admg(g) => Ok(g.ancestors_of(i)),
            GraphView::Ag(g) => Ok(g.ancestors_of(i)),
            GraphView::Ug(_) => Err("ancestors_of not defined for UG".into()),
            GraphView::Raw(_) => Err("ancestors_of not implemented for UNKNOWN class".into()),
        }
    }
    pub fn descendants_of(&self, i: u32) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(g) => Ok(g.descendants_of(i)),
            GraphView::Pdag(g) => Ok(g.descendants_of(i)),
            GraphView::Admg(g) => Ok(g.descendants_of(i)),
            GraphView::Ag(g) => Ok(g.descendants_of(i)),
            GraphView::Ug(_) => Err("descendants_of not defined for UG".into()),
            GraphView::Raw(_) => Err("descendants_of not implemented for UNKNOWN class".into()),
        }
    }
    pub fn anteriors_of(&self, i: u32) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(g) => Ok(g.anteriors_of(i)),
            GraphView::Pdag(g) => Ok(g.anteriors_of(i)),
            GraphView::Admg(_) => Err("anteriors_of not defined for ADMG".into()),
            GraphView::Ag(g) => Ok(g.anteriors_of(i)),
            GraphView::Ug(_) => Err("anteriors_of not defined for UG".into()),
            GraphView::Raw(_) => Err("anteriors_of not implemented for UNKNOWN class".into()),
        }
    }
    pub fn markov_blanket_of(&self, i: u32) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(g) => Ok(g.markov_blanket_of(i)),
            GraphView::Pdag(g) => Ok(g.markov_blanket_of(i)),
            GraphView::Ug(g) => Ok(g.markov_blanket_of(i)),
            GraphView::Admg(g) => Ok(g.markov_blanket_of(i)),
            GraphView::Ag(g) => Ok(g.markov_blanket_of(i)),
            GraphView::Raw(_) => Err("markov_blanket_of not implemented for UNKNOWN class".into()),
        }
    }
    pub fn exogenous_nodes(&self, undirected_as_parents: bool) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(g) => Ok(g.exogenous_nodes()),
            GraphView::Pdag(g) => Ok(g.exogenous_nodes(undirected_as_parents)),
            GraphView::Ug(g) => Ok(g.exogenous_nodes()),
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
            GraphView::Ug(_) => Err("topological_sort is only defined for DAGs".into()),
            GraphView::Ag(_) => Err("topological_sort is only defined for DAGs".into()),
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
            _ => Err("m_separated is only defined for ADMGs, AGs, and DAGs".into()),
        }
    }

    // ---- DAG-only methods ----
    pub fn d_separated(&self, xs: &[u32], ys: &[u32], z: &[u32]) -> Result<bool, String> {
        match self {
            GraphView::Dag(d) => Ok(d.d_separated(xs, ys, z)),
            _ => Err("d_separated is only defined for DAGs".into()),
        }
    }

    pub fn minimal_d_separator(
        &self,
        xs: &[u32],
        ys: &[u32],
        include: &[u32],
        restrict: &[u32],
    ) -> Result<Option<Vec<u32>>, String> {
        match self {
            GraphView::Dag(d) => d.minimal_d_separator(xs, ys, include, restrict),
            _ => Err("minimal_d_separator is only defined for DAGs".into()),
        }
    }

    pub fn adjustment_set_parents(&self, xs: &[u32], ys: &[u32]) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(d) => Ok(d.adjustment_set_parents(xs, ys)),
            _ => Err("adjustment_set_parents is only defined for DAGs".into()),
        }
    }
    pub fn adjustment_set_backdoor(&self, xs: &[u32], ys: &[u32]) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(d) => Ok(d.adjustment_set_backdoor(xs, ys)),
            _ => Err("adjustment_set_backdoor is only defined for DAGs".into()),
        }
    }
    pub fn adjustment_set_optimal(&self, x: u32, y: u32) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(d) => Ok(d.adjustment_set_optimal(x, y)),
            _ => Err("adjustment_set_optimal is only defined for DAGs".into()),
        }
    }
    pub fn is_valid_backdoor_set(&self, x: u32, y: u32, z: &[u32]) -> Result<bool, String> {
        match self {
            GraphView::Dag(d) => Ok(d.is_valid_backdoor_set(x, y, z)),
            _ => Err("is_valid_backdoor_set is only defined for DAGs".into()),
        }
    }
    pub fn all_backdoor_sets(
        &self,
        x: u32,
        y: u32,
        minimal: bool,
        max_size: u32,
    ) -> Result<Vec<Vec<u32>>, String> {
        match self {
            GraphView::Dag(d) => Ok(d.all_backdoor_sets(x, y, minimal, max_size)),
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
            GraphView::Raw(_) => GraphView::Raw(std::sync::Arc::new(core2)),
        };
        Ok(gv)
    }
}

impl GraphView {
    pub fn to_cpdag(&self) -> Result<GraphView, String> {
        match self {
            GraphView::Dag(d) => {
                let p = d.to_cpdag()?;
                Ok(GraphView::Pdag(std::sync::Arc::new(p)))
            }
            GraphView::Pdag(_) => Ok(self.clone()),
            _ => Err("to_cpdag is only defined for DAGs".into()),
        }
    }

    pub fn skeleton(&self) -> Result<GraphView, String> {
        match self {
            GraphView::Dag(d) => {
                let ug = d.skeleton()?;
                Ok(GraphView::Ug(Arc::new(ug)))
            }
            GraphView::Pdag(p) => {
                let ug = p.skeleton()?;
                Ok(GraphView::Ug(Arc::new(ug)))
            }
            _ => Err("skeleton is defined for DAGs and PDAGs only".into()),
        }
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
        let e = v_dag.undirected_of(0).unwrap_err();
        assert_eq!(
            e,
            "mode 'undirected' not valid for DAG (no undirected edges)"
        );
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

        // Raw view only supports neighbors_of and neighbors_mode_of
        // The semantic wrappers (parents_of, children_of, etc.) should error for UNKNOWN graphs
        let v_raw = GraphView::Raw(pdag_core);
        assert_eq!(v_raw.n(), 4);

        // Semantic wrappers should error for UNKNOWN graphs
        assert!(v_raw.parents_of(1).is_err());
        assert!(v_raw.children_of(0).is_err());
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
        assert_eq!(v.adjustment_set_optimal(1, 2).unwrap(), vec![0]);

        // backdoor validity + enumeration
        assert_eq!(v.is_valid_backdoor_set(1, 2, &[0]).unwrap(), true);
        assert_eq!(v.is_valid_backdoor_set(1, 2, &[]).unwrap(), false);
        assert_eq!(v.all_backdoor_sets(1, 2, true, 5).unwrap(), vec![vec![0]]);
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
            vp.adjustment_set_optimal(0, 1).unwrap_err(),
            "adjustment_set_optimal is only defined for DAGs"
        );
        assert_eq!(
            vr.adjustment_set_optimal(0, 1).unwrap_err(),
            "adjustment_set_optimal is only defined for DAGs"
        );

        // is_valid_backdoor_set
        assert_eq!(
            vp.is_valid_backdoor_set(0, 1, &[]).unwrap_err(),
            "is_valid_backdoor_set is only defined for DAGs"
        );
        assert_eq!(
            vr.is_valid_backdoor_set(0, 1, &[]).unwrap_err(),
            "is_valid_backdoor_set is only defined for DAGs"
        );

        // all_backdoor_sets
        assert_eq!(
            vp.all_backdoor_sets(0, 1, true, 5).unwrap_err(),
            "all_backdoor_sets is only defined for DAGs"
        );
        assert_eq!(
            vr.all_backdoor_sets(0, 1, true, 5).unwrap_err(),
            "all_backdoor_sets is only defined for DAGs"
        );
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
        match pbg {
            GraphView::Dag(ref d) => {
                // Y should only have L as parent
                assert_eq!(d.parents_of(2), &[0]);
                // A and Y should NOT be d-separated without conditioning
                // (backdoor path A <- L -> Y remains)
                assert!(!d.d_separated(&[1], &[2], &[]));
            }
            _ => panic!("Expected DAG"),
        }
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
        match moral {
            GraphView::Ug(ref u) => {
                assert_eq!(u.n(), 3);
                // L should be adjacent to A (parent of A)
                // L should be adjacent to Y (parent of Y)
                // A should be adjacent to Y (A->Y in original, also married via Y)
                let mut l_nb = u.neighbors_of(0).to_vec();
                l_nb.sort();
                assert_eq!(l_nb, vec![1, 2]);
            }
            _ => panic!("Expected UG"),
        }
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
        match reduced {
            GraphView::Dag(ref d) => {
                assert_eq!(d.n(), 3); // nodes {0,1,2}
            }
            _ => panic!("Expected DAG"),
        }
    }

    #[test]
    fn graphview_skeleton_from_dag_and_pdag_and_errors() {
        use crate::graph::ug::Ug;
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
        let ug = match v_dag.skeleton().unwrap() {
            GraphView::Ug(g) => g,
            _ => panic!("expected UG"),
        };
        assert_eq!(ug.neighbors_of(0), &[1]);
        assert_eq!(ug.neighbors_of(1), &[0, 2]);
        assert_eq!(ug.neighbors_of(2), &[1]);

        // PDAG: 0->1, 1--2  ⇒ skeleton neighbors {0:[1], 1:[0,2], 2:[1]}
        let mut bp = GraphBuilder::new_with_registry(3, true, &r);
        bp.add_edge(0, 1, d).unwrap();
        bp.add_edge(1, 2, u).unwrap();
        let v_pdag = GraphView::Pdag(Arc::new(
            Pdag::new(Arc::new(bp.finalize().unwrap())).unwrap(),
        ));
        let ug2 = match v_pdag.skeleton().unwrap() {
            GraphView::Ug(g) => g,
            _ => panic!("expected UG"),
        };
        assert_eq!(ug2.neighbors_of(0), &[1]);
        assert_eq!(ug2.neighbors_of(1), &[0, 2]);
        assert_eq!(ug2.neighbors_of(2), &[1]);

        // UG: calling skeleton() must error
        let mut bu = GraphBuilder::new_with_registry(2, true, &r);
        bu.add_edge(0, 1, u).unwrap();
        let v_ug = GraphView::Ug(Arc::new(Ug::new(Arc::new(bu.finalize().unwrap())).unwrap()));
        assert_eq!(
            v_ug.skeleton().unwrap_err(),
            "skeleton is defined for DAGs and PDAGs only"
        );
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
        let ug = match v_dag.moralize().unwrap() {
            GraphView::Ug(g) => g,
            _ => panic!("expected UG"),
        };
        assert_eq!(ug.neighbors_of(0), &[1, 2]);
        assert_eq!(ug.neighbors_of(1), &[0, 2]);
        assert_eq!(ug.neighbors_of(2), &[0, 1]);

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
        assert!(v.neighbors_of(0, NeighborMode::Undirected).is_err());
        assert!(v.neighbors_of(0, NeighborMode::Partial).is_err());

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
        assert!(v.neighbors_of(1, NeighborMode::Partial).is_err());
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

        // Graph: 0 -> 1, 1 --- 2, 1 <-> 3, 1 o-> 4, 1 o-o 5
        // Edge marks:
        // 0 -> 1: tail at 0, arrow at 1
        // 1 --- 2: tail at 1, tail at 2
        // 1 <-> 3: arrow at 1, arrow at 3
        // 1 o-> 4: circle at 1, arrow at 4
        // 1 o-o 5: circle at 1, circle at 5
        let mut b = GraphBuilder::new_with_registry(6, false, &r);
        b.add_edge(0, 1, d).unwrap(); // 0 -> 1
        b.add_edge(1, 2, u).unwrap(); // 1 --- 2
        b.add_edge(1, 3, bi).unwrap(); // 1 <-> 3
        b.add_edge(1, 4, po).unwrap(); // 1 o-> 4
        b.add_edge(1, 5, oo).unwrap(); // 1 o-o 5
        let core = Arc::new(b.finalize().unwrap());
        let v = GraphView::Raw(core);

        // Node 1 neighbors:
        // - All: 0, 2, 3, 4, 5
        let all = v.neighbors_of(1, NeighborMode::All).unwrap();
        assert_eq!(all.len(), 5);
        assert!(all.contains(&0));
        assert!(all.contains(&2));
        assert!(all.contains(&3));
        assert!(all.contains(&4));
        assert!(all.contains(&5));

        // - In: node 1 has Arrow mark in edges 0->1 (arrow at 1) and 1<->3 (arrow at 1)
        let in_neigh = v.neighbors_of(1, NeighborMode::In).unwrap();
        assert_eq!(in_neigh.len(), 2);
        assert!(in_neigh.contains(&0)); // 0 -> 1
        assert!(in_neigh.contains(&3)); // 1 <-> 3 (arrow at both ends)

        // - Out: neighbor has Arrow mark in edges 1<->3 (arrow at 3) and 1o->4 (arrow at 4)
        let out_neigh = v.neighbors_of(1, NeighborMode::Out).unwrap();
        assert_eq!(out_neigh.len(), 2);
        assert!(out_neigh.contains(&3)); // 1 <-> 3 (arrow at 3)
        assert!(out_neigh.contains(&4)); // 1 o-> 4 (arrow at 4)

        // - Undirected: node 1 has Tail mark in edge 1---2
        let und_neigh = v.neighbors_of(1, NeighborMode::Undirected).unwrap();
        assert_eq!(und_neigh, vec![2]);

        // - Bidirected: both node 1 AND neighbor have Arrow marks (only 1<->3)
        let bi_neigh = v.neighbors_of(1, NeighborMode::Bidirected).unwrap();
        assert_eq!(bi_neigh, vec![3]);

        // - Partial: node 1 has Circle mark in edges 1o->4 and 1o-o5
        let part_neigh = v.neighbors_of(1, NeighborMode::Partial).unwrap();
        assert_eq!(part_neigh.len(), 2);
        assert!(part_neigh.contains(&4));
        assert!(part_neigh.contains(&5));

        // Now test from node 4's perspective (4 is at head of 1 o-> 4)
        // 4 has Arrow mark, 1 has Circle mark
        assert_eq!(v.neighbors_of(4, NeighborMode::In).unwrap(), vec![1]); // arrow at 4, so 1 goes IN
        assert!(v.neighbors_of(4, NeighborMode::Out).unwrap().is_empty()); // no arrow at 1
        assert!(v.neighbors_of(4, NeighborMode::Partial).unwrap().is_empty()); // no circle at 4
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
        assert!(v.neighbors_of(1, NeighborMode::In).is_err());
        assert!(v.neighbors_of(1, NeighborMode::Out).is_err());
        assert!(v.neighbors_of(1, NeighborMode::Partial).is_err());

        // Check error messages
        let e_in = v.neighbors_of(1, NeighborMode::In).unwrap_err();
        assert!(e_in.contains("not defined for UG"));
        let e_out = v.neighbors_of(1, NeighborMode::Out).unwrap_err();
        assert!(e_out.contains("not defined for UG"));
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
        assert!(v.neighbors_of(1, NeighborMode::Undirected).is_err());
        assert!(v.neighbors_of(1, NeighborMode::Partial).is_err());
        let e_und = v.neighbors_of(1, NeighborMode::Undirected).unwrap_err();
        let e_part = v.neighbors_of(1, NeighborMode::Partial).unwrap_err();
        assert!(e_und.contains("not valid for ADMG"));
        assert!(e_part.contains("not valid for ADMG"));

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
        assert!(v.neighbors_of(0, NeighborMode::Partial).is_err());
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
        assert!(v.undirected_of(1).is_err());

        // spouses_of should error for DAG
        assert!(v.spouses_of(1).is_err());
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
        assert!(v.spouses_of(1).is_err());
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
        assert!(v.parents_of(1).is_err());
        assert!(v.children_of(1).is_err());

        // spouses_of should error for UG
        assert!(v.spouses_of(1).is_err());
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
        assert!(v.undirected_of(1).is_err());

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

        // For UNKNOWN graphs, semantic wrappers should error
        assert!(v.parents_of(1).is_err());
        assert!(v.children_of(1).is_err());
        assert!(v.undirected_of(1).is_err());
        assert!(v.bidirected_of(1).is_err());
        assert!(v.spouses_of(1).is_err());

        // But neighbors_of works with explicit mode
        let all = v.neighbors_of(1, NeighborMode::All).unwrap();
        assert_eq!(all.len(), 3);
        assert!(all.contains(&0));
        assert!(all.contains(&2));
        assert!(all.contains(&3));

        // neighbors_of allows explicit mode selection
        let in_neigh = v.neighbors_of(1, NeighborMode::In).unwrap();
        assert_eq!(in_neigh.len(), 2);
        assert!(in_neigh.contains(&0)); // 0 -> 1
        assert!(in_neigh.contains(&3)); // 1 <-> 3 (arrow at 1)

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
        assert_eq!(v.neighbors_of(0, NeighborMode::Out).unwrap(), vec![1]); // B has Arrow (pointing in)
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
        assert_eq!(v.neighbors_of(1, NeighborMode::In).unwrap(), vec![0]); // B has Arrow (pointing in)
        assert!(v.neighbors_of(1, NeighborMode::Out).unwrap().is_empty()); // A has no Arrow
        assert!(v
            .neighbors_of(1, NeighborMode::Undirected)
            .unwrap()
            .is_empty()); // B has no Tail
        assert!(v
            .neighbors_of(1, NeighborMode::Bidirected)
            .unwrap()
            .is_empty()); // Not both Arrow
        assert!(v.neighbors_of(1, NeighborMode::Partial).unwrap().is_empty()); // B has no Circle
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
        assert!(v.neighbors_of(0, NeighborMode::Partial).unwrap().is_empty()); // A has no Circle

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

        // Test partial mode: returns neighbors where current node has Circle mark
        // Node 0: position 0 in o-o, so my_mark = Circle -> returns 1
        assert_eq!(v.neighbors_of(0, NeighborMode::Partial).unwrap(), vec![1]);

        // Node 1: position 1 in o-o (Circle) and position 0 in o-> (Circle)
        let p1 = v.neighbors_of(1, NeighborMode::Partial).unwrap();
        assert_eq!(p1.len(), 2);
        assert!(p1.contains(&0)); // from o-o (Circle at position 1)
        assert!(p1.contains(&2)); // from o-> (Circle at position 0)

        // Node 2: position 1 in o-> (Arrow) and position 0 in --o (Tail)
        // Neither has Circle, so partial is empty for node 2
        assert!(v.neighbors_of(2, NeighborMode::Partial).unwrap().is_empty());

        // Node 3: position 1 in --o (Circle) -> returns 2
        assert_eq!(v.neighbors_of(3, NeighborMode::Partial).unwrap(), vec![2]);

        // In mode: returns neighbors where current node has Arrow mark
        // Node 2: position 1 in o-> (Arrow) -> returns 1
        assert_eq!(v.neighbors_of(2, NeighborMode::In).unwrap(), vec![1]);
        assert!(v.neighbors_of(1, NeighborMode::In).unwrap().is_empty()); // no Arrow at node 1

        // Out mode: returns neighbors where neighbor has Arrow mark
        // Node 1: neighbor 2 has Arrow (from o->) -> returns 2
        assert_eq!(v.neighbors_of(1, NeighborMode::Out).unwrap(), vec![2]);
        assert!(v.neighbors_of(2, NeighborMode::Out).unwrap().is_empty()); // neighbor 3 has Circle, not Arrow

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
    fn neighbors_mode_of_dag_bidirected_error() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();

        let mut b = GraphBuilder::new_with_registry(2, true, &r);
        b.add_edge(0, 1, d).unwrap();
        let v = GraphView::Dag(Arc::new(Dag::new(Arc::new(b.finalize().unwrap())).unwrap()));

        // DAG doesn't have bidirected edges - should error
        assert!(v.neighbors_of(0, NeighborMode::Bidirected).is_err());
        let e = v.neighbors_of(0, NeighborMode::Bidirected).unwrap_err();
        assert!(e.contains("not valid for DAG"));
    }

    #[test]
    fn neighbors_mode_of_pdag_bidirected_error() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let u = r.code_of("---").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, u).unwrap();
        let v = GraphView::Pdag(Arc::new(
            Pdag::new(Arc::new(b.finalize().unwrap())).unwrap(),
        ));

        // PDAG doesn't have bidirected edges - should error
        assert!(v.neighbors_of(0, NeighborMode::Bidirected).is_err());
        let e = v.neighbors_of(0, NeighborMode::Bidirected).unwrap_err();
        assert!(e.contains("not valid for PDAG"));
    }

    #[test]
    fn neighbors_mode_of_ug_bidirected_error() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let u = r.code_of("---").unwrap();

        let mut b = GraphBuilder::new_with_registry(2, true, &r);
        b.add_edge(0, 1, u).unwrap();
        let v = GraphView::Ug(Arc::new(Ug::new(Arc::new(b.finalize().unwrap())).unwrap()));

        // UG doesn't have bidirected edges - should error
        assert!(v.neighbors_of(0, NeighborMode::Bidirected).is_err());
        let e = v.neighbors_of(0, NeighborMode::Bidirected).unwrap_err();
        assert!(e.contains("not valid for UG"));
    }

    #[test]
    fn neighbors_mode_of_admg_undirected_error() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let bi = r.code_of("<->").unwrap();

        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, bi).unwrap();
        let v = GraphView::Admg(Arc::new(
            Admg::new(Arc::new(b.finalize().unwrap())).unwrap(),
        ));

        // ADMG doesn't have undirected edges - should error
        assert!(v.neighbors_of(1, NeighborMode::Undirected).is_err());
        let e = v.neighbors_of(1, NeighborMode::Undirected).unwrap_err();
        assert!(e.contains("not valid for ADMG"));
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
