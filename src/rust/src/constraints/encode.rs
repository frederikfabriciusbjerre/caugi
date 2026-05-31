//! Encode a (grounded) [`Formula`] into CNF for the SAT backend.
//!
//! Pipeline:
//!   1. Allocate variables for the node set per the chosen
//!      [`GraphClass`] ([`VarMap`]).
//!   2. Post class invariants — edge-type mutex per pair, plus
//!      acyclicity on the directed substructure for DAG/PDAG/ADMG.
//!   3. Walk the formula tree via Tseitin transformation.
//!   4. Add the top-level literal as a unit clause.
//!
//! Tier-C atoms (`dsep`, `msep`, discriminating paths) are rejected at
//! encode time.

use rustc_hash::FxHashMap;

use super::ast::{Atom, AtomTier, CardKind, CardinalitySet, Formula, NodeRef};
use super::cardinality::{self, AuxAllocator, Lit};
use super::class::GraphClass;
use super::varmap::VarMap;

#[derive(Debug)]
pub struct Encoding {
    pub clauses: Vec<Vec<Lit>>,
    pub var_map: VarMap,
}

/// Encode a list of top-level formulas against a node set under the
/// chosen graph class.
pub fn encode(
    formulas: &[Formula],
    nodes: Vec<String>,
    class: GraphClass,
) -> Result<Encoding, String> {
    let mut var_map = VarMap::new(nodes, class);
    let mut clauses: Vec<Vec<Lit>> = Vec::new();
    encode_class_invariants(&mut clauses, &var_map);
    let mut ctx = EncodeCtx::new(&mut var_map, &mut clauses);
    for f in formulas {
        let lit = ctx.encode_formula(f)?;
        ctx.clauses.push(vec![lit]);
    }
    Ok(Encoding { clauses, var_map })
}

// ── class invariants ────────────────────────────────────────────────────────

fn encode_class_invariants(clauses: &mut Vec<Vec<Lit>>, vm: &VarMap) {
    encode_edge_mutex(clauses, vm);
    if vm.class().requires_directed_acyclicity() {
        encode_directed_acyclicity(clauses, vm);
    }
}

/// At most one edge type per pair `(u, v)` (unordered). Implemented as
/// pairwise mutex over the relevant edge variables.
fn encode_edge_mutex(clauses: &mut Vec<Vec<Lit>>, vm: &VarMap) {
    let n = vm.n();
    let class = vm.class();
    for u in 0..n {
        for v in (u + 1)..n {
            // Collect every edge variable touching the unordered pair
            // {u, v} across the class's edge types.
            let mut vars: Vec<i32> = Vec::new();
            for (glyph, _symmetric) in class.edge_types().iter().copied() {
                if glyph == "-->" {
                    vars.push(vm.edge_var(u, v, glyph));
                    vars.push(vm.edge_var(v, u, glyph));
                } else {
                    vars.push(vm.edge_var(u, v, glyph));
                }
            }
            for i in 0..vars.len() {
                for j in (i + 1)..vars.len() {
                    clauses.push(vec![-vars[i], -vars[j]]);
                }
            }
        }
    }
}

/// Acyclicity on the directed substructure. Uses reach variables and
/// the standard transitive-closure axioms; only `-->` edges
/// contribute to reach.
fn encode_directed_acyclicity(clauses: &mut Vec<Vec<Lit>>, vm: &VarMap) {
    if !vm.has_edge_type("-->") {
        return;
    }
    let n = vm.n();

    // edge(u, v) → reach(u, v)
    for u in 0..n {
        for v in 0..n {
            if u == v {
                continue;
            }
            let ev = vm.edge_var(u, v, "-->");
            let rv = vm.reach_var(u, v);
            clauses.push(vec![-ev, rv]);
        }
    }

    // reach(u, w) ∧ edge(w, v) → reach(u, v)
    for u in 0..n {
        for w in 0..n {
            if u == w {
                continue;
            }
            for v in 0..n {
                if w == v {
                    continue;
                }
                let ruw = vm.reach_var(u, w);
                let ewv = vm.edge_var(w, v, "-->");
                let ruv = vm.reach_var(u, v);
                clauses.push(vec![-ruw, -ewv, ruv]);
            }
        }
    }

    // ¬reach(v, v)
    for v in 0..n {
        clauses.push(vec![-vm.reach_var(v, v)]);
    }
}

