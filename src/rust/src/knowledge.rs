// SPDX-License-Identifier: MIT
//! Background knowledge: what each pair of nodes may be.
//!
//! A statement, a tier and an exogenous node each say which of three things a
//! pair {a, b} may be: no edge, `a --> b` or `b --> a`. That set is
//! [`Allowed`]. Combining knowledge is intersection, and a contradiction is
//! the empty set.

use crate::graph::alg::meek;
use crate::graph::mpdag::Mpdag;
use crate::graph::pdag::Pdag;
use bitflags::bitflags;
use std::collections::{BTreeMap, HashMap, HashSet, VecDeque};
use std::fmt;

#[cfg(test)]
mod oracle;

bitflags! {
    /// What the pair {a, b}, a < b, may be.
    #[derive(Clone, Copy, Debug, PartialEq, Eq)]
    pub struct Allowed: u8 {
        /// No edge.
        const NONE = 1;
        /// `a --> b`.
        const AB = 2;
        /// `b --> a`.
        const BA = 4;
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum KnowledgeError {
    /// Malformed input, such as an unknown node.
    Invalid(String),
    /// No DAG satisfies the knowledge.
    Inconsistent(String),
}

pub type Result<T> = std::result::Result<T, KnowledgeError>;

fn invalid<T>(msg: impl Into<String>) -> Result<T> {
    Err(KnowledgeError::Invalid(msg.into()))
}

pub const MAX_LAG: &str = "`max_lag` must be a whole number of at least 1.";

/// A statement about the edge `from --> to`: required, or forbidden.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Statement {
    pub from: String,
    pub to: String,
    pub required: bool,
}

/// `A --> B` if required, `!(A --> B)` if forbidden.
impl fmt::Display for Statement {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let edge = format!("{} --> {}", self.from, self.to);
        if self.required {
            write!(f, "{edge}")
        } else {
            write!(f, "!({edge})")
        }
    }
}

/// What an edit does with the statements it names.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Edit {
    /// Adds them.
    Add,
    /// Replaces what is said about each `from --> to`.
    Set,
    /// Removes them; with no status, both kinds.
    Remove,
}

/// Background knowledge over a set of named nodes.
#[derive(Clone, Debug, Default)]
pub struct Knowledge {
    names: Vec<String>,
    index: HashMap<String, u32>,
    /// Statements as written: from, to, required.
    statements: Vec<(u32, u32, bool)>,
    /// Tier names, earliest first.
    tier_names: Vec<String>,
    /// The tier of each node, if it has one.
    tier: Vec<Option<u32>>,
    max_lag: Option<u32>,
    exogenous: Vec<bool>,
    /// When set, the nodes are fixed: no edit may add one.
    closed: bool,
}

impl Knowledge {
    /// Knowledge on `names`. Every statement, tier and exogenous node must
    /// name nodes in `names`. Empty tiers are dropped, and `max_lag` with the
    /// last one. With `closed`, later edits may not add nodes.
    pub fn new(
        names: &[String],
        statements: &[Statement],
        tiers: &[(String, Vec<String>)],
        max_lag: Option<u32>,
        exogenous: &[String],
        closed: bool,
    ) -> Result<Self> {
        let mut k = Self::default();
        for name in names {
            k.push_node(name);
        }
        k.put_statements(statements)?;
        k.put_tiers(tiers, max_lag)?;
        k.put_exogenous(exogenous)?;
        k.closed = closed;
        k.validate()?;
        Ok(k)
    }

    // ── Edits ───────────────────────────────────────────────────────────────

