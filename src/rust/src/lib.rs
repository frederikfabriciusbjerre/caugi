// SPDX-License-Identifier: MIT
//! R bindings for caugi graph library.

use extendr_api::prelude::*;
pub mod edges;
pub mod graph;

use edges::{EdgeClass, EdgeRegistry, EdgeSpec, Mark, QueryFlags};
use graph::builder::GraphBuilder;
use graph::metrics::{hd, shd_with_perm};
use graph::view::GraphView;
use graph::{CaugiGraph, dag::Dag, pdag::Pdag};
use std::collections::HashMap;
use std::sync::Arc;

// ---------- helpers ----------
fn rint_to_u32(x: Rint, field: &str) -> u32 {
    if x.is_na() {
        throw_r_error(format!("NA in `{}`", field));
    }
    let v = x.inner();
    if v < 0 {
        throw_r_error(format!("`{}` must be >= 0", field));
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
    flags: Vec<String>,
) -> i32 {
    use QueryFlags as F;
    fn parse_flags(v: &[String]) -> F {
        let mut out = F::empty();
        for raw in v {
            match raw.trim().to_ascii_uppercase().as_str() {
                "TRAVERSABLE_WHEN_CONDITIONED" | "TRAVERSABLE" => {
                    out |= F::TRAVERSABLE_WHEN_CONDITIONED
                }
                "LATENT_CONFOUNDING" => out |= F::LATENT_CONFOUNDING,
                other => throw_r_error(format!("Unknown flag '{other}'")),
            }
        }
        out
    }
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
        flags: parse_flags(&flags),
    };
    match reg.as_mut().register(spec) {
        Ok(c) => c as i32,
        Err(e) => throw_r_error(e.to_string()),
    }
}

#[extendr]
fn edge_registry_code_of(reg: ExternalPtr<EdgeRegistry>, glyph: &str) -> i32 {
    reg.as_ref()
        .code_of(glyph)
        .map(|c| c as i32)
        .unwrap_or_else(|e| throw_r_error(e.to_string()))
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
    match class.trim().to_ascii_uppercase().as_str() {
        "DAG" => {
            let dag =
                Dag::new(Arc::new(core.as_ref().clone())).unwrap_or_else(|e| throw_r_error(e));
            ExternalPtr::new(GraphView::Dag(Arc::new(dag)))
        }
        "PDAG" | "CPDAG" => {
            let pdag =
                Pdag::new(Arc::new(core.as_ref().clone())).unwrap_or_else(|e| throw_r_error(e));
            ExternalPtr::new(GraphView::Pdag(Arc::new(pdag)))
        }
        _ => ExternalPtr::new(GraphView::Raw(Arc::new(core.as_ref().clone()))),
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

// ── Unified queries ────────────────────────────────────────────────────────────────
#[extendr]
fn parents_of_ptr(g: ExternalPtr<GraphView>, i: i32) -> Robj {
    g.as_ref()
        .parents_of(i as u32)
        .map(|s| s.iter().map(|&x| x as i32).collect_robj())
        .unwrap_or_else(|e| throw_r_error(e))
}
#[extendr]
fn children_of_ptr(g: ExternalPtr<GraphView>, i: i32) -> Robj {
    g.as_ref()
        .children_of(i as u32)
        .map(|s| s.iter().map(|&x| x as i32).collect_robj())
        .unwrap_or_else(|e| throw_r_error(e))
}
#[extendr]
fn undirected_of_ptr(g: ExternalPtr<GraphView>, i: i32) -> Robj {
    g.as_ref()
        .undirected_of(i as u32)
        .map(|s| s.iter().map(|&x| x as i32).collect_robj())
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn neighbors_of_ptr(g: ExternalPtr<GraphView>, i: i32) -> Robj {
    g.as_ref()
        .neighbors_of(i as u32)
        .map(|s| s.iter().map(|&x| x as i32).collect_robj())
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn ancestors_of_ptr(g: ExternalPtr<GraphView>, i: i32) -> Robj {
    g.as_ref()
        .ancestors_of(i as u32)
        .map(|s| s.iter().map(|x| *x as i32).collect_robj())
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn descendants_of_ptr(g: ExternalPtr<GraphView>, i: i32) -> Robj {
    g.as_ref()
        .descendants_of(i as u32)
        .map(|s| s.iter().map(|x| *x as i32).collect_robj())
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn markov_blanket_of_ptr(g: ExternalPtr<GraphView>, i: i32) -> Robj {
    g.as_ref()
        .markov_blanket_of(i as u32)
        .map(|s| s.iter().map(|x| *x as i32).collect_robj())
        .unwrap_or_else(|e| throw_r_error(e))
}

#[extendr]
fn exogenous_nodes_of_ptr(g: ExternalPtr<GraphView>, undirected_as_parents: Rbool) -> Robj {
    let undirected_as_parents = undirected_as_parents.is_true();
    g.as_ref()
        .exogenous_nodes(undirected_as_parents)
        .map(|s| s.iter().map(|&x| x as i32).collect_robj())
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
fn graph_class_ptr(g: ExternalPtr<GraphView>) -> String {
    match g.as_ref() {
        GraphView::Dag(_) => "DAG",
        GraphView::Pdag(_) => "PDAG",
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

// ── Causal queries ────────────────────────────────────────────────────────────────

#[extendr]
fn is_d_separated_ptr(g: ExternalPtr<GraphView>, xs: Integers, ys: Integers, z: Integers) -> bool {
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
    let z_u: Vec<u32> = z.iter().map(|ri| rint_to_u32(ri, "z")).collect();
    g.as_ref()
        .is_d_separated(&xs_u, &ys_u, &z_u)
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

    // builder + core
    fn graph_builder_new;
    fn graph_builder_add_edges;

    // class factory
    fn graph_builder_build_view;

    // queries
    fn parents_of_ptr;
    fn children_of_ptr;
    fn undirected_of_ptr;
    fn neighbors_of_ptr;
    fn ancestors_of_ptr;
    fn descendants_of_ptr;
    fn markov_blanket_of_ptr;
    fn exogenous_nodes_of_ptr;

    // graph properties
    fn is_simple_ptr;
    fn graph_class_ptr;

    // acyclicity test
    fn is_acyclic_ptr;

    // class tests + validator
    fn is_dag_type_ptr;
    fn is_pdag_type_ptr;

    // metrics
    fn shd_of_ptrs;
    fn hd_of_ptrs;

    // causal queries
    fn is_d_separated_ptr;
    fn adjustment_set_parents_ptr;
    fn adjustment_set_backdoor_ptr;
    fn adjustment_set_optimal_ptr;
    fn is_valid_backdoor_set_ptr;
    fn all_backdoor_sets_ptr;
}