/// Lazily add reach upper-bound axioms when a positive ancestor
/// membership atom is encountered.
fn encode_reach_upper_bound(clauses: &mut Vec<Vec<Lit>>, vm: &mut VarMap, cached: &mut Option<()>) {
    if cached.is_some() || !vm.has_edge_type("-->") {
        return;
    }
    *cached = Some(());
    let n = vm.n();
    for u in 0..n {
        for v in 0..n {
            if u == v {
                continue;
            }
            let ruv = vm.reach_var(u, v);
            let euv = vm.edge_var(u, v, "-->");
            let mut big = vec![-ruv, euv];
            for w in 0..n {
                if w == u || w == v {
                    continue;
                }
                let p = vm.fresh_aux();
                let euw = vm.edge_var(u, w, "-->");
                let rwv = vm.reach_var(w, v);
                clauses.push(vec![-p, euw]);
                clauses.push(vec![-p, rwv]);
                clauses.push(vec![-euw, -rwv, p]);
                big.push(p);
            }
            clauses.push(big);
        }
    }
}

// ── encoding context ────────────────────────────────────────────────────────

struct EncodeCtx<'a> {
    var_map: &'a mut VarMap,
    clauses: &'a mut Vec<Vec<Lit>>,
    reach_ub_added: Option<()>,
    /// Bidirected-reach aux vars, keyed by unordered `(lo, hi)`. Used
    /// for `districts` and ADMG `markov_blanket`. Lazily allocated.
    bireach: Option<FxHashMap<(usize, usize), i32>>,
    bireach_invariants: bool,
    /// Mixed-reach (forward-directed + both-way undirected) aux vars
    /// keyed by ordered `(u, v)`. Used for PDAG `anteriors` /
    /// `posteriors`. Lazily allocated.
    mreach: Option<FxHashMap<(usize, usize), i32>>,
    mreach_invariants: bool,
}

impl<'a> EncodeCtx<'a> {
    fn new(var_map: &'a mut VarMap, clauses: &'a mut Vec<Vec<Lit>>) -> Self {
        Self {
            var_map,
            clauses,
            reach_ub_added: None,
            bireach: None,
            bireach_invariants: false,
            mreach: None,
            mreach_invariants: false,
        }
    }

    fn encode_formula(&mut self, formula: &Formula) -> Result<Lit, String> {
        match formula {
            Formula::Atom(a) => self.encode_atom(a),
            Formula::Not(body) => {
                let lit = self.encode_formula(body)?;
                Ok(-lit)
            }
            Formula::And(args) => {
                if args.is_empty() {
                    return Ok(self.true_lit());
                }
                let child_lits: Vec<Lit> = args
                    .iter()
                    .map(|f| self.encode_formula(f))
                    .collect::<Result<_, _>>()?;
                let a = self.var_map.fresh_aux();
                for &c in &child_lits {
                    self.clauses.push(vec![-a, c]);
                }
                let mut neg: Vec<Lit> = child_lits.iter().map(|&c| -c).collect();
                neg.push(a);
                self.clauses.push(neg);
                Ok(a)
            }
            Formula::Or(args) => {
                if args.is_empty() {
                    return Ok(self.false_lit());
                }
                let child_lits: Vec<Lit> = args
                    .iter()
                    .map(|f| self.encode_formula(f))
                    .collect::<Result<_, _>>()?;
                let a = self.var_map.fresh_aux();
                for &c in &child_lits {
                    self.clauses.push(vec![-c, a]);
                }
                let mut pos: Vec<Lit> = child_lits.clone();
                pos.insert(0, -a);
                self.clauses.push(pos);
                Ok(a)
            }
            Formula::Xor(p, q) => {
                let lp = self.encode_formula(p)?;
                let lq = self.encode_formula(q)?;
                let a = self.var_map.fresh_aux();
                self.clauses.push(vec![-a, lp, lq]);
                self.clauses.push(vec![-a, -lp, -lq]);
                self.clauses.push(vec![-lp, lq, a]);
                self.clauses.push(vec![lp, -lq, a]);
                Ok(a)
            }
            Formula::Implies(ant, con) => {
                let lp = self.encode_formula(ant)?;
                let lq = self.encode_formula(con)?;
                let a = self.var_map.fresh_aux();
                self.clauses.push(vec![-a, -lp, lq]);
                self.clauses.push(vec![lp, a]);
                self.clauses.push(vec![-lq, a]);
                Ok(a)
            }
            Formula::Cardinality { kind, k, set } => self.encode_cardinality(*kind, *k, set),
            Formula::Forall { .. } | Formula::Exists { .. } => {
                Err("Quantifiers must be ground (forall/exists expanded) before encoding.".into())
            }
        }
    }

