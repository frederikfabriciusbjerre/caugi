//! Reconstruct edge triples from a SAT model.
//!
//! For every (class-permitted) edge variable that's true in the model,
//! emit a `(from, to, etype)` triple. Symmetric edge types are emitted
//! with `from < to` (canonical form).

use super::varmap::VarMap;

pub type EdgeTriple = (String, String, &'static str);

pub fn edges_from_model(model: &[bool], var_map: &VarMap) -> Vec<EdgeTriple> {
    let mut edges = Vec::new();
    for (from, to, etype, var) in var_map.iter_all_edges() {
        let idx = (var - 1) as usize;
        if idx < model.len() && model[idx] {
            edges.push((
                var_map.name_at(from).to_string(),
                var_map.name_at(to).to_string(),
                etype,
            ));
        }
    }
    edges
}
