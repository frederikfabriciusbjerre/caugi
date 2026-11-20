// SPDX-License-Identifier: MIT
//! Generative checks of knowledge against a brute-force oracle, which reads
//! the definitions straight off each DAG. A DAG on `n` nodes is a bitmask:
//! bit `a * n + b` is the edge `a --> b`.

use super::tests::{core, pdag};
use super::*;
use crate::graph::dag::Dag;

const NAMES: [&str; 6] = ["A", "B", "C", "D", "E", "F"];

fn names(n: usize) -> Vec<String> {
    NAMES[..n].iter().map(|x| x.to_string()).collect()
}

/// xorshift64, so every run draws the same cases.
struct Rng(u64);

impl Rng {
    fn below(&mut self, n: usize) -> usize {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        (self.0 % n as u64) as usize
    }

    fn chance(&mut self, p: f64) -> bool {
        (self.below(1000) as f64) < p * 1000.0
    }

    fn shuffled(&mut self, n: usize) -> Vec<usize> {
        let mut v: Vec<usize> = (0..n).collect();
        for i in (1..n).rev() {
            v.swap(i, self.below(i + 1));
        }
        v
    }
}

fn edge(n: usize, d: u64, a: usize, b: usize) -> bool {
    d >> (a * n + b) & 1 == 1
}

/// A topological order of `d`, if it is acyclic.
fn topological(n: usize, d: u64) -> Option<Vec<usize>> {
    let mut order = vec![];
    while order.len() < n {
        let next = (0..n).find(|&v| {
            !order.contains(&v) && (0..n).all(|u| order.contains(&u) || !edge(n, d, u, v))
        })?;
        order.push(next);
    }
    Some(order)
}

/// Every DAG on `n` nodes.
fn all_dags(n: usize) -> Vec<u64> {
    let pairs: Vec<(usize, usize)> = (0..n)
        .flat_map(|a| (a + 1..n).map(move |b| (a, b)))
        .collect();
    (0..3u64.pow(pairs.len() as u32))
        .map(|mut state| {
            let mut d = 0;
            for &(a, b) in &pairs {
                match state % 3 {
                    1 => d |= 1 << (a * n + b),
                    2 => d |= 1 << (b * n + a),
                    _ => {}
                }
                state /= 3;
            }
            d
        })
        .filter(|&d| topological(n, d).is_some())
        .collect()
}

/// Knowledge written out plainly: statements as (from, to, required), and a
/// tier and an exogenous flag per node.
#[derive(Clone, Debug)]
struct Spec {
    n: usize,
    statements: Vec<(usize, usize, bool)>,
    tier: Vec<Option<u32>>,
    max_lag: Option<u32>,
    exogenous: Vec<bool>,
}

impl Spec {
    fn new(n: usize) -> Self {
        Spec {
            n,
            statements: vec![],
            tier: vec![None; n],
            max_lag: None,
            exogenous: vec![false; n],
        }
    }

    fn of(n: usize, rows: &[Statement]) -> Self {
        let id = |x: &str| NAMES.iter().position(|&y| y == x).unwrap();
        let statements = rows
            .iter()
            .map(|s| (id(&s.from), id(&s.to), s.required))
            .collect();
        Spec {
            statements,
            ..Spec::new(n)
        }
    }

    /// Does the DAG `d` satisfy the spec, by the definitions?
    fn holds(&self, d: u64) -> bool {
        let n = self.n;
        let fits = |a: usize, b: usize| {
            !self.exogenous[b]
                && match (self.tier[a], self.tier[b]) {
                    (Some(ta), Some(tb)) => ta <= tb && self.max_lag.map_or(true, |l| tb - ta <= l),
                    _ => true,
                }
        };
        self.statements
            .iter()
            .all(|&(a, b, r)| edge(n, d, a, b) == r)
            && (0..n).all(|a| (0..n).all(|b| !edge(n, d, a, b) || fits(a, b)))
    }

