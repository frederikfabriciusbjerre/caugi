//! Parse the R-side constraint AST (nested named lists from
//! `R/constraints.R`) into the Rust [`Formula`] / [`Atom`] types.
//!
//! The parser is intentionally strict: any missing field or unknown
//! `kind` tag is a hard error. We'd rather fail loudly with a clear
//! message than silently accept partial input — the R surface is the
//! single source of truth for AST shape.

use super::ast::*;
use extendr_api::prelude::*;

/// Parse a single formula node.
///
/// Errors are returned as `String` so the extendr layer can decide how
/// to surface them (typically via `throw_r_error`).
pub fn parse_formula(robj: &Robj) -> Result<Formula, String> {
    let list = as_list(robj, "formula")?;
    let kind = field_string(&list, "kind")?;
    match kind.as_str() {
        "atom" => {
            let atom_robj = field(&list, "atom")?;
            Ok(Formula::Atom(parse_atom(&atom_robj)?))
        }
        "not" => {
            let body_robj = field(&list, "body")?;
            Ok(Formula::Not(Box::new(parse_formula(&body_robj)?)))
        }
        "and" => {
            let args = parse_formula_list(&field(&list, "args")?)?;
            Ok(Formula::And(args))
        }
        "or" => {
            let args = parse_formula_list(&field(&list, "args")?)?;
            Ok(Formula::Or(args))
        }
        "xor" => {
            let args = parse_formula_list(&field(&list, "args")?)?;
            if args.len() != 2 {
                return Err(format!("`xor` expects exactly 2 args, got {}", args.len()));
            }
            let mut it = args.into_iter();
            let a = it.next().unwrap();
            let b = it.next().unwrap();
            Ok(Formula::Xor(Box::new(a), Box::new(b)))
        }
        "implies" => {
            let ant = parse_formula(&field(&list, "antecedent")?)?;
            let con = parse_formula(&field(&list, "consequent")?)?;
            Ok(Formula::Implies(Box::new(ant), Box::new(con)))
        }
        "forall" | "exists" => {
            let vars = field_string_vec(&list, "vars")?;
            let scope = parse_scope(&field(&list, "scope")?)?;
            let body = Box::new(parse_formula(&field(&list, "body")?)?);
            if kind == "forall" {
                Ok(Formula::Forall { vars, scope, body })
            } else {
                Ok(Formula::Exists { vars, scope, body })
            }
        }
        "cardinality" => {
            let card_kind = parse_card_kind(&field_string(&list, "card_kind")?)?;
            let k = field_int_nonneg(&list, "k")? as u32;
            let set = parse_cardinality_set(&field(&list, "set")?)?;
            Ok(Formula::Cardinality {
                kind: card_kind,
                k,
                set,
            })
        }
        other => Err(format!("Unknown formula kind: `{}`", other)),
    }
}

fn parse_atom(robj: &Robj) -> Result<Atom, String> {
    let list = as_list(robj, "atom")?;
    let kind = field_string(&list, "kind")?;
    match kind.as_str() {
        "edge" => Ok(Atom::Edge {
            from: field_string(&list, "from")?,
            to: field_string(&list, "to")?,
            etype: field_string(&list, "etype")?,
        }),
        "membership" => Ok(Atom::Membership {
            elem: field_string(&list, "elem")?,
            query: field_string(&list, "query")?,
            args: parse_node_set_list(&field(&list, "args")?)?,
            tier: parse_tier(&field_string(&list, "tier")?)?,
        }),
        "acyclic" => Ok(Atom::Acyclic),
        "collider" => Ok(Atom::Collider {
            a: field_string(&list, "a")?,
            mid: field_string(&list, "mid")?,
            c: field_string(&list, "c")?,
        }),
        "v_structure" => Ok(Atom::VStructure {
            a: field_string(&list, "a")?,
            mid: field_string(&list, "mid")?,
            c: field_string(&list, "c")?,
        }),
        "dsep" => Ok(Atom::Dsep {
            x: field_node_set(&list, "x")?,
            y: field_node_set(&list, "y")?,
            given: field_node_set(&list, "given")?,
        }),
        other => Err(format!("Unknown atom kind: `{}`", other)),
    }
}

