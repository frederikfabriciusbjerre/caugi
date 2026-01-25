// SPDX-License-Identifier: MIT
//! R bindings for caugi graph library.

use extendr_api::prelude::*;
pub mod edges;
pub mod graph;
mod reactive;

use edges::{EdgeClass, EdgeRegistry, EdgeSpec, Mark};
use graph::builder::GraphBuilder;

#[cfg(feature = "gadjid")]
use graph::metrics::aid;
use graph::metrics::{hd, shd_with_perm};

use graph::view::GraphView;
use graph::{admg::Admg, ag::Ag, dag::Dag, pdag::Pdag, ug::Ug, CaugiGraph};
use std::collections::HashMap;
use std::sync::Arc;

// ---------- helpers ----------
fn rint_to_u32(x: Rint, field: &str) -> u32 {
    if x.is_na() {
        throw_r_error(format!("NA in `{}`", field));
    }
    let v = x.inner();
    if v < 0 {
        throw_r_error(format!(
            "`{}` must be >= 0. Note that the input number from R might have been subtracted with 1.",
            field
        ));
    }
    v as u32
}
fn rint_to_u8(x: Rint, field: &str) -> u8 {
    if x.is_na() {
        throw_r_error(format!("NA in `{}`", field));
    }
    let v = x.inner();
    if !(0..=255).contains(&v) {
        throw_r_error(format!("`{}` must be in 0..=255", field));
    }
    v as u8
}
fn rbool_to_bool(x: Rbool, field: &str) -> bool {
    if x.is_na() {
        throw_r_error(format!("NA in `{}`", field));
    }
    x.is_true()
}

/// Validate that an index is within bounds.
#[inline]
fn validate_index(i: u32, n: u32) {
    if i >= n {
        throw_r_error(format!("Index {} is out of bounds", i));
    }
}

/// Convert R Integers to Vec<u32>.
fn integers_to_u32_vec(ints: &Integers, name: &str) -> Vec<u32> {
    ints.iter().map(|ri| rint_to_u32(ri, name)).collect()
}

/// Convert Vec<u32> to Robj (as i32 vector).
fn u32_vec_to_robj(v: &[u32]) -> Robj {
    v.iter().map(|&x| x as i32).collect_robj()
}

/// Convert coordinate pairs to R list with x and y vectors.
fn coords_to_list(coords: Vec<(f64, f64)>) -> Robj {
    let mut x: Vec<f64> = Vec::with_capacity(coords.len());
    let mut y: Vec<f64> = Vec::with_capacity(coords.len());
    for (xi, yi) in coords {
        x.push(xi);
        y.push(yi);
    }
    list!(x = x, y = y).into_robj()
}

fn graph_class_from_view(view: &GraphView) -> GraphClass {
    match view {
        GraphView::Dag(_) => GraphClass::Dag,
        GraphView::Pdag(_) => GraphClass::Pdag,
        GraphView::Ug(_) => GraphClass::Ug,
        GraphView::Admg(_) => GraphClass::Admg,
        GraphView::Ag(_) => GraphClass::Ag,
        GraphView::Raw(_) => GraphClass::Unknown,
    }
}

fn graph_class_label_from_view(view: &GraphView) -> &'static str {
    match view {
        GraphView::Dag(_) => "DAG",
        GraphView::Pdag(_) => "PDAG",
        GraphView::Ug(_) => "UG",
        GraphView::Admg(_) => "ADMG",
        GraphView::Ag(_) => "AG",
        GraphView::Raw(_) => "UNKNOWN",
    }
}

fn edge_buffer_from_core(core: &CaugiGraph) -> EdgeBuffer {
    let n = core.n();
    let mut from: Vec<u32> = Vec::new();
    let mut to: Vec<u32> = Vec::new();
    let mut etype: Vec<u8> = Vec::new();

    for u in 0..n {
        for k in core.row_range(u) {
            let v = core.col_index[k];
            let code = core.etype[k];
            let spec = &core.registry.specs[code as usize];
            if spec.symmetric {
                if u < v {
                    from.push(u);
                    to.push(v);
                    etype.push(code);
                }
            } else if core.side[k] == 0 {
                from.push(u);
                to.push(v);
                etype.push(code);
            }
        }
    }

    EdgeBuffer { from, to, etype }
}

fn session_from_view(view: GraphView, node_names: Vec<String>) -> GraphSession {
    let core = view.core();
    let class = graph_class_from_view(&view);
    let mut session = GraphSession::from_snapshot(
        Arc::new(core.registry.clone()),
        core.n(),
        core.simple,
        class,
    );
    session.set_names(node_names);
    session.set_edges(edge_buffer_from_core(&core));
    session
}

// ── Edge Registry  ────────────────────────────────────────────────────────────────

#[extendr]
fn edge_registry_new() -> ExternalPtr<EdgeRegistry> {
    ExternalPtr::new(EdgeRegistry::new())
}

#[extendr]
fn edge_registry_register_builtins(mut reg: ExternalPtr<EdgeRegistry>) {
    if let Err(e) = reg.as_mut().register_builtins() {
        throw_r_error(e.to_string());
    }
}

#[extendr]
fn edge_registry_seal(mut reg: ExternalPtr<EdgeRegistry>) {
    reg.as_mut().seal();
}

#[extendr]
fn edge_registry_len(reg: ExternalPtr<EdgeRegistry>) -> i32 {
    reg.as_ref().len() as i32
}

#[extendr]
fn edge_registry_register(
    mut reg: ExternalPtr<EdgeRegistry>,
    glyph: &str,
    tail_mark: &str,
    head_mark: &str,
    class: &str,
    symmetric: bool,
) -> i32 {
    let tail = tail_mark
        .parse::<Mark>()
        .unwrap_or_else(|e| throw_r_error(e));
    let head = head_mark
        .parse::<Mark>()
        .unwrap_or_else(|e| throw_r_error(e));
    let class = class
        .parse::<EdgeClass>()
        .unwrap_or_else(|e| throw_r_error(e));
    let spec = EdgeSpec {
        glyph: glyph.to_string(),
        tail,
        head,
        symmetric,
        class,
    };
    match reg.as_mut().register(spec) {
        Ok(c) => c as i32,
        Err(e) => throw_r_error(e.to_string()),
    }
}

#[extendr]
fn edge_registry_code_of(reg: ExternalPtr<EdgeRegistry>, glyphs: Strings) -> Robj {
    let mut out: Vec<i32> = Vec::with_capacity(glyphs.len());
    for g in glyphs.iter() {
        let code = reg
            .as_ref()
            .code_of(g.as_str())
            .unwrap_or_else(|e| throw_r_error(e.to_string()));
        out.push(code as i32);
    }
    out.into_robj()
}

#[extendr]
fn edge_registry_spec_of_code(reg: ExternalPtr<EdgeRegistry>, code: i32) -> Robj {
    if !(0..=255).contains(&code) {
        throw_r_error("code must be in 0..=255");
    }
    match reg.as_ref().spec_of_code(code as u8) {
        Ok(spec) => list!(
            glyph = spec.glyph.to_string(),
            tail = spec.tail.to_string(),
            head = spec.head.to_string(),
            class = spec.class.to_string(),
            symmetric = spec.symmetric
        )
        .into_robj(),
        Err(e) => throw_r_error(e.to_string()),
    }
}

// ── Core builder ────────────────────────────────────────────────────────────────
#[extendr]
fn graph_builder_new(
    reg: ExternalPtr<EdgeRegistry>,
    n: i32,
    simple: Rbool,
) -> ExternalPtr<GraphBuilder> {
    if n < 0 {
        throw_r_error("n must be >= 0");
    }
    ExternalPtr::new(GraphBuilder::new(n as u32, simple.is_true(), reg.as_ref()))
}
#[extendr]
fn graph_builder_add_edges(
    mut b: ExternalPtr<GraphBuilder>,
    from: Integers,
    to: Integers,
    etype: Integers,
) {
    if from.len() != to.len() || from.len() != etype.len() {
        throw_r_error("vectors must have equal length");
    }
    for i in 0..from.len() {
        let u = rint_to_u32(from[i], "from");
        let v = rint_to_u32(to[i], "to");
        let t = rint_to_u8(etype[i], "etype");
        if let Err(e) = b.as_mut().add_edge(u, v, t) {
            throw_r_error(e);
        }
    }
}