    fn encode_cardinality(
        &mut self,
        kind: CardKind,
        k: u32,
        set: &CardinalitySet,
    ) -> Result<Lit, String> {
        match set {
            CardinalitySet::Formulas(formulas) => {
                let lits: Vec<Lit> = formulas
                    .iter()
                    .map(|f| self.encode_formula(f))
                    .collect::<Result<_, _>>()?;
                self.encode_cardinality_over_lits(kind, k, &lits)
            }
            CardinalitySet::Query { name, args, tier } => {
                if *tier == AtomTier::C {
                    return Err(format!(
                        "Tier-C query `{}()` is evaluator-only; rejected by the encoder.",
                        name
                    ));
                }
                if args.len() != 1 {
                    return Err(format!(
                        "Cardinality query `{}()` must have exactly one argument set.",
                        name
                    ));
                }
                let lits = self.query_membership_lits(name, &args[0])?;
                self.encode_cardinality_over_lits(kind, k, &lits)
            }
        }
    }

    fn encode_cardinality_over_lits(
        &mut self,
        kind: CardKind,
        k: u32,
        lits: &[Lit],
    ) -> Result<Lit, String> {
        let a = self.var_map.fresh_aux();
        let mut alloc = AuxAllocator::new(self.var_map.n_vars() + 1);
        let extra = cardinality::encode(kind, k, lits, &mut alloc);
        let used = alloc.peek_next() - 1;
        while self.var_map.n_vars() < used {
            let _ = self.var_map.fresh_aux();
        }
        for mut cl in extra {
            cl.push(-a);
            self.clauses.push(cl);
        }
        Ok(a)
    }

    fn encode_atom(&mut self, atom: &Atom) -> Result<Lit, String> {
        match atom {
            Atom::Edge { from, to, etype } => {
                if !self.var_map.has_edge_type(etype.as_str()) {
                    return Err(format!(
                        "Edge type `{}` is not allowed in class `{}`.",
                        etype,
                        self.var_map.class()
                    ));
                }
                let f = self.resolve(from)?;
                let t = self.resolve(to)?;
                if f == t {
                    return Ok(self.false_lit());
                }
                Ok(self.var_map.edge_var(f, t, etype.as_str()))
            }
            Atom::Membership {
                elem,
                query,
                args,
                tier,
            } => {
                if *tier == AtomTier::C {
                    return Err(format!(
                        "Tier-C membership query `{}()` is evaluator-only.",
                        query
                    ));
                }
                if args.len() != 1 {
                    return Err(format!(
                        "Membership atom `{} %in% {}(...)` must have exactly one argument set.",
                        elem, query
                    ));
                }
                let target_set = &args[0];
                if target_set.len() != 1 {
                    return Err(format!(
                        "Encoder supports single-node query arguments; got {} nodes.",
                        target_set.len()
                    ));
                }
                let target = self.resolve(&target_set[0])?;
                let e = self.resolve(elem)?;
                self.membership_lit(query.as_str(), e, target)
            }
            Atom::Acyclic => {
                // The class invariants enforce acyclicity when
                // applicable. For UG (no directed edges) acyclicity is
                // trivially satisfied.
                Ok(self.true_lit())
            }
            Atom::Collider { a, mid, c } => {
                self.encode_collider(a, mid, c, /*shielded=*/ true)
            }
            Atom::VStructure { a, mid, c } => {
                self.encode_collider(a, mid, c, /*shielded=*/ false)
            }
            Atom::Dsep { .. } => {
                Err("`dsep()` is evaluator-only and not supported by the encoder.".into())
            }
        }
    }

