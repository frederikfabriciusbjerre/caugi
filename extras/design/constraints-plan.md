# `caugi_constraints` — Implementation Plan

> Status: design — branch `feat/constraints`.
>
> The goal is to introduce **constraints** as a native concept in caugi: Boolean
> formulas over the same predicates caugi already exposes via queries (edge
> presence, orientation, ancestrality). Background knowledge in causal discovery
> falls out as one specific *use* of constraints, and the same machinery covers
> sensitivity analysis, MEC enumeration, composition of expert priors with
> algorithmic output, and user-defined predicates.

## 1. Scope

**In scope (v1)**

- `caugi_constraints()` AST builder, operators (`%<<%`, `xor`, `implies`,
  `forall`, `exists`, `at_most`, `at_least`, `exactly`), boolean algebra
  (`&`, `|`, `!`).
- Atom tiers A (boolean combinations of edge atoms, including `collider`,
  `v_structure`, and set-membership atoms whose query is tier-A — `parents`,
  `children`, `neighbors`, `spouses`, `mb`, `districts`) and B (set-membership
  atoms whose query is tier-B — `ancestors`, `descendants`, `anteriors`,
  `posteriors` — plus `acyclic`, `connected`) usable as constraints; tier C
  (`dsep`, future `msep` / discriminating-path atoms) usable only in
  evaluation.
- Set-membership atoms via R's existing `%in%` operator and caugi's existing
  query functions: `A %in% ancestors(Y)`, `B %in% mb(A)`, etc. No new
  ancestrality operator on the surface; the internal AST still has an
  `Ancestral`-flavoured representation under `Membership { query =
  "ancestors", ... }`.
- Topological-ordering sugar `%<<%` desugars to a conjunction of
  `!(r %in% ancestors(l))` over the cartesian product of `(l ∈ L, r ∈ R)`.
- Quantifiers grounded eagerly over the current node set.
- Cardinality via native PB in the solver.
- Operations: `satisfies()`, `violations()`, `consistent()`, `entails()`,
  `enumerate()`, `with_constraints()`, `constraints()`.
- User-defined predicates via `caugi_predicate()`.
- Graph-class invariants (DAG acyclicity, PDAG/MPDAG rules) composed into the
  encoding automatically.

**Out of scope (deferred)**

- `unsat_core` — addable later; every real solver gives cores for free.
- Soft / weighted (MaxSAT).
- Serialization (`read_constraints` / `write_constraints`).
- `as_constraints()` from a `caugi`.
- Tier-C atoms (`dsep`) in constraint position.
- Plot integration beyond a `highlight = violations(...)` hook.

## 2. Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ R                                                             │
│   caugi_constraints(...)  %<<%  forall  at_most  &  |  !      │
│             │                                                 │
│             ▼                                                 │
│   R-side AST (S7) ──► serialize ──► Rust AST                  │
└──────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼────────────────────────────────┐
│ Rust (src/rust/src/constraints/)                              │
│                                                               │
│   ast.rs ──► evaluator.rs ─────► satisfies / violations       │
│       │                                                       │
│       └─► ground.rs ─► encode.rs ─► solver.rs                 │
│                            │            │                     │
│                    edge / mutex /       ▼                     │
│                    transitive closure  pumpkin (or splr)      │
│                    PB / class invariants                      │
│                            │                                  │
│                            ▼                                  │
│                    reconstruct.rs ──► caugi model(s)          │
└──────────────────────────────────────────────────────────────┘
```

Layer responsibilities:

- **R AST**: thin, S7-classed, mostly captured expressions plus a tag tree. The
  same AST drives both the evaluator and the solver paths.
- **Grounder**: removes `forall` / `exists` / parameterised cardinality by
  substituting the actual node set; leaves a purely propositional + PB formula.
- **Encoder**: introduces edge variables `e(u, v, t)` per (ordered pair, edge
  type), edge-type mutex per pair, transitive-closure auxiliary vars
  `reach(u, v)`, class invariants. Translates `at_most` / `at_least` / `exactly`
  to PB.
- **Solver**: splr (pure-Rust CDCL). Picked in the Phase 0 spike; see
  `extras/design/constraints-spike-s0.md` for the size measurements and
  decision rationale. Cardinality (`at_most(k, …)` etc.) is encoded as
  totalizer / sequential counter at Phase 2 encoding time.
- **Reconstructor**: solver model → assignment over `e(u, v, t)` → `caugi` via
  existing builders.

## 3. AST data model

A constraint is a tree of nodes. Each node carries a kind tag and children.
Approximate Rust shape:

```rust
enum Atom {
    // tier A — boolean combinations of edge variables
    Edge { from: NodeRef, to: NodeRef, etype: EdgeType },
    Observed { x: NodeRef },
    Collider { mid: NodeRef, on: (NodeRef, NodeRef) },   // = two edge atoms
    VStructure { a: NodeRef, b: NodeRef, c: NodeRef },   // = collider + ¬adjacent

