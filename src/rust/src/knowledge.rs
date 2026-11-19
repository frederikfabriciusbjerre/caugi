// SPDX-License-Identifier: MIT
//! Background knowledge: what each pair of nodes may be.
//!
//! A statement, a tier and an exogenous node each say which of three things a
//! pair {a, b} may be: no edge, `a --> b` or `b --> a`. That set is
//! [`Allowed`]. Combining knowledge is intersection, and a contradiction is
//! the empty set.

use bitflags::bitflags;
use std::collections::{BTreeMap, HashMap, VecDeque};

bitflags! {
    /// What the pair {a, b}, a < b, may be.
    #[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
    pub struct Allowed: u8 {
        /// No edge.
        const NONE = 1;
        /// `a --> b`.
        const AB = 2;
        /// `b --> a`.
        const BA = 4;
    }
}

impl Allowed {
    /// Adjacent, either way.
    pub const ADJACENT: Self = Self::AB.union(Self::BA);
    /// Anything but `a --> b`.
    pub const NOT_AB: Self = Self::NONE.union(Self::BA);
    /// Anything but `b --> a`.
    pub const NOT_BA: Self = Self::NONE.union(Self::AB);

    /// The set the statement `a <glyph> b` allows.
    pub fn of_glyph(glyph: &str) -> Option<Self> {
        match glyph {
            "-->" => Some(Self::AB),
            "!-->" => Some(Self::NOT_AB),
            "---" => Some(Self::ADJACENT),
            "!---" => Some(Self::NONE),
            _ => None,
        }
    }

    /// The statement that allows exactly this set: its glyph, and whether it
    /// is written from b to a. `None` for no constraint or a contradiction.
    pub fn glyph(self) -> Option<(&'static str, bool)> {
        match self {
            Self::AB => Some(("-->", false)),
            Self::BA => Some(("-->", true)),
            Self::ADJACENT => Some(("---", false)),
            Self::NONE => Some(("!---", false)),
            Self::NOT_AB => Some(("!-->", false)),
            Self::NOT_BA => Some(("!-->", true)),
            _ => None,
        }
    }