    fn statements(&self) -> Vec<Statement> {
        self.statements
            .iter()
            .map(|&(a, b, required)| Statement {
                from: NAMES[a].into(),
                to: NAMES[b].into(),
                required,
            })
            .collect()
    }

    fn tiers(&self) -> Vec<(String, Vec<String>)> {
        let count = self.tier.iter().flatten().max().map_or(0, |t| t + 1);
        (0..count)
            .map(|t| {
                let members = (0..self.n).filter(|&v| self.tier[v] == Some(t));
                (format!("t{t}"), members.map(|v| NAMES[v].into()).collect())
            })
            .collect()
    }

    fn exogenous(&self) -> Vec<String> {
        (0..self.n)
            .filter(|&v| self.exogenous[v])
            .map(|v| NAMES[v].into())
            .collect()
    }

    fn build(&self, names: &[String]) -> Result<Knowledge> {
        let (tiers, exogenous) = (self.tiers(), self.exogenous());
        Knowledge::new(
            names,
            &self.statements(),
            &tiers,
            self.max_lag,
            &exogenous,
            false,
        )
    }
}

/// Random knowledge on `n` nodes. With `truth`, the DAG satisfies it.
fn random_spec(rng: &mut Rng, n: usize, truth: Option<u64>) -> Spec {
    let mut spec = Spec::new(n);
    // Random knowledge leans on required edges, so they can form cycles.
    for _ in 0..rng.below(9) {
        let a = rng.below(n);
        let b = (a + 1 + rng.below(n - 1)) % n;
        let required = match truth {
            Some(d) => edge(n, d, a, b),
            None => rng.chance(0.6),
        };
        spec.statements.push((a, b, required));
    }
    if rng.chance(0.4) {
        // Tiers cut a topological order of `truth`, or a random order, and
        // skip some nodes.
        let order = truth.map_or_else(|| rng.shuffled(n), |d| topological(n, d).unwrap());
        let mut t = 0;
        for v in order {
            t += rng.chance(0.4) as u32;
            spec.tier[v] = (!rng.chance(0.2)).then_some(t);
        }
        // Number the tiers in use from 0, as knowledge drops empty ones.
        let mut used: Vec<u32> = spec.tier.iter().flatten().copied().collect();
        used.sort();
        used.dedup();
        for t in spec.tier.iter_mut().flatten() {
            *t = used.iter().position(|u| u == t).unwrap() as u32;
        }
        if used.len() > 1 && rng.chance(0.5) {
            let gaps = (0..n * n)
                .filter(|&i| truth.is_some_and(|d| edge(n, d, i / n, i % n)))
                .filter_map(|i| Some(spec.tier[i % n]?.abs_diff(spec.tier[i / n]?)));
            spec.max_lag = Some(gaps.max().unwrap_or(1).max(1));
        }
    }
    if rng.chance(0.3) {
        for b in 0..n {
            let has_parent = |d: u64| (0..n).any(|a| edge(n, d, a, b));
            spec.exogenous[b] = rng.chance(0.5) && !truth.is_some_and(has_parent);
        }
    }
    spec
}

#[test]
fn knowledge_matches_the_oracle_on_every_dag_over_four_nodes() {
    let dags = all_dags(4);
    assert_eq!(dags.len(), 543);
    let mut rng = Rng(1);
    for case in 0..2000 {
        let truth = rng.chance(0.5).then(|| dags[rng.below(dags.len())]);
        let spec = random_spec(&mut rng, 4, truth);
        let sat: Vec<bool> = dags.iter().map(|&d| spec.holds(d)).collect();
        match spec.build(&names(4)) {
            // Contradictions are found exactly.
            Err(e) => {
                assert!(
                    matches!(e, KnowledgeError::Inconsistent(_)),
                    "case {case}: {e:?}"
                );
                assert!(!sat.contains(&true), "case {case}: {spec:?}")
            }
            Ok(k) => {
                assert!(sat.contains(&true), "case {case}: {spec:?}");
                // The expanded statements allow exactly the same DAGs.
                let rows = Spec::of(4, &k.expand());
                let same = dags.iter().zip(&sat).all(|(&d, &s)| rows.holds(d) == s);
                assert!(same, "case {case}: {spec:?}");
            }
        }
    }
}