    fn encode_collider(
        &mut self,
        a: &NodeRef,
        mid: &NodeRef,
        c: &NodeRef,
        shielded: bool,
    ) -> Result<Lit, String> {
        let ai = self.resolve(a)?;
        let mi = self.resolve(mid)?;
        let ci = self.resolve(c)?;
        if ai == mi || ci == mi || ai == ci {
            return Ok(self.false_lit());
        }
        // Arrowhead into `mid` from `ai`: an arrowhead occurs via -->
        // (ai --> mi) or <-> (ai <-> mi). The same for c.
        let into_left = self.arrowhead_into(ai, mi)?;
        let into_right = self.arrowhead_into(ci, mi)?;
        let r = self.var_map.fresh_aux();
        // r ↔ into_left ∧ into_right [∧ not adjacent for v_structure]
        self.clauses.push(vec![-r, into_left]);
        self.clauses.push(vec![-r, into_right]);
        if !shielded {
            // Non-adjacent: no edge of any allowed type between ai and ci.
            for (glyph, sym) in self.var_map.class().edge_types().iter().copied() {
                if sym {
                    let e = self.var_map.edge_var(ai, ci, glyph);
                    self.clauses.push(vec![-r, -e]);
                } else {
                    let e1 = self.var_map.edge_var(ai, ci, glyph);
                    let e2 = self.var_map.edge_var(ci, ai, glyph);
                    self.clauses.push(vec![-r, -e1]);
                    self.clauses.push(vec![-r, -e2]);
                }
            }
        }
        // Reverse direction (so r reifies fully) would require
        // negating the conjunction; for top-level positive usage the
        // single-direction Tseitin is sufficient and standard.
        Ok(r)
    }

    /// Literal that's true iff there's an arrowhead into `to` from
    /// `from` — i.e. an edge whose `to`-end is an arrowhead. Covers
    /// `-->` (from → to) and `<->` (either direction).
    fn arrowhead_into(&mut self, from: usize, to: usize) -> Result<Lit, String> {
        let mut lits: Vec<Lit> = Vec::new();
        if self.var_map.has_edge_type("-->") {
            lits.push(self.var_map.edge_var(from, to, "-->"));
        }
        if self.var_map.has_edge_type("<->") {
            lits.push(self.var_map.edge_var(from, to, "<->"));
        }
        match lits.len() {
            0 => Ok(self.false_lit()),
            1 => Ok(lits[0]),
            _ => {
                let r = self.var_map.fresh_aux();
                // r ↔ ⋁ lits
                for &l in &lits {
                    self.clauses.push(vec![-l, r]);
                }
                let mut pos: Vec<Lit> = lits.clone();
                pos.insert(0, -r);
                self.clauses.push(pos);
                Ok(r)
            }
        }
    }

