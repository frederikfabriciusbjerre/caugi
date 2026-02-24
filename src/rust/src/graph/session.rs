// SPDX-License-Identifier: MIT
//! GraphSession: Canonical mutable state object with reactive computation.
//!
//! This module provides a single source of truth for graph state, implementing:
//! - Lazy compilation of CSR core and typed views
//! - Automatic invalidation on mutation
//! - On-demand query computation (no caching)

use super::admg::Admg;
use super::ag::Ag;
use super::builder::GraphBuilder;
use super::dag::Dag;
use super::pdag::Pdag;
use super::ug::Ug;
use super::view::GraphView;
use super::CaugiGraph;
use super::RegistrySnapshot;
use crate::edges::{EdgeRegistry, EdgeSpec};
use crate::graph::NeighborMode;
use std::collections::HashMap;
use std::sync::Arc;

/// The target graph class for typed view construction.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GraphClass {
    /// Directed Acyclic Graph (only `-->`)
    Dag,
    /// Partially Directed Acyclic Graph (`-->`, `---`)
    Pdag,
    /// Undirected Graph (only `---`)
    Ug,
    /// Acyclic Directed Mixed Graph (`-->`, `<->`)
    Admg,
    /// Ancestral Graph (`-->`, `<->`, `---`)
    Ag,
    /// Unknown/Raw (no validation)
    Unknown,
    /// Auto - no validation, will be resolved when edges are added
    Auto,
}

impl std::str::FromStr for GraphClass {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "dag" => Ok(GraphClass::Dag),
            "pdag" | "cpdag" => Ok(GraphClass::Pdag),
            "ug" => Ok(GraphClass::Ug),
            "admg" => Ok(GraphClass::Admg),
            "ag" | "mag" | "pag" => Ok(GraphClass::Ag),
            "unknown" | "raw" => Ok(GraphClass::Unknown),
            "auto" => Ok(GraphClass::Auto),
            _ => Err(format!("Unknown graph class: '{}'", s)),
        }
    }
}

impl GraphClass {
    pub fn as_str(&self) -> &'static str {
        match self {
            GraphClass::Dag => "DAG",
            GraphClass::Pdag => "PDAG",
            GraphClass::Ug => "UG",
            GraphClass::Admg => "ADMG",
            GraphClass::Ag => "AG",
            GraphClass::Unknown => "UNKNOWN",
            GraphClass::Auto => "AUTO",
        }
    }
}

/// Compact buffer for storing edges before CSR compilation.
#[derive(Debug, Clone, Default)]
pub struct EdgeBuffer {
    /// Source node indices (0-based)
    pub from: Vec<u32>,
    /// Target node indices (0-based)
    pub to: Vec<u32>,
    /// Edge type codes
    pub etype: Vec<u8>,
}

impl EdgeBuffer {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn with_capacity(capacity: usize) -> Self {
        Self {
            from: Vec::with_capacity(capacity),
            to: Vec::with_capacity(capacity),
            etype: Vec::with_capacity(capacity),
        }
    }

    pub fn push(&mut self, from: u32, to: u32, etype: u8) {
        self.from.push(from);
        self.to.push(to);
        self.etype.push(etype);
    }

    pub fn len(&self) -> usize {
        self.from.len()
    }

    pub fn is_empty(&self) -> bool {
        self.from.is_empty()
    }

    pub fn clear(&mut self) {
        self.from.clear();
        self.to.clear();
        self.etype.clear();
    }
}

/// Canonical graph session containing mutable state and computed values.
///
/// # Design
///
/// The session holds:
/// - **Variables**: Mutable inputs (n, simple, class, registry, edges, names)
/// - **Declarations**: Lazily computed outputs (core, view)
/// - **Queries**: Computed on demand without caching
///
/// # Invalidation Rules
///
/// - `edges`, `n`, `simple`, `registry` change → invalidate `core` → invalidate `view`
/// - `class` change → invalidate `view` only
/// - `names` change → no invalidation (names are metadata)
pub struct GraphSession {
    // ═══════════════════════════════════════════════════════════════════════════
    // VARIABLES (mutable inputs)
    // ═══════════════════════════════════════════════════════════════════════════
    n: u32,
    simple: bool,
    graph_class: GraphClass,
    registry: Arc<RegistrySnapshot>,
    edges: EdgeBuffer,
    names: Vec<String>,
    /// Maps node names to their 0-based indices for fast lookup.
    name_to_index: HashMap<String, u32>,

