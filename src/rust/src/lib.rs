// SPDX-License-Identifier: MIT
//! R bindings for caugi graph library.

use extendr_api::prelude::*;
pub mod edges;
pub mod graph;

use edges::{EdgeClass, EdgeRegistry, EdgeSpec, Mark};
use graph::builder::GraphBuilder;

#[cfg(feature = "gadjid")]
use graph::metrics::aid;
use graph::metrics::{hd, shd_with_perm};

use graph::view::GraphView;
use graph::{admg::Admg, dag::Dag, pdag::Pdag, ug::Ug, CaugiGraph};
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
        "UG" => {
            let ug = Ug::new(Arc::new(core.as_ref().clone())).unwrap_or_else(|e| throw_r_error(e));
            ExternalPtr::new(GraphView::Ug(Arc::new(ug)))
        }
        "ADMG" => {
            let admg =
                Admg::new(Arc::new(core.as_ref().clone())).unwrap_or_else(|e| throw_r_error(e));
            ExternalPtr::new(GraphView::Admg(Arc::new(admg)))
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
fn parents_of_ptr(g: ExternalPtr<GraphView>, idxs: Integers) -> Robj {
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        // check if index is out of bounds
        if i >= g.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i));
        }
        let v = g
            .as_ref()
            .parents_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(v.into_iter().map(|&x| x as i32).collect_robj());
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn children_of_ptr(g: ExternalPtr<GraphView>, idxs: Integers) -> Robj {
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        if i >= g.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i));
        }
        let v = g
            .as_ref()
            .children_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(v.into_iter().map(|&x| x as i32).collect_robj());
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn undirected_of_ptr(g: ExternalPtr<GraphView>, idxs: Integers) -> Robj {
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        if i >= g.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i));
        }
        let v = g
            .as_ref()
            .undirected_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(v.into_iter().map(|&x| x as i32).collect_robj());
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn neighbors_of_ptr(g: ExternalPtr<GraphView>, idxs: Integers) -> Robj {
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        if i >= g.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i));
        }
        let v = g
            .as_ref()
            .neighbors_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(v.into_iter().map(|&x| x as i32).collect_robj());
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn ancestors_of_ptr(g: ExternalPtr<GraphView>, idxs: Integers) -> Robj {
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        if i >= g.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i));
        }
        let v = g
            .as_ref()
            .ancestors_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(v.iter().map(|&x| x as i32).collect_robj());
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn descendants_of_ptr(g: ExternalPtr<GraphView>, idxs: Integers) -> Robj {
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        if i >= g.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i));
        }
        let v = g
            .as_ref()
            .descendants_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(v.iter().map(|&x| x as i32).collect_robj());
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn markov_blanket_of_ptr(g: ExternalPtr<GraphView>, idxs: Integers) -> Robj {
    let mut out: Vec<Robj> = Vec::with_capacity(idxs.len());
    for ri in idxs.iter() {
        let i = rint_to_u32(ri, "idxs");
        if i >= g.as_ref().n() {
            throw_r_error(format!("Index {} is out of bounds", i));
        }
        let v = g
            .as_ref()
            .markov_blanket_of(i)
            .unwrap_or_else(|e| throw_r_error(e));
        out.push(v.iter().map(|&x| x as i32).collect_robj());
    }
    extendr_api::prelude::List::from_values(out).into_robj()
}