    /// The knowledge after an edit of its statements, as (from, to,
    /// required), where `None` means either kind. Adding or setting a
    /// statement adds the nodes it names, unless the nodes are closed.
    pub fn edit(&self, edit: Edit, statements: &[(String, String, Option<bool>)]) -> Result<Self> {
        self.edited(|k| {
            if edit == Edit::Remove {
                let ends = k.ends(statements.iter().map(|r| (&r.0, &r.1)))?;
                for ((a, b), (_, _, required)) in ends.into_iter().zip(statements) {
                    k.statements
                        .retain(|&(f, t, r)| (f, t) != (a, b) || required.is_some_and(|q| q != r));
                }
                return Ok(());
            }
            let mut rows = vec![];
            for (from, to, required) in statements {
                let Some(required) = *required else {
                    return invalid("A statement must be required or forbidden.");
                };
                rows.push(Statement {
                    from: from.clone(),
                    to: to.clone(),
                    required,
                });
            }
            k.grow(rows.iter().flat_map(|s| [&s.from, &s.to]))?;
            if edit == Edit::Set {
                let ends = k.ends(rows.iter().map(|s| (&s.from, &s.to)))?;
                k.statements.retain(|&(f, t, _)| !ends.contains(&(f, t)));
            }
            k.put_statements(&rows)
        })
    }

    pub fn add_nodes(&self, names: &[String]) -> Result<Self> {
        self.edited(|k| k.grow(names))
    }

    /// The knowledge without these nodes and what it says about them.
    pub fn remove_nodes(&self, names: &[String]) -> Result<Self> {
        let gone: HashSet<u32> = self.ids(names)?.into_iter().collect();
        let rest: Vec<String> = (0..self.names.len() as u32)
            .filter(|i| !gone.contains(i))
            .map(|i| self.names[i as usize].clone())
            .collect();
        self.rebuilt(&rest, self.closed)
    }

    /// The knowledge with these tiers, adding the nodes they name.
    pub fn set_tiers(&self, tiers: &[(String, Vec<String>)], max_lag: Option<u32>) -> Result<Self> {
        self.edited(|k| {
            k.grow(tiers.iter().flat_map(|t| &t.1))?;
            k.put_tiers(tiers, max_lag)
        })
    }

    /// The knowledge with these exogenous nodes, adding them if new.
    pub fn set_exogenous(&self, names: &[String]) -> Result<Self> {
        self.edited(|k| {
            k.grow(names)?;
            k.put_exogenous(names)
        })
    }

    // ── Reading ─────────────────────────────────────────────────────────────

    pub fn names(&self) -> &[String] {
        &self.names
    }

    /// The tier name of each node.
    pub fn tier_of(&self) -> Vec<Option<&str>> {
        let name = |t: u32| self.tier_names[t as usize].as_str();
        self.tier.iter().map(|t| t.map(name)).collect()
    }

    /// Tier names with their nodes, earliest first.
    pub fn tiers(&self) -> Vec<(String, Vec<String>)> {
        let mut out: Vec<(String, Vec<String>)> = self
            .tier_names
            .iter()
            .map(|t| (t.clone(), vec![]))
            .collect();
        for (i, t) in self.tier.iter().enumerate() {
            if let Some(t) = t {
                out[*t as usize].1.push(self.names[i].clone());
            }
        }
        out
    }

    pub fn max_lag(&self) -> Option<u32> {
        self.max_lag
    }

    pub fn exogenous(&self) -> &[bool] {
        &self.exogenous
    }

    /// The statements as written.
    pub fn statements(&self) -> Vec<Statement> {
        self.statements
            .iter()
            .map(|&(f, t, required)| self.statement(f, t, required))
            .collect()
    }

    /// The fewest statements that say everything the knowledge says about
    /// each constrained pair.
    pub fn expand(&self) -> Vec<Statement> {
        self.constrained()
            .into_iter()
            .flat_map(|(a, b, m)| self.rows(a, b, m))
            .collect()
    }

    // ── Graphs ──────────────────────────────────────────────────────────────

    /// The same knowledge on a graph's nodes, in its order. Nodes the
    /// knowledge doesn't name are added, so exogenous nodes rule out edges
    /// from them too.
    pub fn on(&self, names: &[String]) -> Result<Self> {
        let k = self.rebuilt(names, false)?;
        k.ids(&self.names)?;
        Ok(k)
    }