    // tier B — transitive-closure aux vars
    Acyclic, Connected,

    // tier C — evaluator only, rejected by encoder
    Dsep { x: NodeSet, y: NodeSet, given: NodeSet },

    // Set-membership: element ∈ query(args). The tier of a `Membership`
    // atom is determined by `query`:
    //   tier A : parents, children, neighbors, spouses, mb, districts
    //   tier B : ancestors, descendants, anteriors, posteriors
    // The user-facing surface is `X %in% <query>(<args>)`; topological
    // ordering sugar `%<<%` desugars into negated `Membership` atoms with
    // `query = "ancestors"`.
    Membership { elem: NodeRef, query: String, args: Vec<NodeRef> },
}

enum NodeRef { Named(String), Var(VarId) }   // Var = bound by a quantifier

enum Formula {
    Atom(Atom),
    Not(Box<Formula>),
    And(Vec<Formula>),  Or(Vec<Formula>),
    Xor(Box<Formula>, Box<Formula>),
    Implies(Box<Formula>, Box<Formula>),
    Forall { vars: Vec<VarId>, body: Box<Formula>, scope: Scope },
    Exists { vars: Vec<VarId>, body: Box<Formula>, scope: Scope },
    Cardinality { kind: CardKind, k: u32, set: Vec<Formula> }, // AtMost | AtLeast | Exactly
    Predicate { name: String, args: Vec<NodeRef>, body: Box<Formula> },
}