// ── Constructors for class views ────────────────────────────────────────────────────────────────
fn graphview_new(core: ExternalPtr<CaugiGraph>, class: &str) -> ExternalPtr<GraphView> {
    let core_arc = Arc::new(core.as_ref().clone());
    
    match class.trim().to_ascii_uppercase().as_str() {
        "DAG" => {
            let dag = Dag::new(Arc::clone(&core_arc)).unwrap_or_else(|e| throw_r_error(e));
            ExternalPtr::new(GraphView::Dag(Arc::new(dag)))
        }
        "PDAG" | "CPDAG" => {
            let pdag = Pdag::new(Arc::clone(&core_arc)).unwrap_or_else(|e| throw_r_error(e));
            ExternalPtr::new(GraphView::Pdag(Arc::new(pdag)))
        }
        "UG" => {
            let ug = Ug::new(Arc::clone(&core_arc)).unwrap_or_else(|e| throw_r_error(e));
            ExternalPtr::new(GraphView::Ug(Arc::new(ug)))
        }
        "ADMG" => {
            let admg = Admg::new(Arc::clone(&core_arc)).unwrap_or_else(|e| throw_r_error(e));
            ExternalPtr::new(GraphView::Admg(Arc::new(admg)))
        }
        "AG" => {
            let ag = Ag::new(Arc::clone(&core_arc)).unwrap_or_else(|e| throw_r_error(e));
            ExternalPtr::new(GraphView::Ag(Arc::new(ag)))
        }
        "AUTO" => {
            // Try each class in order: DAG → UG → PDAG → ADMG → AG → Raw
            if let Ok(dag) = Dag::new(Arc::clone(&core_arc)) {
                ExternalPtr::new(GraphView::Dag(Arc::new(dag)))
            } else if let Ok(ug) = Ug::new(Arc::clone(&core_arc)) {
                ExternalPtr::new(GraphView::Ug(Arc::new(ug)))
            } else if let Ok(pdag) = Pdag::new(Arc::clone(&core_arc)) {
                ExternalPtr::new(GraphView::Pdag(Arc::new(pdag)))
            } else if let Ok(admg) = Admg::new(Arc::clone(&core_arc)) {
                ExternalPtr::new(GraphView::Admg(Arc::new(admg)))
            } else if let Ok(ag) = Ag::new(Arc::clone(&core_arc)) {
                ExternalPtr::new(GraphView::Ag(Arc::new(ag)))
            } else {
                ExternalPtr::new(GraphView::Raw(core_arc))
            }
        }
        _ => ExternalPtr::new(GraphView::Raw(core_arc)),
    }
}

#[extendr]
fn graph_builder_build_view(
    mut b: ExternalPtr<GraphBuilder>,
    class: &str,
) -> ExternalPtr<GraphView> {
    let core = b
        .as_mut()
        .finalize_in_place()
        .unwrap_or_else(|e| throw_r_error(e));
    graphview_new(ExternalPtr::new(core), class)
}

#[extendr]
fn graph_builder_resolve_class(mut b: ExternalPtr<GraphBuilder>, class: &str) -> String {
    let core = b
        .as_mut()
        .finalize_in_place()
        .unwrap_or_else(|e| throw_r_error(e));
    let view = graphview_new(ExternalPtr::new(core), class);
    graph_class_label_from_view(view.as_ref()).to_string()
}