    fn membership_lit(&mut self, query: &str, elem: usize, target: usize) -> Result<Lit, String> {
        if elem == target {
            return Ok(self.false_lit());
        }
        match query {
            "parents" => {
                self.require_edge_type("-->", query)?;
                Ok(self.var_map.edge_var(elem, target, "-->"))
            }
            "children" => {
                self.require_edge_type("-->", query)?;
                Ok(self.var_map.edge_var(target, elem, "-->"))
            }
            "neighbors" => {
                // Adjacent of any class-allowed type, in either direction.
                let mut lits: Vec<Lit> = Vec::new();
                for (glyph, sym) in self.var_map.class().edge_types().iter().copied() {
                    if sym {
                        lits.push(self.var_map.edge_var(elem, target, glyph));
                    } else {
                        lits.push(self.var_map.edge_var(elem, target, glyph));
                        lits.push(self.var_map.edge_var(target, elem, glyph));
                    }
                }
                self.disjunction(&lits)
            }
            "spouses" => {
                if !self.var_map.has_edge_type("<->") {
                    return Ok(self.false_lit());
                }
                Ok(self.var_map.edge_var(elem, target, "<->"))
            }
            "ancestors" => {
                self.require_edge_type("-->", query)?;
                self.ensure_reach_upper_bound();
                Ok(self.var_map.reach_var(elem, target))
            }
            "descendants" => {
                self.require_edge_type("-->", query)?;
                self.ensure_reach_upper_bound();
                Ok(self.var_map.reach_var(target, elem))
            }
            "anteriors" => self.anteriors_lit(elem, target),
            "posteriors" => self.posteriors_lit(elem, target),
            "markov_blanket" => self.markov_blanket_lit(elem, target),
            "districts" => self.districts_lit(elem, target),
            other => Err(format!("Unknown query `{}` in membership atom.", other)),
        }
    }

    fn query_membership_lits(
        &mut self,
        query: &str,
        target_set: &[NodeRef],
    ) -> Result<Vec<Lit>, String> {
        if target_set.len() != 1 {
            return Err(format!(
                "Cardinality query `{}(...)` must take exactly one node argument.",
                query
            ));
        }
        let target = self.resolve(&target_set[0])?;
        let n = self.var_map.n();
        let mut lits = Vec::with_capacity(n.saturating_sub(1));
        for u in 0..n {
            if u == target {
                continue;
            }
            lits.push(self.membership_lit(query, u, target)?);
        }
        Ok(lits)
    }

    fn ensure_reach_upper_bound(&mut self) {
        encode_reach_upper_bound(self.clauses, self.var_map, &mut self.reach_ub_added);
    }

    fn require_edge_type(&self, etype: &str, query: &str) -> Result<(), String> {
        if !self.var_map.has_edge_type(etype) {
            return Err(format!(
                "Query `{}()` requires `{}` edges, which are not allowed in class `{}`.",
                query,
                etype,
                self.var_map.class()
            ));
        }
        Ok(())
    }

    fn resolve(&self, n: &NodeRef) -> Result<usize, String> {
        self.var_map
            .idx_of(n)
            .ok_or_else(|| format!("Unknown node `{}` referenced in constraint.", n))
    }

    fn disjunction(&mut self, lits: &[Lit]) -> Result<Lit, String> {
        match lits.len() {
            0 => Ok(self.false_lit()),
            1 => Ok(lits[0]),
            _ => {
                let r = self.var_map.fresh_aux();
                for &l in lits {
                    self.clauses.push(vec![-l, r]);
                }
                let mut pos: Vec<Lit> = lits.to_vec();
                pos.insert(0, -r);
                self.clauses.push(pos);
                Ok(r)
            }
        }
    }

    fn true_lit(&mut self) -> Lit {
        let a = self.var_map.fresh_aux();
        self.clauses.push(vec![a]);
        a
    }

    fn false_lit(&mut self) -> Lit {
        let a = self.var_map.fresh_aux();
        self.clauses.push(vec![-a]);
        a
    }

    // ── Markov blanket, anteriors, posteriors, districts ────────────────────
    //
    // Each routes by class.

    fn markov_blanket_lit(&mut self, elem: usize, target: usize) -> Result<Lit, String> {
        match self.var_map.class() {
            GraphClass::Dag => self.mb_dag(elem, target),
            GraphClass::Ug => {
                // MB(target) = neighbors(target). Symmetric edge var.
                Ok(self.var_map.edge_var(elem, target, "---"))
            }
            GraphClass::Pdag => {
                // DAG part + undirected neighbour.
                let dag_part = self.mb_dag(elem, target)?;
                let undir = self.var_map.edge_var(elem, target, "---");
                self.disjunction(&[dag_part, undir])
            }
            GraphClass::Admg => {
                // MB(target) = (district(target) \ {target})
                //              ∪ parents of district members.
                // i.e. elem ∈ MB(target) iff
                //      elem is in target's district  OR
                //      ∃D: D is in target's district AND elem is parent of D.
                self.ensure_bireach_invariants();
                let in_district = self.bireach_lit_pair(elem, target);
                let n = self.var_map.n();
                let mut lits: Vec<Lit> = vec![in_district];
                for d in 0..n {
                    if d == elem {
                        continue;
                    }
                    // bireach(target, d) ∧ edge(elem, d, "-->")
                    let br = self.bireach_lit_pair(target, d);
                    let pa = self.var_map.edge_var(elem, d, "-->");
                    let conj = self.var_map.fresh_aux();
                    self.clauses.push(vec![-conj, br]);
                    self.clauses.push(vec![-conj, pa]);
                    self.clauses.push(vec![-br, -pa, conj]);
                    lits.push(conj);
                }
                self.disjunction(&lits)
            }
        }
    }