    /// For each statement of [`Knowledge::expand`], whether it holds in every
    /// DAG `g` stands for (`Some(true)`), in none (`Some(false)`), or in some
    /// (`None`). `g` must be closed under Meek's rules, on the knowledge's
    /// nodes.
    pub fn holds(&self, g: &Pdag) -> Vec<(Statement, Option<bool>)> {
        self.expand()
            .into_iter()
            .map(|s| {
                let (a, b) = (self.index[&s.from], self.index[&s.to]);
                let says = if s.required {
                    Allowed::AB
                } else {
                    !Allowed::AB
                };
                let have = allowed_in(g, a, b);
                let holds = if says.contains(have) {
                    Some(true)
                } else if (says & have).is_empty() {
                    Some(false)
                } else {
                    None
                };
                (s, holds)
            })
            .collect()
    }

    /// The tightest MPDAG that agrees with both `g` and the knowledge. `g`
    /// must be closed under Meek's rules, on the knowledge's nodes. Edges are
    /// oriented one at a time, each followed by Meek's rules (Algorithm 1 of
    /// Perković et al., 2017).
    pub fn orient(&self, g: &Mpdag) -> Result<Mpdag> {
        let pdag = g.as_pdag();
        let undirected = Allowed::AB | Allowed::BA;
        let mut violated = vec![];
        let mut required = vec![];
        for (a, b, m) in self.constrained() {
            let have = allowed_in(pdag, a, b);
            match m & have {
                x if x.is_empty() => violated.extend(self.rows(a, b, m)),
                Allowed::AB if have == undirected => required.push((a, b)),
                Allowed::BA if have == undirected => required.push((b, a)),
                _ => {}
            }
        }
        if !violated.is_empty() {
            let rows: Vec<String> = violated.iter().map(Statement::to_string).collect();
            return Err(KnowledgeError::Inconsistent(format!(
                "Knowledge contradicts the graph: {}",
                rows.join(", ")
            )));
        }
        let (mut pa, mut ch, mut und) = pdag.adjacency_sets();
        for (a, b) in required {
            if ch[a as usize].contains(&b) {
                continue;
            }
            if !und[a as usize].contains(&b) {
                let (a, b) = (&self.names[a as usize], &self.names[b as usize]);
                return Err(KnowledgeError::Inconsistent(format!(
                    "Knowledge contradicts the graph: it needs {a} --> {b}, \
                     but {b} --> {a} follows from the rest."
                )));
            }
            meek::orient(a, b, &mut und, &mut pa, &mut ch);
            meek::apply_meek_closure(&mut pa, &mut ch, &mut und, true);
        }
        pdag.mpdag_from_sets(&pa, &ch, &und)
            .map_err(KnowledgeError::Invalid)
    }

    // ── Internals ───────────────────────────────────────────────────────────

    /// The statements combined per pair (a, b), a < b.
    fn said(&self) -> BTreeMap<(u32, u32), Allowed> {
        let mut said = BTreeMap::new();
        for &(f, t, required) in &self.statements {
            let dir = if f < t { Allowed::AB } else { Allowed::BA };
            let m = if required { dir } else { !dir };
            *said.entry((f.min(t), f.max(t))).or_insert(Allowed::all()) &= m;
        }
        said
    }

    /// Everything the knowledge says about the pair {a, b}, a < b.
    fn allowed(&self, said: &BTreeMap<(u32, u32), Allowed>, a: u32, b: u32) -> Allowed {
        let mut m = said.get(&(a, b)).copied().unwrap_or(Allowed::all());
        if let (Some(ta), Some(tb)) = (self.tier[a as usize], self.tier[b as usize]) {
            if ta < tb {
                m.remove(Allowed::BA);
            } else if tb < ta {
                m.remove(Allowed::AB);
            }
            if self.max_lag.is_some_and(|lag| ta.abs_diff(tb) > lag) {
                m &= Allowed::NONE;
            }
        }
        if self.exogenous[b as usize] {
            m.remove(Allowed::AB);
        }
        if self.exogenous[a as usize] {
            m.remove(Allowed::BA);
        }
        m
    }