#[test]
fn edits_match_the_oracle() {
    let dags = all_dags(4);
    let mut rng = Rng(2);
    for case in 0..500 {
        // Statements edited one at a time match a plain list, and an edit
        // that leaves no DAG fails and changes nothing.
        let mut k = Knowledge::new(&names(4), &[], &[], None, &[], true).unwrap();
        let mut list = Spec::new(4);
        for _ in 0..8 {
            let a = rng.below(4);
            let b = (a + 1 + rng.below(3)) % 4;
            let edit = [Edit::Add, Edit::Set, Edit::Remove][rng.below(3)];
            let status = [None, Some(true), Some(false)][rng.below(3)];
            let row = [(NAMES[a].to_string(), NAMES[b].to_string(), status)];
            let mut next = list.clone();
            let s = &mut next.statements;
            match (edit, status) {
                (Edit::Remove, _) => {
                    s.retain(|&(f, t, r)| (f, t) != (a, b) || status.is_some_and(|q| q != r))
                }
                (_, None) => {
                    assert!(k.edit(edit, &row).is_err(), "case {case}");
                    continue;
                }
                (Edit::Set, Some(r)) => {
                    s.retain(|&(f, t, _)| (f, t) != (a, b));
                    s.push((a, b, r));
                }
                (_, Some(r)) => s.push((a, b, r)),
            }
            s.sort();
            s.dedup();
            let possible = dags.iter().any(|&d| next.holds(d));
            match k.edit(edit, &row) {
                Ok(edited) => {
                    assert!(possible, "case {case}: {next:?}");
                    (k, list) = (edited, next);
                }
                Err(e) => {
                    assert!(
                        matches!(e, KnowledgeError::Inconsistent(_)),
                        "case {case}: {e:?}"
                    );
                    assert!(!possible, "case {case}");
                }
            }
            assert_eq!(k.statements(), list.statements(), "case {case}");
        }
        // Building through the edits gives what new() gives.
        let truth = rng.chance(0.5).then(|| dags[rng.below(dags.len())]);
        let spec = random_spec(&mut rng, 4, truth);
        let rows: Vec<_> = spec
            .statements()
            .into_iter()
            .map(|s| (s.from, s.to, Some(s.required)))
            .collect();
        let built = Knowledge::new(&names(4), &[], &[], None, &[], false)
            .and_then(|k| k.edit(Edit::Add, &rows))
            .and_then(|k| k.set_exogenous(&spec.exogenous()))
            .and_then(|k| k.set_tiers(&spec.tiers(), spec.max_lag));
        let inconsistent =
            |r: &Result<Knowledge>| matches!(r, Err(KnowledgeError::Inconsistent(_)));
        match (spec.build(&names(4)), built) {
            (Ok(a), Ok(b)) => assert_eq!(a.expand(), b.expand(), "case {case}"),
            (a, b) => assert!(
                inconsistent(&a) && inconsistent(&b),
                "case {case}: {a:?} {b:?}"
            ),
        }
    }
}

/// The DAG `d` as a bitmask.
fn mask(n: usize, d: &Dag) -> u64 {
    (0..n)
        .flat_map(|a| {
            d.children_of(a as u32)
                .iter()
                .map(move |&b| (a, b as usize))
        })
        .fold(0, |m, (a, b)| m | 1 << (a * n + b))
}

fn members(n: usize, g: &Pdag) -> Vec<u64> {
    let mut out: Vec<u64> = g
        .enumerate_mec()
        .unwrap()
        .iter()
        .map(|d| mask(n, d))
        .collect();
    out.sort();
    out
}

