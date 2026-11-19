// SPDX-License-Identifier: MIT
//! Generative checks of knowledge against a brute-force oracle, which reads
//! the definitions straight off each DAG. A DAG on `n` nodes is a bitmask:
//! bit `a * n + b` is the edge `a --> b`.

use super::*;

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
            Err(KnowledgeError::Inconsistent(_)) => {
                assert!(!sat.contains(&true), "case {case}: {spec:?}")
            }
            Err(e) => panic!("case {case}: {e:?}"),
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
                Err(KnowledgeError::Inconsistent(_)) => assert!(!possible, "case {case}"),
                Err(e) => panic!("case {case}: {e:?}"),
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
        match (spec.build(&names(4)), built) {
            (Ok(a), Ok(b)) => assert_eq!(a.expand(), b.expand(), "case {case}"),
            (Err(KnowledgeError::Inconsistent(_)), Err(KnowledgeError::Inconsistent(_))) => {}
            other => panic!("case {case}: {other:?}"),
        }
    }
}