enum Scope {
    AllNodes,
    OrderedTuples(usize),     // distinct, ordered
    UnorderedSets(usize),     // distinct, unordered
    NamedSet(Vec<String>),
}
```

**Atom tier policy** is a property of `Atom`; the encoder errors loudly on
tier-C atoms, the evaluator handles all three.

## 4. Phase 0 — Spikes & lock-ins (1 week)

Decisions that everything downstream depends on. Each is a small spike.

| Spike | Deliverable | Decision criterion |
| --- | --- | --- |
| **S0.1** Solver choice | A ~200-line Rust prototype encoding `at_most(k, S)` over 20 boolean vars in both pumpkin and splr; toy benchmark on n=10, 20, 30 node "find a DAG satisfying X" problems | Pick pumpkin unless it can't build cleanly into the existing extendr crate, or its CRAN-friendliness is unclear. **Outcome: splr picked — see `constraints-spike-s0.md`.** |
| **S0.2** Re-vendoring impact | Run `rextendr::vendor_pkgs(overwrite = TRUE)` after adding the candidate solver; record `vendor.tar.xz` size delta | Acceptable if <2 MB increase; otherwise reconsider. **Outcome: splr +0.10 MB ✓; pumpkin +4.88 MB ✗.** |
| **S0.3** Grounding semantics | One-page doc: `forall(X, …)` over current nodes; tuples ordered/distinct; bound variables shadow node names; predicates are α-renamed on instantiation | Locked-in before any code lands |
| **S0.4** AST schema version | `schema_version = 1` baked into both R and Rust AST representations | Trivial; do it now to make future serialization painless |
| **S0.5** Atom tier policy doc | Short note in `R/constraints.R` header: A vs B vs C, what errors when, where it's enforced | Reviewable before Phase 1 |

**Exit criterion for Phase 0**: solver picked, vendored, builds locally; design
doc circulated and merged.

## 5. Phase 1 — AST + evaluator (2 weeks)

The whole user-facing surface compiles and works against given graphs. No
solver yet. This phase alone gives `satisfies` / `violations` and unblocks
causalDisco's first integration.

### R side

- `R/all-classes.R`: new S7 classes `caugi_constraints`, `caugi_atom`,
  `caugi_predicate`.
- `R/constraints.R`: `caugi_constraints(...)` constructor — captures
  expressions, classifies each into atom/combinator, validates tier.
- `R/constraint-operators.R`:
  - `%<<%` (topological order — desugars to a conjunction of
    `!(r %in% ancestors(l))` over the cartesian product of right vs left).
  - `xor()`, `implies()` — function form (R has no native logical-implication
    infix).
  - `forall()`, `exists()` — capture body as expression, bind variables.
  - `at_most()`, `at_least()`, `exactly()`.
  - `caugi_predicate()` — builds a reusable closure.
- `R/constraint-algebra.R`: S7 methods for `&`, `|`, `!` on
  `caugi_constraints`.
- `R/with-constraints.R`: `with_constraints(cg, ctr)` attaches,
  `constraints(cg)` retrieves.
- Extend `R/queries.R`: `satisfies()`, `violations()`. These dispatch to Rust.
- `R/format-caugi.R`: pretty `print` and `format` methods for constraint
  objects.

### Rust side

- `src/rust/src/constraints/mod.rs`
- `src/rust/src/constraints/ast.rs` — `Formula`, `Atom`, `NodeRef`, `Scope`,
  helpers.
- `src/rust/src/constraints/parse.rs` — extendr serialisation: receive R-side
  AST as a nested list, build Rust AST. Robust to malformed input (typed errors
  back to R).
- `src/rust/src/constraints/evaluator.rs`:
  - `evaluate(formula, graph) -> EvalResult`.
  - Walks AST, looks up atoms against graph (uses existing query
    infrastructure).
  - For quantifiers: instantiates over actual nodes lazily, short-circuits.
  - Returns structured result:
    `{ satisfied: bool, failing_atoms: Vec<(AtomLoc, Witness)> }`.
- `src/rust/src/lib.rs` — extendr export of `rs_constraints_evaluate`.

### Tests (`tests/testthat/test-constraints-*.R`)

- `test-constraints-construction.R` — every operator, every atom, mixed
  expressions.
- `test-constraints-algebra.R` — `&`, `|`, `!` laws (associativity, double
  negation).
- `test-constraints-evaluate-tierA.R` — edge presence, adjacency, observed,
  collider, v_structure.
- `test-constraints-evaluate-tierB.R` — ancestrality, acyclic, connected.
- `test-constraints-evaluate-tierC.R` — dsep.
- `test-constraints-quantifiers.R` — `forall` / `exists` over small graphs,
  including empty.
- `test-constraints-cardinality.R` — `at_most(0)`, `at_most(n)`, equality.
- `test-constraints-violations.R` — witness correctness on hand-rolled
  counterexamples.
- `test-constraints-precedence.R` — `%<<%` desugars correctly into ancestral
  negations.
- `test-constraints-class-invariants.R` — DAG/PDAG-specific invariants compose.
- `test-constraints-errors.R` — tier-C atoms in constraint position fail at
  construction with a clear message.

### Exit criterion

- `devtools::check()` clean.
- `air format . --check` clean.
- All Phase 1 tests pass.
- Vignette draft: `vignettes/constraints.Rmd` showing the user-facing examples
  from the colleague-message verbatim.
- causalDisco can build a `caugi_constraints` object and call `satisfies()` /
  `violations()`.

## 6. Phase 2 — Solver integration (DAG/UG/PDAG/ADMG landed 2026-05-17)

Status as of branch `feat/constraints`: class-aware encoder, splr
backend, `consistent()`, `enumerate()` all working for `DAG`, `UG`,
`PDAG`, `ADMG`. Known counts validated:

- DAGs n=1..4 follow Robinson (1, 3, 25, 543).
- UGs n=2..4 follow 2^C(n,2) (2, 8, 64).
- PDAGs / ADMGs n=2..3 follow 4^C(n,2) − (directed cycles): 4, 62.

`MPDAG`, `AG`, `MAG`, `PAG` classes plus `entails()` are deferred to a
follow-up phase.



This is the largest phase. By the end, `consistent()`, `enumerate()`,
`entails()` work.

### Steps in order

1. **Edge variable scheme**: define `var(u, v, t)` mapping. One boolean per
   (ordered pair, edge type) for directed / bidirected; one per (unordered
   pair) for undirected. Build a `VarMap` with bidirectional lookup.
2. **Edge-type mutex clauses**: at most one edge type per pair (e.g., a pair
   can't be both `-->` and `<->`).
3. **Class invariant clauses**:
   - `DAG`: acyclicity via `reach(u, v)` aux vars + `!reach(v, v)`. Standard
     encoding: `edge(u, v) → reach(u, v)`,
     `reach(u, w) & reach(w, v) → reach(u, v)`. O(n³) clauses; fine up to ~50
     nodes for v1.
   - `PDAG` / `MPDAG`: chain rules.
   - `ADMG`, `UG`: their respective invariants.
   - These come from existing Rust graph-class checkers — extract the
     propositional version once, reuse everywhere.
4. **Tier-B membership encoding**: `A %in% ancestors(B) ↔ reach(A, B)`.
   Reuses the aux vars from acyclicity. Other tier-B queries
   (`descendants`, `anteriors`, `posteriors`) reuse the same closure with
   role swaps.
5. **Cardinality encoding** (splr does not provide native PB):
   - `at_most(1, S)`: sequential counter (linear in |S|).
   - `at_most(k, S)` for k > 1: totalizer (`O(|S|·log k)` aux vars).
   - `at_least(k, S)` and `exactly(k, S)` derived from `at_most`.
   - Wrapped in `cardinality.rs` so call sites stay solver-agnostic
     should we ever want to swap in a PB-native backend.
6. **Grounder** (`ground.rs`): walk the AST, instantiate `forall` / `exists` /
   parameterised cardinality. Emit a `GroundFormula` with no quantifiers and no
   `Var` node-refs.
7. **Encoder** (`encode.rs`): `GroundFormula` → CNF + PB clauses, using
   `VarMap`. Standard Tseitin transformation for arbitrary boolean structure.
   Reject tier-C atoms with an actionable error.
8. **Solver wrapper** (`solver.rs`): `Backend` trait with `solve`, `solve_all`
   (up to limit), `assume` (for `entails`). Two impls: `Pumpkin`, `Splr`.
   Feature-flag in Cargo.
9. **Reconstructor** (`reconstruct.rs`): solver model → assignment over
   `e(u, v, t)` → builds a `caugi` via existing constructors.
10. **R bindings**: `rs_constraints_consistent`, `rs_constraints_enumerate`,
    `rs_constraints_entails`.
11. **R API**: `consistent()`, `enumerate(ctr, nodes, limit, class = "DAG")`,
    `entails(ctr, atom)`.

### Tests

- `test-constraints-encode-edges.R` — every edge-type combination.
- `test-constraints-encode-acyclic.R` — DAG invariant holds in every enumerated
  model.
- `test-constraints-encode-pdag.R`, `-mpdag.R`, `-admg.R`, `-ug.R`.
- `test-constraints-encode-cardinality.R` — PB / totalizer agreement on small
  instances.
- `test-constraints-grounding.R` — `forall` over n=0, 1, 2, 3, 5 nodes, with
  bound variables shadowing.
- `test-constraints-consistent.R` — known SAT / UNSAT pairs.
- `test-constraints-enumerate.R` — known model counts for small graphs (e.g.,
  #DAGs on 3 nodes = 25).
- `test-constraints-entails.R` — known entailments (transitive closure of
  must / must-not).
- `test-constraints-solver-parity.R` — pumpkin and splr agree on a corpus of
  small problems.
- `test-constraints-tier-c-rejection.R` — `dsep` in constraint position errors
  at encode time.
- `test-constraints-perf-smoke.R` — n=20 random problems complete in <5s;
  skipped on CRAN.

### Exit criterion

- All Phase 1 + Phase 2 tests pass under both solver backends (feature-toggle
  in CI matrix).
- `rextendr::vendor_pkgs(overwrite = TRUE)` re-run; `vendor.tar.xz` and
  `vendor-config.toml` committed.
- `enumerate()` reproduces the known DAG counts (Robinson sequence: 1, 3, 25,
  543, …) for n = 1..4 with no constraints.
- Performance smoke test on n=20 passes.

## 7. Phase 3 — User-defined predicates (1 week)

Mostly bookkeeping if Phase 1 was done cleanly.

- `caugi_predicate(name, fn)` produces a closure-like S7 object.
- At constraint construction, predicate invocations
  `instrument("Z", "A", "Y")` are recorded with their argument bindings.
- Grounder inlines predicate bodies with α-renamed bound variables to avoid
  capture.
- Allow predicates to call other predicates (acyclic dependency check at
  construction).
- Tests:
  - `test-predicates-basic.R` — define + use.
  - `test-predicates-substitution.R` — α-renaming.
  - `test-predicates-nested.R` — predicate calling predicate.
  - `test-predicates-recursion.R` — recursive predicates must error at
    construction (no fixed-point machinery in v1).

## 8. Phase 4 — Polish (1 week)

- `plot()` integration:
  `plot(cg, highlight = violations(cg, ctr))` colours offending edges;
  `print(ctr)` produces a readable formula listing.
- Vignette: `vignettes/constraints.Rmd`, covering the worked example from the
  colleague message plus a longer "constraints in causal discovery" walkthrough
  that causalDisco can link to.
- pkgdown: add a `Constraints` section to `_pkgdown.yml`.
- `NEWS.md`: new "Constraints" subsection under New Features.
- README: one-paragraph mention.

## 8.5 Phase 5 — Constructive constrained sampler (`caugi_sample`)

> Proposed; not yet built. Resolves the practical question "I have BK as a
> constraint set — give me random DAGs satisfying it" without falling back
> to rejection sampling or to `enumerate()`'s biased ordering.

`enumerate()` returns the first *N* graphs splr happens to find — strongly
biased toward sparse / minimum-flip variants. Useful for "is there any?"
or "list everything", **not** for "sample one randomly". The right shape
is a direct sampler that compiles common BK constraints into the random
construction itself.

### User surface

```r
sample <- caugi_sample(
  ctr,
  nodes  = c("A", "B", paste0("V", 3:10)),
  class  = "DAG",
  p      = 0.3,      # edge probability for unconstrained pairs
  n      = 1L,       # number of samples
  seed   = NULL
)
```

Returns a list of `caugi` objects (length `n`).

### Algorithm

```
1. compile(ctr) → CompiledConstraints {
       required   : set<(from, to)>          // positive edge atoms
       forbidden  : set<(from, to)>          // negated edge atoms
       precedence : partial order on nodes   // %<<% + required A → B
       degree     : map<node, max in-degree> // at_most(k, parents(X))
       residual   : list<Formula>            // anything not compilable
   }