fn parse_scope(robj: &Robj) -> Result<Scope, String> {
    let list = as_list(robj, "scope")?;
    let kind = field_string(&list, "kind")?;
    match kind.as_str() {
        "all_nodes" => Ok(Scope::AllNodes),
        "ordered_tuples" => Ok(Scope::OrderedTuples(
            field_int_nonneg(&list, "arity")? as usize
        )),
        "unordered_sets" => Ok(Scope::UnorderedSets(
            field_int_nonneg(&list, "arity")? as usize
        )),
        "named_set" => Ok(Scope::NamedSet(field_string_vec(&list, "names")?)),
        other => Err(format!("Unknown scope kind: `{}`", other)),
    }
}

fn parse_card_kind(s: &str) -> Result<CardKind, String> {
    match s {
        "at_most" => Ok(CardKind::AtMost),
        "at_least" => Ok(CardKind::AtLeast),
        "exactly" => Ok(CardKind::Exactly),
        other => Err(format!("Unknown cardinality kind: `{}`", other)),
    }
}

fn parse_cardinality_set(robj: &Robj) -> Result<CardinalitySet, String> {
    let list = as_list(robj, "cardinality set")?;
    let kind = field_string(&list, "kind")?;
    match kind.as_str() {
        "formulas" => {
            let formulas = parse_formula_list(&field(&list, "formulas")?)?;
            Ok(CardinalitySet::Formulas(formulas))
        }
        "query" => Ok(CardinalitySet::Query {
            name: field_string(&list, "query")?,
            args: parse_node_set_list(&field(&list, "args")?)?,
            tier: parse_tier(&field_string(&list, "tier")?)?,
        }),
        other => Err(format!("Unknown cardinality set kind: `{}`", other)),
    }
}

fn parse_tier(s: &str) -> Result<AtomTier, String> {
    match s {
        "A" => Ok(AtomTier::A),
        "B" => Ok(AtomTier::B),
        "C" => Ok(AtomTier::C),
        other => Err(format!("Unknown atom tier: `{}`", other)),
    }
}

fn parse_formula_list(robj: &Robj) -> Result<Vec<Formula>, String> {
    let list = as_list(robj, "formula list")?;
    list.iter().map(|(_, v)| parse_formula(&v)).collect()
}

fn parse_node_set_list(robj: &Robj) -> Result<Vec<NodeSet>, String> {
    let list = as_list(robj, "node-set list")?;
    list.iter().map(|(_, v)| robj_to_node_set(&v)).collect()
}

fn robj_to_node_set(robj: &Robj) -> Result<NodeSet, String> {
    if let Some(s) = robj.as_str() {
        return Ok(vec![s.to_string()]);
    }
    if let Some(strs) = robj.as_str_vector() {
        return Ok(strs.into_iter().map(String::from).collect());
    }
    Err(format!(
        "Expected a node set (character vector), got: {:?}",
        robj.rtype()
    ))
}

// ── named-list field helpers ───────────────────────────────────────────────

fn as_list<'a>(robj: &'a Robj, ctx: &str) -> Result<List, String> {
    robj.as_list()
        .ok_or_else(|| format!("Expected list for {}, got {:?}", ctx, robj.rtype()))
}

fn field(list: &List, key: &str) -> Result<Robj, String> {
    for (name, value) in list.iter() {
        if name == key {
            return Ok(value);
        }
    }
    Err(format!("Missing field `{}`", key))
}

fn field_string(list: &List, key: &str) -> Result<String, String> {
    let v = field(list, key)?;
    v.as_str()
        .map(String::from)
        .ok_or_else(|| format!("Field `{}` must be a single string", key))
}

fn field_string_vec(list: &List, key: &str) -> Result<Vec<String>, String> {
    let v = field(list, key)?;
    if let Some(s) = v.as_str() {
        return Ok(vec![s.to_string()]);
    }
    if let Some(strs) = v.as_str_vector() {
        return Ok(strs.into_iter().map(String::from).collect());
    }
    Err(format!("Field `{}` must be a character vector", key))
}

fn field_int_nonneg(list: &List, key: &str) -> Result<i32, String> {
    let v = field(list, key)?;
    let i = v
        .as_integer()
        .or_else(|| v.as_real().map(|f| f as i32))
        .ok_or_else(|| format!("Field `{}` must be a non-negative integer", key))?;
    if i < 0 {
        return Err(format!("Field `{}` must be non-negative, got {}", key, i));
    }
    Ok(i)
}

fn field_node_set(list: &List, key: &str) -> Result<NodeSet, String> {
    let v = field(list, key)?;
    robj_to_node_set(&v)
}
