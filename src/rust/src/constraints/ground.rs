//! Ground a [`Formula`] over the current node set.
//!
//! Grounding removes quantifiers (`forall(X, body)`, `exists(Z, body)`)
//! by enumerating ordered tuples of distinct nodes and substituting
//! each binding into the body. Parametric cardinality query forms
//! (`at_most(k, parents(X))`) survive grounding intact when their
//! query argument is concrete; if the argument is itself a bound
//! variable, grounding substitutes it.
//!
//! The result is a "closed" formula: no [`Formula::Forall`] /
//! [`Formula::Exists`] nodes remain, and every [`NodeRef`] in any atom
//! is a concrete node name (not a bound-variable placeholder — though
//! we don't have a separate [`NodeRef::Var`] variant, so substitution
//! is by name match).

use rustc_hash::FxHashMap;

use super::ast::{Atom, CardinalitySet, Formula, NodeRef, NodeSet, Scope};

/// Ground every quantifier in `formula` against the given node universe.
pub fn ground(formula: &Formula, nodes: &[String]) -> Formula {
    ground_with_env(formula, nodes, &FxHashMap::default())
}

fn ground_with_env(
    formula: &Formula,
    nodes: &[String],
    env: &FxHashMap<String, String>,
) -> Formula {
    match formula {
        Formula::Atom(a) => Formula::Atom(substitute_atom(a, env)),
        Formula::Not(body) => Formula::Not(Box::new(ground_with_env(body, nodes, env))),
        Formula::And(args) => Formula::And(
            args.iter()
                .map(|f| ground_with_env(f, nodes, env))
                .collect(),
        ),
        Formula::Or(args) => Formula::Or(
            args.iter()
                .map(|f| ground_with_env(f, nodes, env))
                .collect(),
        ),
        Formula::Xor(p, q) => Formula::Xor(
            Box::new(ground_with_env(p, nodes, env)),
            Box::new(ground_with_env(q, nodes, env)),
        ),
        Formula::Implies(p, q) => Formula::Implies(
            Box::new(ground_with_env(p, nodes, env)),
            Box::new(ground_with_env(q, nodes, env)),
        ),
        Formula::Cardinality { kind, k, set } => Formula::Cardinality {
            kind: *kind,
            k: *k,
            set: substitute_cardinality_set(set, nodes, env),
        },
        Formula::Forall { vars, scope, body } => {
            let tuples = enumerate_tuples(scope, nodes, vars.len());
            let mut conj = Vec::with_capacity(tuples.len());
            for tup in tuples {
                let new_env = extend_env(env, vars, &tup);
                conj.push(ground_with_env(body, nodes, &new_env));
            }
            if conj.is_empty() {
                Formula::And(Vec::new()) // vacuously true
            } else if conj.len() == 1 {
                conj.into_iter().next().unwrap()
            } else {
                Formula::And(conj)
            }
        }
        Formula::Exists { vars, scope, body } => {
            let tuples = enumerate_tuples(scope, nodes, vars.len());
            let mut disj = Vec::with_capacity(tuples.len());
            for tup in tuples {
                let new_env = extend_env(env, vars, &tup);
                disj.push(ground_with_env(body, nodes, &new_env));
            }
            if disj.is_empty() {
                Formula::Or(Vec::new()) // vacuously false
            } else if disj.len() == 1 {
                disj.into_iter().next().unwrap()
            } else {
                Formula::Or(disj)
            }
        }
    }
}

fn substitute_cardinality_set(
    set: &CardinalitySet,
    nodes: &[String],
    env: &FxHashMap<String, String>,
) -> CardinalitySet {
    match set {
        CardinalitySet::Formulas(formulas) => CardinalitySet::Formulas(
            formulas
                .iter()
                .map(|f| ground_with_env(f, nodes, env))
                .collect(),
        ),
        CardinalitySet::Query { name, args, tier } => CardinalitySet::Query {
            name: name.clone(),
            args: args.iter().map(|a| substitute_node_set(a, env)).collect(),
            tier: *tier,
        },
    }
}

fn substitute_atom(atom: &Atom, env: &FxHashMap<String, String>) -> Atom {
    match atom {
        Atom::Edge { from, to, etype } => Atom::Edge {
            from: substitute_ref(from, env),
            to: substitute_ref(to, env),
            etype: etype.clone(),
        },
        Atom::Membership {
            elem,
            query,
            args,
            tier,
        } => Atom::Membership {
            elem: substitute_ref(elem, env),
            query: query.clone(),
            args: args.iter().map(|a| substitute_node_set(a, env)).collect(),
            tier: *tier,
        },
        Atom::Acyclic => Atom::Acyclic,
        Atom::Collider { a, mid, c } => Atom::Collider {
            a: substitute_ref(a, env),
            mid: substitute_ref(mid, env),
            c: substitute_ref(c, env),
        },
        Atom::VStructure { a, mid, c } => Atom::VStructure {
            a: substitute_ref(a, env),
            mid: substitute_ref(mid, env),
            c: substitute_ref(c, env),
        },
        Atom::Dsep { x, y, given } => Atom::Dsep {
            x: substitute_node_set(x, env),
            y: substitute_node_set(y, env),
            given: substitute_node_set(given, env),
        },
    }
}

fn substitute_ref(n: &NodeRef, env: &FxHashMap<String, String>) -> NodeRef {
    env.get(n).cloned().unwrap_or_else(|| n.clone())
}

fn substitute_node_set(set: &NodeSet, env: &FxHashMap<String, String>) -> NodeSet {
    set.iter().map(|n| substitute_ref(n, env)).collect()
}

fn extend_env(
    base: &FxHashMap<String, String>,
    vars: &[String],
    values: &[String],
) -> FxHashMap<String, String> {
    let mut e = base.clone();
    for (v, val) in vars.iter().zip(values.iter()) {
        e.insert(v.clone(), val.clone());
    }
    e
}

/// Enumerate ordered tuples of distinct nodes for the given scope and
/// arity. `AllNodes` is treated as `OrderedTuples(arity)` against the
/// supplied universe.
fn enumerate_tuples(scope: &Scope, nodes: &[String], arity: usize) -> Vec<Vec<String>> {
    let universe: &[String] = match scope {
        Scope::AllNodes | Scope::OrderedTuples(_) => nodes,
        Scope::UnorderedSets(_) => nodes, // currently treated as ordered too
        Scope::NamedSet(names) => names,
    };
    if arity == 0 {
        return vec![vec![]];
    }
    if universe.len() < arity {
        return vec![];
    }
    let mut out = Vec::new();
    let mut current = Vec::with_capacity(arity);
    permute(universe, arity, &mut current, &mut out);
    out
}

fn permute(
    universe: &[String],
    remaining: usize,
    current: &mut Vec<String>,
    out: &mut Vec<Vec<String>>,
) {
    if remaining == 0 {
        out.push(current.clone());
        return;
    }
    for v in universe {
        if current.iter().any(|x| x == v) {
            continue;
        }
        current.push(v.clone());
        permute(universe, remaining - 1, current, out);
        current.pop();
    }
}