2. Sample a topological permutation π of `nodes` uniformly at random
   from the linear extensions of `precedence`. Fails fast (no sample
   possible) if `precedence` is cyclic.

3. For each ordered pair (u, v) with π(u) < π(v):
       if (u, v) ∈ required    → include
       elif (u, v) ∈ forbidden → exclude
       else                     → include with probability p
   Track per-target in-degree; switch a target to "exclude" mode once
   its cap is reached. (When `degree` and `required` conflict — required
   edges already exceed the cap — fail fast.)

4. Build the caugi.
5. If `residual` is empty: return.
   Else: validate via satisfies(cg, residual). Reject + retry the sample
   only on residual failure.
```

### What compiles vs what falls through to residual

**Compilable today** (the bulk of practical BK):

- Edge atoms at top level (required / forbidden).
- `%<<%` topological precedence.
- `at_most(k, parents(X))` and `exactly(k, parents(X))` (degree bounds).
- Conjunctions of the above.

**Residual (handled via rejection)**:

- Positive ancestor/descendant atoms (`A %in% ancestors(Y)`) — needs path
  existence, can't be enforced edge-by-edge.
- Heterogeneous cardinality sets (`at_most(k, c(A %-->% Y, X %---% Y))`).
- Required colliders / v-structures.
- Disjunctions (`A %-->% B | C %-->% B`) — would require sampling within
  each branch, biased by branch weight.
- `dsep` — see tier-C note (under revision).

Documented expectation: rejection rate is zero or near-zero for typical
causal-discovery BK, which is dominated by the compilable cases.

### Sampling-distribution semantics

Under no constraints, `caugi_sample` is the standard random-DAG
distribution caugi's `generate_graph(p = …)` already produces: random
topological order × Bernoulli(p) per ordered pair. Constraints narrow
the distribution to the satisfying sub-family, **without re-weighting**
— so the sampler stays "uniform over satisfying DAGs *under that
distribution*". Not uniform over the satisfying set in the
combinatorial sense (that would require a uniform-SAT sampler like
ApproxMC). Document this clearly.

### Class coverage

- v1: `class = "DAG"` (the dominant use case).
- v2: extend to `PDAG` (sample directed + undirected per pair) and
  `ADMG` (sample directed + bidirected). The same compiler layout
  applies; only the per-pair edge sampler changes.
- `UG`: trivial — no topological order needed.

### Tests

- Marginal-distribution checks: with no constraints,
  `mean(satisfies(samples, A %-->% B))` ≈ `p / 2` over many samples.
- Constraint-satisfaction checks: every sampled DAG passes
  `satisfies(cg, ctr)` for the full constraint set.
- Cross-check against `enumerate()`: for small `(ctr, nodes)`, the
  empirical sample distribution after many draws should be uniform over
  `enumerate(ctr, nodes)` once weighted by the unconstrained
  distribution. Property test.

### Implementation cost

- ~200 lines of R (no Rust changes needed — sampler operates over the
  R-side AST and builds caugis with the existing constructor).
- One new exported function: `caugi_sample()`.
- New test file: `tests/testthat/test-constraints-sample.R`.

## 9. Cross-cutting concerns

### Testing

- **Three-layer parity testing**: every Phase 2 test case is also run as
  `satisfies(enumerated_graph, ctr)` to confirm evaluator and encoder agree.
- **Golden tests**: known model counts (Robinson) for unconstrained DAG
  enumeration.
- **Property tests** with `hedgehog` (optional dep): for random small graphs
  and random constraints,
  `consistent(ctr) == (enumerate(ctr, limit=1) returns ≥1)`.
- **CI matrix**: macOS + Linux × solver = pumpkin / solver = splr.

### Performance budget

- n ≤ 20 nodes: any constraint set, <1s for `satisfies`, <30s for `consistent`
  / `enumerate(limit=10)`.
- n ≤ 50 nodes: tier-A + tier-B without cardinality, <10s.
- Above that: best-effort, document.
- Don't optimise inside Phase 2. Optimise once a bottleneck has been measured.

### Re-vendoring

- After Phase 0 lands the solver crate, run
  `rextendr::vendor_pkgs(overwrite = TRUE)` and commit
  `src/rust/vendor.tar.xz` + `src/rust/vendor-config.toml` per AGENTS.md.
- Same after any further Rust dep changes — every Cargo.lock change.

### API stability

- The R-side AST shape is treated as semver-stable from the first release.
  Internal Rust AST can churn.
- `schema_version = 1` baked into the serialized AST from day one, enabling
  future `read_constraints` / `write_constraints` without breakage.

## 10. Risks & mitigations

| Risk | Mitigation |
| --- | --- |
| pumpkin not stable enough for CRAN | Phase-0 spike S0.1 evaluates; splr is the fallback, identical API behind the `Backend` trait. |
| Re-vendoring blows binary size past CRAN limits | Phase-0 spike S0.2 measures. If too big, switch solver or shrink with `cargo-shrink`-style flags. |
| Transitive-closure encoding scales poorly | Document n ≤ 50 sweet spot; expose a `method = "eval-only"` switch on `satisfies()` for users who only need evaluation. |
| Quantifier grounding explodes (e.g., `forall(c(X,Y,Z), …)` is O(n³)) | Detect arity at construction, warn for arity ≥ 3 with n ≥ 20. Encourage rewriting via predicates or atom restriction. |
| User confusion over tier-C atom restriction | Construction-time error with a pointer to docs; vignette section explicitly lists each tier with examples of what works where. |
| Naming clash with R's `xor` / `at_most` / `forall` from other packages | Export from `caugi` namespace; document `caugi::forall` qualification when needed. Consider `c_forall` if conflicts bite. |
| API drifts during phases and breaks early causalDisco usage | Ship Phase 1 to causalDisco as an internal alpha, lock the R-facing AST shape before Phase 2 begins. |

## 11. Open questions worth resolving before / during Phase 0

1. **Is pumpkin's CRAN story acceptable?** Needs a real check — license, build
   reproducibility, vendored deps.
2. **`%<<%` semantics: strict vs reflexive?** Default to strict (`A %<<% A` is
   false). Confirm with one example from causalDisco's tier usage.
3. **`forall(X, ...)` over current nodes — what counts as "current"?** Nodes
   present at evaluation time, including ones added after the constraint was
   built. Document explicitly.
4. **Should `with_constraints()` validate immediately or lazily?** Lean lazy
   (only when `satisfies()` / `build()` runs) to match caugi's existing
   lazy-build model.
5. **What does `enumerate()` return when the result set is huge?** A lazy
   iterator, materialised on demand. `limit` is required (no default
   unlimited). Confirm with a couple of intended call sites.

## 12. Suggested calendar

Assuming one developer, normal load:

| Phase | Duration | Cumulative |
| --- | --- | --- |
| 0 — spikes | 1 week | 1 |
| 1 — AST + evaluator | 2 weeks | 3 |
| 2 — solver integration | 3 weeks | 6 |
| 3 — user-defined predicates | 1 week | 7 |
| 4 — polish | 1 week | 8 |

Phase 1 is independently shippable as a `0.x` release, which lets causalDisco
start building against the AST while Phase 2 is in flight.

## 13. What the first PR looks like

To make the plan concrete: the first PR contains only Phase 0 + the skeleton
of Phase 1.

- `R/all-classes.R`: empty S7 `caugi_constraints` class.
- `R/constraints.R`: `caugi_constraints()` builds and returns the object; no
  operators yet.
- `src/rust/src/constraints/{mod,ast}.rs`: types, no logic.
- `tests/testthat/test-constraints-construction.R`: builds an object, checks
  class.
- `NEWS.md`: "Skeleton for constraint system (experimental, unexported)." entry
  under New Features.

That PR is small, reviewable, and locks in the AST shape decisions from
Phase 0 before any real work goes in.