    /// MB encoding for DAG-style classes (DAG part of PDAG MB too).
    /// elem ∈ MB(target) ⇔
    ///   edge(elem, target, "-->")            (parent)
    /// ∨ edge(target, elem, "-->")            (child)
    /// ∨ ∃C ≠ elem, target:
    ///       edge(target, C, "-->") ∧ edge(elem, C, "-->")   (co-parent)
    fn mb_dag(&mut self, elem: usize, target: usize) -> Result<Lit, String> {
        if !self.var_map.has_edge_type("-->") {
            return Ok(self.false_lit());
        }
        let parent_lit = self.var_map.edge_var(elem, target, "-->");
        let child_lit = self.var_map.edge_var(target, elem, "-->");
        let n = self.var_map.n();
        let mut lits: Vec<Lit> = vec![parent_lit, child_lit];
        for c in 0..n {
            if c == elem || c == target {
                continue;
            }
            let target_to_c = self.var_map.edge_var(target, c, "-->");
            let elem_to_c = self.var_map.edge_var(elem, c, "-->");
            let conj = self.var_map.fresh_aux();
            self.clauses.push(vec![-conj, target_to_c]);
            self.clauses.push(vec![-conj, elem_to_c]);
            self.clauses.push(vec![-target_to_c, -elem_to_c, conj]);
            lits.push(conj);
        }
        self.disjunction(&lits)
    }

    fn anteriors_lit(&mut self, elem: usize, target: usize) -> Result<Lit, String> {
        match self.var_map.class() {
            GraphClass::Dag => {
                // Anteriors == ancestors on a DAG.
                self.ensure_reach_upper_bound();
                Ok(self.var_map.reach_var(elem, target))
            }
            GraphClass::Pdag => {
                // Mixed reach: forward-directed + both-way undirected.
                self.ensure_mreach_invariants();
                Ok(self.mreach_lit_pair(elem, target))
            }
            other => Err(format!(
                "`anteriors()` is not defined for class `{}`.",
                other
            )),
        }
    }

    fn posteriors_lit(&mut self, elem: usize, target: usize) -> Result<Lit, String> {
        match self.var_map.class() {
            GraphClass::Dag => {
                self.ensure_reach_upper_bound();
                Ok(self.var_map.reach_var(target, elem))
            }
            GraphClass::Pdag => {
                self.ensure_mreach_invariants();
                Ok(self.mreach_lit_pair(target, elem))
            }
            other => Err(format!(
                "`posteriors()` is not defined for class `{}`.",
                other
            )),
        }
    }

    fn districts_lit(&mut self, elem: usize, target: usize) -> Result<Lit, String> {
        match self.var_map.class() {
            GraphClass::Admg => {
                // Element is in target's district iff bireach(target, elem).
                self.ensure_bireach_invariants();
                Ok(self.bireach_lit_pair(elem, target))
            }
            other => Err(format!(
                "`districts()` is only defined for ADMG (got class `{}`).",
                other
            )),
        }
    }

