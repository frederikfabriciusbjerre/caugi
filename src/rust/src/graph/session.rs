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
use rustc_hash::FxHashSet;
use std::collections::HashMap;
use std::sync::Arc;

/// The target graph class for typed view construction.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GraphClass {
    /// Directed Acyclic Graph (only `-->`)
    Dag,
    /// Partially Directed Acyclic Graph (`-->`, `---`)
    Pdag,
    /// Maximally Oriented Partially Directed Acyclic Graph (Meek-closed PDAG)
    Mpdag,
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
            "mpdag" => Ok(GraphClass::Mpdag),
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
            GraphClass::Mpdag => "MPDAG",
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
/// - **Queries**: Computed on demand (no query-level caching)
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
    /// When true, edges are known to be valid (e.g., subset of an already-valid
    /// graph) and `build_core` can skip per-edge validation.
    edges_trusted: bool,

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
            edges_trusted: false,

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
            edges_trusted: false,

            core: None,
            view: None,
        }
    }

    /// Create a new session from an existing registry snapshot plus full data.
    /// Edges are marked as trusted (skipping validation on build).
    pub fn from_snapshot_with_data(
        registry: Arc<RegistrySnapshot>,
        simple: bool,
        class: GraphClass,
        edges: EdgeBuffer,
        names: Vec<String>,
    ) -> Self {
        let n = names.len() as u32;
        let name_to_index = Self::build_name_to_index(&names);
        Self {
            n,
            simple,
            graph_class: class,
            registry,
            edges,
            names,
            name_to_index,
            core_valid: false,
            view_valid: false,
            edges_trusted: true,
            core: None,
            view: None,
        }
    }

    /// Create a session with a pre-built CSR core (e.g., from CSR-based subgraph extraction).
    /// The edge buffer is reconstructed from the CSR so future mutations are possible.
    pub fn from_prebuilt_core(
        registry: Arc<RegistrySnapshot>,
        simple: bool,
        class: GraphClass,
        core: CaugiGraph,
        names: Vec<String>,
    ) -> Self {
        // Reconstruct edge buffer from CSR: collect tail-side half-edges only
        // (each undirected edge has both a tail and head half; we only want one copy).
        let n = core.n();
        let mut edges = EdgeBuffer::new();
        for u in 0..n {
            for k in core.row_range(u) {
                if core.side[k] == 0 {
                    // side 0 = Tail position → this node is the source
                    edges.push(u, core.col_index[k], core.etype[k]);
                }
            }
        }

        let name_to_index = Self::build_name_to_index(&names);
        Self {
            n,
            simple,
            graph_class: class,
            registry,
            edges,
            names,
            name_to_index,
            core_valid: true,
            view_valid: false,
            edges_trusted: true,
            core: Some(Arc::new(core)),
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
            edges_trusted: self.edges_trusted,
            core: None,
            view: None,
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INVALIDATION
    // ═══════════════════════════════════════════════════════════════════════════

    fn invalidate_core(&mut self) {
        self.core_valid = false;
        self.edges_trusted = false;
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

    pub fn replace_edges_for_pairs(&mut self, new_edges: EdgeBuffer) {
        let mut remove_pairs: FxHashSet<(u32, u32)> =
            FxHashSet::with_capacity_and_hasher(new_edges.len(), Default::default());
        if self.simple {
            for i in 0..new_edges.len() {
                let u = new_edges.from[i];
                let v = new_edges.to[i];
                let pair = if u <= v { (u, v) } else { (v, u) };
                remove_pairs.insert(pair);
            }
        } else {
            for i in 0..new_edges.len() {
                remove_pairs.insert((new_edges.from[i], new_edges.to[i]));
            }
        }

        let mut kept = EdgeBuffer::with_capacity(self.edges.len() + new_edges.len());
        let mut seen: FxHashSet<(u32, u32, u8)> = FxHashSet::with_capacity_and_hasher(
            self.edges.len() + new_edges.len(),
            Default::default(),
        );

        for i in 0..self.edges.len() {
            let u = self.edges.from[i];
            let v = self.edges.to[i];
            let t = self.edges.etype[i];
            let remove = if self.simple {
                let pair = if u <= v { (u, v) } else { (v, u) };
                remove_pairs.contains(&pair)
            } else {
                remove_pairs.contains(&(u, v))
            };
            if !remove && seen.insert((u, v, t)) {
                kept.push(u, v, t);
            }
        }

        for i in 0..new_edges.len() {
            let u = new_edges.from[i];
            let v = new_edges.to[i];
            let t = new_edges.etype[i];
            if seen.insert((u, v, t)) {
                kept.push(u, v, t);
            }
        }

        self.edges = kept;
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
        if self.edges_trusted {
            return GraphBuilder::build_from_edge_buffer(
                self.n,
                self.simple,
                &self.edges,
                Arc::clone(&self.registry),
            );
        }

        let mut builder = GraphBuilder::new_from_snapshot_with_capacity(
            self.n,
            self.simple,
            Arc::clone(&self.registry),
            self.edges.len(),
        );

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
            GraphClass::Mpdag => {
                let pdag = Pdag::new(core).map_err(|e| self.map_error(e))?;
                if pdag.is_meek_closed() {
                    Ok(GraphView::Pdag(Arc::new(pdag)))
                } else {
                    Err("graph is not MPDAG (not closed under Meek rules)".to_string())
                }
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

    /// Get posteriors of a node.
    pub fn posteriors_of(&mut self, node: u32) -> Result<Vec<u32>, String> {
        let view = self.view()?;
        view.posteriors_of(node).map_err(|e| self.map_error(e))
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

    /// Check if the graph is an MPDAG (PDAG + Meek closure).
    pub fn is_mpdag(&mut self) -> Result<bool, String> {
        let core = self.core()?;
        match Pdag::new(Arc::new(core.as_ref().clone())) {
            Ok(p) => Ok(p.is_meek_closed()),
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
            GraphClass::Mpdag => {
                let pdag =
                    Pdag::new(Arc::new(core.as_ref().clone())).map_err(|e| self.map_error(e))?;
                if pdag.is_meek_closed() {
                    Ok(GraphClass::Mpdag)
                } else {
                    Err("graph is not MPDAG (not closed under Meek rules)".to_string())
                }
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
                } else if let Ok(pdag) = Pdag::new(Arc::new(core.as_ref().clone())) {
                    if pdag.is_meek_closed() {
                        Ok(GraphClass::Mpdag)
                    } else {
                        Ok(GraphClass::Pdag)
                    }
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

    /// Apply Meek closure to a PDAG.
    pub fn meek_closure(&mut self) -> Result<GraphView, String> {
        let core = self.core()?;
        let pdag = Pdag::new(Arc::new(core.as_ref().clone())).map_err(|e| self.map_error(e))?;
        let closed = pdag.meek_closure().map_err(|e| self.map_error(e))?;
        Ok(GraphView::Pdag(Arc::new(closed)))
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

    /// Exogenize a set of nodes (DAG only).
    pub fn exogenize(&mut self, nodes: &[u32]) -> Result<GraphView, String> {
        let view = self.view()?;
        view.exogenize(nodes).map_err(|e| self.map_error(e))
    }

    /// Normalize latent structure (DAG only).
    pub fn normalize_latent_structure(
        &mut self,
        latents: &[u32],
    ) -> Result<(GraphView, Vec<u32>), String> {
        let view = self.view()?;
        view.normalize_latent_structure(latents)
            .map_err(|e| self.map_error(e))
    }

    /// D-separation query (DAG only).
    pub fn d_separated(&mut self, xs: &[u32], ys: &[u32], z: &[u32]) -> Result<bool, String> {
        let view = self.view()?;
        view.d_separated(xs, ys, z).map_err(|e| self.map_error(e))
    }

    /// Minimal separator computation (DAG / ADMG / AG).
    pub fn minimal_separator(
        &mut self,
        xs: &[u32],
        ys: &[u32],
        include: &[u32],
        restrict: &[u32],
    ) -> Result<Option<Vec<u32>>, String> {
        let view = self.view()?;
        view.minimal_separator(xs, ys, include, restrict)
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
    use crate::graph::NeighborMode;
    use crate::graph::RegistrySnapshot;
    use std::sync::Arc;

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

    fn make_registry() -> EdgeRegistry {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        reg
    }

    fn snapshot_from_registry(reg: &EdgeRegistry) -> Arc<RegistrySnapshot> {
        let specs: Arc<[crate::edges::EdgeSpec]> = (0..reg.len() as u8)
            .map(|c| reg.spec_of_code(c).unwrap().clone())
            .collect::<Vec<_>>()
            .into();
        Arc::new(RegistrySnapshot::from_specs(specs, reg.len() as u32))
    }

    fn sorted(mut v: Vec<u32>) -> Vec<u32> {
        v.sort_unstable();
        v
    }

    #[test]
    fn graph_class_from_str_and_as_str() {
        assert_eq!("dag".parse::<GraphClass>().unwrap(), GraphClass::Dag);
        assert_eq!("CPDAG".parse::<GraphClass>().unwrap(), GraphClass::Pdag);
        assert_eq!("mpdag".parse::<GraphClass>().unwrap(), GraphClass::Mpdag);
        assert_eq!("ug".parse::<GraphClass>().unwrap(), GraphClass::Ug);
        assert_eq!("admg".parse::<GraphClass>().unwrap(), GraphClass::Admg);
        assert_eq!("mag".parse::<GraphClass>().unwrap(), GraphClass::Ag);
        assert_eq!("raw".parse::<GraphClass>().unwrap(), GraphClass::Unknown);
        assert_eq!("auto".parse::<GraphClass>().unwrap(), GraphClass::Auto);
        assert!("not-a-class".parse::<GraphClass>().is_err());

        assert_eq!(GraphClass::Dag.as_str(), "DAG");
        assert_eq!(GraphClass::Pdag.as_str(), "PDAG");
        assert_eq!(GraphClass::Mpdag.as_str(), "MPDAG");
        assert_eq!(GraphClass::Ug.as_str(), "UG");
        assert_eq!(GraphClass::Admg.as_str(), "ADMG");
        assert_eq!(GraphClass::Ag.as_str(), "AG");
        assert_eq!(GraphClass::Unknown.as_str(), "UNKNOWN");
        assert_eq!(GraphClass::Auto.as_str(), "AUTO");
    }

    #[test]
    fn edge_buffer_helpers_cover_basic_mutations() {
        let mut buf = EdgeBuffer::new();
        assert!(buf.is_empty());
        buf.push(0, 1, 2);
        assert_eq!(buf.len(), 1);
        assert!(!buf.is_empty());
        buf.clear();
        assert!(buf.is_empty());

        let mut buf2 = EdgeBuffer::with_capacity(2);
        buf2.push(1, 2, 3);
        assert_eq!(buf2.from, vec![1]);
        assert_eq!(buf2.to, vec![2]);
        assert_eq!(buf2.etype, vec![3]);
    }

    #[test]
    fn session_setters_and_replace_spec_update_state_and_invalidate() {
        let reg = make_registry();
        let mut session = GraphSession::new(&reg, 3, true, GraphClass::Dag);
        let d = reg.code_of("-->").unwrap();

        let mut edges = EdgeBuffer::new();
        edges.push(0, 1, d);
        session.set_edges(edges);
        session.core().unwrap();
        session.view().unwrap();
        assert!(session.is_core_valid());
        assert!(session.is_view_valid());

        session.set_n(3);
        assert!(session.is_core_valid());
        assert!(session.is_view_valid());

        session.set_n(4);
        assert_eq!(session.n(), 4);
        assert!(!session.is_core_valid());
        assert!(!session.is_view_valid());

        session.core().unwrap();
        session.view().unwrap();
        session.set_simple(true);
        assert!(session.is_core_valid());
        assert!(session.is_view_valid());

        session.set_simple(false);
        assert!(!session.is_core_valid());
        assert!(!session.is_view_valid());
        assert!(!session.simple());

        session.set_edges_from_vecs(vec![0], vec![1], vec![d]);
        assert_eq!(session.edge_buffer().from, vec![0]);
        assert_eq!(session.edge_buffer().to, vec![1]);
        assert_eq!(session.edge_buffer().etype, vec![d]);

        let snap = snapshot_from_registry(&reg);
        session.set_registry(Arc::clone(&snap));
        assert_eq!(session.registry().version, snap.version);
        assert!(!session.is_core_valid());

        let mut new_edges = EdgeBuffer::new();
        new_edges.push(0, 2, d);
        session.replace_spec(
            3,
            true,
            GraphClass::Unknown,
            Arc::clone(&snap),
            new_edges,
            vec!["A".into(), "B".into(), "C".into()],
        );
        assert_eq!(session.n(), 3);
        assert!(session.simple());
        assert_eq!(session.class(), GraphClass::Unknown);
        assert_eq!(session.names(), &["A", "B", "C"]);
        assert_eq!(session.edge_buffer().from, vec![0]);
        assert_eq!(session.edge_buffer().to, vec![2]);
        assert_eq!(session.edge_buffer().etype, vec![d]);
        assert!(!session.is_core_valid());
        assert!(!session.is_view_valid());
    }

    #[test]
    fn replace_edges_for_pairs_handles_simple_vs_non_simple() {
        let reg = make_registry();
        let d = reg.code_of("-->").unwrap();
        let u = reg.code_of("---").unwrap();

        let mut simple = GraphSession::new(&reg, 3, true, GraphClass::Unknown);
        let mut old = EdgeBuffer::new();
        old.push(0, 1, d);
        old.push(1, 0, d);
        old.push(1, 2, d);
        simple.set_edges(old);

        let mut repl = EdgeBuffer::new();
        repl.push(1, 0, u);
        repl.push(1, 0, u); // duplicate in replacement input
        simple.replace_edges_for_pairs(repl);
        assert_eq!(simple.edge_buffer().from, vec![1, 1]);
        assert_eq!(simple.edge_buffer().to, vec![2, 0]);
        assert_eq!(simple.edge_buffer().etype, vec![d, u]);

        let mut non_simple = GraphSession::new(&reg, 3, false, GraphClass::Unknown);
        let mut old2 = EdgeBuffer::new();
        old2.push(0, 1, d);
        old2.push(1, 0, d);
        old2.push(0, 1, d); // duplicate to exercise dedup
        non_simple.set_edges(old2);

        let mut repl2 = EdgeBuffer::new();
        repl2.push(0, 1, u);
        non_simple.replace_edges_for_pairs(repl2);
        assert_eq!(non_simple.edge_buffer().from, vec![1, 0]);
        assert_eq!(non_simple.edge_buffer().to, vec![0, 1]);
        assert_eq!(non_simple.edge_buffer().etype, vec![d, u]);
    }

    #[test]
    fn session_query_and_transform_paths_for_dag() {
        let reg = make_registry();
        let d = reg.code_of("-->").unwrap();
        let mut session = GraphSession::new(&reg, 4, true, GraphClass::Dag);
        let mut edges = EdgeBuffer::new();
        edges.push(0, 1, d);
        edges.push(1, 2, d);
        edges.push(2, 3, d);
        edges.push(0, 2, d);
        session.set_edges(edges);

        assert_eq!(session.topological_sort().unwrap(), vec![0, 1, 2, 3]);
        assert_eq!(sorted(session.parents_of(2).unwrap()), vec![0, 1]);
        assert_eq!(sorted(session.children_of(0).unwrap()), vec![1, 2]);
        assert_eq!(
            sorted(session.neighbors_of(1, NeighborMode::All).unwrap()),
            vec![0, 2]
        );
        assert!(session.undirected_of(1).is_err());
        assert_eq!(sorted(session.ancestors_of(3).unwrap()), vec![0, 1, 2]);
        assert_eq!(sorted(session.descendants_of(0).unwrap()), vec![1, 2, 3]);
        assert_eq!(sorted(session.anteriors_of(3).unwrap()), vec![0, 1, 2]);
        assert_eq!(sorted(session.posteriors_of(0).unwrap()), vec![1, 2, 3]);
        assert_eq!(sorted(session.markov_blanket_of(1).unwrap()), vec![0, 2]);
        assert_eq!(session.exogenous_nodes(false).unwrap(), vec![0]);
        assert!(session.is_acyclic().unwrap());
        assert!(session.is_dag_type().unwrap());
        assert!(session.is_pdag_type().unwrap());
        assert!(!session.is_ug_type().unwrap());
        assert!(session.is_admg_type().unwrap());
        assert!(session.is_ag_type().unwrap());
        let _ = session.is_cpdag().unwrap();
        let _ = session.is_mag().unwrap();
        assert_eq!(
            session.resolve_class(GraphClass::Auto).unwrap(),
            GraphClass::Dag
        );

        let to_cpdag = session.to_cpdag().unwrap();
        assert!(matches!(to_cpdag, GraphView::Pdag(_)));

        let skeleton = session.skeleton().unwrap();
        assert!(matches!(skeleton, GraphView::Ug(_)));

        let moralized = session.moralize().unwrap();
        assert!(matches!(moralized, GraphView::Ug(_)));

        let projected = session.latent_project(&[1]).unwrap();
        assert!(matches!(projected, GraphView::Admg(_)));
        assert_eq!(projected.n(), 3);

        assert!(!session.d_separated(&[0], &[3], &[]).unwrap());
        assert!(session.d_separated(&[0], &[3], &[2]).unwrap());
        assert_eq!(
            session
                .minimal_separator(&[0], &[3], &[], &[0, 1, 2, 3])
                .unwrap(),
            Some(vec![2])
        );
        assert!(session.m_separated(&[0], &[3], &[2]).unwrap());
    }

    #[test]
    fn session_adjustment_queries_and_guards() {
        let reg = make_registry();
        let d = reg.code_of("-->").unwrap();
        let mut session = GraphSession::new(&reg, 3, true, GraphClass::Dag);
        let mut edges = EdgeBuffer::new();
        edges.push(2, 0, d);
        edges.push(2, 1, d);
        session.set_edges(edges);

        let parents = session.adjustment_set_parents(&[0], &[1]).unwrap();
        assert!(parents.iter().all(|&z| z < 3 && z != 0 && z != 1));

        let backdoor = session.adjustment_set_backdoor(&[0], &[1]).unwrap();
        assert!(backdoor.iter().all(|&z| z < 3 && z != 0 && z != 1));

        let optimal = session.adjustment_set_optimal(&[0], &[1]).unwrap();
        assert!(optimal.iter().all(|&z| z < 3 && z != 0 && z != 1));

        assert!(session
            .is_valid_backdoor_set(&[0], &[1], &backdoor)
            .unwrap());
        let sets = session.all_backdoor_sets(&[0], &[1], true, 3).unwrap();
        assert!(sets
            .iter()
            .all(|set| set.iter().all(|&z| z < 3 && z != 0 && z != 1)));

        assert!(session.adjustment_set_optimal(&[0, 2], &[1]).is_err());
        assert!(session.is_valid_backdoor_set(&[0, 2], &[1], &[2]).is_err());
        assert!(session.all_backdoor_sets(&[0, 2], &[1], true, 3).is_err());
    }

    #[test]
    fn session_admg_specific_queries_and_resolve_auto_paths() {
        let reg = make_registry();
        let d = reg.code_of("-->").unwrap();
        let b = reg.code_of("<->").unwrap();
        let u = reg.code_of("---").unwrap();

        let mut admg = GraphSession::new(&reg, 3, true, GraphClass::Admg);
        let mut e = EdgeBuffer::new();
        e.push(0, 1, d);
        e.push(1, 2, b);
        admg.set_edges(e);

        let districts = admg.districts().unwrap();
        assert!(districts.iter().any(|d| d == &vec![1, 2]));
        assert_eq!(admg.district_of(1).unwrap(), vec![1, 2]);
        assert_eq!(admg.spouses_of(1).unwrap(), vec![2]);
        let _ = admg.is_valid_adjustment_set_admg(&[0], &[2], &[1]).unwrap();
        let _ = admg.all_adjustment_sets_admg(&[0], &[2], true, 2).unwrap();
        assert_eq!(
            admg.resolve_class(GraphClass::Auto).unwrap(),
            GraphClass::Admg
        );

        let mut ug = GraphSession::new(&reg, 2, true, GraphClass::Unknown);
        let mut e2 = EdgeBuffer::new();
        e2.push(0, 1, u);
        ug.set_edges(e2);
        assert_eq!(ug.resolve_class(GraphClass::Auto).unwrap(), GraphClass::Ug);
        assert!(ug.to_cpdag().is_err());
        assert!(ug.moralize().is_err());
        assert!(ug.latent_project(&[0]).is_err());
        assert!(ug.d_separated(&[0], &[1], &[]).is_err());
        assert!(ug.minimal_separator(&[0], &[1], &[], &[]).is_err());
        assert!(ug.adjustment_set_parents(&[0], &[1]).is_err());
        assert!(ug.adjustment_set_backdoor(&[0], &[1]).is_err());
        assert!(ug.adjustment_set_optimal(&[0], &[1]).is_err());
        assert!(ug.is_valid_backdoor_set(&[0], &[1], &[]).is_err());
        assert!(ug.all_backdoor_sets(&[0], &[1], true, 2).is_err());

        let mut cyclic = GraphSession::new(&reg, 2, false, GraphClass::Unknown);
        let mut e3 = EdgeBuffer::new();
        e3.push(0, 1, d);
        e3.push(1, 0, d);
        cyclic.set_edges(e3);
        assert_eq!(
            cyclic.resolve_class(GraphClass::Auto).unwrap(),
            GraphClass::Unknown
        );
    }

    #[test]
    fn session_from_snapshot_and_class_resolution_variants() {
        let reg = make_registry();
        let d = reg.code_of("-->").unwrap();
        let u = reg.code_of("---").unwrap();
        let b = reg.code_of("<->").unwrap();
        let snapshot = snapshot_from_registry(&reg);

        let mut pdag =
            GraphSession::from_snapshot(Arc::clone(&snapshot), 3, true, GraphClass::Pdag);
        let mut pdag_edges = EdgeBuffer::new();
        pdag_edges.push(0, 1, d);
        pdag_edges.push(1, 2, u);
        pdag.set_edges(pdag_edges);
        assert!(matches!(&*pdag.view().unwrap(), GraphView::Pdag(_)));
        assert_eq!(
            pdag.resolve_class(GraphClass::Pdag).unwrap(),
            GraphClass::Pdag
        );
        assert_eq!(
            pdag.resolve_class(GraphClass::Auto).unwrap(),
            GraphClass::Pdag
        );

        let mut mpdag =
            GraphSession::from_snapshot(Arc::clone(&snapshot), 3, true, GraphClass::Mpdag);
        let mut mpdag_edges = EdgeBuffer::new();
        mpdag_edges.push(0, 2, d);
        mpdag_edges.push(1, 2, d);
        mpdag.set_edges(mpdag_edges);
        assert!(matches!(&*mpdag.view().unwrap(), GraphView::Pdag(_)));
        assert_eq!(
            mpdag.resolve_class(GraphClass::Mpdag).unwrap(),
            GraphClass::Mpdag
        );
        assert_eq!(
            mpdag.resolve_class(GraphClass::Auto).unwrap(),
            // AUTO prioritizes DAG over (M)PDAG when both are valid.
            GraphClass::Dag
        );

        let mut ug = GraphSession::from_snapshot(Arc::clone(&snapshot), 2, true, GraphClass::Ug);
        let mut ug_edges = EdgeBuffer::new();
        ug_edges.push(0, 1, u);
        ug.set_edges(ug_edges);
        assert!(matches!(&*ug.view().unwrap(), GraphView::Ug(_)));
        assert_eq!(ug.resolve_class(GraphClass::Ug).unwrap(), GraphClass::Ug);

        let mut admg =
            GraphSession::from_snapshot(Arc::clone(&snapshot), 2, true, GraphClass::Admg);
        let mut admg_edges = EdgeBuffer::new();
        admg_edges.push(0, 1, b);
        admg.set_edges(admg_edges);
        assert!(matches!(&*admg.view().unwrap(), GraphView::Admg(_)));
        assert_eq!(
            admg.resolve_class(GraphClass::Admg).unwrap(),
            GraphClass::Admg
        );

        // AG valid, but not DAG/UG/PDAG/ADMG: mix undirected and bidirected on disjoint nodes
        let mut ag = GraphSession::from_snapshot(Arc::clone(&snapshot), 4, true, GraphClass::Ag);
        let mut ag_edges = EdgeBuffer::new();
        ag_edges.push(0, 1, u);
        ag_edges.push(2, 3, b);
        ag.set_edges(ag_edges);
        assert!(matches!(&*ag.view().unwrap(), GraphView::Ag(_)));
        assert_eq!(ag.resolve_class(GraphClass::Ag).unwrap(), GraphClass::Ag);
        assert_eq!(ag.resolve_class(GraphClass::Auto).unwrap(), GraphClass::Ag);

        let mut dag = GraphSession::from_snapshot(snapshot, 3, true, GraphClass::Dag);
        let mut dag_edges = EdgeBuffer::new();
        dag_edges.push(0, 1, d);
        dag_edges.push(1, 2, d);
        dag.set_edges(dag_edges);
        assert!(matches!(&*dag.view().unwrap(), GraphView::Dag(_)));
        assert_eq!(dag.resolve_class(GraphClass::Dag).unwrap(), GraphClass::Dag);
        assert_eq!(
            dag.resolve_class(GraphClass::Unknown).unwrap(),
            GraphClass::Unknown
        );

        // Invalid for PDAG/AG type checks should hit Err -> false paths
        let mut invalid = GraphSession::new(&reg, 2, false, GraphClass::Unknown);
        let mut invalid_edges = EdgeBuffer::new();
        invalid_edges.push(0, 1, d);
        invalid_edges.push(1, 0, d);
        invalid.set_edges(invalid_edges);
        assert!(!invalid.is_cpdag().unwrap());
        assert!(!invalid.is_mag().unwrap());
    }

    #[test]
    fn session_map_error_str_rewrites_indexed_messages_with_names() {
        let mut session = make_session();
        session.set_names(vec!["A".into(), "B".into(), "C".into()]);

        assert_eq!(
            session
                .map_error_str("Node index 1 out of bounds (max: 2)")
                .unwrap(),
            "Node B out of bounds (max: C)"
        );
        assert_eq!(
            session
                .map_error_str("Node 1 out of range (max: 2)")
                .unwrap(),
            "Node B out of range (max: C)"
        );
        assert_eq!(
            session
                .map_error_str("Self-loops not allowed in simple graphs (node 1)")
                .unwrap(),
            "Self-loops not allowed in simple graphs (node B)"
        );
        assert_eq!(
            session
                .map_error_str("Parallel edges not allowed in simple graphs (0 -> 1)")
                .unwrap(),
            "Parallel edges not allowed in simple graphs (A -> B)"
        );
        assert_eq!(
            session
                .map_error_str("Duplicate edge 0 -> 1 (type -->)")
                .unwrap(),
            "Duplicate edge A -> B (type -->)"
        );
        assert_eq!(
            session
                .map_error_str(
                    "Anterior constraint violated: node 1 has arrowhead from 0 but is an anterior of 2"
                )
                .unwrap(),
            "Anterior constraint violated: node B has arrowhead from A but is an anterior of C"
        );
        assert_eq!(
            session
                .map_error_str(
                    "Undirected constraint violated: node 1 has both undirected and arrowhead edges"
                )
                .unwrap(),
            "Undirected constraint violated: node B has both undirected and arrowhead edges"
        );
        assert_eq!(
            session.map_error_str("Index 1 is out of bounds").unwrap(),
            "Node B is out of bounds"
        );
        assert_eq!(
            session.map_error_str("node id 1 out of bounds").unwrap(),
            "node id B out of bounds"
        );
        assert!(session
            .map_error_str("Node index 1 out of bounds")
            .is_none());
        assert!(session.map_error_str("Node 1 out of range").is_none());
        assert!(session
            .map_error_str("Parallel edges not allowed in simple graphs (0->1)")
            .is_none());
        assert!(session.map_error_str("Duplicate edge 0 -> 1").is_none());
        assert!(session
            .map_error_str("Duplicate edge 0 -> 1 (kind -->)")
            .is_none());
        assert!(session
            .map_error_str("Duplicate edge 0=>1 (type -->)")
            .is_none());
        assert!(session
            .map_error_str("Anterior constraint violated: node 1 has arrowhead from 0")
            .is_none());
        assert!(session
            .map_error_str(
                "Anterior constraint violated: node 1 has arrowhead from 0 but is anterior of 2"
            )
            .is_none());
        assert!(session
            .map_error_str(
                "Anterior constraint violated: node 1 has arrowheadfrom 0 but is an anterior of 2"
            )
            .is_none());
        assert!(session.map_error_str("unmapped error").is_none());
    }

    #[test]
    fn session_map_error_is_used_for_builder_failures() {
        let reg = make_registry();
        let d = reg.code_of("-->").unwrap();
        let u = reg.code_of("---").unwrap();

        let mut self_loop = GraphSession::new(&reg, 2, true, GraphClass::Unknown);
        self_loop.set_names(vec!["A".into(), "B".into()]);
        let mut e1 = EdgeBuffer::new();
        e1.push(0, 0, d);
        self_loop.set_edges(e1);
        let err1 = self_loop.core().unwrap_err();
        assert!(err1.contains("Self-loops not allowed in simple graphs (node A)"));

        let mut parallel = GraphSession::new(&reg, 2, true, GraphClass::Unknown);
        parallel.set_names(vec!["A".into(), "B".into()]);
        let mut e2 = EdgeBuffer::new();
        e2.push(0, 1, d);
        e2.push(0, 1, u);
        parallel.set_edges(e2);
        let err2 = parallel.core().unwrap_err();
        assert!(err2.contains("Parallel edges not allowed in simple graphs (A -> B)"));

        let mut duplicate = GraphSession::new(&reg, 2, false, GraphClass::Unknown);
        duplicate.set_names(vec!["A".into(), "B".into()]);
        let mut e3 = EdgeBuffer::new();
        e3.push(0, 1, d);
        e3.push(0, 1, d);
        duplicate.set_edges(e3);
        let err3 = duplicate.core().unwrap_err();
        assert!(err3.contains("Duplicate edge A -> B (type"));

        let mut oob = GraphSession::new(&reg, 2, true, GraphClass::Unknown);
        oob.set_names(vec!["A".into(), "B".into()]);
        let mut e4 = EdgeBuffer::new();
        e4.push(0, 3, d);
        oob.set_edges(e4);
        let err4 = oob.core().unwrap_err();
        assert!(err4.contains("Node 3 out of range (max: B)"));
    }

    #[test]
    fn session_ag_queries() {
        let reg = make_registry();
        let d = reg.code_of("-->").unwrap();
        let b = reg.code_of("<->").unwrap();
        let u = reg.code_of("---").unwrap();

        // Build AG: 0 --> 1, 1 <-> 2 (no mixing undirected + arrowhead on same node)
        let mut ag = GraphSession::new(&reg, 4, true, GraphClass::Ag);
        let mut e = EdgeBuffer::new();
        e.push(0, 1, d);
        e.push(1, 2, b);
        e.push(0, 3, u); // node 3 has only undirected, node 0 has directed + undirected
        ag.set_edges(e);

        // anteriors_of and posteriors_of through session (AG supports these)
        let ant = ag.anteriors_of(1).unwrap();
        assert!(ant.contains(&0));
        let post = ag.posteriors_of(0).unwrap();
        assert!(post.contains(&1));

        // m_separated through AG
        let _ = ag.m_separated(&[0], &[2], &[1]).unwrap();

        // districts and district_of through AG
        let districts = ag.districts().unwrap();
        assert!(!districts.is_empty());
        let dist = ag.district_of(1).unwrap();
        assert!(dist.contains(&1));

        // spouses_of through AG
        let sp = ag.spouses_of(1).unwrap();
        assert!(sp.contains(&2));

        // exogenous_nodes through AG (both flags)
        let _exo = ag.exogenous_nodes(false).unwrap();
        // node 3 has only undirected neighbors, no parents
        let exo2 = ag.exogenous_nodes(true).unwrap();
        // With undirected_as_parents, nodes with undirected edges are not exogenous
        assert!(!exo2.contains(&3));

        // skeleton through AG errors
        assert!(ag.skeleton().is_err());

        // Test AG with only undirected edges for undirected_of
        let mut ag2 = GraphSession::new(&reg, 3, true, GraphClass::Ag);
        let mut e2 = EdgeBuffer::new();
        e2.push(0, 1, u);
        e2.push(1, 2, u);
        ag2.set_edges(e2);
        let und = ag2.undirected_of(1).unwrap();
        assert!(und.contains(&0) && und.contains(&2));
    }

    #[test]
    fn session_admg_m_separated_and_error_propagation() {
        let reg = make_registry();
        let d = reg.code_of("-->").unwrap();
        let b = reg.code_of("<->").unwrap();

        // Build ADMG: 0 --> 1 <-> 2
        let mut admg = GraphSession::new(&reg, 3, true, GraphClass::Admg);
        admg.set_names(vec!["X".into(), "Y".into(), "Z".into()]);
        let mut e = EdgeBuffer::new();
        e.push(0, 1, d);
        e.push(1, 2, b);
        admg.set_edges(e);

        // m_separated through ADMG session.
        // 0 --> 1 <-> 2 lifts to 0 -> 1, U -> 1, U -> 2; conditioning on the
        // collider 1 opens the path, so 0 is m-connected to 2 given {1}.
        assert!(!admg.m_separated(&[0], &[2], &[1]).unwrap());

        // anteriors_of errors on ADMG (not supported)
        let err = admg.anteriors_of(0).unwrap_err();
        assert!(err.contains("not defined for ADMG"));

        // posteriors_of errors on ADMG
        let err = admg.posteriors_of(0).unwrap_err();
        assert!(err.contains("not defined for ADMG"));

        // topological_sort errors on ADMG
        let err = admg.topological_sort().unwrap_err();
        assert!(err.contains("only defined for DAGs"));

        // exogenous_nodes through ADMG
        let exo = admg.exogenous_nodes(false).unwrap();
        assert!(exo.contains(&0));

        // is_acyclic through ADMG
        assert!(admg.is_acyclic().unwrap());
    }

    #[test]
    fn session_ug_queries_and_error_paths() {
        let reg = make_registry();
        let u = reg.code_of("---").unwrap();

        // Build UG: 0 --- 1 --- 2
        let mut ug = GraphSession::new(&reg, 3, true, GraphClass::Ug);
        ug.set_names(vec!["A".into(), "B".into(), "C".into()]);
        let mut e = EdgeBuffer::new();
        e.push(0, 1, u);
        e.push(1, 2, u);
        ug.set_edges(e);

        // undirected_of through UG
        let und = ug.undirected_of(1).unwrap();
        assert!(und.contains(&0) && und.contains(&2));

        // markov_blanket_of through UG
        let mb = ug.markov_blanket_of(0).unwrap();
        assert!(mb.contains(&1));

        // exogenous_nodes through UG
        let exo = ug.exogenous_nodes(false).unwrap();
        assert!(exo.is_empty()); // all nodes have undirected neighbors

        // Type checks through UG
        assert!(!ug.is_dag_type().unwrap());
        assert!(!ug.is_admg_type().unwrap());
        assert!(ug.is_ug_type().unwrap());
        assert!(ug.is_pdag_type().unwrap()); // UG edges are valid in PDAG
        assert!(ug.is_ag_type().unwrap()); // UG is valid AG

        // is_acyclic on UG (no directed edges, so acyclic)
        assert!(ug.is_acyclic().unwrap());

        // Error paths: districts on UG
        assert!(ug.districts().is_err());
        assert!(ug.district_of(0).is_err());

        // Error: spouses_of on UG (bidirected mode not valid)
        assert!(ug.spouses_of(0).is_err());

        // Error: ancestors_of on UG
        assert!(ug.ancestors_of(0).is_err());
        assert!(ug.descendants_of(0).is_err());
        assert!(ug.anteriors_of(0).is_err());
        assert!(ug.posteriors_of(0).is_err());
        assert!(ug.parents_of(0).is_err());
        assert!(ug.children_of(0).is_err());

        // m_separated on UG errors
        assert!(ug.m_separated(&[0], &[2], &[1]).is_err());

        // is_valid_adjustment_set_admg on UG errors
        assert!(ug.is_valid_adjustment_set_admg(&[0], &[2], &[1]).is_err());
        assert!(ug.all_adjustment_sets_admg(&[0], &[2], true, 2).is_err());
    }

    #[test]
    fn session_pdag_queries() {
        let reg = make_registry();
        let d = reg.code_of("-->").unwrap();
        let u = reg.code_of("---").unwrap();

        // Build PDAG: 0 --> 1 --- 2
        let mut pdag = GraphSession::new(&reg, 3, true, GraphClass::Pdag);
        let mut e = EdgeBuffer::new();
        e.push(0, 1, d);
        e.push(1, 2, u);
        pdag.set_edges(e);

        // skeleton through PDAG
        let skel = pdag.skeleton().unwrap();
        assert!(matches!(skel, GraphView::Ug(_)));

        // is_cpdag through a proper PDAG
        let is_cp = pdag.is_cpdag().unwrap();
        // Just verify it returns a bool without error
        let _ = is_cp;

        // exogenous_nodes through PDAG
        let exo = pdag.exogenous_nodes(false).unwrap();
        assert!(exo.contains(&0));
        let exo2 = pdag.exogenous_nodes(true).unwrap();
        assert!(exo2.contains(&0));

        // to_cpdag on PDAG applies Meek closure
        let cpdag = pdag.to_cpdag().unwrap();
        match cpdag {
            GraphView::Pdag(cp) => {
                assert_eq!(cp.children_of(1), &[2]); // 0->1, 1--2 => 1->2
            }
            _ => panic!("expected PDAG"),
        }

        // Error paths for PDAG
        assert!(pdag.d_separated(&[0], &[2], &[1]).is_err());
        assert!(pdag.minimal_separator(&[0], &[2], &[], &[]).is_err());
        assert!(pdag.moralize().is_err());
        assert!(pdag.latent_project(&[0]).is_err());
        assert!(pdag.districts().is_err());
        assert!(pdag.adjustment_set_parents(&[0], &[2]).is_err());
        assert!(pdag.adjustment_set_backdoor(&[0], &[2]).is_err());
        assert!(pdag.adjustment_set_optimal(&[0], &[2]).is_err());
        assert!(pdag.is_valid_backdoor_set(&[0], &[2], &[1]).is_err());
        assert!(pdag.all_backdoor_sets(&[0], &[2], true, 2).is_err());
        assert!(pdag.is_valid_adjustment_set_admg(&[0], &[2], &[1]).is_err());
        assert!(pdag.all_adjustment_sets_admg(&[0], &[2], true, 2).is_err());
    }

    #[test]
    fn session_resolve_class_error_paths() {
        let reg = make_registry();
        let u = reg.code_of("---").unwrap();

        // UG graph cannot resolve to DAG
        let mut ug = GraphSession::new(&reg, 2, true, GraphClass::Unknown);
        let mut e = EdgeBuffer::new();
        e.push(0, 1, u);
        ug.set_edges(e);

        assert!(ug.resolve_class(GraphClass::Dag).is_err());
        assert!(ug.resolve_class(GraphClass::Admg).is_err());

        let b = reg.code_of("<->").unwrap();
        let mut admg = GraphSession::new(&reg, 2, true, GraphClass::Unknown);
        let mut e2 = EdgeBuffer::new();
        e2.push(0, 1, b);
        admg.set_edges(e2);
        assert!(admg.resolve_class(GraphClass::Dag).is_err());
        assert!(admg.resolve_class(GraphClass::Ug).is_err());
        assert!(admg.resolve_class(GraphClass::Pdag).is_err());
    }

    #[test]
    fn session_is_mag_with_valid_ag() {
        let reg = make_registry();
        let d = reg.code_of("-->").unwrap();
        let b = reg.code_of("<->").unwrap();

        // Build AG: 0 --> 1, 0 <-> 2 (valid MAG if ancestral constraints hold)
        let mut ag = GraphSession::new(&reg, 3, true, GraphClass::Ag);
        let mut e = EdgeBuffer::new();
        e.push(0, 1, d);
        e.push(0, 2, b);
        ag.set_edges(e);

        let is_mag = ag.is_mag().unwrap();
        // Just verify it returns without error
        let _ = is_mag;

        // is_cpdag on AG returns false
        assert!(!ag.is_cpdag().unwrap());
    }

    #[test]
    fn session_raw_view_error_paths() {
        let reg = make_registry();
        let d = reg.code_of("-->").unwrap();

        let mut raw = GraphSession::new(&reg, 3, true, GraphClass::Unknown);
        let mut e = EdgeBuffer::new();
        e.push(0, 1, d);
        e.push(1, 2, d);
        raw.set_edges(e);

        // Raw view should error on most query methods
        assert!(raw.topological_sort().is_err());
        assert!(raw.markov_blanket_of(0).is_err());
        assert!(raw.exogenous_nodes(false).is_err());
        assert!(raw.districts().is_err());
        assert!(raw.spouses_of(0).is_err());
    }

    #[test]
    fn session_query_api_view_failure_paths() {
        let reg = make_registry();
        let d = reg.code_of("-->").unwrap();

        // Create a session with class=Dag but edges that form a cycle (0-->1, 1-->0).
        // This means core() succeeds (the CSR builds fine), but view() fails because
        // Dag::new detects the cycle. Every query method that calls self.view()? will
        // propagate this Err, covering the early-return ? path.
        let mut dag = GraphSession::new(&reg, 2, false, GraphClass::Dag);
        dag.set_names(vec!["A".into(), "B".into()]);
        let mut e = EdgeBuffer::new();
        e.push(0, 1, d);
        e.push(1, 0, d);
        dag.set_edges(e);

        // Verify the core builds successfully but the view fails
        assert!(dag.core().is_ok());
        assert!(dag.view().is_err());

        // Every query method below goes through self.view()? which must fail
        assert!(dag.topological_sort().is_err());
        assert!(dag.parents_of(0).is_err());
        assert!(dag.children_of(0).is_err());
        assert!(dag.undirected_of(0).is_err());
        assert!(dag.neighbors_of(0, NeighborMode::All).is_err());
        assert!(dag.ancestors_of(0).is_err());
        assert!(dag.descendants_of(0).is_err());
        assert!(dag.anteriors_of(0).is_err());
        assert!(dag.posteriors_of(0).is_err());
        assert!(dag.markov_blanket_of(0).is_err());
        assert!(dag.districts().is_err());
        assert!(dag.district_of(0).is_err());
        assert!(dag.spouses_of(0).is_err());
        assert!(dag.exogenous_nodes(false).is_err());
        assert!(dag.d_separated(&[0], &[1], &[]).is_err());
        assert!(dag.minimal_separator(&[0], &[1], &[], &[0, 1]).is_err());
        assert!(dag.m_separated(&[0], &[1], &[]).is_err());
        assert!(dag.adjustment_set_parents(&[0], &[1]).is_err());
        assert!(dag.adjustment_set_backdoor(&[0], &[1]).is_err());
        assert!(dag.adjustment_set_optimal(&[0], &[1]).is_err());
        assert!(dag.is_valid_backdoor_set(&[0], &[1], &[]).is_err());
        assert!(dag.all_backdoor_sets(&[0], &[1], false, 10).is_err());
        assert!(dag.is_valid_adjustment_set_admg(&[0], &[1], &[]).is_err());
        assert!(dag.all_adjustment_sets_admg(&[0], &[1], false, 10).is_err());
        assert!(dag.to_cpdag().is_err());
        assert!(dag.skeleton().is_err());
        assert!(dag.moralize().is_err());
        assert!(dag.latent_project(&[]).is_err());

        // resolve_class(Dag) should also fail on the cyclic graph since
        // Dag::new will reject the cycle
        assert!(dag.resolve_class(GraphClass::Dag).is_err());

        // Verify error messages are name-mapped through map_error
        let err = dag.view().unwrap_err();
        assert!(
            !err.contains("0") && !err.contains("1") || err.contains("A") || err.contains("B"),
            "Error should use node names, got: {}",
            err
        );
    }
}