    /// Every pair with a constraint, and what it allows.
    fn constrained(&self) -> Vec<(u32, u32, Allowed)> {
        let said = self.said();
        let n = self.names.len() as u32;
        (0..n)
            .flat_map(|a| (a + 1..n).map(move |b| (a, b)))
            .map(|(a, b)| (a, b, self.allowed(&said, a, b)))
            .filter(|&(_, _, m)| m != Allowed::all())
            .collect()
    }

    /// The fewest statements that allow exactly `m` for the pair {a, b}: one
    /// required edge, or one forbidden edge per direction `m` rules out.
    fn rows(&self, a: u32, b: u32, m: Allowed) -> Vec<Statement> {
        match m {
            Allowed::AB => vec![self.statement(a, b, true)],
            Allowed::BA => vec![self.statement(b, a, true)],
            _ => [(Allowed::AB, a, b), (Allowed::BA, b, a)]
                .into_iter()
                .filter(|&(dir, ..)| !m.contains(dir))
                .map(|(_, f, t)| self.statement(f, t, false))
                .collect(),
        }
    }

    fn statement(&self, from: u32, to: u32, required: bool) -> Statement {
        Statement {
            from: self.names[from as usize].clone(),
            to: self.names[to as usize].clone(),
            required,
        }
    }

    // ── Building ────────────────────────────────────────────────────────────

    fn push_node(&mut self, name: &str) {
        if !self.index.contains_key(name) {
            self.index.insert(name.to_string(), self.names.len() as u32);
            self.names.push(name.to_string());
            self.tier.push(None);
            self.exogenous.push(false);
        }
    }