#[extendr]
fn exogenous_nodes_of_ptr(g: ExternalPtr<GraphView>, undirected_as_parents: Rbool) -> Robj {
    let undirected_as_parents = undirected_as_parents.is_true();
    g.as_ref()
        .exogenous_nodes(undirected_as_parents)
        .map(|s| s.iter().map(|&x| x as i32).collect_robj())
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
fn graph_class_ptr(g: ExternalPtr<GraphView>) -> String {
    match g.as_ref() {
        GraphView::Dag(_) => "DAG",
        GraphView::Pdag(_) => "PDAG",
        GraphView::Ug(_) => "UG",
        GraphView::Admg(_) => "ADMG",
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
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
    let z_u: Vec<u32> = z.iter().map(|ri| rint_to_u32(ri, "z")).collect();
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
    let xs_u: Vec<u32> = xs.iter().map(|ri| rint_to_u32(ri, "xs")).collect();
    let ys_u: Vec<u32> = ys.iter().map(|ri| rint_to_u32(ri, "ys")).collect();
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

#[cfg(feature = "gadjid")]
fn to_aid_input(view: &GraphView) -> std::result::Result<aid::AidInput<'_>, String> {
    match view {
        GraphView::Dag(d) => Ok(aid::AidInput::Dag(d.as_ref())),
        GraphView::Pdag(p) => Ok(aid::AidInput::Pdag(p.as_ref())),
        _ => Err("expected graph of type DAG or PDAG".into()),
    }
}

#[cfg(feature = "gadjid")]
fn build_inv_from_names(
    names_true: &extendr_api::prelude::Strings,
    names_guess: &extendr_api::prelude::Strings,
) -> std::result::Result<Vec<usize>, String> {
    use std::collections::HashMap;
    let n = names_true.len();
    if n != names_guess.len() {
        return Err("names length must match number of nodes".into());
    }
    let mut idx_guess: HashMap<String, usize> = HashMap::with_capacity(n);
    for (i, s) in names_guess.iter().enumerate() {
        let k = s.as_str().to_string();
        if idx_guess.insert(k, i).is_some() {
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

// ── Layout ────────────────────────────────────────────────────────────────────

#[extendr]
fn compute_layout_ptr(g: ExternalPtr<GraphView>, method: &str) -> Robj {
    use graph::layout::{compute_layout, LayoutMethod};
    use std::str::FromStr;

    let layout_method = LayoutMethod::from_str(method).unwrap_or_else(|e| throw_r_error(e));

    let coords =
        compute_layout(g.as_ref().core(), layout_method).unwrap_or_else(|e| throw_r_error(e));

    let n = coords.len();
    let mut x = Vec::with_capacity(n);
    let mut y = Vec::with_capacity(n);

    for (xi, yi) in coords {
        x.push(xi);
        y.push(yi);
    }

    list!(x = x, y = y).into_robj()
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
    fn topological_sort_ptr;
    fn induced_subgraph_ptr;

    // graph properties
    fn is_simple_ptr;
    fn graph_class_ptr;

    // graph operations
    fn skeleton_ptr;
    fn moralize_ptr;

    // acyclicity test and conversion
    fn is_acyclic_ptr;
    fn to_cpdag_ptr;
    fn is_cpdag_ptr;

    // class tests + validator
    fn is_dag_type_ptr;
    fn is_pdag_type_ptr;
    fn is_ug_type_ptr;
    fn is_admg_type_ptr;

    // ADMG-specific queries
    fn spouses_of_ptr;
    fn districts_ptr;
    fn district_of_ptr;
    fn m_separated_ptr;
    fn is_valid_adjustment_set_admg_ptr;
    fn all_adjustment_sets_admg_ptr;

    // metrics
    fn shd_of_ptrs;
    fn hd_of_ptrs;

    fn ancestor_aid_of_ptrs;
    fn oset_aid_of_ptrs;
    fn parent_aid_of_ptrs;

    // causal queries
    fn d_separated_ptr;
    fn adjustment_set_parents_ptr;
    fn adjustment_set_backdoor_ptr;
    fn adjustment_set_optimal_ptr;
    fn is_valid_backdoor_set_ptr;
    fn all_backdoor_sets_ptr;

    // graph transformations
    fn proper_backdoor_graph_ptr;
    fn moral_of_ancestors_ptr;
    fn ancestral_reduction_ptr;

    // view df
    fn n_ptr;
    fn edges_ptr_df;

    // layout
    fn compute_layout_ptr;
    fn compute_bipartite_layout_ptr;

    // serialization
    fn write_caugi_file_ptr;
    fn read_caugi_file_ptr;
    fn serialize_caugi_ptr;
    fn deserialize_caugi_ptr;
}