// ── Unified queries ────────────────────────────────────────────────────────────────
#[extendr]
fn parents_of_ptr(g: ExternalPtr<GraphView>, idxs: Integers) -> Robj {
    let n = g.as_ref().n();
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        validate_index(i, n);
        let v = g
            .as_ref()
            .parents_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(u32_vec_to_robj(&v));
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn children_of_ptr(g: ExternalPtr<GraphView>, idxs: Integers) -> Robj {
    let n = g.as_ref().n();
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        validate_index(i, n);
        let v = g
            .as_ref()
            .children_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(u32_vec_to_robj(&v));
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn undirected_of_ptr(g: ExternalPtr<GraphView>, idxs: Integers) -> Robj {
    let n = g.as_ref().n();
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        validate_index(i, n);
        let v = g
            .as_ref()
            .undirected_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(u32_vec_to_robj(&v));
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn neighbors_of_ptr(g: ExternalPtr<GraphView>, idxs: Integers, mode: Strings) -> Robj {
    use graph::NeighborMode;

    // Default to "all" if mode is empty or NA
    let neighbor_mode = if mode.len() == 0 {
        NeighborMode::All
    } else {
        let mode_rstr = mode.elt(0);
        if mode_rstr.is_na() {
            NeighborMode::All
        } else {
            NeighborMode::from_str(mode_rstr.as_str()).unwrap_or_else(|e| throw_r_error(e))
        }
    };

    let n = g.as_ref().n();
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        validate_index(i, n);
        let v = g
            .as_ref()
            .neighbors_of(i, neighbor_mode)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(u32_vec_to_robj(&v));
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn ancestors_of_ptr(g: ExternalPtr<GraphView>, idxs: Integers) -> Robj {
    let n = g.as_ref().n();
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        validate_index(i, n);
        let v = g
            .as_ref()
            .ancestors_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(u32_vec_to_robj(&v));
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn descendants_of_ptr(g: ExternalPtr<GraphView>, idxs: Integers) -> Robj {
    let n = g.as_ref().n();
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        validate_index(i, n);
        let v = g
            .as_ref()
            .descendants_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(u32_vec_to_robj(&v));
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn anteriors_of_ptr(g: ExternalPtr<GraphView>, idxs: Integers) -> Robj {
    let n = g.as_ref().n();
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        validate_index(i, n);
        let v = g
            .as_ref()
            .anteriors_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(u32_vec_to_robj(&v));
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn markov_blanket_of_ptr(g: ExternalPtr<GraphView>, idxs: Integers) -> Robj {
    let n = g.as_ref().n();
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        validate_index(i, n);
        let v = g
            .as_ref()
            .markov_blanket_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(u32_vec_to_robj(&v));
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn exogenous_nodes_of_ptr(g: ExternalPtr<GraphView>, undirected_as_parents: Rbool) -> Robj {
    let undirected_as_parents = undirected_as_parents.is_true();
    g.as_ref()
        .exogenous_nodes(undirected_as_parents)
        .map(|s| u32_vec_to_robj(&s))
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn topological_sort_ptr(g: ExternalPtr<GraphView>) -> Robj {
    g.as_ref()
        .topological_sort()
        .map(|v| v.iter().map(|&x| x as i32).collect_robj())
        .unwrap_or_else(|e| throw_r_error(e))
}

// ── Validation / class checks ────────────────────────────────────────────────────────────────
#[extendr]
fn is_dag_type_ptr(g: ExternalPtr<GraphView>) -> bool {
    let core = g.as_ref().core();
    Dag::new(Arc::new(core.clone())).is_ok()
}

#[extendr]
fn is_pdag_type_ptr(g: ExternalPtr<GraphView>) -> bool {
    let core = g.as_ref().core();
    Pdag::new(Arc::new(core.clone())).is_ok()
}

#[extendr]
fn is_ug_type_ptr(g: ExternalPtr<GraphView>) -> bool {
    let core = g.as_ref().core();
    Ug::new(Arc::new(core.clone())).is_ok()
}

#[extendr]
fn is_admg_type_ptr(g: ExternalPtr<GraphView>) -> bool {
    let core = g.as_ref().core();
    Admg::new(Arc::new(core.clone())).is_ok()
}

#[extendr]
fn is_ag_type_ptr(g: ExternalPtr<GraphView>) -> bool {
    let core = g.as_ref().core();
    Ag::new(Arc::new(core.clone())).is_ok()
}

#[extendr]
fn is_mag_ptr(g: ExternalPtr<GraphView>) -> bool {
    let core = g.as_ref().core();
    match Ag::new(Arc::new(core.clone())) {
        Ok(ag) => ag.is_mag(),
        Err(_) => false,
    }
}

#[extendr]
fn graph_class_ptr(g: ExternalPtr<GraphView>) -> String {
    match g.as_ref() {
        GraphView::Dag(_) => "DAG",
        GraphView::Pdag(_) => "PDAG",
        GraphView::Ug(_) => "UG",
        GraphView::Admg(_) => "ADMG",
        GraphView::Ag(_) => "AG",
        GraphView::Raw(_) => "UNKNOWN",
    }
    .to_string()
}

#[extendr]
fn is_acyclic_ptr(g: ExternalPtr<GraphView>) -> bool {
    let core = g.as_ref().core();
    crate::graph::alg::directed_part_is_acyclic(core)
}

#[extendr]
fn is_simple_ptr(g: ExternalPtr<GraphView>) -> bool {
    g.as_ref().core().simple
}

// ── ADMG-specific queries ────────────────────────────────────────────────────
#[extendr]
fn spouses_of_ptr(g: ExternalPtr<GraphView>, idxs: Integers) -> Robj {
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        if i >= g.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i));
        }
        let v = g
            .as_ref()
            .spouses_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(v.iter().map(|&x| x as i32).collect_robj());
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn districts_ptr(g: ExternalPtr<GraphView>) -> Robj {
    let districts = g.as_ref().districts().unwrap_or_else(|e| throw_r_error(e));
    let robjs: Vec<Robj> = districts
        .into_iter()
        .map(|v| v.into_iter().map(|u| u as i32).collect_robj())
        .collect();
    extendr_api::prelude::List::from_values(robjs).into_robj()
}

#[extendr]
fn district_of_ptr(g: ExternalPtr<GraphView>, idx: i32) -> Robj {
    if idx < 0 {
        throw_r_error("idx must be >= 0");
    }
    let i = idx as u32;
    if i >= g.as_ref().n() {
        throw_r_error(format!("Index {} is out of bounds", i));
    }
    let v = g
        .as_ref()
        .district_of(i)
        .unwrap_or_else(|e| throw_r_error(e));
    v.into_iter().map(|x| x as i32).collect_robj()
}

#[extendr]
fn m_separated_ptr(g: ExternalPtr<GraphView>, xs: Integers, ys: Integers, z: Integers) -> bool {
    let xs_u = integers_to_u32_vec(&xs, "xs");
    let ys_u = integers_to_u32_vec(&ys, "ys");
    let z_u = integers_to_u32_vec(&z, "z");
    let n = g.as_ref().n();
    for &i in xs_u.iter().chain(ys_u.iter()).chain(z_u.iter()) {
        validate_index(i, n);
    }
    g.as_ref()
        .m_separated(&xs_u, &ys_u, &z_u)
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn is_valid_adjustment_set_admg_ptr(
    g: ExternalPtr<GraphView>,
    xs: Integers,
    ys: Integers,
    z: Integers,
) -> bool {
    let xs_u = integers_to_u32_vec(&xs, "xs");
    let ys_u = integers_to_u32_vec(&ys, "ys");
    let z_u = integers_to_u32_vec(&z, "z");
    g.as_ref()
        .is_valid_adjustment_set_admg(&xs_u, &ys_u, &z_u)
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn all_adjustment_sets_admg_ptr(
    g: ExternalPtr<GraphView>,
    xs: Integers,
    ys: Integers,
    minimal: Rbool,
    max_size: i32,
) -> Robj {
    let xs_u = integers_to_u32_vec(&xs, "xs");
    let ys_u = integers_to_u32_vec(&ys, "ys");
    let max_size = rint_to_u32(Rint::from(max_size), "max_size");
    let sets = g
        .as_ref()
        .all_adjustment_sets_admg(&xs_u, &ys_u, rbool_to_bool(minimal, "minimal"), max_size)
        .unwrap_or_else(|e| throw_r_error(e));
    let robjs: Vec<Robj> = sets
        .into_iter()
        .map(|v| v.into_iter().map(|u| u as i32).collect_robj())
        .collect();
    extendr_api::prelude::List::from_values(robjs).into_robj()
}

// ── Metrics ────────────────────────────────────────────────────────────────
#[extendr]
fn shd_of_ptrs(
    g1: ExternalPtr<GraphView>,
    names1: Strings,
    g2: ExternalPtr<GraphView>,
    names2: Strings,
) -> Robj {
    let core1 = g1.as_ref().core();
    let core2 = g2.as_ref().core();
    if core1.n() != core2.n() {
        throw_r_error("graph size mismatch");
    }
    if names1.len() as u32 != core1.n() || names2.len() as u32 != core2.n() {
        throw_r_error("names length must match number of nodes");
    }
    let mut idx2: HashMap<String, u32> = HashMap::with_capacity(names2.len());
    for (i, s) in names2.iter().enumerate() {
        let k = s.as_str().to_string();
        if idx2.insert(k, i as u32).is_some() {
            throw_r_error("duplicate node name in names2");
        }
    }
    let mut perm = Vec::with_capacity(names1.len());
    for s in names1.iter() {
        let key = s.as_str();
        let j = *idx2.get(key).unwrap_or_else(|| {
            throw_r_error(format!("name '{key}' present in names1 but not in names2"))
        });
        perm.push(j);
    }
    let (norm, count) = shd_with_perm(core1, core2, &perm);
    list!(normalized = norm, count = count as i32).into_robj()
}

#[extendr]
fn hd_of_ptrs(g1: ExternalPtr<GraphView>, g2: ExternalPtr<GraphView>) -> Robj {
    let (norm, count) = hd(g1.as_ref().core(), g2.as_ref().core());
    list!(normalized = norm, count = count as i32).into_robj()
}

#[extendr]
fn graph_session_shd(
    mut s1: ExternalPtr<GraphSession>,
    mut s2: ExternalPtr<GraphSession>,
) -> Robj {
    let core1 = s1.as_mut().core().unwrap_or_else(|e| throw_r_error(e));
    let core2 = s2.as_mut().core().unwrap_or_else(|e| throw_r_error(e));
    if core1.n() != core2.n() {
        throw_r_error("graph size mismatch");
    }
    let names1 = s1.as_ref().names();
    let names2 = s2.as_ref().names();
    let perm = build_perm_from_string_slices(names1, names2)
        .unwrap_or_else(|e| throw_r_error(e));
    let (norm, count) = shd_with_perm(core1.as_ref(), core2.as_ref(), &perm);
    list!(normalized = norm, count = count as i32).into_robj()
}

#[extendr]
fn graph_session_hd(mut s1: ExternalPtr<GraphSession>, mut s2: ExternalPtr<GraphSession>) -> Robj {
    let core1 = s1.as_mut().core().unwrap_or_else(|e| throw_r_error(e));
    let core2 = s2.as_mut().core().unwrap_or_else(|e| throw_r_error(e));
    let (norm, count) = hd(core1.as_ref(), core2.as_ref());
    list!(normalized = norm, count = count as i32).into_robj()
}

#[cfg(feature = "gadjid")]
fn to_aid_input(view: &GraphView) -> std::result::Result<aid::AidInput<'_>, String> {
    match view {
        GraphView::Dag(d) => Ok(aid::AidInput::Dag(d.as_ref())),
        GraphView::Pdag(p) => Ok(aid::AidInput::Pdag(p.as_ref())),
        _ => Err("expected graph of type DAG or PDAG".into()),
    }
}

/// Type of AID metric to compute.
#[cfg(feature = "gadjid")]
#[derive(Clone, Copy)]
enum AidType {
    Oset,
    Ancestor,
    Parent,
}

/// Compute AID metric for two graph sessions.
#[cfg(feature = "gadjid")]
fn session_aid_impl(
    s_true: &mut ExternalPtr<GraphSession>,
    s_guess: &mut ExternalPtr<GraphSession>,
    aid_type: AidType,
) -> Robj {
    let core_t = s_true.as_mut().core().unwrap_or_else(|e| throw_r_error(e));
    let core_g = s_guess.as_mut().core().unwrap_or_else(|e| throw_r_error(e));
    if core_t.n() != core_g.n() {
        throw_r_error("graph size mismatch");
    }
    let names_true = s_true.as_ref().names();
    let names_guess = s_guess.as_ref().names();
    let inv = build_inv_from_string_slices(names_true, names_guess)
        .unwrap_or_else(|e| throw_r_error(e));
    let t_view = s_true.as_mut().view().unwrap_or_else(|e| throw_r_error(e));
    let g_view = s_guess.as_mut().view().unwrap_or_else(|e| throw_r_error(e));
    let t = to_aid_input(t_view.as_ref()).unwrap_or_else(|e| throw_r_error(e.to_string()));
    let g = to_aid_input(g_view.as_ref()).unwrap_or_else(|e| throw_r_error(e.to_string()));
    let (score, count) = match aid_type {
        AidType::Oset => aid::oset_aid_align(t, g, &inv),
        AidType::Ancestor => aid::ancestor_aid_align(t, g, &inv),
        AidType::Parent => aid::parent_aid_align(t, g, &inv),
    }
    .unwrap_or_else(|e| throw_r_error(e.to_string()));
    list!(score = score, count = count as i32).into_robj()
}

/// Build a permutation mapping from names1 to names2 (for SHD).
/// Returns perm where perm[i] = index in names2 for the i-th name in names1.
fn build_perm_from_string_slices(
    names1: &[String],
    names2: &[String],
) -> std::result::Result<Vec<u32>, String> {
    use std::collections::HashMap;
    let n = names1.len();
    if n != names2.len() {
        return Err("names length must match number of nodes".into());
    }
    let mut idx2: HashMap<&str, u32> = HashMap::with_capacity(n);
    for (i, s) in names2.iter().enumerate() {
        if idx2.insert(s.as_str(), i as u32).is_some() {
            return Err("duplicate node name in names2".into());
        }
    }
    let mut perm = Vec::with_capacity(n);
    for s in names1.iter() {
        let key = s.as_str();
        let j = *idx2
            .get(key)
            .ok_or_else(|| format!("name '{key}' present in names1 but not in names2"))?;
        perm.push(j);
    }
    Ok(perm)
}

#[cfg(feature = "gadjid")]
fn build_inv_from_string_slices(
    names_true: &[String],
    names_guess: &[String],
) -> std::result::Result<Vec<usize>, String> {
    use std::collections::HashMap;
    let n = names_true.len();
    if n != names_guess.len() {
        return Err("names length must match number of nodes".into());
    }
    let mut idx_guess: HashMap<&str, usize> = HashMap::with_capacity(n);
    for (i, s) in names_guess.iter().enumerate() {
        if idx_guess.insert(s.as_str(), i).is_some() {
            return Err("duplicate node name in names_guess".into());
        }
    }
    // perm[i] = guess-index of the i-th true node
    let mut perm = Vec::with_capacity(n);
    for s in names_true.iter() {
        let key = s.as_str();
        let j = *idx_guess
            .get(key)
            .ok_or_else(|| format!("name '{key}' present in names_true but not in names_guess"))?;
        perm.push(j);
    }
    // invert: inv[j] = i
    let mut inv = vec![0usize; n];
    for (i, &j) in perm.iter().enumerate() {
        inv[j] = i;
    }
    Ok(inv)
}

/// Version of build_inv_from_string_slices that works with extendr Strings.
/// Used by the *_aid_of_ptrs functions that receive names from R.
#[cfg(feature = "gadjid")]
fn build_inv_from_names(
    names_true: &extendr_api::prelude::Strings,
    names_guess: &extendr_api::prelude::Strings,
) -> std::result::Result<Vec<usize>, String> {
    let true_vec: Vec<String> = names_true.iter().map(|s| s.to_string()).collect();
    let guess_vec: Vec<String> = names_guess.iter().map(|s| s.to_string()).collect();
    build_inv_from_string_slices(&true_vec, &guess_vec)
}

#[cfg(feature = "gadjid")]
#[extendr]
fn ancestor_aid_of_ptrs(
    g_true: ExternalPtr<GraphView>,
    names_true: Strings,
    g_guess: ExternalPtr<GraphView>,
    names_guess: Strings,
) -> Robj {
    let core_t = g_true.as_ref().core();
    let core_g = g_guess.as_ref().core();
    if core_t.n() != core_g.n() {
        throw_r_error("graph size mismatch");
    }
    let inv = build_inv_from_names(&names_true, &names_guess)
        .unwrap_or_else(|e| throw_r_error(e.to_string()));

    let t = to_aid_input(g_true.as_ref()).unwrap_or_else(|e| throw_r_error(e.to_string()));
    let g = to_aid_input(g_guess.as_ref()).unwrap_or_else(|e| throw_r_error(e.to_string()));
    let (score, count) =
        aid::ancestor_aid_align(t, g, &inv).unwrap_or_else(|e| throw_r_error(e.to_string()));
    list!(score = score, count = count as i32).into_robj()
}

#[cfg(feature = "gadjid")]
#[extendr]
fn oset_aid_of_ptrs(
    g_true: ExternalPtr<GraphView>,
    names_true: Strings,
    g_guess: ExternalPtr<GraphView>,
    names_guess: Strings,
) -> Robj {
    let core_t = g_true.as_ref().core();
    let core_g = g_guess.as_ref().core();
    if core_t.n() != core_g.n() {
        throw_r_error("graph size mismatch");
    }
    let inv = build_inv_from_names(&names_true, &names_guess)
        .unwrap_or_else(|e| throw_r_error(e.to_string()));

    let t = to_aid_input(g_true.as_ref()).unwrap_or_else(|e| throw_r_error(e.to_string()));
    let g = to_aid_input(g_guess.as_ref()).unwrap_or_else(|e| throw_r_error(e.to_string()));
    let (score, count) =
        aid::oset_aid_align(t, g, &inv).unwrap_or_else(|e| throw_r_error(e.to_string()));
    list!(score = score, count = count as i32).into_robj()
}

#[cfg(feature = "gadjid")]
#[extendr]
fn parent_aid_of_ptrs(
    g_true: ExternalPtr<GraphView>,
    names_true: Strings,
    g_guess: ExternalPtr<GraphView>,
    names_guess: Strings,
) -> Robj {
    let core_t = g_true.as_ref().core();
    let core_g = g_guess.as_ref().core();
    if core_t.n() != core_g.n() {
        throw_r_error("graph size mismatch");
    }
    let inv = build_inv_from_names(&names_true, &names_guess)
        .unwrap_or_else(|e| throw_r_error(e.to_string()));

    let t = to_aid_input(g_true.as_ref()).unwrap_or_else(|e| throw_r_error(e.to_string()));
    let g = to_aid_input(g_guess.as_ref()).unwrap_or_else(|e| throw_r_error(e.to_string()));
    let (score, count) =
        aid::parent_aid_align(t, g, &inv).unwrap_or_else(|e| throw_r_error(e.to_string()));
    list!(score = score, count = count as i32).into_robj()
}

#[cfg(feature = "gadjid")]
#[extendr]
fn graph_session_ancestor_aid(
    mut s_true: ExternalPtr<GraphSession>,
    mut s_guess: ExternalPtr<GraphSession>,
) -> Robj {
    session_aid_impl(&mut s_true, &mut s_guess, AidType::Ancestor)
}

#[cfg(feature = "gadjid")]
#[extendr]
fn graph_session_oset_aid(
    mut s_true: ExternalPtr<GraphSession>,
    mut s_guess: ExternalPtr<GraphSession>,
) -> Robj {
    session_aid_impl(&mut s_true, &mut s_guess, AidType::Oset)
}

#[cfg(feature = "gadjid")]
#[extendr]
fn graph_session_parent_aid(
    mut s_true: ExternalPtr<GraphSession>,
    mut s_guess: ExternalPtr<GraphSession>,
) -> Robj {
    session_aid_impl(&mut s_true, &mut s_guess, AidType::Parent)
}

// ── Causal queries ────────────────────────────────────────────────────────────────

#[extendr]
fn d_separated_ptr(g: ExternalPtr<GraphView>, xs: Integers, ys: Integers, z: Integers) -> bool {
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
    let z_u: Vec<u32> = z.iter().map(|ri| rint_to_u32(ri, "z")).collect();
    // Check that all indices are within bounds
    for &i in xs_u.iter().chain(ys_u.iter()).chain(z_u.iter()) {
        if i >= g.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i + 1));
        }
    }
    g.as_ref()
        .d_separated(&xs_u, &ys_u, &z_u)
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn adjustment_set_parents_ptr(g: ExternalPtr<GraphView>, xs: Integers, ys: Integers) -> Robj {
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
    g.as_ref()
        .adjustment_set_parents(&xs_u, &ys_u)
        .map(|v| v.into_iter().map(|x| x as i32).collect_robj())
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn adjustment_set_backdoor_ptr(g: ExternalPtr<GraphView>, xs: Integers, ys: Integers) -> Robj {
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
    g.as_ref()
        .adjustment_set_backdoor(&xs_u, &ys_u)
        .map(|v| v.into_iter().map(|x| x as i32).collect_robj())
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn adjustment_set_optimal_ptr(g: ExternalPtr<GraphView>, x: i32, y: i32) -> Robj {
    if x < 0 || y < 0 {
        throw_r_error("x and y must be >= 0");
    }
    g.as_ref()
        .adjustment_set_optimal(x as u32, y as u32)
        .map(|v| v.into_iter().map(|x| x as i32).collect_robj())
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn is_valid_backdoor_set_ptr(g: ExternalPtr<GraphView>, x: i32, y: i32, z: Integers) -> bool {
    if x < 0 || y < 0 {
        throw_r_error("x and y must be >= 0");
    }
    let z_u: Vec<u32> = z.iter().map(|ri| rint_to_u32(ri, "z")).collect();
    g.as_ref()
        .is_valid_backdoor_set(x as u32, y as u32, &z_u)
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn all_backdoor_sets_ptr(
    g: ExternalPtr<GraphView>,
    x: i32,
    y: i32,
    minimal: Rbool,
    max_size: i32,
) -> Robj {
    if x < 0 || y < 0 {
        throw_r_error("x and y must be >= 0");
    }
    let max_size = rint_to_u32(Rint::from(max_size), "max_size");
    let sets = g
        .as_ref()
        .all_backdoor_sets(
            x as u32,
            y as u32,
            rbool_to_bool(minimal, "minimal"),
            max_size,
        )
        .unwrap_or_else(|e| throw_r_error(e));
    let robjs: Vec<Robj> = sets
        .into_iter()
        .map(|v| v.into_iter().map(|u| u as i32).collect_robj())
        .collect();
    extendr_api::prelude::List::from_values(robjs).into_robj()
}

// ── Graph transformations ──────────────────────────────────────────────────────

#[extendr]
fn proper_backdoor_graph_ptr(
    g: ExternalPtr<GraphView>,
    xs: Integers,
    ys: Integers,
) -> ExternalPtr<GraphView> {
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
    // Check bounds
    for &i in xs_u.iter().chain(ys_u.iter()) {
        if i >= g.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i + 1));
        }
    }
    let out = g
        .as_ref()
        .proper_backdoor_graph(&xs_u, &ys_u)
        .unwrap_or_else(|e| throw_r_error(e));
    ExternalPtr::new(out)
}

#[extendr]
fn moral_of_ancestors_ptr(g: ExternalPtr<GraphView>, seeds: Integers) -> ExternalPtr<GraphView> {
    let seeds_u: Vec<u32> = seeds.iter().map(|ri| rint_to_u32(ri, "seeds")).collect();
    // Check bounds
    for &i in &seeds_u {
        if i >= g.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i + 1));
        }
    }
    let out = g
        .as_ref()
        .moral_of_ancestors(&seeds_u)
        .unwrap_or_else(|e| throw_r_error(e));
    ExternalPtr::new(out)
}

#[extendr]
fn ancestral_reduction_ptr(g: ExternalPtr<GraphView>, seeds: Integers) -> ExternalPtr<GraphView> {
    let seeds_u: Vec<u32> = seeds.iter().map(|ri| rint_to_u32(ri, "seeds")).collect();
    // Check bounds
    for &i in &seeds_u {
        if i >= g.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i + 1));
        }
    }
    let out = g
        .as_ref()
        .ancestral_reduction(&seeds_u)
        .unwrap_or_else(|e| throw_r_error(e));
    ExternalPtr::new(out)
}

// ── Serialization ──────────────────────────────────────────────────────────────

#[extendr]
fn graph_session_write_caugi_file(
    mut session: ExternalPtr<GraphSession>,
    reg: ExternalPtr<EdgeRegistry>,
    graph_class: &str,
    path: &str,
    comment: Nullable<&str>,
    tags: Nullable<Strings>,
) {
    let node_names_vec: Vec<String> = session.as_ref().names().to_vec();
    let comment_opt = comment.into_option().map(|s| s.to_string());
    let tags_opt = tags
        .into_option()
        .map(|strs| strs.iter().map(|s| s.to_string()).collect::<Vec<_>>());

    let view = session
        .as_mut()
        .view()
        .unwrap_or_else(|e| throw_r_error(e));

    graph::serialization::write_caugi_file(
        view.as_ref(),
        reg.as_ref(),
        graph_class,
        node_names_vec,
        path,
        comment_opt,
        tags_opt,
    )
    .unwrap_or_else(|e| throw_r_error(e));
}

#[extendr]
fn graph_session_serialize_caugi(
    mut session: ExternalPtr<GraphSession>,
    reg: ExternalPtr<EdgeRegistry>,
    graph_class: &str,
    comment: Nullable<&str>,
    tags: Nullable<Strings>,
) -> String {
    let node_names_vec: Vec<String> = session.as_ref().names().to_vec();
    let comment_opt = comment.into_option().map(|s| s.to_string());
    let tags_opt = tags
        .into_option()
        .map(|strs| strs.iter().map(|s| s.to_string()).collect::<Vec<_>>());

    let view = session
        .as_mut()
        .view()
        .unwrap_or_else(|e| throw_r_error(e));

    graph::serialization::serialize_caugi(
        view.as_ref(),
        reg.as_ref(),
        graph_class,
        node_names_vec,
        comment_opt,
        tags_opt,
    )
    .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn graph_session_serialize_graphml(
    mut session: ExternalPtr<GraphSession>,
    reg: ExternalPtr<EdgeRegistry>,
    graph_class: &str,
) -> String {
    let node_names_vec: Vec<String> = session.as_ref().names().to_vec();

    let view = session
        .as_mut()
        .view()
        .unwrap_or_else(|e| throw_r_error(e));

    graph::graphml::serialize_graphml(view.as_ref(), reg.as_ref(), graph_class, node_names_vec)
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn write_caugi_file_ptr(
    g: ExternalPtr<GraphView>,
    reg: ExternalPtr<EdgeRegistry>,
    graph_class: &str,
    node_names: Strings,
    path: &str,
    comment: Nullable<&str>,
    tags: Nullable<Strings>,
) {
    let node_names_vec: Vec<String> = node_names.iter().map(|s| s.to_string()).collect();
    let comment_opt = comment.into_option().map(|s| s.to_string());
    let tags_opt = tags
        .into_option()
        .map(|strs| strs.iter().map(|s| s.to_string()).collect::<Vec<_>>());

    graph::serialization::write_caugi_file(
        g.as_ref(),
        reg.as_ref(),
        graph_class,
        node_names_vec,
        path,
        comment_opt,
        tags_opt,
    )
    .unwrap_or_else(|e| throw_r_error(e));
}

#[extendr]
fn read_caugi_file_ptr(path: &str, reg: ExternalPtr<EdgeRegistry>) -> Robj {
    let data = graph::serialization::read_caugi_file(path, reg.as_ref())
        .unwrap_or_else(|e| throw_r_error(e));

    list!(
        nodes = data.nodes,
        edges_from = data.edges_from,
        edges_to = data.edges_to,
        edges_type = data.edges_type,
        graph_class = data.graph_class
    )
    .into_robj()
}

#[extendr]
fn read_caugi_file(path: &str, reg: ExternalPtr<EdgeRegistry>) -> Robj {
    read_caugi_file_ptr(path, reg)
}

#[extendr]
fn serialize_caugi_ptr(
    g: ExternalPtr<GraphView>,
    reg: ExternalPtr<EdgeRegistry>,
    graph_class: &str,
    node_names: Strings,
    comment: Nullable<&str>,
    tags: Nullable<Strings>,
) -> String {
    let node_names_vec: Vec<String> = node_names.iter().map(|s| s.to_string()).collect();
    let comment_opt = comment.into_option().map(|s| s.to_string());
    let tags_opt = tags
        .into_option()
        .map(|strs| strs.iter().map(|s| s.to_string()).collect::<Vec<_>>());

    graph::serialization::serialize_caugi(
        g.as_ref(),
        reg.as_ref(),
        graph_class,
        node_names_vec,
        comment_opt,
        tags_opt,
    )
    .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn deserialize_caugi_ptr(json: &str, reg: ExternalPtr<EdgeRegistry>) -> Robj {
    let data = graph::serialization::deserialize_caugi(json, reg.as_ref())
        .unwrap_or_else(|e| throw_r_error(e));

    list!(
        nodes = data.nodes,
        edges_from = data.edges_from,
        edges_to = data.edges_to,
        edges_type = data.edges_type,
        graph_class = data.graph_class
    )
    .into_robj()
}

#[extendr]
fn deserialize_caugi(json: &str, reg: ExternalPtr<EdgeRegistry>) -> Robj {
    deserialize_caugi_ptr(json, reg)
}

#[extendr]
fn serialize_graphml_ptr(
    g: ExternalPtr<GraphView>,
    reg: ExternalPtr<EdgeRegistry>,
    graph_class: &str,
    node_names: Strings,
) -> String {
    let node_names_vec: Vec<String> = node_names.iter().map(|s| s.to_string()).collect();

    graph::graphml::serialize_graphml(g.as_ref(), reg.as_ref(), graph_class, node_names_vec)
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn deserialize_graphml_ptr(xml: &str, reg: ExternalPtr<EdgeRegistry>) -> Robj {
    let data = graph::graphml::deserialize_graphml(xml, reg.as_ref())
        .unwrap_or_else(|e| throw_r_error(e));

    list!(
        nodes = data.nodes,
        edges_from = data.edges_from,
        edges_to = data.edges_to,
        edges_type = data.edges_type,
        graph_class = data.graph_class
    )
    .into_robj()
}

#[extendr]
fn deserialize_graphml(xml: &str, reg: ExternalPtr<EdgeRegistry>) -> Robj {
    deserialize_graphml_ptr(xml, reg)
}

// ── Subgraph ────────────────────────────────────────────────────────────────

#[extendr]
fn induced_subgraph_ptr(g: ExternalPtr<GraphView>, keep: Integers) -> Robj {
    let mut ks: Vec<u32> = Vec::with_capacity(keep.len());
    for ri in keep.iter() {
        let u = rint_to_u32(ri, "keep");
        if u >= g.as_ref().n() {
            throw_r_error(format!("node id {} out of bounds", u));
        }
        ks.push(u);
    }

    let sub = g
        .as_ref()
        .induced_subgraph(&ks)
        .unwrap_or_else(|e| throw_r_error(e));

    let sub_ptr = ExternalPtr::new(sub);
    sub_ptr.into_robj()
}

// ── View dataframe ──────────────────────────────────────────────────────────
#[extendr]
fn n_ptr(g: ExternalPtr<GraphView>) -> i32 {
    g.as_ref().n() as i32
}

#[extendr]
fn edges_ptr_df(g: ExternalPtr<GraphView>) -> Robj {
    let core = g.as_ref().core();
    let n = core.n();
    let mut from0: Vec<i32> = Vec::new();
    let mut to0: Vec<i32> = Vec::new();
    let mut code: Vec<i32> = Vec::new();
    let mut glyph: Vec<String> = Vec::new();

    for u in 0..n {
        for k in core.row_range(u) {
            let v = core.col_index[k];
            let ecode = core.etype[k];
            let spec = &core.registry.specs[ecode as usize];
            if spec.symmetric {
                if u < v {
                    from0.push(u as i32);
                    to0.push(v as i32);
                    code.push(ecode as i32);
                    glyph.push(spec.glyph.clone());
                }
            } else if core.side[k] == 0 {
                // emit once per asymmetric edge, from the tail side
                from0.push(u as i32);
                to0.push(v as i32);
                code.push(ecode as i32);
                glyph.push(spec.glyph.clone());
            }
        }
    }
    list!(from0 = from0, to0 = to0, code = code, glyph = glyph).into_robj() // data.frame()
}

#[extendr]
fn to_cpdag_ptr(g: ExternalPtr<GraphView>) -> ExternalPtr<GraphView> {
    let out = g.as_ref().to_cpdag().unwrap_or_else(|e| throw_r_error(e));
    ExternalPtr::new(out)
}

#[extendr]
fn is_cpdag_ptr(g: ExternalPtr<GraphView>) -> bool {
    let core = g.as_ref().core();
    match Pdag::new(Arc::new(core.clone())) {
        Ok(p) => p.is_cpdag(),
        Err(_) => false,
    }
}

// ── Skeleton and moralize ──────────────────────────────────────────────────────────

#[extendr]
fn skeleton_ptr(g: ExternalPtr<GraphView>) -> ExternalPtr<GraphView> {
    let out = g.as_ref().skeleton().unwrap_or_else(|e| throw_r_error(e));
    ExternalPtr::new(out)
}

#[extendr]
fn moralize_ptr(g: ExternalPtr<GraphView>) -> ExternalPtr<GraphView> {
    let out = g.as_ref().moralize().unwrap_or_else(|e| throw_r_error(e));
    ExternalPtr::new(out)
}

#[extendr]
fn latent_project_ptr(g: ExternalPtr<GraphView>, latents: Integers) -> ExternalPtr<GraphView> {
    let latents_u: Vec<u32> = latents
        .iter()
        .map(|ri| rint_to_u32(ri, "latents"))
        .collect();
    let out = g
        .as_ref()
        .latent_project(&latents_u)
        .unwrap_or_else(|e| throw_r_error(e));
    ExternalPtr::new(out)
}

// ── Layout ────────────────────────────────────────────────────────────────────

#[extendr]
fn compute_layout_ptr(g: ExternalPtr<GraphView>, method: &str, packing_ratio: f64) -> Robj {
    use graph::layout::{compute_layout, LayoutMethod};
    use std::str::FromStr;

    let layout_method = LayoutMethod::from_str(method).unwrap_or_else(|e| throw_r_error(e));
    let coords = compute_layout(g.as_ref().core(), layout_method, packing_ratio)
        .unwrap_or_else(|e| throw_r_error(e));
    coords_to_list(coords)
}

#[extendr]
fn compute_bipartite_layout_ptr(
    g: ExternalPtr<GraphView>,
    partition: Robj,
    orientation: &str,
) -> Robj {
    use graph::layout::{compute_bipartite_layout, BipartiteOrientation};
    use std::str::FromStr;

    let orient = BipartiteOrientation::from_str(orientation).unwrap_or_else(|e| throw_r_error(e));

    // Convert logical vector to Vec<bool>
    let partition_vec: Vec<bool> = partition
        .as_logical_slice()
        .unwrap_or_else(|| throw_r_error("partition must be a logical vector"))
        .iter()
        .map(|&x| x.is_true())
        .collect();

    let coords = compute_bipartite_layout(g.as_ref().core(), &partition_vec, orient)
        .unwrap_or_else(|e| throw_r_error(e));

    let n = coords.len();
    let mut x = Vec::with_capacity(n);
    let mut y = Vec::with_capacity(n);

    for (xi, yi) in coords {
        x.push(xi);
        y.push(yi);
    }

    list!(x = x, y = y).into_robj()
}

// ── GraphSession API ────────────────────────────────────────────────────────────────
use graph::session::{EdgeBuffer, GraphClass, GraphSession};

#[extendr]
fn graph_session_new(
    reg: ExternalPtr<EdgeRegistry>,
    n: i32,
    simple: Rbool,
    class: &str,
) -> ExternalPtr<GraphSession> {
    if n < 0 {
        throw_r_error("n must be >= 0");
    }
    let graph_class = GraphClass::from_str(class).unwrap_or_else(|e| throw_r_error(e));
    ExternalPtr::new(GraphSession::new(reg.as_ref(), n as u32, simple.is_true(), graph_class))
}

#[extendr]
fn graph_session_clone(session: ExternalPtr<GraphSession>) -> ExternalPtr<GraphSession> {
    ExternalPtr::new(session.as_ref().clone_for_cow())
}

#[extendr]
fn graph_session_set_edges(
    mut session: ExternalPtr<GraphSession>,
    from: Integers,
    to: Integers,
    etype: Integers,
) {
    if from.len() != to.len() || from.len() != etype.len() {
        throw_r_error("vectors must have equal length");
    }
    let mut edges = EdgeBuffer::with_capacity(from.len());
    for i in 0..from.len() {
        let u = rint_to_u32(from[i], "from");
        let v = rint_to_u32(to[i], "to");
        let t = rint_to_u8(etype[i], "etype");
        edges.push(u, v, t);
    }
    session.as_mut().set_edges(edges);
}

#[extendr]
fn graph_session_set_n(mut session: ExternalPtr<GraphSession>, n: i32) {
    if n < 0 {
        throw_r_error("n must be >= 0");
    }
    session.as_mut().set_n(n as u32);
}

#[extendr]
fn graph_session_set_simple(mut session: ExternalPtr<GraphSession>, simple: Rbool) {
    session.as_mut().set_simple(simple.is_true());
}

#[extendr]
fn graph_session_set_class(mut session: ExternalPtr<GraphSession>, class: &str) {
    let graph_class = GraphClass::from_str(class).unwrap_or_else(|e| throw_r_error(e));
    session.as_mut().set_class(graph_class);
}

#[extendr]
fn graph_session_set_names(mut session: ExternalPtr<GraphSession>, names: Strings) {
    // Handle empty names vector safely - extendr can have issues with empty Strings
    let name_vec: Vec<String> = if names.len() == 0 {
        Vec::new()
    } else {
        names.iter().map(|s| s.to_string()).collect()
    };
    session.as_mut().set_names(name_vec);
}

#[extendr]
fn graph_session_layout(mut session: ExternalPtr<GraphSession>, method: &str) -> Robj {
    let coords = session
        .as_mut()
        .layout(method)
        .unwrap_or_else(|e| throw_r_error(e));
    
    let mut x: Vec<f64> = Vec::with_capacity(coords.len());
    let mut y: Vec<f64> = Vec::with_capacity(coords.len());
    for (xi, yi) in coords {
        x.push(xi);
        y.push(yi);
    }
    list!(x = x, y = y).into_robj()
}

#[extendr]
fn graph_session_compute_layout(
    mut session: ExternalPtr<GraphSession>,
    method: &str,
    packing_ratio: f64,
) -> Robj {
    use graph::layout::{compute_layout, LayoutMethod};
    use std::str::FromStr;

    let core = session
        .as_mut()
        .core()
        .unwrap_or_else(|e| throw_r_error(e));
    let layout_method = LayoutMethod::from_str(method).unwrap_or_else(|e| throw_r_error(e));
    let coords = compute_layout(core.as_ref(), layout_method, packing_ratio)
        .unwrap_or_else(|e| throw_r_error(e));
    coords_to_list(coords)
}

#[extendr]
fn graph_session_compute_bipartite_layout(
    mut session: ExternalPtr<GraphSession>,
    partition: Robj,
    orientation: &str,
) -> Robj {
    use graph::layout::{compute_bipartite_layout, BipartiteOrientation};
    use std::str::FromStr;

    let partition_vec: Vec<bool> = partition
        .as_logical_vector()
        .ok_or("partition must be logical")
        .unwrap_or_else(|e| throw_r_error(e))
        .iter()
        .map(|x| x.is_true())
        .collect();

    let orient = BipartiteOrientation::from_str(orientation).unwrap_or_else(|e| throw_r_error(e));
    let core = session
        .as_mut()
        .core()
        .unwrap_or_else(|e| throw_r_error(e));

    let coords = compute_bipartite_layout(core.as_ref(), &partition_vec, orient)
        .unwrap_or_else(|e| throw_r_error(e));
    coords_to_list(coords)
}

#[extendr]
fn graph_session_n(session: ExternalPtr<GraphSession>) -> i32 {
    session.as_ref().n() as i32
}

#[extendr]
fn graph_session_is_simple(mut session: ExternalPtr<GraphSession>) -> bool {
    let core = session
        .as_mut()
        .core()
        .unwrap_or_else(|e| throw_r_error(e));
    core.simple
}

#[extendr]
fn graph_session_class(session: ExternalPtr<GraphSession>) -> String {
    session.as_ref().class().as_str().to_string()
}

#[extendr]
fn graph_session_graph_class(mut session: ExternalPtr<GraphSession>) -> String {
    let view = session
        .as_mut()
        .view()
        .unwrap_or_else(|e| throw_r_error(e));
    graph_class_label_from_view(view.as_ref()).to_string()
}

#[extendr]
fn graph_session_names(session: ExternalPtr<GraphSession>) -> Strings {
    session.as_ref().names().iter().map(|s| s.as_str()).collect()
}

#[extendr]
fn graph_session_edges_df(mut session: ExternalPtr<GraphSession>) -> Robj {
    let core = session
        .as_mut()
        .core()
        .unwrap_or_else(|e| throw_r_error(e));
    let n = core.n();
    let mut from0: Vec<i32> = Vec::new();
    let mut to0: Vec<i32> = Vec::new();
    let mut code: Vec<i32> = Vec::new();
    let mut glyph: Vec<String> = Vec::new();

    for u in 0..n {
        for k in core.row_range(u) {
            let v = core.col_index[k];
            let ecode = core.etype[k];
            let spec = &core.registry.specs[ecode as usize];
            if spec.symmetric {
                if u < v {
                    from0.push(u as i32);
                    to0.push(v as i32);
                    code.push(ecode as i32);
                    glyph.push(spec.glyph.clone());
                }
            } else if core.side[k] == 0 {
                from0.push(u as i32);
                to0.push(v as i32);
                code.push(ecode as i32);
                glyph.push(spec.glyph.clone());
            }
        }
    }
    list!(from0 = from0, to0 = to0, code = code, glyph = glyph).into_robj()
}

#[extendr]
fn graph_session_is_valid(session: ExternalPtr<GraphSession>) -> Robj {
    list!(
        core_valid = session.as_ref().is_core_valid(),
        view_valid = session.as_ref().is_view_valid()
    )
    .into_robj()
}

// Query accessors
#[extendr]
fn graph_session_topological_sort(mut session: ExternalPtr<GraphSession>) -> Robj {
    let result = session
        .as_mut()
        .topological_sort()
        .unwrap_or_else(|e| throw_r_error(e));
    result.iter().map(|&x| x as i32).collect_robj()
}

#[extendr]
fn graph_session_parents_of(mut session: ExternalPtr<GraphSession>, idxs: Integers) -> Robj {
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        if i >= session.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i));
        }
        let v = session
            .as_mut()
            .parents_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(v.iter().map(|&x| x as i32).collect_robj());
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn graph_session_children_of(mut session: ExternalPtr<GraphSession>, idxs: Integers) -> Robj {
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        if i >= session.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i));
        }
        let v = session
            .as_mut()
            .children_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(v.iter().map(|&x| x as i32).collect_robj());
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn graph_session_undirected_of(mut session: ExternalPtr<GraphSession>, idxs: Integers) -> Robj {
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        if i >= session.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i));
        }
        let v = session
            .as_mut()
            .undirected_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(v.iter().map(|&x| x as i32).collect_robj());
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn graph_session_neighbors_of(
    mut session: ExternalPtr<GraphSession>,
    idxs: Integers,
    mode: Strings,
) -> Robj {
    use graph::NeighborMode;
    // Allow single mode to apply to all indices, or one mode per index
    if mode.len() != 1 && mode.len() != idxs.len() {
        throw_r_error("mode must be length 1 or match index length");
    }
    let single_mode = mode.len() == 1;
    let first_mode = if single_mode {
        Some(
            NeighborMode::from_str(mode.iter().next().unwrap().as_str())
                .unwrap_or_else(|e| throw_r_error(e)),
        )
    } else {
        None
    };

    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for (idx, ri) in idxs.iter().enumerate() {
        let i = rint_to_u32(ri, "idxs");
        if i >= session.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i));
        }
        let neighbor_mode = if single_mode {
            first_mode.unwrap()
        } else {
            NeighborMode::from_str(mode.elt(idx).as_str())
                .unwrap_or_else(|e| throw_r_error(e))
        };
        let v = session
            .as_mut()
            .neighbors_of(i, neighbor_mode)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(v.iter().map(|&x| x as i32).collect_robj());
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn graph_session_ancestors_of(mut session: ExternalPtr<GraphSession>, node: i32) -> Robj {
    let idx = rint_to_u32(Rint::from(node), "node");
    let result = session
        .as_mut()
        .ancestors_of(idx)
        .unwrap_or_else(|e| throw_r_error(e));
    result.iter().map(|&x| x as i32).collect_robj()
}