    /// Adds the nodes it doesn't know yet, or errors if the nodes are closed.
    fn grow<'a>(&mut self, names: impl IntoIterator<Item = &'a String>) -> Result<()> {
        if self.closed {
            return self.ids(names).map(|_| ());
        }
        for name in names {
            self.push_node(name);
        }
        Ok(())
    }

    /// A checked copy of the knowledge after `change`.
    fn edited(&self, change: impl FnOnce(&mut Self) -> Result<()>) -> Result<Self> {
        let mut k = self.clone();
        change(&mut k)?;
        k.validate()?;
        Ok(k)
    }

    /// The knowledge on `names`: what it says about other nodes is dropped,
    /// and new nodes are added.
    fn rebuilt(&self, names: &[String], closed: bool) -> Result<Self> {
        let kept: HashSet<&String> = names.iter().collect();
        let statements: Vec<Statement> = self
            .statements()
            .into_iter()
            .filter(|s| kept.contains(&s.from) && kept.contains(&s.to))
            .collect();
        let tiers: Vec<(String, Vec<String>)> = self
            .tiers()
            .into_iter()
            .map(|(t, m)| (t, m.into_iter().filter(|x| kept.contains(x)).collect()))
            .collect();
        let exogenous: Vec<String> = self
            .names
            .iter()
            .zip(&self.exogenous)
            .filter(|(x, &e)| e && kept.contains(x))
            .map(|(x, _)| x.clone())
            .collect();
        Knowledge::new(names, &statements, &tiers, self.max_lag, &exogenous, closed)
    }

    fn ids<'a>(&self, names: impl IntoIterator<Item = &'a String>) -> Result<Vec<u32>> {
        let names: Vec<&String> = names.into_iter().collect();
        let unknown: Vec<&str> = names
            .iter()
            .filter(|x| !self.index.contains_key(**x))
            .map(|x| x.as_str())
            .collect();
        if !unknown.is_empty() {
            return invalid(format!("Unknown node(s): {}", unknown.join(", ")));
        }
        Ok(names.iter().map(|x| self.index[*x]).collect())
    }

    /// The node ids at both ends of each (from, to).
    fn ends<'a>(
        &self,
        pairs: impl IntoIterator<Item = (&'a String, &'a String)>,
    ) -> Result<Vec<(u32, u32)>> {
        let (from, to): (Vec<_>, Vec<_>) = pairs.into_iter().unzip();
        Ok(self.ids(from)?.into_iter().zip(self.ids(to)?).collect())
    }

    fn put_statements(&mut self, statements: &[Statement]) -> Result<()> {
        let ends = self.ends(statements.iter().map(|s| (&s.from, &s.to)))?;
        for ((f, t), s) in ends.into_iter().zip(statements) {
            if f == t {
                return invalid("Knowledge can't relate a node to itself.");
            }
            self.statements.push((f, t, s.required));
        }
        self.statements.sort();
        self.statements.dedup();
        Ok(())
    }

    fn put_tiers(&mut self, tiers: &[(String, Vec<String>)], max_lag: Option<u32>) -> Result<()> {
        let tiers: Vec<_> = tiers.iter().filter(|t| !t.1.is_empty()).collect();
        let mut names: Vec<&String> = tiers.iter().map(|t| &t.0).collect();
        names.sort();
        if names.windows(2).any(|w| w[0] == w[1]) {
            return invalid("Tier names must be unique.");
        }
        self.tier = vec![None; self.names.len()];
        for (t, (_, members)) in tiers.iter().enumerate() {
            for i in self.ids(members)? {
                if self.tier[i as usize].replace(t as u32).is_some() {
                    return invalid("A node can be in only one tier.");
                }
            }
        }
        self.tier_names = tiers.iter().map(|t| t.0.clone()).collect();
        self.max_lag = max_lag.filter(|_| !tiers.is_empty());
        Ok(())
    }

    fn put_exogenous(&mut self, names: &[String]) -> Result<()> {
        self.exogenous = vec![false; self.names.len()];
        for i in self.ids(names)? {
            self.exogenous[i as usize] = true;
        }
        Ok(())
    }

    /// Checks `max_lag`, and that some DAG satisfies the knowledge. Only the
    /// pairs the statements name can contradict each other, and only required
    /// edges can form a cycle.
    fn validate(&self) -> Result<()> {
        if self.max_lag == Some(0) {
            return invalid(MAX_LAG);
        }
        let said = self.said();
        let clash: Vec<String> = said
            .keys()
            .filter(|&&(a, b)| self.allowed(&said, a, b).is_empty())
            .map(|&(a, b)| format!("{} and {}", self.names[a as usize], self.names[b as usize]))
            .collect();
        if !clash.is_empty() {
            return Err(KnowledgeError::Inconsistent(format!(
                "Knowledge contradicts itself about {}.",
                clash.join(", ")
            )));
        }
        let required: Vec<(u32, u32)> = self
            .statements
            .iter()
            .filter(|s| s.2)
            .map(|&(f, t, _)| (f, t))
            .collect();
        if has_cycle(self.names.len(), &required) {
            return Err(KnowledgeError::Inconsistent(
                "Knowledge contradicts itself: the required edges form a cycle.".into(),
            ));
        }
        Ok(())
    }
}

/// What the PDAG `g` allows for the pair {a, b}.
fn allowed_in(g: &Pdag, a: u32, b: u32) -> Allowed {
    if g.children_of(a).contains(&b) {
        Allowed::AB
    } else if g.parents_of(a).contains(&b) {
        Allowed::BA
    } else if g.undirected_of(a).contains(&b) {
        Allowed::AB | Allowed::BA
    } else {
        Allowed::NONE
    }
}