    /// The same set, seen from b.
    pub fn flip(self) -> Self {
        let mut out = self & Self::NONE;
        out.set(Self::AB, self.contains(Self::BA));
        out.set(Self::BA, self.contains(Self::AB));
        out
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

pub const MAX_LAG: &str = "`max_lag` must be a whole number of at least 1, and needs tiers.";

/// A statement as written: from, glyph, to.
pub type Row = (String, &'static str, String);

/// Background knowledge over a set of named nodes.
#[derive(Clone, Debug, Default)]
pub struct Knowledge {
    names: Vec<String>,
    index: HashMap<String, u32>,
    /// Statements on pairs (a, b), a < b.
    statements: Vec<(u32, u32, Allowed)>,
    /// Tier names, earliest first.
    tier_names: Vec<String>,
    /// The tier of each node.
    tier: Vec<Option<u32>>,
    max_lag: Option<u32>,
    exogenous: Vec<bool>,
}

impl Knowledge {
    /// Knowledge on `names`. Every statement, tier and exogenous node must
    /// name nodes in `names`.
    pub fn new<G: AsRef<str>>(
        names: &[String],
        statements: &[(String, G, String)],
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
    pub fn statements(&self) -> Vec<Row> {
        self.statements
            .iter()
            .map(|&(a, b, m)| self.row(a, b, m))
            .collect()
    }

    /// The tightest statement about each pair the knowledge constrains.
    pub fn expand(&self) -> Vec<Row> {
        self.constrained()
            .into_iter()
            .map(|(a, b, m)| self.row(a, b, m))
            .collect()
    }

    // ── Reading ─────────────────────────────────────────────────────────────

    /// The statements combined per pair.
    fn said(&self) -> BTreeMap<(u32, u32), Allowed> {
        let mut said = BTreeMap::new();
        for &(a, b, m) in &self.statements {
            *said.entry((a, b)).or_insert(Allowed::all()) &= m;
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

    fn row(&self, a: u32, b: u32, m: Allowed) -> Row {
        let (glyph, flip) = m.glyph().expect("a statement allows a set with a glyph");
        let (from, to) = if flip { (b, a) } else { (a, b) };
        (
            self.names[from as usize].clone(),
            glyph,
            self.names[to as usize].clone(),
        )
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

    fn ids(&self, names: &[String]) -> Result<Vec<u32>> {
        let unknown: Vec<&str> = names
            .iter()
            .filter(|x| !self.index.contains_key(*x))
            .map(String::as_str)
            .collect();
        if !unknown.is_empty() {
            return invalid(format!("Unknown node(s): {}", unknown.join(", ")));
        }
        Ok(names.iter().map(|x| self.index[x]).collect())
    }

    fn put_statements<G: AsRef<str>>(&mut self, statements: &[(String, G, String)]) -> Result<()> {
        let from: Vec<String> = statements.iter().map(|r| r.0.clone()).collect();
        let to: Vec<String> = statements.iter().map(|r| r.2.clone()).collect();
        let (a, b) = (self.ids(&from)?, self.ids(&to)?);
        for ((&a, &b), (_, glyph, _)) in a.iter().zip(&b).zip(statements) {
            if a == b {
                return invalid("Knowledge can't relate a node to itself.");
            }
            let glyph = glyph.as_ref();
            let Some(m) = Allowed::of_glyph(glyph) else {
                return invalid(format!("Not a knowledge edge: {glyph}"));
            };
            self.statements
                .push(if a < b { (a, b, m) } else { (b, a, m.flip()) });
        }
        self.statements.sort();
        self.statements.dedup();
        Ok(())
    }

    fn put_tiers(&mut self, tiers: &[(String, Vec<String>)], max_lag: Option<u32>) -> Result<()> {
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
        self.max_lag = max_lag;
        Ok(())
    }

    fn put_exogenous(&mut self, names: &[String]) -> Result<()> {
        self.exogenous = vec![false; self.names.len()];
        for i in self.ids(names)? {
            self.exogenous[i as usize] = true;
        }
        Ok(())
    }

    /// Checks the tiers, and that some DAG satisfies the knowledge. Only the
    /// pairs the statements name can be required to be adjacent, so they are
    /// the only pairs that can contradict each other.
    fn validate(&self) -> Result<()> {
        if !self.tier_names.is_empty() {
            let untiered: Vec<&str> = self
                .names
                .iter()
                .zip(&self.tier)
                .filter(|(_, t)| t.is_none())
                .map(|(x, _)| x.as_str())
                .collect();
            if !untiered.is_empty() {
                return invalid(format!("Node(s) without a tier: {}", untiered.join(", ")));
            }
        }
        if self
            .max_lag
            .is_some_and(|lag| lag == 0 || self.tier_names.is_empty())
        {
            return invalid(MAX_LAG);
        }

        let said = self.said();
        let mut clash = vec![];
        let mut forced = vec![];
        for &(a, b) in said.keys() {
            let m = self.allowed(&said, a, b);
            if m.is_empty() {
                clash.push(format!(
                    "{} and {}",
                    self.names[a as usize], self.names[b as usize]
                ));
            } else if m == Allowed::AB {
                forced.push((a, b));
            } else if m == Allowed::BA {
                forced.push((b, a));
            }
        }
        if !clash.is_empty() {
            return Err(KnowledgeError::Inconsistent(format!(
                "Knowledge contradicts itself: {} must be adjacent, but no direction is allowed.",
                clash.join(", ")
            )));
        }
        if has_cycle(self.names.len(), &forced) {
            return Err(KnowledgeError::Inconsistent(
                "Knowledge contradicts itself: the required directions form a cycle.".into(),
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

    fn st(rows: &[(&str, &str, &str)]) -> Vec<(String, String, String)> {
        rows.iter()
            .map(|(a, g, b)| (a.to_string(), g.to_string(), b.to_string()))
            .collect()
    }

    fn kn(nodes: &[&str], rows: &[(&str, &str, &str)]) -> Result<Knowledge> {
        Knowledge::new(&s(nodes), &st(rows), &[], None, &[])
    }

    #[test]
    fn glyphs_round_trip() {
        for g in ["-->", "!-->", "---", "!---"] {
            let m = Allowed::of_glyph(g).unwrap();
            assert_eq!(m.glyph(), Some((g, false)));
            assert_eq!(m.flip().flip(), m);
        }
        assert_eq!(Allowed::AB.flip(), Allowed::BA);
        assert_eq!(Allowed::NOT_AB.flip().glyph(), Some(("!-->", true)));
        assert_eq!(Allowed::all().glyph(), None);
        assert_eq!(Allowed::empty().glyph(), None);
        assert_eq!(Allowed::of_glyph("<->"), None);
    }

    #[test]
    fn expand_gives_the_tightest_statement_per_pair() {
        let k = kn(
            &["A", "B", "C", "D"],
            &[("B", "-->", "A"), ("C", "!-->", "D"), ("A", "!---", "D")],
        )
        .unwrap();
        assert_eq!(
            k.expand(),
            vec![
                ("B".into(), "-->", "A".into()),
                ("A".into(), "!---", "D".into()),
                ("C".into(), "!-->", "D".into()),
            ]
        );
        // Statements are kept as written, one way round.
        assert_eq!(k.statements().len(), 3);
    }

    #[test]
    fn tiers_and_exogenous_nodes_constrain_pairs() {
        let tiers = vec![
            ("t1".to_string(), s(&["A"])),
            ("t2".to_string(), s(&["B"])),
            ("t3".to_string(), s(&["C"])),
        ];
        let k =
            Knowledge::new(&s(&["A", "B", "C"]), &st(&[]), &tiers, Some(1), &s(&["B"])).unwrap();
        // B is exogenous, and A and C are two tiers apart.
        assert_eq!(
            k.expand(),
            vec![
                ("A".into(), "!---", "B".into()),
                ("A".into(), "!---", "C".into()),
                ("C".into(), "!-->", "B".into()),
            ]
        );
        assert_eq!(k.tier_of(), vec![Some("t1"), Some("t2"), Some("t3")]);
        assert_eq!(k.tiers()[1], ("t2".to_string(), s(&["B"])));
    }

    #[test]
    fn contradictions_are_found() {
        let inconsistent = |r: Result<Knowledge>| matches!(r, Err(KnowledgeError::Inconsistent(_)));
        assert!(inconsistent(kn(
            &["A", "B"],
            &[("A", "-->", "B"), ("B", "-->", "A")]
        )));
        assert!(inconsistent(kn(
            &["A", "B"],
            &[("A", "---", "B"), ("B", "!---", "A")]
        )));
        assert!(inconsistent(kn(
            &["A", "B", "C"],
            &[("A", "-->", "B"), ("B", "-->", "C"), ("C", "-->", "A")]
        )));
        assert!(kn(
            &["A", "B", "C"],
            &[("A", "-->", "B"), ("B", "-->", "C"), ("A", "-->", "C")]
        )
        .is_ok());
    }

    #[test]
    fn bad_input_is_invalid() {
        let msg = |r: Result<Knowledge>| match r {
            Err(KnowledgeError::Invalid(m)) => m,
            other => panic!("expected an invalid input, got {other:?}"),
        };
        assert_eq!(msg(kn(&["A"], &[("A", "-->", "D")])), "Unknown node(s): D");
        assert!(msg(kn(&["A"], &[("A", "-->", "A")])).contains("itself"));
        assert!(msg(kn(&["A", "B"], &[("A", "<->", "B")])).contains("<->"));
        let two = vec![("a".to_string(), s(&["A"])), ("a".to_string(), s(&["B"]))];
        assert!(msg(Knowledge::new(&s(&["A", "B"]), &st(&[]), &two, None, &[])).contains("unique"));
        let both = vec![
            ("1".to_string(), s(&["A"])),
            ("2".to_string(), s(&["A", "B"])),
        ];
        assert!(
            msg(Knowledge::new(&s(&["A", "B"]), &st(&[]), &both, None, &[])).contains("one tier")
        );
        let some = vec![("1".to_string(), s(&["A"]))];
        assert!(msg(Knowledge::new(&s(&["A", "B"]), &st(&[]), &some, None, &[])).contains("B"));
        assert_eq!(
            msg(Knowledge::new(&s(&["A"]), &st(&[]), &[], Some(1), &[])),
            MAX_LAG
        );
    }

    #[test]
    fn statements_tiers_and_exogenous_nodes_are_kept() {
        let k = kn(
            &["A", "B", "C"],
            &[("B", "!-->", "A"), ("C", "---", "A"), ("A", "---", "C")],
        )
        .unwrap();
        // One way round, without duplicates, and printed as written.
        assert_eq!(
            k.statements(),
            vec![
                ("B".into(), "!-->", "A".into()),
                ("A".into(), "---", "C".into())
            ]
        );
        let tiers = vec![
            ("t1".to_string(), s(&["A"])),
            ("t2".to_string(), s(&["B", "C"])),
        ];
        let k =
            Knowledge::new(&s(&["A", "B", "C"]), &st(&[]), &tiers, Some(1), &s(&["C"])).unwrap();
        assert_eq!(k.tier_of(), vec![Some("t1"), Some("t2"), Some("t2")]);
        assert_eq!(k.tiers(), tiers);
        assert_eq!(k.max_lag(), Some(1));
        assert_eq!(k.exogenous(), &[false, false, true]);
    }
}