    // ── Bidirected reach (ADMG only) ─────────────────────────────────────────
    //
    // `bireach(u, v)` is true iff u and v are in the same district —
    // connected by a path of `<->` edges. Symmetric, so we canonicalise
    // on the unordered pair `(min, max)`.
    //
    // We use a **level-bounded** encoding: `bireach^k(u, v)` is true
    // iff u, v are connected by a path of at most `k` bidirected
    // steps. Final answer is `bireach^{n-1}`. This is the textbook
    // remedy for SAT-encoded reach in graphs with cycles — the naive
    // transitive-closure upper bound allows "circular satisfaction"
    // where mutually-supporting reach vars are TRUE without any real
    // path. Levels force every reach claim to bottom out within
    // n-1 hops.

    fn bireach_lit_pair(&mut self, u: usize, v: usize) -> Lit {
        if u == v {
            return self.true_lit();
        }
        let key = if u < v { (u, v) } else { (v, u) };
        self.bireach
            .as_ref()
            .and_then(|m| m.get(&key).copied())
            .unwrap_or_else(|| {
                // The caller forgot to ensure invariants; allocate
                // unconstrained so the clause we're building doesn't
                // crash, but the result will be unhelpful.
                self.false_lit()
            })
    }

    fn ensure_bireach_invariants(&mut self) {
        if self.bireach_invariants {
            return;
        }
        self.bireach_invariants = true;
        if !self.var_map.has_edge_type("<->") {
            return;
        }
        let n = self.var_map.n();
        if n < 2 {
            return;
        }
        // Allocate level vars: bireach^k for k = 1..n-1, all unordered
        // pairs. Plus the final-level map exposed via
        // `bireach_lit_pair`.
        let mut levels: Vec<FxHashMap<(usize, usize), i32>> = Vec::with_capacity(n);
        levels.push(FxHashMap::default()); // k = 0 (we never look up)
        for _ in 1..n {
            let mut layer = FxHashMap::default();
            for u in 0..n {
                for v in (u + 1)..n {
                    layer.insert((u, v), self.var_map.fresh_aux());
                }
            }
            levels.push(layer);
        }
        // Final level is what `bireach_lit_pair` returns.
        self.bireach = Some(levels[n - 1].clone());

        // Recurrence. For k = 1: bireach^1(u, v) ↔ edge(u, v, "<->").
        for u in 0..n {
            for v in (u + 1)..n {
                let b1 = *levels[1].get(&(u, v)).unwrap();
                let e = self.var_map.edge_var(u, v, "<->");
                self.clauses.push(vec![-b1, e]);
                self.clauses.push(vec![-e, b1]);
            }
        }
        // For k > 1: bireach^k(u, v) ↔ bireach^{k-1}(u, v) ∨
        //   ⋁_{w ≠ u, w ≠ v} (edge(u, w, "<->") ∧ bireach^{k-1}({w, v}))
        for k in 2..n {
            for u in 0..n {
                for v in (u + 1)..n {
                    let bk = *levels[k].get(&(u, v)).unwrap();
                    let bk_prev = *levels[k - 1].get(&(u, v)).unwrap();
                    // Subsumption: bk_prev → bk.
                    self.clauses.push(vec![-bk_prev, bk]);
                    let mut big = vec![-bk, bk_prev];
                    for w in 0..n {
                        if w == u || w == v {
                            continue;
                        }
                        let euw = self.var_map.edge_var(u, w, "<->");
                        // bireach^{k-1}({w, v}) — canonical (min, max).
                        let wv_key = if w < v { (w, v) } else { (v, w) };
                        let bwv = *levels[k - 1].get(&wv_key).unwrap();
                        let p = self.var_map.fresh_aux();
                        self.clauses.push(vec![-p, euw]);
                        self.clauses.push(vec![-p, bwv]);
                        self.clauses.push(vec![-euw, -bwv, p]);
                        // p → bk
                        self.clauses.push(vec![-p, bk]);
                        big.push(p);
                    }
                    // bk → bk_prev ∨ ⋁ p_w  (upper bound)
                    self.clauses.push(big);
                }
            }
        }
    }

    // ── Mixed reach (PDAG only) ───────────────────────────────────────────────
    //
    // `mreach(u, v)` is true iff there's a path u → … → v in the
    // PDAG's mixed graph: `-->` traversed forward, `---` either way.
    // Same level encoding as bireach. Asymmetric (directed) so we key
    // on ordered pairs.