#[test]
fn holds_and_orient_match_the_dags_a_graph_stands_for() {
    let mut rng = Rng(3);
    for case in 0..300 {
        let n = 4 + rng.below(3);
        let order = rng.shuffled(n);
        let p = 0.2 + rng.below(50) as f64 / 100.0;
        let mut dag = 0u64;
        for i in 0..n {
            for j in i + 1..n {
                if rng.chance(p) {
                    dag |= 1 << (order[i] * n + order[j]);
                }
            }
        }
        let dag_edges: Vec<(u32, u32, &str)> = (0..n * n)
            .filter(|&i| edge(n, dag, i / n, i % n))
            .map(|i| ((i / n) as u32, (i % n) as u32, "-->"))
            .collect();
        // The CPDAG of the DAG, and half the time a PDAG between the two that
        // Meek's rules haven't closed.
        let cpdag = Dag::new(core(n as u32, &dag_edges))
            .unwrap()
            .to_cpdag()
            .unwrap();
        let cpdag = cpdag.as_mpdag().as_pdag();
        let mut edges = vec![];
        let mut undirected = vec![];
        for a in 0..n as u32 {
            for &b in cpdag.children_of(a) {
                edges.push((a, b, "-->"));
            }
            for &b in cpdag.undirected_of(a).iter().filter(|&&b| b > a) {
                if rng.chance(0.25) {
                    let forward = edge(n, dag, a as usize, b as usize);
                    edges.push(if forward {
                        (a, b, "-->")
                    } else {
                        (b, a, "-->")
                    });
                } else {
                    edges.push((a, b, "---"));
                    undirected.push((a as usize, b as usize));
                }
            }
        }
        let graph = pdag(n as u32, &edges);
        let all = members(n, &graph);

        let spec = match rng.below(4) {
            0 => random_spec(&mut rng, n, Some(dag)),
            1 => random_spec(&mut rng, n, None),
            // Orientations of undirected edges: fine alone, but they can
            // contradict the graph through Meek's rules.
            2 => {
                let mut spec = Spec::new(n);
                for &(a, b) in &undirected {
                    if rng.chance(0.5) {
                        let (f, t) = if rng.chance(0.5) { (a, b) } else { (b, a) };
                        spec.statements.push((f, t, true));
                    }
                }
                spec
            }
            _ => {
                let mut spec = Spec::new(n);
                spec.exogenous[rng.below(n)] = true;
                spec
            }
        };
        // Half the time, the knowledge names only the nodes it constrains.
        let named: Vec<String> = if rng.chance(0.5) {
            names(n)
        } else {
            let used = |v: usize| {
                spec.tier[v].is_some()
                    || spec.exogenous[v]
                    || spec.statements.iter().any(|s| s.0 == v || s.1 == v)
            };
            (0..n)
                .filter(|&v| used(v))
                .map(|v| NAMES[v].into())
                .collect()
        };
        let Ok(k) = spec.build(&named) else { continue };
        let k = k.on(&names(n)).unwrap();
        let closed = graph.meek_closure().unwrap();

        // holds(): TRUE in every member DAG, FALSE in none, NA otherwise.
        for (s, holds) in k.holds(closed.as_pdag()) {
            let one = Spec::of(n, &[s]);
            let count = all.iter().filter(|&&d| one.holds(d)).count();
            let expected = match count {
                c if c == all.len() => Some(true),
                0 => Some(false),
                _ => None,
            };
            assert_eq!(holds, expected, "case {case}");
        }
        // orient(): exactly the member DAGs that satisfy the knowledge.
        let sat: Vec<u64> = all.iter().copied().filter(|&d| spec.holds(d)).collect();
        match k.orient(&closed) {
            Ok(m) => assert_eq!(members(n, m.as_pdag()), sat, "case {case}"),
            Err(e) => {
                assert!(
                    matches!(e, KnowledgeError::Inconsistent(_)),
                    "case {case}: {e:?}"
                );
                assert!(sat.is_empty(), "case {case}");
            }
        }
        // A DAG is only checked.
        let one = pdag(n as u32, &dag_edges).meek_closure().unwrap();
        assert_eq!(k.orient(&one).is_ok(), spec.holds(dag), "case {case}");
    }
}