    // ═══════════════════════════════════════════════════════════════════════════
    // VALIDITY FLAGS
    // ═══════════════════════════════════════════════════════════════════════════
    core_valid: bool,
    view_valid: bool,

    // ═══════════════════════════════════════════════════════════════════════════
    // DECLARATIONS (computed values)
    // ═══════════════════════════════════════════════════════════════════════════
    core: Option<Arc<CaugiGraph>>,
    view: Option<Arc<GraphView>>,
}

impl GraphSession {
    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a new session with the given registry and initial parameters.
    pub fn new(registry: &EdgeRegistry, n: u32, simple: bool, class: GraphClass) -> Self {
        let specs: Arc<[EdgeSpec]> = (0..registry.len() as u8)
            .map(|c| registry.spec_of_code(c).unwrap().clone())
            .collect::<Vec<_>>()
            .into();
        // Use registry length as a version indicator
        let snapshot = Arc::new(RegistrySnapshot::from_specs(specs, registry.len() as u32));

        let names: Vec<String> = (0..n).map(|i| format!("{}", i)).collect();
        let name_to_index = Self::build_name_to_index(&names);

        Self {
            n,
            simple,
            graph_class: class,
            registry: snapshot,
            edges: EdgeBuffer::new(),
            names,
            name_to_index,

            core_valid: false,
            view_valid: false,

            core: None,
            view: None,
        }
    }

    /// Create a new session from an existing registry snapshot.
    pub fn from_snapshot(
        registry: Arc<RegistrySnapshot>,
        n: u32,
        simple: bool,
        class: GraphClass,
    ) -> Self {
        let names: Vec<String> = (0..n).map(|i| format!("{}", i)).collect();
        let name_to_index = Self::build_name_to_index(&names);

        Self {
            n,
            simple,
            graph_class: class,
            registry,
            edges: EdgeBuffer::new(),
            names,
            name_to_index,

            core_valid: false,
            view_valid: false,

            core: None,
            view: None,
        }
    }

