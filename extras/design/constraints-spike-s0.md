# Phase 0 — Solver Spike Report

> Spike work for `feat/constraints`, dated 2026-05-17.
>
> Decisions to lock down: S0.1 (solver choice), S0.2 (vendor-size
> impact). The remaining S0.3–S0.5 items were already addressed in
> earlier commits on the branch (grounding semantics, schema version,
> tier policy doc).

## S0.1 — Solver candidates

Both candidates were prototyped behind cargo feature flags inside
[`src/rust/src/constraints/spike.rs`](../../src/rust/src/constraints/spike.rs).
The prototype encodes a small canonical CNF problem:

```
(x1 ∨ x2) ∧ (¬x1 ∨ x3)                   — SAT
(x1 ∨ x2) ∧ (¬x1 ∨ x3) ∧ (¬x2) ∧ (¬x3)   — UNSAT
```

plus, for the pumpkin probe, a smoke test of native pseudo-boolean
(`at_most(1, [x1, x2, x3])` combined with `(x1 ∨ x2)`).

### Pumpkin (`pumpkin-solver = "0.3"`)

- License: MIT OR Apache-2.0 ✅
- API: high-level CP solver. Booleans are encoded as 0/1 integer
  domains; CNF clauses are built from `Predicate`s via
  `solver.add_clause(...)`; native PB via `less_than_or_equals(...)`.
- Result: **SAT/UNSAT/PB all correct** on the probes.
- Build: clean against extendr 0.9, no FFI complications.

### Splr (`splr = "0.17"`)

- License: MPL-2.0 ✅ (file-level copyleft on splr's own files; safe
  for a Rust dep — we don't modify splr's source).
- API: classic CDCL SAT solver. Variables are positive integers
  (1-indexed); a clause is a `Vec<i32>` with positive/negative
  literals.
- Result: **SAT/UNSAT correct** on the probes. No native PB.
- Build: clean.

### Verdict on S0.1

Both backends are functionally adequate at the level the spike probes.
Pumpkin offers native PB which would shave some encoder work in Phase
2; splr is leaner and stricter (pure CDCL). The deciding factor is
S0.2 below.

## S0.2 — Vendoring impact

`rextendr::vendor_pkgs(overwrite = TRUE)` was run after each candidate
Cargo configuration. Each line below is the compressed `vendor.tar.xz`
size; bytes are exact, MB is rounded.

| Configuration | bytes | MB | Δ vs baseline |
| --- | ---: | ---: | ---: |
| baseline (no solver) | 3 308 964 | 3.16 | — |
| `solver-splr` only | 3 409 820 | 3.25 | **+0.10 MB** |
| `solver-pumpkin` only | 8 427 272 | 8.04 | **+4.88 MB** |
| both | 8 551 052 | 8.15 | +5.00 MB |

The plan's acceptability threshold was **<2 MB**. Splr is well inside;
pumpkin is roughly 2.5× over. The pumpkin increment comes from its
multi-crate workspace (`pumpkin-core`, `pumpkin-constraints`,
`pumpkin-conflict-resolvers`, `pumpkin-propagators`, `pumpkin-checking`)
plus transitive deps (petgraph, rayon, etc.).

### Verdict on S0.2

**Splr** is the only candidate that meets the vendor-size threshold
for CRAN-friendly shipping.

## Decision

**Solver: `splr = "0.17"`**, behind cargo feature `solver-splr`,
optional and not enabled by default. The encoder will live in
`src/rust/src/constraints/encode.rs` (Phase 2) and translate cardinality
constraints (`at_most`, `at_least`, `exactly`) via:

- `at_most(1, S)` → sequential counter (linear in |S|)
- `at_most(k, S)` for k > 1 → totalizer encoding (`O(|S|·log k)` aux
  variables)
- `at_least(k, S)` → `at_most(|S|−k, ¬S)`
- `exactly(k, S)` → `at_most(k) ∧ at_least(k)`

These are textbook PB-to-CNF encodings; we'll add a small
`cardinality.rs` module that wraps both encodings behind a solver-
agnostic interface, leaving the door open to swap in pumpkin (or
another PB-native solver) later without churning the encoder call
sites.

## What lands on the branch

Phase 0 deliverables committed alongside this report:

- `src/rust/Cargo.toml` — `splr = { version = "0.17", optional = true }`
  + `solver-splr` feature.
- `src/rust/src/constraints/spike.rs` — gated splr smoke probes
  (compile + 2 unit tests).
- Re-vendored `src/rust/vendor.tar.xz` (3.25 MB) and
  `src/rust/vendor-config.toml`.
- Updated `extras/design/constraints-plan.md` solver entry.

## What's deferred to Phase 2

Everything below depends on Phase 2 work and is **not** in scope here:

- Edge-variable scheme + mutex clauses.
- Class invariant clauses (`acyclic` via transitive-closure aux vars).
- Grounder for quantifiers + parameterised cardinality.
- Encoder (Tseitin + the cardinality encodings above).
- Solver wrapper (`Backend` trait + splr impl).
- Reconstructor (assignment → caugi).
- R bindings (`consistent`, `enumerate`, `entails`).

## Open items to revisit

1. **`enumerate()` strategy with splr** — splr's API supports
   incremental solving / model enumeration, but the pattern is
   `solve()` + add blocking clause + `solve()` again. Confirm
   performance on n ≤ 20 graphs during Phase 2 perf-smoke.
2. **`unsat_core` deferred** per the plan; if it later becomes
   important, splr exposes proof traces via the `Certificate` enum and
   we can extract a core there.
3. **License surface** — splr is MPL-2.0; we vendor its source, so
   modifications would need to be released under MPL. We don't plan to
   modify, but flag for `DESCRIPTION` `License:` field handling at
   CRAN submission time. The `LinkingTo` / `SystemRequirements` story
   is unchanged because splr is pure-Rust.