#[extendr]
fn graph_session_descendants_of(mut session: ExternalPtr<GraphSession>, node: i32) -> Robj {
    let idx = rint_to_u32(Rint::from(node), "node");
    let result = session
        .as_mut()
        .descendants_of(idx)
        .unwrap_or_else(|e| throw_r_error(e));
    result.iter().map(|&x| x as i32).collect_robj()
}

#[extendr]
fn graph_session_anteriors_of(mut session: ExternalPtr<GraphSession>, node: i32) -> Robj {
    let idx = rint_to_u32(Rint::from(node), "node");
    let result = session
        .as_mut()
        .anteriors_of(idx)
        .unwrap_or_else(|e| throw_r_error(e));
    result.iter().map(|&x| x as i32).collect_robj()
}

#[extendr]
fn graph_session_markov_blanket_of(mut session: ExternalPtr<GraphSession>, node: i32) -> Robj {
    let idx = rint_to_u32(Rint::from(node), "node");
    let result = session
        .as_mut()
        .markov_blanket_of(idx)
        .unwrap_or_else(|e| throw_r_error(e));
    result.iter().map(|&x| x as i32).collect_robj()
}

#[extendr]
fn graph_session_spouses_of(mut session: ExternalPtr<GraphSession>, idxs: Integers) -> Robj {
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        if i >= session.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i));
        }
        let v = session
            .as_mut()
            .spouses_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(v.iter().map(|&x| x as i32).collect_robj());
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn graph_session_exogenous_nodes(
    mut session: ExternalPtr<GraphSession>,
    undirected_as_parents: Rbool,
) -> Robj {
    let result = session
        .as_mut()
        .exogenous_nodes(undirected_as_parents.is_true())
        .unwrap_or_else(|e| throw_r_error(e));
    result.iter().map(|&x| x as i32).collect_robj()
}