    fn mreach_lit_pair(&mut self, u: usize, v: usize) -> Lit {
        if u == v {
            return self.true_lit();
        }
        self.mreach
            .as_ref()
            .and_then(|m| m.get(&(u, v)).copied())
            .unwrap_or_else(|| self.false_lit())
    }

    fn ensure_mreach_invariants(&mut self) {
        if self.mreach_invariants {
            return;
        }
        self.mreach_invariants = true;
        let has_dir = self.var_map.has_edge_type("-->");
        let has_und = self.var_map.has_edge_type("---");
        if !has_dir && !has_und {
            return;
        }
        let n = self.var_map.n();
        if n < 2 {
            return;
        }
        // Precompute step(u, w) — "is there a usable forward edge from
        // u to w in the mixed graph?".
        let mut step: FxHashMap<(usize, usize), i32> = FxHashMap::default();
        for u in 0..n {
            for w in 0..n {
                if u == w {
                    continue;
                }
                let s = self.mreach_step_lit(u, w, has_dir, has_und);
                step.insert((u, w), s);
            }
        }
        // Allocate level vars: mreach^k for k = 1..n-1, all ordered
        // pairs.
        let mut levels: Vec<FxHashMap<(usize, usize), i32>> = Vec::with_capacity(n);
        levels.push(FxHashMap::default());
        for _ in 1..n {
            let mut layer = FxHashMap::default();
            for u in 0..n {
                for v in 0..n {
                    if u == v {
                        continue;
                    }
                    layer.insert((u, v), self.var_map.fresh_aux());
                }
            }
            levels.push(layer);
        }
        self.mreach = Some(levels[n - 1].clone());

        // k = 1: mreach^1(u, v) ↔ step(u, v).
        for u in 0..n {
            for v in 0..n {
                if u == v {
                    continue;
                }
                let m1 = *levels[1].get(&(u, v)).unwrap();
                let s = *step.get(&(u, v)).unwrap();
                self.clauses.push(vec![-m1, s]);
                self.clauses.push(vec![-s, m1]);
            }
        }
        // k > 1: mreach^k(u, v) ↔ mreach^{k-1}(u, v) ∨
        //   ⋁_{w ≠ u, v} (step(u, w) ∧ mreach^{k-1}(w, v))
        for k in 2..n {
            for u in 0..n {
                for v in 0..n {
                    if u == v {
                        continue;
                    }
                    let mk = *levels[k].get(&(u, v)).unwrap();
                    let mk_prev = *levels[k - 1].get(&(u, v)).unwrap();
                    self.clauses.push(vec![-mk_prev, mk]);
                    let mut big = vec![-mk, mk_prev];
                    for w in 0..n {
                        if w == u || w == v {
                            continue;
                        }
                        let s = *step.get(&(u, w)).unwrap();
                        let mwv = *levels[k - 1].get(&(w, v)).unwrap();
                        let p = self.var_map.fresh_aux();
                        self.clauses.push(vec![-p, s]);
                        self.clauses.push(vec![-p, mwv]);
                        self.clauses.push(vec![-s, -mwv, p]);
                        self.clauses.push(vec![-p, mk]);
                        big.push(p);
                    }
                    self.clauses.push(big);
                }
            }
        }
    }

    /// Disjunction of edge types that contribute to a forward step
    /// from `u` to `w` in PDAG mixed reach.
    fn mreach_step_lit(&mut self, u: usize, w: usize, has_dir: bool, has_und: bool) -> Lit {
        match (has_dir, has_und) {
            (true, true) => {
                let a = self.var_map.edge_var(u, w, "-->");
                let b = self.var_map.edge_var(u, w, "---");
                let r = self.var_map.fresh_aux();
                self.clauses.push(vec![-a, r]);
                self.clauses.push(vec![-b, r]);
                self.clauses.push(vec![-r, a, b]);
                r
            }
            (true, false) => self.var_map.edge_var(u, w, "-->"),
            (false, true) => self.var_map.edge_var(u, w, "---"),
            _ => self.false_lit(),
        }
    }
}