    /// Clone for R's copy-on-write semantics.
    ///
    /// Creates a deep copy with all declarations invalidated.
    /// The registry is shared (Arc clone) for efficiency.
    pub fn clone_for_cow(&self) -> Self {
        Self {
            n: self.n,
            simple: self.simple,
            graph_class: self.graph_class,
            registry: Arc::clone(&self.registry),
            edges: self.edges.clone(),
            names: self.names.clone(),
            name_to_index: self.name_to_index.clone(),

            // Invalidate all declarations in the clone
            core_valid: false,
            view_valid: false,
            core: None,
            view: None,
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INVALIDATION
    // ═══════════════════════════════════════════════════════════════════════════

    fn invalidate_core(&mut self) {
        self.core_valid = false;
        self.core = None;
        self.invalidate_view();
    }

    fn invalidate_view(&mut self) {
        self.view_valid = false;
        self.view = None;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MUTATION API
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn set_n(&mut self, n: u32) {
        if self.n != n {
            self.n = n;
            self.invalidate_core();
        }
    }

    pub fn set_simple(&mut self, simple: bool) {
        if self.simple != simple {
            self.simple = simple;
            self.invalidate_core();
        }
    }

    pub fn set_edges(&mut self, edges: EdgeBuffer) {
        self.edges = edges;
        self.invalidate_core();
    }

    pub fn set_edges_from_vecs(&mut self, from: Vec<u32>, to: Vec<u32>, etype: Vec<u8>) {
        self.edges = EdgeBuffer { from, to, etype };
        self.invalidate_core();
    }

    pub fn set_class(&mut self, class: GraphClass) {
        if self.graph_class != class {
            self.graph_class = class;
            self.invalidate_view(); // Only view, not core
        }
    }

    pub fn set_names(&mut self, names: Vec<String>) {
        self.name_to_index = Self::build_name_to_index(&names);
        self.names = names;
        // No invalidation - names are metadata
    }

    pub fn set_registry(&mut self, registry: Arc<RegistrySnapshot>) {
        self.registry = registry;
        self.invalidate_core();
    }

    /// Batch update (single invalidation pass).
    pub fn replace_spec(
        &mut self,
        n: u32,
        simple: bool,
        class: GraphClass,
        registry: Arc<RegistrySnapshot>,
        edges: EdgeBuffer,
        names: Vec<String>,
    ) {
        self.n = n;
        self.simple = simple;
        self.graph_class = class;
        self.registry = registry;
        self.edges = edges;
        self.name_to_index = Self::build_name_to_index(&names);
        self.names = names;
        self.invalidate_core();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BUILD HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    fn build_core(&self) -> Result<CaugiGraph, String> {
        let mut builder =
            GraphBuilder::new_from_snapshot(self.n, self.simple, Arc::clone(&self.registry));

        for i in 0..self.edges.len() {
            builder
                .add_edge(self.edges.from[i], self.edges.to[i], self.edges.etype[i])
                .map_err(|e| self.map_error(e))?;
        }

        builder.finalize().map_err(|e| self.map_error(e))
    }

    fn build_view(&self, core: Arc<CaugiGraph>) -> Result<GraphView, String> {
        match self.graph_class {
            GraphClass::Dag => {
                let dag = Dag::new(core).map_err(|e| self.map_error(e))?;
                Ok(GraphView::Dag(Arc::new(dag)))
            }
            GraphClass::Pdag => {
                let pdag = Pdag::new(core).map_err(|e| self.map_error(e))?;
                Ok(GraphView::Pdag(Arc::new(pdag)))
            }
            GraphClass::Ug => {
                let ug = Ug::new(core).map_err(|e| self.map_error(e))?;
                Ok(GraphView::Ug(Arc::new(ug)))
            }
            GraphClass::Admg => {
                let admg = Admg::new(core).map_err(|e| self.map_error(e))?;
                Ok(GraphView::Admg(Arc::new(admg)))
            }
            GraphClass::Ag => {
                let ag = Ag::new(core).map_err(|e| self.map_error(e))?;
                Ok(GraphView::Ag(Arc::new(ag)))
            }
            GraphClass::Unknown | GraphClass::Auto => Ok(GraphView::Raw(core)),
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ACCESSOR API
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get the compiled CSR core, building if necessary.
    pub fn core(&mut self) -> Result<Arc<CaugiGraph>, String> {
        if !self.core_valid {
            let built = self.build_core()?;
            self.core = Some(Arc::new(built));
            self.core_valid = true;
        }
        Ok(Arc::clone(
            self.core
                .as_ref()
                .expect("core must be Some when core_valid is true"),
        ))
    }

    /// Get the typed view, building if necessary.
    pub fn view(&mut self) -> Result<Arc<GraphView>, String> {
        if !self.view_valid {
            let core = self.core()?;
            let built = self.build_view(core)?;
            self.view = Some(Arc::new(built));
            self.view_valid = true;
        }
        Ok(Arc::clone(
            self.view
                .as_ref()
                .expect("view must be Some when view_valid is true"),
        ))
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // QUERY API
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get topological sort.
    pub fn topological_sort(&mut self) -> Result<Vec<u32>, String> {
        let view = self.view()?;
        view.topological_sort().map_err(|e| self.map_error(e))
    }

    /// Get parents of a node.
    pub fn parents_of(&mut self, node: u32) -> Result<Vec<u32>, String> {
        let view = self.view()?;
        view.parents_of(node).map_err(|e| self.map_error(e))
    }

    /// Get children of a node.
    pub fn children_of(&mut self, node: u32) -> Result<Vec<u32>, String> {
        let view = self.view()?;
        view.children_of(node).map_err(|e| self.map_error(e))
    }

    /// Get undirected neighbors of a node.
    pub fn undirected_of(&mut self, node: u32) -> Result<Vec<u32>, String> {
        let view = self.view()?;
        view.undirected_of(node).map_err(|e| self.map_error(e))
    }

    /// Get neighbors of a node by mode.
    pub fn neighbors_of(&mut self, node: u32, mode: NeighborMode) -> Result<Vec<u32>, String> {
        let view = self.view()?;
        view.neighbors_of(node, mode).map_err(|e| self.map_error(e))
    }

    /// Get ancestors of a node.
    pub fn ancestors_of(&mut self, node: u32) -> Result<Vec<u32>, String> {
        let view = self.view()?;
        view.ancestors_of(node).map_err(|e| self.map_error(e))
    }

    /// Get descendants of a node.
    pub fn descendants_of(&mut self, node: u32) -> Result<Vec<u32>, String> {
        let view = self.view()?;
        view.descendants_of(node).map_err(|e| self.map_error(e))
    }

    /// Get anteriors of a node.
    pub fn anteriors_of(&mut self, node: u32) -> Result<Vec<u32>, String> {
        let view = self.view()?;
        view.anteriors_of(node).map_err(|e| self.map_error(e))
    }

    /// Get Markov blanket of a node.
    pub fn markov_blanket_of(&mut self, node: u32) -> Result<Vec<u32>, String> {
        let view = self.view()?;
        view.markov_blanket_of(node).map_err(|e| self.map_error(e))
    }

    /// Get districts (ADMG only).
    pub fn districts(&mut self) -> Result<Vec<Vec<u32>>, String> {
        let view = self.view()?;
        view.districts().map_err(|e| self.map_error(e))
    }

    /// Get district of a node (ADMG/AG only).
    pub fn district_of(&mut self, node: u32) -> Result<Vec<u32>, String> {
        let view = self.view()?;
        view.district_of(node).map_err(|e| self.map_error(e))
    }

    /// Get spouses of a node (ADMG/AG bidirected neighbors).
    pub fn spouses_of(&mut self, node: u32) -> Result<Vec<u32>, String> {
        let view = self.view()?;
        view.spouses_of(node).map_err(|e| self.map_error(e))
    }

    /// Get exogenous nodes.
    /// The `undirected_as_parents` flag determines whether undirected edges count as parent edges.
    pub fn exogenous_nodes(&mut self, undirected_as_parents: bool) -> Result<Vec<u32>, String> {
        let view = self.view()?;
        view.exogenous_nodes(undirected_as_parents)
            .map_err(|e| self.map_error(e))
    }

    /// Check whether the directed part is acyclic.
    pub fn is_acyclic(&mut self) -> Result<bool, String> {
        let core = self.core()?;
        Ok(crate::graph::alg::directed_part_is_acyclic(core.as_ref()))
    }

    /// Check if the graph is compatible with DAG.
    pub fn is_dag_type(&mut self) -> Result<bool, String> {
        let core = self.core()?;
        Ok(Dag::new(Arc::new(core.as_ref().clone())).is_ok())
    }

    /// Check if the graph is compatible with PDAG.
    pub fn is_pdag_type(&mut self) -> Result<bool, String> {
        let core = self.core()?;
        Ok(Pdag::new(Arc::new(core.as_ref().clone())).is_ok())
    }

    /// Check if the graph is compatible with UG.
    pub fn is_ug_type(&mut self) -> Result<bool, String> {
        let core = self.core()?;
        Ok(Ug::new(Arc::new(core.as_ref().clone())).is_ok())
    }

    /// Check if the graph is compatible with ADMG.
    pub fn is_admg_type(&mut self) -> Result<bool, String> {
        let core = self.core()?;
        Ok(Admg::new(Arc::new(core.as_ref().clone())).is_ok())
    }

    /// Check if the graph is compatible with AG.
    pub fn is_ag_type(&mut self) -> Result<bool, String> {
        let core = self.core()?;
        Ok(Ag::new(Arc::new(core.as_ref().clone())).is_ok())
    }

    /// Check if the graph is a CPDAG (PDAG-only).
    pub fn is_cpdag(&mut self) -> Result<bool, String> {
        let core = self.core()?;
        match Pdag::new(Arc::new(core.as_ref().clone())) {
            Ok(p) => Ok(p.is_cpdag()),
            Err(_) => Ok(false),
        }
    }

    /// Check if the graph is a MAG (AG only).
    pub fn is_mag(&mut self) -> Result<bool, String> {
        let core = self.core()?;
        match Ag::new(Arc::new(core.as_ref().clone())) {
            Ok(ag) => Ok(ag.is_mag()),
            Err(_) => Ok(false),
        }
    }

    /// Resolve a graph class given the current edges/core.
    pub fn resolve_class(&mut self, class: GraphClass) -> Result<GraphClass, String> {
        let core = self.core()?;
        match class {
            GraphClass::Dag => {
                Dag::new(Arc::new(core.as_ref().clone())).map_err(|e| self.map_error(e))?;
                Ok(GraphClass::Dag)
            }
            GraphClass::Pdag => {
                Pdag::new(Arc::new(core.as_ref().clone())).map_err(|e| self.map_error(e))?;
                Ok(GraphClass::Pdag)
            }
            GraphClass::Ug => {
                Ug::new(Arc::new(core.as_ref().clone())).map_err(|e| self.map_error(e))?;
                Ok(GraphClass::Ug)
            }
            GraphClass::Admg => {
                Admg::new(Arc::new(core.as_ref().clone())).map_err(|e| self.map_error(e))?;
                Ok(GraphClass::Admg)
            }
            GraphClass::Ag => {
                Ag::new(Arc::new(core.as_ref().clone())).map_err(|e| self.map_error(e))?;
                Ok(GraphClass::Ag)
            }
            GraphClass::Unknown => Ok(GraphClass::Unknown),
            GraphClass::Auto => {
                if Dag::new(Arc::new(core.as_ref().clone())).is_ok() {
                    Ok(GraphClass::Dag)
                } else if Ug::new(Arc::new(core.as_ref().clone())).is_ok() {
                    Ok(GraphClass::Ug)
                } else if Pdag::new(Arc::new(core.as_ref().clone())).is_ok() {
                    Ok(GraphClass::Pdag)
                } else if Admg::new(Arc::new(core.as_ref().clone())).is_ok() {
                    Ok(GraphClass::Admg)
                } else if Ag::new(Arc::new(core.as_ref().clone())).is_ok() {
                    Ok(GraphClass::Ag)
                } else {
                    Ok(GraphClass::Unknown)
                }
            }
        }
    }

    /// Convert DAG to CPDAG (DAG only).
    pub fn to_cpdag(&mut self) -> Result<GraphView, String> {
        let view = self.view()?;
        view.to_cpdag().map_err(|e| self.map_error(e))
    }

    /// Skeleton of the graph.
    pub fn skeleton(&mut self) -> Result<GraphView, String> {
        let view = self.view()?;
        view.skeleton().map_err(|e| self.map_error(e))
    }

    /// Moralized version of the graph (DAG only).
    pub fn moralize(&mut self) -> Result<GraphView, String> {
        let view = self.view()?;
        view.moralize().map_err(|e| self.map_error(e))
    }

    /// Latent projection (DAG only).
    pub fn latent_project(&mut self, latents: &[u32]) -> Result<GraphView, String> {
        let view = self.view()?;
        view.latent_project(latents).map_err(|e| self.map_error(e))
    }

    /// D-separation query (DAG only).
    pub fn d_separated(&mut self, xs: &[u32], ys: &[u32], z: &[u32]) -> Result<bool, String> {
        let view = self.view()?;
        view.d_separated(xs, ys, z).map_err(|e| self.map_error(e))
    }

    /// Minimal d-separator computation (DAG only).
    pub fn minimal_d_separator(
        &mut self,
        xs: &[u32],
        ys: &[u32],
        include: &[u32],
        restrict: &[u32],
    ) -> Result<Option<Vec<u32>>, String> {
        let view = self.view()?;
        view.minimal_d_separator(xs, ys, include, restrict)
            .map_err(|e| self.map_error(e))
    }

    /// M-separation query (ADMG/AG/DAG).
    pub fn m_separated(&mut self, xs: &[u32], ys: &[u32], z: &[u32]) -> Result<bool, String> {
        let view = self.view()?;
        view.m_separated(xs, ys, z).map_err(|e| self.map_error(e))
    }

    /// Adjustment set: parents.
    pub fn adjustment_set_parents(&mut self, xs: &[u32], ys: &[u32]) -> Result<Vec<u32>, String> {
        let view = self.view()?;
        view.adjustment_set_parents(xs, ys)
            .map_err(|e| self.map_error(e))
    }

    /// Adjustment set: backdoor.
    pub fn adjustment_set_backdoor(&mut self, xs: &[u32], ys: &[u32]) -> Result<Vec<u32>, String> {
        let view = self.view()?;
        view.adjustment_set_backdoor(xs, ys)
            .map_err(|e| self.map_error(e))
    }

    /// Adjustment set: optimal.
    pub fn adjustment_set_optimal(&mut self, xs: &[u32], ys: &[u32]) -> Result<Vec<u32>, String> {
        if xs.len() != 1 || ys.len() != 1 {
            return Err("adjustment_set_optimal expects exactly one X and one Y".into());
        }
        let view = self.view()?;
        view.adjustment_set_optimal(xs[0], ys[0])
            .map_err(|e| self.map_error(e))
    }

    /// Validate a backdoor set.
    pub fn is_valid_backdoor_set(
        &mut self,
        xs: &[u32],
        ys: &[u32],
        z: &[u32],
    ) -> Result<bool, String> {
        if xs.len() != 1 || ys.len() != 1 {
            return Err("is_valid_backdoor_set expects exactly one X and one Y".into());
        }
        let view = self.view()?;
        view.is_valid_backdoor_set(xs[0], ys[0], z)
            .map_err(|e| self.map_error(e))
    }

    /// Enumerate all backdoor sets.
    pub fn all_backdoor_sets(
        &mut self,
        xs: &[u32],
        ys: &[u32],
        minimal: bool,
        max_size: u32,
    ) -> Result<Vec<Vec<u32>>, String> {
        if xs.len() != 1 || ys.len() != 1 {
            return Err("all_backdoor_sets expects exactly one X and one Y".into());
        }
        let view = self.view()?;
        view.all_backdoor_sets(xs[0], ys[0], minimal, max_size)
            .map_err(|e| self.map_error(e))
    }

    /// Validate adjustment set for ADMG/AG.
    pub fn is_valid_adjustment_set_admg(
        &mut self,
        xs: &[u32],
        ys: &[u32],
        z: &[u32],
    ) -> Result<bool, String> {
        let view = self.view()?;
        view.is_valid_adjustment_set_admg(xs, ys, z)
            .map_err(|e| self.map_error(e))
    }

    /// Enumerate all adjustment sets for ADMG/AG.
    pub fn all_adjustment_sets_admg(
        &mut self,
        xs: &[u32],
        ys: &[u32],
        minimal: bool,
        max_size: u32,
    ) -> Result<Vec<Vec<u32>>, String> {
        let view = self.view()?;
        view.all_adjustment_sets_admg(xs, ys, minimal, max_size)
            .map_err(|e| self.map_error(e))
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INTROSPECTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get current number of nodes.
    pub fn n(&self) -> u32 {
        self.n
    }

    /// Get current graph class.
    pub fn class(&self) -> GraphClass {
        self.graph_class
    }

    /// Get whether the graph is declared as simple (no parallel edges or self-loops).
    pub fn simple(&self) -> bool {
        self.simple
    }

    /// Get current node names.
    pub fn names(&self) -> &[String] {
        &self.names
    }

    /// Build the name-to-index HashMap from a slice of names.
    fn build_name_to_index(names: &[String]) -> HashMap<String, u32> {
        names
            .iter()
            .enumerate()
            .map(|(i, name)| (name.clone(), i as u32))
            .collect()
    }

    /// Look up the 0-based index of a node by name.
    /// Returns `None` if the name is not found.
    pub fn index_of(&self, name: &str) -> Option<u32> {
        self.name_to_index.get(name).copied()
    }

    /// Look up the 0-based indices of multiple nodes by name.
    /// Returns an error if any name is not found.
    pub fn indices_of(&self, names: &[String]) -> Result<Vec<u32>, String> {
        let mut result = Vec::with_capacity(names.len());
        for name in names {
            match self.name_to_index.get(name) {
                Some(&idx) => result.push(idx),
                None => return Err(format!("Non-existent node name: {}", name)),
            }
        }
        Ok(result)
    }

    fn format_index(&self, idx: u32) -> String {
        if let Some(name) = self.names.get(idx as usize) {
            name.clone()
        } else {
            idx.to_string()
        }
    }

    fn map_error(&self, err: String) -> String {
        self.map_error_str(&err).unwrap_or(err)
    }

    fn map_error_str(&self, err: &str) -> Option<String> {
        if let Some(rest) = err.strip_prefix("Node index ") {
            let parts: Vec<&str> = rest.split(" out of bounds (max: ").collect();
            if parts.len() == 2 {
                let idx: u32 = parts[0].parse().ok()?;
                let max: u32 = parts[1].trim_end_matches(')').parse().ok()?;
                return Some(format!(
                    "Node {} out of bounds (max: {})",
                    self.format_index(idx),
                    self.format_index(max)
                ));
            }
        }

        if let Some(rest) = err.strip_prefix("Node ") {
            let parts: Vec<&str> = rest.split(" out of range (max: ").collect();
            if parts.len() == 2 {
                let idx: u32 = parts[0].parse().ok()?;
                let max: u32 = parts[1].trim_end_matches(')').parse().ok()?;
                return Some(format!(
                    "Node {} out of range (max: {})",
                    self.format_index(idx),
                    self.format_index(max)
                ));
            }
        }

        if let Some(rest) = err.strip_prefix("Self-loops not allowed in simple graphs (node ") {
            let idx: u32 = rest.trim_end_matches(')').parse().ok()?;
            return Some(format!(
                "Self-loops not allowed in simple graphs (node {})",
                self.format_index(idx)
            ));
        }

        if let Some(rest) = err.strip_prefix("Parallel edges not allowed in simple graphs (") {
            let parts: Vec<&str> = rest.trim_end_matches(')').split(" -> ").collect();
            if parts.len() == 2 {
                let from: u32 = parts[0].parse().ok()?;
                let to: u32 = parts[1].parse().ok()?;
                return Some(format!(
                    "Parallel edges not allowed in simple graphs ({} -> {})",
                    self.format_index(from),
                    self.format_index(to)
                ));
            }
        }

        if let Some(rest) = err.strip_prefix("Duplicate edge ") {
            let parts: Vec<&str> = rest.split(" -> ").collect();
            if parts.len() == 2 {
                let from: u32 = parts[0].parse().ok()?;
                let tail = parts[1];
                let parts2: Vec<&str> = tail.split(" (type ").collect();
                if parts2.len() == 2 {
                    let to: u32 = parts2[0].parse().ok()?;
                    let edge_type = parts2[1].trim_end_matches(')');
                    return Some(format!(
                        "Duplicate edge {} -> {} (type {})",
                        self.format_index(from),
                        self.format_index(to),
                        edge_type
                    ));
                }
            }
        }

        if let Some(rest) = err.strip_prefix("Anterior constraint violated: node ") {
            let parts: Vec<&str> = rest.split(" has arrowhead from ").collect();
            if parts.len() == 2 {
                let target: u32 = parts[0].parse().ok()?;
                let parts2: Vec<&str> = parts[1].split(" but is an anterior of ").collect();
                if parts2.len() == 2 {
                    let source: u32 = parts2[0].parse().ok()?;
                    let source2: u32 = parts2[1].parse().ok()?;
                    return Some(format!(
                        "Anterior constraint violated: node {} has arrowhead from {} but is an anterior of {}",
                        self.format_index(target),
                        self.format_index(source),
                        self.format_index(source2)
                    ));
                }
            }
        }

        if let Some(rest) = err.strip_prefix("Undirected constraint violated: node ") {
            let idx: u32 = rest
                .trim_end_matches(" has both undirected and arrowhead edges")
                .parse()
                .ok()?;
            return Some(format!(
                "Undirected constraint violated: node {} has both undirected and arrowhead edges",
                self.format_index(idx)
            ));
        }

        if let Some(rest) = err.strip_prefix("Index ") {
            let idx: u32 = rest.trim_end_matches(" is out of bounds").parse().ok()?;
            return Some(format!("Node {} is out of bounds", self.format_index(idx)));
        }

        if let Some(rest) = err.strip_prefix("node id ") {
            let idx: u32 = rest.trim_end_matches(" out of bounds").parse().ok()?;
            return Some(format!("node id {} out of bounds", self.format_index(idx)));
        }

        None
    }

    /// Get the registry snapshot.
    pub fn registry(&self) -> &Arc<RegistrySnapshot> {
        &self.registry
    }

    /// Get the edge buffer (preserves original input order).
    pub fn edge_buffer(&self) -> &EdgeBuffer {
        &self.edges
    }

    /// Check if the core is currently valid.
    pub fn is_core_valid(&self) -> bool {
        self.core_valid
    }

    /// Check if the view is currently valid.
    pub fn is_view_valid(&self) -> bool {
        self.view_valid
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;

    fn make_session() -> GraphSession {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        GraphSession::new(&reg, 3, true, GraphClass::Dag)
    }

    #[test]
    fn session_new_and_accessors() {
        let session = make_session();
        assert_eq!(session.n(), 3);
        assert_eq!(session.class(), GraphClass::Dag);
        assert!(!session.is_core_valid());
        assert!(!session.is_view_valid());
    }

    #[test]
    fn session_lazy_build() {
        let mut session = make_session();

        // Initially invalid
        assert!(!session.is_core_valid());

        // Access core triggers build
        let core = session.core().unwrap();
        assert!(session.is_core_valid());
        assert_eq!(core.n(), 3);

        // Access view triggers view build
        let view = session.view().unwrap();
        assert!(session.is_view_valid());
        assert_eq!(view.n(), 3);
    }

    #[test]
    fn session_mutation_invalidates() {
        let mut session = make_session();

        // Build
        session.core().unwrap();
        session.view().unwrap();
        assert!(session.is_core_valid());
        assert!(session.is_view_valid());

        // Mutate edges -> invalidates core and view
        session.set_edges(EdgeBuffer::new());
        assert!(!session.is_core_valid());
        assert!(!session.is_view_valid());

        // Rebuild
        session.view().unwrap();
        assert!(session.is_view_valid());

        // Change class -> only invalidates view
        session.set_class(GraphClass::Unknown);
        assert!(session.is_core_valid()); // Core still valid!
        assert!(!session.is_view_valid());
    }

    #[test]
    fn session_names_no_invalidation() {
        let mut session = make_session();
        session.view().unwrap();
        assert!(session.is_view_valid());

        session.set_names(vec!["A".into(), "B".into(), "C".into()]);
        assert!(session.is_view_valid()); // Still valid!
        assert_eq!(session.names(), &["A", "B", "C"]);
    }

    #[test]
    fn session_clone_for_cow() {
        let mut session = make_session();
        session.view().unwrap();
        assert!(session.is_view_valid());

        let cloned = session.clone_for_cow();
        assert!(!cloned.is_core_valid());
        assert!(!cloned.is_view_valid());
        assert_eq!(cloned.n(), session.n());
    }

    #[test]
    fn session_index_of() {
        let mut session = make_session();
        session.set_names(vec!["A".into(), "B".into(), "C".into()]);

        assert_eq!(session.index_of("A"), Some(0));
        assert_eq!(session.index_of("B"), Some(1));
        assert_eq!(session.index_of("C"), Some(2));
        assert_eq!(session.index_of("D"), None);
    }

    #[test]
    fn session_indices_of() {
        let mut session = make_session();
        session.set_names(vec!["A".into(), "B".into(), "C".into()]);

        let indices = session.indices_of(&["A".into(), "C".into()]).unwrap();
        assert_eq!(indices, vec![0, 2]);

        let err = session.indices_of(&["A".into(), "D".into()]);
        assert!(err.is_err());
        assert!(err.unwrap_err().contains("Non-existent node name: D"));
    }

    #[test]
    fn session_name_index_updated_on_set_names() {
        let mut session = make_session();

        // Initially has default names "0", "1", "2"
        assert_eq!(session.index_of("0"), Some(0));
        assert_eq!(session.index_of("A"), None);

        // Update names
        session.set_names(vec!["X".into(), "Y".into(), "Z".into()]);

        // Old names should be gone
        assert_eq!(session.index_of("0"), None);

        // New names should work
        assert_eq!(session.index_of("X"), Some(0));
        assert_eq!(session.index_of("Y"), Some(1));
        assert_eq!(session.index_of("Z"), Some(2));
    }
}