#[extendr]
fn graph_session_districts(mut session: ExternalPtr<GraphSession>) -> Robj {
    let result = session
        .as_mut()
        .districts()
        .unwrap_or_else(|e| throw_r_error(e));
    
    let out: Vec<Robj> = result
        .iter()
        .map(|d| d.iter().map(|&x| x as i32).collect_robj())
        .collect();
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn graph_session_district_of(mut session: ExternalPtr<GraphSession>, idx: i32) -> Robj {
    if idx < 0 {
        throw_r_error("idx must be >= 0");
    }
    let i = idx as u32;
    if i >= session.as_ref().n() {
        throw_r_error(format!("Index {} is out of bounds", i));
    }
    let v = session
        .as_mut()
        .district_of(i)
        .unwrap_or_else(|e| throw_r_error(e));
    v.into_iter().map(|x| x as i32).collect_robj()
}

// ── Session validation / class checks ────────────────────────────────────────
#[extendr]
fn graph_session_is_acyclic(mut session: ExternalPtr<GraphSession>) -> bool {
    session
        .as_mut()
        .is_acyclic()
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn graph_session_is_dag_type(mut session: ExternalPtr<GraphSession>) -> bool {
    session
        .as_mut()
        .is_dag_type()
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn graph_session_is_pdag_type(mut session: ExternalPtr<GraphSession>) -> bool {
    session
        .as_mut()
        .is_pdag_type()
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn graph_session_is_ug_type(mut session: ExternalPtr<GraphSession>) -> bool {
    session
        .as_mut()
        .is_ug_type()
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn graph_session_is_admg_type(mut session: ExternalPtr<GraphSession>) -> bool {
    session
        .as_mut()
        .is_admg_type()
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn graph_session_is_ag_type(mut session: ExternalPtr<GraphSession>) -> bool {
    session
        .as_mut()
        .is_ag_type()
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn graph_session_is_mag(mut session: ExternalPtr<GraphSession>) -> bool {
    session
        .as_mut()
        .is_mag()
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn graph_session_is_cpdag(mut session: ExternalPtr<GraphSession>) -> bool {
    session
        .as_mut()
        .is_cpdag()
        .unwrap_or_else(|e| throw_r_error(e))
}

// ── Session transforms ───────────────────────────────────────────────────────
#[extendr]
fn graph_session_to_cpdag(mut session: ExternalPtr<GraphSession>) -> ExternalPtr<GraphSession> {
    let view = session
        .as_mut()
        .to_cpdag()
        .unwrap_or_else(|e| throw_r_error(e));
    let names: Vec<String> = session.as_ref().names().to_vec();
    ExternalPtr::new(session_from_view(view, names))
}

#[extendr]
fn graph_session_skeleton(mut session: ExternalPtr<GraphSession>) -> ExternalPtr<GraphSession> {
    let view = session
        .as_mut()
        .skeleton()
        .unwrap_or_else(|e| throw_r_error(e));
    let names: Vec<String> = session.as_ref().names().to_vec();
    ExternalPtr::new(session_from_view(view, names))
}

#[extendr]
fn graph_session_moralize(mut session: ExternalPtr<GraphSession>) -> ExternalPtr<GraphSession> {
    let view = session
        .as_mut()
        .moralize()
        .unwrap_or_else(|e| throw_r_error(e));
    let names: Vec<String> = session.as_ref().names().to_vec();
    ExternalPtr::new(session_from_view(view, names))
}

#[extendr]
fn graph_session_latent_project(
    mut session: ExternalPtr<GraphSession>,
    latents: Integers,
) -> ExternalPtr<GraphSession> {
    let latents_u: Vec<u32> = latents
        .iter()
        .map(|ri| rint_to_u32(ri, "latents"))
        .collect();
    for &i in &latents_u {
        if i >= session.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i));
        }
    }
    let view = session
        .as_mut()
        .latent_project(&latents_u)
        .unwrap_or_else(|e| throw_r_error(e));

    let mut keep = vec![true; session.as_ref().n() as usize];
    for &i in &latents_u {
        if (i as usize) < keep.len() {
            keep[i as usize] = false;
        }
    }
    let names: Vec<String> = session
        .as_ref()
        .names()
        .iter()
        .zip(keep.iter())
        .filter_map(|(name, keep)| if *keep { Some(name.clone()) } else { None })
        .collect();

    ExternalPtr::new(session_from_view(view, names))
}

#[extendr]
fn graph_session_proper_backdoor_graph(
    mut session: ExternalPtr<GraphSession>,
    xs: Integers,
    ys: Integers,
) -> ExternalPtr<GraphSession> {
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
    let view = session
        .as_mut()
        .proper_backdoor_graph(&xs_u, &ys_u)
        .unwrap_or_else(|e| throw_r_error(e));
    let names: Vec<String> = session.as_ref().names().to_vec();
    ExternalPtr::new(session_from_view(view, names))
}

#[extendr]
fn graph_session_moral_of_ancestors(
    mut session: ExternalPtr<GraphSession>,
    seeds: Integers,
) -> ExternalPtr<GraphSession> {
    let seeds_u: Vec<u32> = seeds.iter().map(|ri| rint_to_u32(ri, "seeds")).collect();
    let view = session
        .as_mut()
        .moral_of_ancestors(&seeds_u)
        .unwrap_or_else(|e| throw_r_error(e));
    let names: Vec<String> = session.as_ref().names().to_vec();
    ExternalPtr::new(session_from_view(view, names))
}

#[extendr]
fn graph_session_ancestral_reduction(
    mut session: ExternalPtr<GraphSession>,
    seeds: Integers,
) -> ExternalPtr<GraphSession> {
    use graph::alg::bitset;

    let seeds_u: Vec<u32> = seeds.iter().map(|ri| rint_to_u32(ri, "seeds")).collect();
    let view = session
        .as_mut()
        .ancestral_reduction(&seeds_u)
        .unwrap_or_else(|e| throw_r_error(e));

    let keep: Vec<u32> = match session.as_mut().view().unwrap_or_else(|e| throw_r_error(e)).as_ref() {
        GraphView::Dag(d) => {
            let mask = bitset::ancestors_mask(&seeds_u, |u| d.parents_of(u), d.n());
            bitset::collect_from_mask(&mask)
        }
        GraphView::Pdag(p) => {
            let mask = bitset::ancestors_mask(&seeds_u, |u| p.parents_of(u), p.n());
            bitset::collect_from_mask(&mask)
        }
        GraphView::Admg(a) => {
            let mask = bitset::ancestors_mask(&seeds_u, |u| a.parents_of(u), a.n());
            bitset::collect_from_mask(&mask)
        }
        GraphView::Ag(g) => {
            let mask = bitset::ancestors_mask(&seeds_u, |u| g.parents_of(u), g.n());
            bitset::collect_from_mask(&mask)
        }
        _ => Vec::new(),
    };

    let names: Vec<String> = session
        .as_ref()
        .names()
        .iter()
        .enumerate()
        .filter_map(|(i, name)| {
            if keep.contains(&(i as u32)) {
                Some(name.clone())
            } else {
                None
            }
        })
        .collect();

    ExternalPtr::new(session_from_view(view, names))
}

#[extendr]
fn graph_session_induced_subgraph(
    mut session: ExternalPtr<GraphSession>,
    keep: Integers,
) -> ExternalPtr<GraphSession> {
    let keep_u: Vec<u32> = keep.iter().map(|ri| rint_to_u32(ri, "keep")).collect();
    for &i in &keep_u {
        if i >= session.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i));
        }
    }
    let view = session
        .as_mut()
        .induced_subgraph(&keep_u)
        .unwrap_or_else(|e| throw_r_error(e));
    let names: Vec<String> = keep_u
        .iter()
        .map(|&i| session.as_ref().names()[i as usize].clone())
        .collect();
    ExternalPtr::new(session_from_view(view, names))
}

// ── Session causal queries ───────────────────────────────────────────────────
#[extendr]
fn graph_session_d_separated(
    mut session: ExternalPtr<GraphSession>,
    xs: Integers,
    ys: Integers,
    z: Integers,
) -> bool {
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
    let z_u: Vec<u32> = z.iter().map(|ri| rint_to_u32(ri, "z")).collect();
    session
        .as_mut()
        .d_separated(&xs_u, &ys_u, &z_u)
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn graph_session_m_separated(
    mut session: ExternalPtr<GraphSession>,
    xs: Integers,
    ys: Integers,
    z: Integers,
) -> bool {
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
    let z_u: Vec<u32> = z.iter().map(|ri| rint_to_u32(ri, "z")).collect();
    session
        .as_mut()
        .m_separated(&xs_u, &ys_u, &z_u)
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn graph_session_adjustment_set_parents(
    mut session: ExternalPtr<GraphSession>,
    xs: Integers,
    ys: Integers,
) -> Robj {
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
    session
        .as_mut()
        .adjustment_set_parents(&xs_u, &ys_u)
        .map(|v| v.into_iter().map(|x| x as i32).collect_robj())
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn graph_session_adjustment_set_backdoor(
    mut session: ExternalPtr<GraphSession>,
    xs: Integers,
    ys: Integers,
) -> Robj {
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
    session
        .as_mut()
        .adjustment_set_backdoor(&xs_u, &ys_u)
        .map(|v| v.into_iter().map(|x| x as i32).collect_robj())
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn graph_session_adjustment_set_optimal(
    mut session: ExternalPtr<GraphSession>,
    xs: Integers,
    ys: Integers,
) -> Robj {
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
    session
        .as_mut()
        .adjustment_set_optimal(&xs_u, &ys_u)
        .map(|v| v.into_iter().map(|x| x as i32).collect_robj())
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn graph_session_is_valid_backdoor_set(
    mut session: ExternalPtr<GraphSession>,
    xs: Integers,
    ys: Integers,
    z: Integers,
) -> bool {
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
    let z_u: Vec<u32> = z.iter().map(|ri| rint_to_u32(ri, "z")).collect();
    session
        .as_mut()
        .is_valid_backdoor_set(&xs_u, &ys_u, &z_u)
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn graph_session_all_backdoor_sets(
    mut session: ExternalPtr<GraphSession>,
    xs: Integers,
    ys: Integers,
    minimal: Rbool,
    max_size: i32,
) -> Robj {
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
    let max_size = rint_to_u32(Rint::from(max_size), "max_size");
    let sets = session
        .as_mut()
        .all_backdoor_sets(&xs_u, &ys_u, rbool_to_bool(minimal, "minimal"), max_size)
        .unwrap_or_else(|e| throw_r_error(e));
    let robjs: Vec<Robj> = sets
        .into_iter()
        .map(|v| v.into_iter().map(|u| u as i32).collect_robj())
        .collect();
    extendr_api::prelude::List::from_values(robjs).into_robj()
}

#[extendr]
fn graph_session_is_valid_adjustment_set_admg(
    mut session: ExternalPtr<GraphSession>,
    xs: Integers,
    ys: Integers,
    z: Integers,
) -> bool {
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
    let z_u: Vec<u32> = z.iter().map(|ri| rint_to_u32(ri, "z")).collect();
    session
        .as_mut()
        .is_valid_adjustment_set_admg(&xs_u, &ys_u, &z_u)
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn graph_session_all_adjustment_sets_admg(
    mut session: ExternalPtr<GraphSession>,
    xs: Integers,
    ys: Integers,
    minimal: Rbool,
    max_size: i32,
) -> Robj {
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
    let max_size = rint_to_u32(Rint::from(max_size), "max_size");
    let sets = session
        .as_mut()
        .all_adjustment_sets_admg(&xs_u, &ys_u, rbool_to_bool(minimal, "minimal"), max_size)
        .unwrap_or_else(|e| throw_r_error(e));
    let robjs: Vec<Robj> = sets
        .into_iter()
        .map(|v| v.into_iter().map(|u| u as i32).collect_robj())
        .collect();
    extendr_api::prelude::List::from_values(robjs).into_robj()
}

#[extendr]
fn graph_session_dependency_json(session: ExternalPtr<GraphSession>) -> String {
    session.as_ref().dependency_json()
}

extendr_module! {
    mod caugi;
    // registry
    fn edge_registry_new;
    fn edge_registry_register_builtins;
    fn edge_registry_seal;
    fn edge_registry_len;
    fn edge_registry_register;
    fn edge_registry_code_of;
    fn edge_registry_spec_of_code;

    // session
    fn graph_session_new;
    fn graph_session_clone;
    fn graph_session_set_edges;
    fn graph_session_set_n;
    fn graph_session_set_simple;
    fn graph_session_set_class;
    fn graph_session_set_names;
    fn graph_session_layout;
    fn graph_session_compute_layout;
    fn graph_session_compute_bipartite_layout;
    fn graph_session_n;
    fn graph_session_is_simple;
    fn graph_session_class;
    fn graph_session_graph_class;
    fn graph_session_names;
    fn graph_session_edges_df;
    fn graph_session_is_valid;
    fn graph_session_topological_sort;
    fn graph_session_parents_of;
    fn graph_session_children_of;
    fn graph_session_undirected_of;
    fn graph_session_neighbors_of;
    fn graph_session_ancestors_of;
    fn graph_session_descendants_of;
    fn graph_session_anteriors_of;
    fn graph_session_markov_blanket_of;
    fn graph_session_spouses_of;
    fn graph_session_exogenous_nodes;
    fn graph_session_districts;
    fn graph_session_district_of;
    fn graph_session_dependency_json;
    fn graph_session_is_acyclic;
    fn graph_session_is_dag_type;
    fn graph_session_is_pdag_type;
    fn graph_session_is_ug_type;
    fn graph_session_is_admg_type;
    fn graph_session_is_ag_type;
    fn graph_session_is_mag;
    fn graph_session_is_cpdag;
    fn graph_session_to_cpdag;
    fn graph_session_skeleton;
    fn graph_session_moralize;
    fn graph_session_latent_project;
    fn graph_session_proper_backdoor_graph;
    fn graph_session_moral_of_ancestors;
    fn graph_session_ancestral_reduction;
    fn graph_session_induced_subgraph;
    fn graph_session_d_separated;
    fn graph_session_m_separated;
    fn graph_session_adjustment_set_parents;
    fn graph_session_adjustment_set_backdoor;
    fn graph_session_adjustment_set_optimal;
    fn graph_session_is_valid_backdoor_set;
    fn graph_session_all_backdoor_sets;
    fn graph_session_is_valid_adjustment_set_admg;
    fn graph_session_all_adjustment_sets_admg;
    fn graph_session_shd;
    fn graph_session_hd;
    fn graph_session_ancestor_aid;
    fn graph_session_oset_aid;
    fn graph_session_parent_aid;

    // builder + core
    fn graph_builder_new;
    fn graph_builder_add_edges;
    fn graph_builder_resolve_class;

    // serialization
    fn graph_session_write_caugi_file;
    fn read_caugi_file;
    fn graph_session_serialize_caugi;
    fn deserialize_caugi;
    fn graph_session_serialize_graphml;
    fn deserialize_graphml;
}
