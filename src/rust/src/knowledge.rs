// SPDX-License-Identifier: MIT
//! Background knowledge: what each pair of nodes may be.
//!
//! A statement, a tier and an exogenous node each say which of three things a
//! pair {a, b} may be: no edge, `a --> b` or `b --> a`. That set is
//! [`Allowed`]. Combining knowledge is intersection, and a contradiction is
//! the empty set.

use bitflags::bitflags;
use std::collections::{BTreeMap, HashMap, VecDeque};

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
}

impl Knowledge {
    /// Knowledge on `names`. Every statement, tier and exogenous node must
    /// name nodes in `names`. Empty tiers are dropped, and `max_lag` with the
    /// last one.
    pub fn new(
        names: &[String],
        statements: &[Statement],
        tiers: &[(String, Vec<String>)],
        max_lag: Option<u32>,
        exogenous: &[String],
    ) -> Result<Self> {
        let mut k = Self::default();
        for name in names {
            k.push_node(name);
        }
        k.put_statements(statements)?;
        k.put_tiers(tiers, max_lag)?;
        k.put_exogenous(exogenous)?;
        k.validate()?;
        Ok(k)
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
        Knowledge::new(&s(nodes), &st(rows), &[], None, &[])
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
        let k = Knowledge::new(&s(&["A", "B", "C"]), &[], &tiers, Some(1), &s(&["C"])).unwrap();
        assert_eq!(k.tier_of(), vec![Some("t1"), Some("t2"), None]);
        assert_eq!(k.tiers(), tiers[..2]);
        assert_eq!(k.max_lag(), Some(1));
        assert_eq!(k.exogenous(), &[false, false, true]);
        // `max_lag` goes with the last tier.
        let k = Knowledge::new(&s(&["A"]), &[], &t(&[("t1", &[])]), Some(1), &[]);
        assert_eq!(k.unwrap().max_lag(), None);
    }

    #[test]
    fn bad_input_is_invalid() {
        let msg = |r: Result<Knowledge>| match r {
            Err(KnowledgeError::Invalid(m)) => m,
            other => panic!("expected an invalid input, got {other:?}"),
        };
        let with_tiers = |tiers: &[(&str, &[&str])], lag: Option<u32>| {
            Knowledge::new(&s(&["A", "B"]), &[], &t(tiers), lag, &[])
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
        let k =
            Knowledge::new(&s(&["A", "B", "C", "D"]), &[], &tiers, Some(1), &s(&["B"])).unwrap();
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
        );
        assert!(inconsistent(tiered));
        assert!(kn(
            &["A", "B", "C"],
            &[("A", "B", true), ("B", "C", true), ("A", "C", true)]
        )
        .is_ok());
    }
}
