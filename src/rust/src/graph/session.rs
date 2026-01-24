// SPDX-License-Identifier: MIT
//! GraphSession: Canonical mutable state object with reactive computation.
//!
//! This module provides a single source of truth for graph state, implementing:
//! - Lazy compilation of CSR core and typed views
//! - Automatic invalidation on mutation
//! - Query caching with optional disable flag
//! - Layout checkpointing that survives invalidation

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
}

impl GraphClass {
    pub fn from_str(s: &str) -> Result<Self, String> {
        match s.to_lowercase().as_str() {
            "dag" => Ok(GraphClass::Dag),
            "pdag" | "cpdag" => Ok(GraphClass::Pdag),
            "ug" => Ok(GraphClass::Ug),
            "admg" => Ok(GraphClass::Admg),
            "ag" | "mag" | "pag" => Ok(GraphClass::Ag),
            "unknown" | "raw" => Ok(GraphClass::Unknown),
            _ => Err(format!("Unknown graph class: '{}'", s)),
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            GraphClass::Dag => "dag",
            GraphClass::Pdag => "pdag",
            GraphClass::Ug => "ug",
            GraphClass::Admg => "admg",
            GraphClass::Ag => "ag",
            GraphClass::Unknown => "unknown",
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

/// Canonical graph session containing mutable state and cached computations.
///
/// # Design
///
/// The session holds:
/// - **Variables**: Mutable inputs (n, simple, class, registry, edges, names)
/// - **Declarations**: Lazily computed outputs (core, view)
/// - **Checkpoint**: Layout that survives invalidation
/// - **Query caches**: Per-node cached results that clear on view invalidation
///
/// # Invalidation Rules
///
/// - `edges`, `n`, `simple`, `registry` change → invalidate `core` → invalidate `view` → clear caches
/// - `class` change → invalidate `view` only → clear caches
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

    // ═══════════════════════════════════════════════════════════════════════════
    // VALIDITY FLAGS
    // ═══════════════════════════════════════════════════════════════════════════
    core_valid: bool,
    view_valid: bool,

    // ═══════════════════════════════════════════════════════════════════════════
    // DECLARATIONS (cached computed values)
    // ═══════════════════════════════════════════════════════════════════════════
    core: Option<Arc<CaugiGraph>>,
    view: Option<Arc<GraphView>>,

    // ═══════════════════════════════════════════════════════════════════════════
    // CHECKPOINT (survives invalidation)
    // ═══════════════════════════════════════════════════════════════════════════
    layout_checkpoint: Option<Vec<(f64, f64)>>,

    // ═══════════════════════════════════════════════════════════════════════════
    // QUERY CACHES (cleared on view invalidation)
    // ═══════════════════════════════════════════════════════════════════════════
    enable_query_cache: bool,
    topo_cache: Option<Vec<u32>>,
    ancestors_cache: HashMap<u32, Vec<u32>>,
    descendants_cache: HashMap<u32, Vec<u32>>,
    anteriors_cache: HashMap<u32, Vec<u32>>,
    markov_cache: HashMap<u32, Vec<u32>>,
    districts_cache: Option<Vec<Vec<u32>>>,
    exogenous_cache: Option<Vec<u32>>,
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

        Self {
            n,
            simple,
            graph_class: class,
            registry: snapshot,
            edges: EdgeBuffer::new(),
            names: (0..n).map(|i| format!("{}", i)).collect(),

            core_valid: false,
            view_valid: false,

            core: None,
            view: None,

            layout_checkpoint: None,

            enable_query_cache: true,
            topo_cache: None,
            ancestors_cache: HashMap::new(),
            descendants_cache: HashMap::new(),
            anteriors_cache: HashMap::new(),
            markov_cache: HashMap::new(),
            districts_cache: None,
            exogenous_cache: None,
        }
    }

    /// Create a new session from an existing registry snapshot.
    pub fn from_snapshot(
        registry: Arc<RegistrySnapshot>,
        n: u32,
        simple: bool,
        class: GraphClass,
    ) -> Self {
        Self {
            n,
            simple,
            graph_class: class,
            registry,
            edges: EdgeBuffer::new(),
            names: (0..n).map(|i| format!("{}", i)).collect(),

            core_valid: false,
            view_valid: false,

            core: None,
            view: None,

            layout_checkpoint: None,

            enable_query_cache: true,
            topo_cache: None,
            ancestors_cache: HashMap::new(),
            descendants_cache: HashMap::new(),
            anteriors_cache: HashMap::new(),
            markov_cache: HashMap::new(),
            districts_cache: None,
            exogenous_cache: None,
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

            // Invalidate all declarations in the clone
            core_valid: false,
            view_valid: false,
            core: None,
            view: None,

            // Clear checkpoint and caches in clone
            layout_checkpoint: None,

            enable_query_cache: self.enable_query_cache,
            topo_cache: None,
            ancestors_cache: HashMap::new(),
            descendants_cache: HashMap::new(),
            anteriors_cache: HashMap::new(),
            markov_cache: HashMap::new(),
            districts_cache: None,
            exogenous_cache: None,
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
        self.clear_query_caches();
        // NOTE: layout_checkpoint is NOT cleared (survives invalidation)
    }

    fn clear_query_caches(&mut self) {
        self.topo_cache = None;
        self.ancestors_cache.clear();
        self.descendants_cache.clear();
        self.anteriors_cache.clear();
        self.markov_cache.clear();
        self.districts_cache = None;
        self.exogenous_cache = None;
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
        self.names = names;
        self.invalidate_core();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BUILD HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    fn build_core(&self) -> Result<CaugiGraph, String> {
        let mut builder = GraphBuilder::new_from_snapshot(
            self.n,
            self.simple,
            Arc::clone(&self.registry),
        );

        for i in 0..self.edges.len() {
            builder.add_edge(self.edges.from[i], self.edges.to[i], self.edges.etype[i])?;
        }

        builder.finalize()
    }

    fn build_view(&self, core: Arc<CaugiGraph>) -> Result<GraphView, String> {
        match self.graph_class {
            GraphClass::Dag => {
                let dag = Dag::new(core)?;
                Ok(GraphView::Dag(Arc::new(dag)))
            }
            GraphClass::Pdag => {
                let pdag = Pdag::new(core)?;
                Ok(GraphView::Pdag(Arc::new(pdag)))
            }
            GraphClass::Ug => {
                let ug = Ug::new(core)?;
                Ok(GraphView::Ug(Arc::new(ug)))
            }
            GraphClass::Admg => {
                let admg = Admg::new(core)?;
                Ok(GraphView::Admg(Arc::new(admg)))
            }
            GraphClass::Ag => {
                let ag = Ag::new(core)?;
                Ok(GraphView::Ag(Arc::new(ag)))
            }
            GraphClass::Unknown => Ok(GraphView::Raw(core)),
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
        Ok(Arc::clone(self.core.as_ref().unwrap()))
    }

    /// Get the typed view, building if necessary.
    pub fn view(&mut self) -> Result<Arc<GraphView>, String> {
        if !self.view_valid {
            let core = self.core()?;
            let built = self.build_view(core)?;
            self.view = Some(Arc::new(built));
            self.view_valid = true;
        }
        Ok(Arc::clone(self.view.as_ref().unwrap()))
    }

    /// Get layout, optionally using checkpoint.
    pub fn layout(
        &mut self,
        method: &str,
        use_checkpoint: bool,
    ) -> Result<Vec<(f64, f64)>, String> {
        if use_checkpoint {
            if let Some(ref cached) = self.layout_checkpoint {
                return Ok(cached.clone());
            }
        }

        let core = self.core()?;
        let packing_ratio = 1.0;

        use super::layout::{compute_layout, LayoutMethod};
        let layout_method: LayoutMethod = method.parse()?;
        let coords = compute_layout(&core, layout_method, packing_ratio)?;
        self.layout_checkpoint = Some(coords.clone());
        Ok(coords)
    }

    /// Clear the layout checkpoint.
    pub fn clear_layout_checkpoint(&mut self) {
        self.layout_checkpoint = None;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CACHED QUERY API
    // ═══════════════════════════════════════════════════════════════════════════

    /// Enable or disable query caching.
    pub fn set_cache_enabled(&mut self, enabled: bool) {
        self.enable_query_cache = enabled;
        if !enabled {
            self.clear_query_caches();
        }
    }

    /// Check if query caching is enabled.
    pub fn is_cache_enabled(&self) -> bool {
        self.enable_query_cache
    }

    /// Get topological sort (cached).
    pub fn topological_sort(&mut self) -> Result<Vec<u32>, String> {
        if self.enable_query_cache {
            if let Some(ref cached) = self.topo_cache {
                return Ok(cached.clone());
            }
        }

        let view = self.view()?;
        let result = view.topological_sort()?;

        if self.enable_query_cache {
            self.topo_cache = Some(result.clone());
        }
        Ok(result)
    }

    /// Get ancestors of a node (cached).
    pub fn ancestors_of(&mut self, node: u32) -> Result<Vec<u32>, String> {
        if self.enable_query_cache {
            if let Some(cached) = self.ancestors_cache.get(&node) {
                return Ok(cached.clone());
            }
        }

        let view = self.view()?;
        let result = view.ancestors_of(node)?;

        if self.enable_query_cache {
            self.ancestors_cache.insert(node, result.clone());
        }
        Ok(result)
    }

    /// Get descendants of a node (cached).
    pub fn descendants_of(&mut self, node: u32) -> Result<Vec<u32>, String> {
        if self.enable_query_cache {
            if let Some(cached) = self.descendants_cache.get(&node) {
                return Ok(cached.clone());
            }
        }

        let view = self.view()?;
        let result = view.descendants_of(node)?;

        if self.enable_query_cache {
            self.descendants_cache.insert(node, result.clone());
        }
        Ok(result)
    }

    /// Get anteriors of a node (cached).
    pub fn anteriors_of(&mut self, node: u32) -> Result<Vec<u32>, String> {
        if self.enable_query_cache {
            if let Some(cached) = self.anteriors_cache.get(&node) {
                return Ok(cached.clone());
            }
        }

        let view = self.view()?;
        let result = view.anteriors_of(node)?;

        if self.enable_query_cache {
            self.anteriors_cache.insert(node, result.clone());
        }
        Ok(result)
    }

    /// Get Markov blanket of a node (cached).
    pub fn markov_blanket_of(&mut self, node: u32) -> Result<Vec<u32>, String> {
        if self.enable_query_cache {
            if let Some(cached) = self.markov_cache.get(&node) {
                return Ok(cached.clone());
            }
        }

        let view = self.view()?;
        let result = view.markov_blanket_of(node)?;

        if self.enable_query_cache {
            self.markov_cache.insert(node, result.clone());
        }
        Ok(result)
    }

    /// Get districts (cached, ADMG only).
    pub fn districts(&mut self) -> Result<Vec<Vec<u32>>, String> {
        if self.enable_query_cache {
            if let Some(ref cached) = self.districts_cache {
                return Ok(cached.clone());
            }
        }

        let view = self.view()?;
        let result = view.districts()?;

        if self.enable_query_cache {
            self.districts_cache = Some(result.clone());
        }
        Ok(result)
    }

    /// Get exogenous nodes (cached).
    /// The `undirected_as_parents` flag determines whether undirected edges count as parent edges.
    pub fn exogenous_nodes(&mut self, undirected_as_parents: bool) -> Result<Vec<u32>, String> {
        if self.enable_query_cache {
            if let Some(ref cached) = self.exogenous_cache {
                return Ok(cached.clone());
            }
        }

        let view = self.view()?;
        let result = view.exogenous_nodes(undirected_as_parents)?;

        if self.enable_query_cache {
            self.exogenous_cache = Some(result.clone());
        }
        Ok(result)
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

    /// Get current node names.
    pub fn names(&self) -> &[String] {
        &self.names
    }

    /// Get the registry snapshot.
    pub fn registry(&self) -> &Arc<RegistrySnapshot> {
        &self.registry
    }

    /// Check if the core is currently valid.
    pub fn is_core_valid(&self) -> bool {
        self.core_valid
    }

    /// Check if the view is currently valid.
    pub fn is_view_valid(&self) -> bool {
        self.view_valid
    }

    /// Check if a layout checkpoint exists.
    pub fn has_layout_checkpoint(&self) -> bool {
        self.layout_checkpoint.is_some()
    }

    /// Get detailed validity state for introspection.
    pub fn validity_state(&self) -> ValidityState {
        ValidityState {
            core_valid: self.core_valid,
            view_valid: self.view_valid,
            query_cache_enabled: self.enable_query_cache,
            has_layout_checkpoint: self.layout_checkpoint.is_some(),
            topo_cached: self.topo_cache.is_some(),
            ancestors_cached: self.ancestors_cache.len(),
            descendants_cached: self.descendants_cache.len(),
            anteriors_cached: self.anteriors_cache.len(),
            markov_cached: self.markov_cache.len(),
            districts_cached: self.districts_cache.is_some(),
            exogenous_cached: self.exogenous_cache.is_some(),
        }
    }

    /// Get JSON representation of the dependency graph and validity state.
    pub fn dependency_json(&self) -> String {
        let state = self.validity_state();
        format!(
            r#"{{
  "variables": {{
    "n": {},
    "simple": {},
    "class": "{}",
    "registry_version": {},
    "edges_count": {},
    "names_count": {}
  }},
  "declarations": {{
    "core": {{ "valid": {} }},
    "view": {{ "valid": {} }}
  }},
  "checkpoints": {{
    "layout": {{ "exists": {} }}
  }},
  "caches": {{
    "enabled": {},
    "topo": {{ "cached": {} }},
    "ancestors": {{ "cached_nodes": {} }},
    "descendants": {{ "cached_nodes": {} }},
    "anteriors": {{ "cached_nodes": {} }},
    "markov_blanket": {{ "cached_nodes": {} }},
    "districts": {{ "cached": {} }},
    "exogenous": {{ "cached": {} }}
  }},
  "dependencies": [
    ["n", "core"],
    ["simple", "core"],
    ["registry", "core"],
    ["edges", "core"],
    ["core", "view"],
    ["class", "view"],
    ["view", "topo"],
    ["view", "ancestors"],
    ["view", "descendants"],
    ["view", "anteriors"],
    ["view", "markov_blanket"],
    ["view", "districts"],
    ["view", "exogenous"],
    ["core", "layout"]
  ]
}}"#,
            self.n,
            self.simple,
            self.graph_class.as_str(),
            self.registry.version,
            self.edges.len(),
            self.names.len(),
            state.core_valid,
            state.view_valid,
            state.has_layout_checkpoint,
            state.query_cache_enabled,
            state.topo_cached,
            state.ancestors_cached,
            state.descendants_cached,
            state.anteriors_cached,
            state.markov_cached,
            state.districts_cached,
            state.exogenous_cached,
        )
    }
}

/// Detailed validity state for introspection.
#[derive(Debug, Clone)]
pub struct ValidityState {
    pub core_valid: bool,
    pub view_valid: bool,
    pub query_cache_enabled: bool,
    pub has_layout_checkpoint: bool,
    pub topo_cached: bool,
    pub ancestors_cached: usize,
    pub descendants_cached: usize,
    pub anteriors_cached: usize,
    pub markov_cached: usize,
    pub districts_cached: bool,
    pub exogenous_cached: bool,
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
    fn session_layout_checkpoint() {
        let mut session = make_session();

        // Get layout
        let layout1 = session.layout("force", false).unwrap();
        assert!(session.has_layout_checkpoint());

        // Mutate -> checkpoint survives
        session.set_edges(EdgeBuffer::new());
        assert!(session.has_layout_checkpoint());

        // Use checkpoint
        let layout2 = session.layout("force", true).unwrap();
        assert_eq!(layout1, layout2);

        // Clear checkpoint
        session.clear_layout_checkpoint();
        assert!(!session.has_layout_checkpoint());
    }

    #[test]
    fn session_cache_control() {
        let mut session = make_session();
        assert!(session.is_cache_enabled());

        session.set_cache_enabled(false);
        assert!(!session.is_cache_enabled());
    }
}