/// Kahn's algorithm: does the directed graph on `n` nodes have a cycle?
fn has_cycle(n: usize, edges: &[(u32, u32)]) -> bool {
    let mut indegree = vec![0usize; n];
    let mut out = vec![vec![]; n];
    for &(a, b) in edges {
        out[a as usize].push(b as usize);
        indegree[b as usize] += 1;
    }
    let mut queue: VecDeque<usize> = (0..n).filter(|&v| indegree[v] == 0).collect();
    let mut seen = 0;
    while let Some(v) = queue.pop_front() {
        seen += 1;
        for &w in &out[v] {
            indegree[w] -= 1;
            if indegree[w] == 0 {
                queue.push_back(w);
            }
        }
    }
    seen < n
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;
    use crate::graph::CaugiGraph;
    use std::sync::Arc;

    fn s(x: &[&str]) -> Vec<String> {
        x.iter().map(|v| v.to_string()).collect()
    }

    /// Statements as (from, to, required).
    fn st(rows: &[(&str, &str, bool)]) -> Vec<Statement> {
        rows.iter()
            .map(|&(a, b, required)| Statement {
                from: a.to_string(),
                to: b.to_string(),
                required,
            })
            .collect()
    }

    fn kn(nodes: &[&str], rows: &[(&str, &str, bool)]) -> Result<Knowledge> {
        Knowledge::new(&s(nodes), &st(rows), &[], None, &[], false)
    }

    fn t(rows: &[(&str, &[&str])]) -> Vec<(String, Vec<String>)> {
        rows.iter().map(|(n, m)| (n.to_string(), s(m))).collect()
    }

    #[test]
    fn statements_tiers_and_exogenous_nodes_are_kept() {
        let k = kn(
            &["A", "B", "C"],
            &[("B", "A", false), ("C", "A", true), ("C", "A", true)],
        )
        .unwrap();
        assert_eq!(k.statements(), st(&[("B", "A", false), ("C", "A", true)]));
        let tiers = t(&[("t1", &["A"]), ("t2", &["B"]), ("t3", &[])]);
        let k =
            Knowledge::new(&s(&["A", "B", "C"]), &[], &tiers, Some(1), &s(&["C"]), true).unwrap();
        assert_eq!(k.tier_of(), vec![Some("t1"), Some("t2"), None]);
        assert_eq!(k.tiers(), tiers[..2]);
        assert_eq!(k.max_lag(), Some(1));
        assert_eq!(k.exogenous(), &[false, false, true]);
        // `max_lag` goes with the last tier.
        let k = Knowledge::new(&s(&["A"]), &[], &t(&[("t1", &[])]), Some(1), &[], false);
        assert_eq!(k.unwrap().max_lag(), None);
    }

    #[test]
    fn bad_input_is_invalid() {
        let msg = |r: Result<Knowledge>| match r {
            Err(KnowledgeError::Invalid(m)) => m,
            other => panic!("expected an invalid input, got {other:?}"),
        };
        let with_tiers = |tiers: &[(&str, &[&str])], lag: Option<u32>| {
            Knowledge::new(&s(&["A", "B"]), &[], &t(tiers), lag, &[], false)
        };
        assert_eq!(msg(kn(&["A"], &[("A", "D", true)])), "Unknown node(s): D");
        assert!(msg(kn(&["A"], &[("A", "A", true)])).contains("itself"));
        assert!(msg(with_tiers(&[("a", &["A"]), ("a", &["B"])], None)).contains("unique"));
        assert!(msg(with_tiers(&[("1", &["A"]), ("2", &["A", "B"])], None)).contains("one tier"));
        assert_eq!(msg(with_tiers(&[("1", &["A"])], Some(0))), MAX_LAG);
    }

    #[test]
    fn expand_gives_the_fewest_statements_per_pair() {
        let k = kn(
            &["A", "B", "C", "D"],
            &[
                ("B", "A", true),
                ("C", "D", false),
                ("A", "D", false),
                ("D", "A", false),
            ],
        )
        .unwrap();
        assert_eq!(
            k.expand(),
            st(&[
                ("B", "A", true),
                ("A", "D", false),
                ("D", "A", false),
                ("C", "D", false),
            ])
        );
    }

    #[test]
    fn tiers_and_exogenous_nodes_constrain_pairs() {
        // A, B and C in three tiers, at most one apart; B exogenous; D untiered.
        let tiers = t(&[("t1", &["A"]), ("t2", &["B"]), ("t3", &["C"])]);
        let k = Knowledge::new(
            &s(&["A", "B", "C", "D"]),
            &[],
            &tiers,
            Some(1),
            &s(&["B"]),
            false,
        )
        .unwrap();
        assert_eq!(
            k.expand(),
            st(&[
                ("A", "B", false),
                ("B", "A", false),
                ("A", "C", false),
                ("C", "A", false),
                ("C", "B", false),
                ("D", "B", false),
            ])
        );
    }

    #[test]
    fn contradictions_are_found() {
        let inconsistent = |r: Result<Knowledge>| matches!(r, Err(KnowledgeError::Inconsistent(_)));
        assert!(inconsistent(kn(
            &["A", "B"],
            &[("A", "B", true), ("A", "B", false)]
        )));
        assert!(inconsistent(kn(
            &["A", "B"],
            &[("A", "B", true), ("B", "A", true)]
        )));
        assert!(inconsistent(kn(
            &["A", "B", "C"],
            &[("A", "B", true), ("B", "C", true), ("C", "A", true)]
        )));
        let tiered = Knowledge::new(
            &s(&["A", "B"]),
            &st(&[("B", "A", true)]),
            &t(&[("1", &["A"]), ("2", &["B"])]),
            None,
            &[],
            false,
        );
        assert!(inconsistent(tiered));
        assert!(kn(
            &["A", "B", "C"],
            &[("A", "B", true), ("B", "C", true), ("A", "C", true)]
        )
        .is_ok());
    }

    #[test]
    fn edits_add_set_and_remove_statements() {
        let rows = |r: &[(&str, &str, Option<bool>)]| -> Vec<(String, String, Option<bool>)> {
            r.iter()
                .map(|(a, b, q)| (a.to_string(), b.to_string(), *q))
                .collect()
        };
        let k = kn(&["A", "B"], &[("A", "B", true)]).unwrap();
        let k = k
            .edit(Edit::Add, &rows(&[("B", "C", Some(false))]))
            .unwrap();
        assert_eq!(k.names(), s(&["A", "B", "C"]).as_slice());
        let k = k
            .edit(Edit::Set, &rows(&[("A", "B", Some(false))]))
            .unwrap();
        assert_eq!(k.statements(), st(&[("A", "B", false), ("B", "C", false)]));
        // Setting C --> B leaves B --> C alone.
        let set = k
            .edit(Edit::Set, &rows(&[("C", "B", Some(false))]))
            .unwrap();
        assert_eq!(set.statements().len(), 3);
        let both = k.edit(Edit::Remove, &rows(&[("B", "C", None)])).unwrap();
        assert_eq!(both.statements(), st(&[("A", "B", false)]));
        let other = k
            .edit(Edit::Remove, &rows(&[("B", "C", Some(true))]))
            .unwrap();
        assert_eq!(other.statements().len(), 2);
        assert!(k.edit(Edit::Add, &rows(&[("A", "B", None)])).is_err());
        assert!(k.edit(Edit::Remove, &rows(&[("A", "D", None)])).is_err());
    }

    #[test]
    fn closed_knowledge_keeps_its_nodes() {
        let k = Knowledge::new(&s(&["A", "B"]), &[], &[], None, &[], true).unwrap();
        let add = vec![("A".to_string(), "C".to_string(), Some(true))];
        assert!(k.edit(Edit::Add, &add).is_err());
        assert!(k.add_nodes(&s(&["C"])).is_err());
        assert!(k.set_exogenous(&s(&["C"])).is_err());
        assert!(k.set_tiers(&t(&[("1", &["C"])]), None).is_err());
        assert!(k
            .remove_nodes(&s(&["B"]))
            .unwrap()
            .add_nodes(&s(&["B"]))
            .is_err());
    }

    #[test]
    fn edits_of_nodes_tiers_and_exogenous_nodes() {
        let tiers = t(&[("t1", &["A", "B"]), ("t2", &["C"])]);
        let k = Knowledge::new(
            &s(&["A", "B", "C"]),
            &st(&[("A", "C", true)]),
            &tiers,
            Some(1),
            &s(&["B"]),
            false,
        )
        .unwrap();
        let k2 = k.remove_nodes(&s(&["B"])).unwrap();
        assert_eq!(k2.tiers(), t(&[("t1", &["A"]), ("t2", &["C"])]));
        assert_eq!(k2.exogenous(), &[false, false]);
        // An emptied tier goes, and `max_lag` with the last one.
        let k3 = k.remove_nodes(&s(&["C"])).unwrap();
        assert_eq!(k3.tiers(), t(&[("t1", &["A", "B"])]));
        assert_eq!(k3.max_lag(), Some(1));
        assert_eq!(k3.remove_nodes(&s(&["A", "B"])).unwrap().max_lag(), None);
        assert_eq!(k.remove_nodes(&s(&["A"])).unwrap().statements(), vec![]);
        assert!(k.remove_nodes(&s(&["D"])).is_err());
        assert_eq!(k.add_nodes(&s(&["D"])).unwrap().tier_of()[3], None);
        assert_eq!(k.set_tiers(&[], None).unwrap().tiers(), vec![]);
        // C can't be exogenous: A --> C is required.
        assert!(k.set_exogenous(&s(&["C"])).is_err());
        assert_eq!(
            k.set_exogenous(&[]).unwrap().exogenous(),
            &[false, false, false]
        );
    }

    /// A graph on `n` nodes, from edges written (from, to, glyph).
    pub(super) fn core(n: u32, edges: &[(u32, u32, &str)]) -> Arc<CaugiGraph> {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        let mut b = GraphBuilder::new_with_registry(n, true, &reg);
        for &(a, c, g) in edges {
            b.add_edge(a, c, reg.code_of(g).unwrap()).unwrap();
        }
        Arc::new(b.finalize().unwrap())
    }

    pub(super) fn pdag(n: u32, edges: &[(u32, u32, &str)]) -> Pdag {
        Pdag::new(core(n, edges)).unwrap()
    }

    #[test]
    fn on_moves_knowledge_onto_a_graphs_nodes() {
        let k = Knowledge::new(&s(&["B"]), &[], &[], None, &s(&["B"]), true).unwrap();
        let on = k.on(&s(&["A", "B", "C"])).unwrap();
        assert_eq!(on.expand(), st(&[("A", "B", false), ("C", "B", false)]));
        assert!(k.on(&s(&["A"])).is_err());
    }

    #[test]
    fn holds_reads_statements_against_a_graph() {
        // A --- B --> C
        let g = pdag(3, &[(0, 1, "---"), (1, 2, "-->")]);
        let k = kn(
            &["A", "B", "C"],
            &[
                ("A", "B", true),
                ("C", "B", false),
                ("A", "C", false),
                ("B", "C", false),
            ],
        )
        .unwrap();
        let holds: Vec<Option<bool>> = k.holds(&g).into_iter().map(|r| r.1).collect();
        assert_eq!(holds, vec![None, Some(true), Some(false), Some(true)]);
    }

    #[test]
    fn orient_applies_knowledge_with_meeks_rules() {
        let g = pdag(3, &[(0, 1, "---"), (1, 2, "---")])
            .meek_closure()
            .unwrap();
        let m = kn(&["A", "B", "C"], &[("A", "B", true)])
            .unwrap()
            .orient(&g)
            .unwrap();
        assert!(m.children_of(0).contains(&1) && m.children_of(1).contains(&2));
        let m = kn(&["A", "B", "C"], &[("C", "B", false)])
            .unwrap()
            .orient(&g)
            .unwrap();
        assert!(m.children_of(1).contains(&2) && m.undirected_of(0).contains(&1));
        let err = |r: Result<Mpdag>| match r {
            Err(KnowledgeError::Inconsistent(m)) => m,
            _ => panic!("expected an inconsistency"),
        };
        let conflict = kn(&["A", "B", "C"], &[("A", "B", true), ("C", "B", true)]);
        assert!(err(conflict.unwrap().orient(&g)).contains("follows from the rest"));
        let violated = kn(&["A", "B", "C"], &[("A", "C", true)]);
        assert!(err(violated.unwrap().orient(&g)).contains("A --> C"));
    }
}
