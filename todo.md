# PAG support in caugi

Branch: `feat/pags`

**Design commitments** (settled 2026-09-10):

- **Selection bias is in scope.** PAGs may contain `---` and `--o`. This rules out
  `pcalg` as a reference for PAG→MAG (its `pag2magAM` explicitly assumes no selection
  variables) and makes FCI rules R5–R7 mandatory. `IntelLabs/causality-lab` is the
  primary reference because it is the only surveyed implementation that has R5–R7.
- **Checks are complete, not necessary-only.** `is_pag()` decides the real question —
  does there exist a MAG `M` with `P = PAG(M)` — so it catches both over-orientation
  (a definite mark that is not invariant across the class) and under-orientation (a
  circle where an invariant mark belongs). `pcalg` has no PAG validity checker, and
  `pywhy-graphs`' `check_pag_definition` tests necessary conditions on the
  directed+bidirected subgraph only.
  **`CausalStructures.jl` does implement exactly this**, and independently arrived at
  the same design: `validation_errors(::PAGConstraints, …)` runs the structural
  checks, builds a MAG with `_mag_from_pag`, and rejects when
  `_pag_signature(_mag_to_pag_edges(mag)) != _pag_signature(cg.edges)` — "the marks
  are not the invariant marks of a Markov equivalence class". Its `_mag_from_pag`
  also matches the `pag_to_mag` here step for step. Useful corroboration of the
  approach rather than a reason to change it.
- **`pcalg` cannot be an oracle for the selection-bias cases.** Verified: on a graph
  that is only `A --- B`, `pcalg::dsepAM(1, 2, {})` returns `TRUE` — it reports two
  adjacent nodes as m-separated, because it ignores undirected edges entirely. This
  silently merges Markov equivalence classes, and it contaminates everything built on
  it (`dsepAMTest`, `fci` + `dsepAMTest`, `dag2pag`). Consequence: `pcalg` fixtures are
  restricted to selection-free graphs, and **`ggm::msep` is the m-separation oracle
  whenever `---` is present** (its `"l"` line type handles it correctly on every case
  tested). `pcalg::pag2magAM` documents the same no-selection assumption, so this is
  consistent with the rest of that package rather than an isolated bug.
- Adjustment uses the **complete** generalized adjustment criterion (Perković et al.
  2018), not the sufficient-but-incomplete generalized backdoor criterion.

## What already exists

- All six PAG glyphs are registered: `-->`, `---`, `<->`, `o-o`, `--o`, `o->`
  (`src/rust/src/edges/mod.rs`), with `Mark::{Arrow,Tail,Circle}`.
- `GraphBuilder` rejects self-loops and parallel/duplicate edges
  (`src/rust/src/graph/builder.rs:133`, `:155`).
- `Ag` (`src/rust/src/graph/ag/mod.rs`) validates acyclicity, the anterior constraint
  and the undirected-endpoint constraint; provides parents/children/spouses/undirected/
  ancestors/descendants/anteriors/posteriors/markov_blanket/districts, plus
  `m_separated` and `minimal_m_separator`.
- `Ag::is_mag()` (`ag/mod.rs:388`) is already a complete exhaustive maximality check.
- `as_caugi(M, class = "PAG")` already parses `pcalg` `amat.pag` codes 0–3.
- `pcalg` and `dagitty` are in `Suggests`, so both are available as test oracles.

## Tasks

### 0. Unblock the class

- [x] Remove the `"pag"` → `GraphClass::Ag` alias at
      `src/rust/src/graph/session.rs:93`. It currently makes `class = "PAG"` silently
      mean AG, which then errors on any circle mark.
- [x] Add `GraphClass::Pag` and wire it through `session.rs`, `view.rs`, `lib.rs`
      (`GraphView::Pag`, class-name strings, `resolve_class`, auto-detection order).
- [x] Stop downgrading PAG to `"UNKNOWN"` in `R/as_caugi.R` (three sites, marked
      `NEEDS TO BE FIXED`). Same for the sibling downgrade sites in that file.
- [x] Accept `class = "PAG"` in the `caugi()` constructor and its docs (`R/caugi.R`;
      not `R/all-classes.R`, which is about export formats). `simple = FALSE` stays
      refused for PAG, which is correct: a PAG carries exactly one edge per pair.
- [x] Give `mutate_caugi()` a `"PAG"` branch (`R/operations.R`). It currently falls
      to `stop("Unknown target class: PAG")`, which is misleading now that PAG is a
      real class. Blocked on `is_pag()` from task 2.

### 1. `Pag` wrapper

- [x] `src/rust/src/graph/pag/mod.rs`, alongside `ag/`. Do **not** extend `Ag`.
- [x] Index neighbours with `PackedBuckets<9>` keyed on the
      `(mark_at_me, mark_at_them)` pair. One uniform indexing rule; every PAG
      predicate then becomes a union of sorted slices, with no per-rule special
      casing. (`Ag` uses a hand-picked `<4>`; that does not generalise to circles.)
- [x] Typed `PagError` variants in `src/rust/src/graph/error.rs`, one per S1 check
      below, each naming the offending node(s) or edge.

### 2. Complete validation — `is_pag()`

Stages S0–S3. S3 alone decides validity; S0–S2 exist so the error messages are
usable. All four are mandatory.

- [x] **S0** — simple graph, no self-loops, every endpoint mark an arrowhead, tail
      or circle. Self-loops and parallel edges are already enforced by
      `GraphBuilder`; the mark check is in `Pag::try_new`.
- [x] **S1** — definite-mark invariants:
  - [x] `-->` sub-skeleton is acyclic (`directed_part_is_acyclic` filters on
        `EdgeClass::Directed`, so `o->` is correctly excluded).
  - [x] No almost-directed cycle. Implemented in the more general form that
        subsumes it: *every* definite arrowhead at `v` from `u` requires that `v`
        is not a definite anterior of `u`. This also catches `o-> `, whose
        arrowhead end is definite even though the other end is a circle.
  - [x] `u --- v` implies no arrowhead at `u` or `v` on any edge. Note `--o` is
        deliberately *not* constrained this way: its circle end is undetermined,
        so the conflict only shows up as under-orientation, which S3 catches.
- [x] **S2** — construct the candidate MAG via `pag_to_mag` (task 6), then verify it
      with `Ag::try_new` (ancestral) **and** `Ag::is_mag()` (maximal). Propagate a
      typed error; do not assume the construction succeeded.
- [x] **S3** — compute `mag_to_pag(M)` (task 7) and compare glyph-for-glyph with `P`.
      Because `M` is in hand, `skeleton(PAG(M)) = skeleton(M)`, so no FCI skeleton
      phase and no Possible-D-SEP search is needed here.
- [x] R-level `is_pag(cg)`. **Deliberately no `force_check`**: unlike `is_ag()`
      and `is_mag()` the class label cannot short-circuit the check, because
      `class = "PAG"` now *is* the complete check. Construction runs S0-S3, so a
      graph carrying that class has already been verified.
- [x] Document the cost honestly in the Roxygen block, as `Ag::is_mag()` does.

### 3. m-separation

- [x] **First, differential-test the *existing* `Ag::m_separated` against `ggm::msep`**
      over all 3,045 four-node MAGs from the ground-truth fixture x every
      (pair, conditioning set) query, ~73k comparisons. `Ag` accepts `---` and has
      never been checked against an independent implementation; `pcalg` has a real
      bug in exactly this spot. This test is worth having on its own, and it is what
      earns `Ag::m_separated` the right to be used as a primitive in task 11.
      **Result: passes.** All 73,080 comparisons agree, including the 553 MAGs that
      contain `---` edges (13,272 queries). So `Ag` does *not* share the
      `pcalg::dsepAM` blind spot, and is cleared for use as a primitive.
      `tests/testthat/test-ag-msep-oracle.R`.
- [x] `src/rust/src/graph/pag/msep.rs`. Ported from causality-lab's
      `PAG.is_m_separated`. **Validated:** all 251 four-node PAGs x 24 queries =
      6,024 comparisons match the per-class oracle signature
      (`tests/testthat/test-pag-msep-oracle.R`).
- [x] Did **not** port from `pywhy-graphs`. Its `definite_m_separated` is an
      unimplemented stub — the body ends at a comment and returns `None`.
- [x] Handle `---` (selection) edges, since selection bias is in scope. Required
      deviating from the reference, which seeds its anterior set with possible
      *ancestors* and so never crosses `---`; this uses possible *anteriors*.
      Reverting that deviation fails the fixture on classes 40 and 82, verified by
      running it as a negative control.
      **Coverage gap:** only 3 of the 251 four-node PAGs contain `---` and none
      contain `--o`, so this is thinly tested until the n = 5 ground truth lands.
- [x] Extend the R-level `m_separated()` to dispatch on PAG (via `GraphView::Pag`;
      no new `#[extendr]` function needed, the existing entry point covers it).
- [x] `minimal_m_separator` for PAGs. **Not** a port of the `Ag` version: the
      linear-time algorithm of van der Zander and Liskiewicz rests on the
      anterior set of `X u Y u I` being a separator whenever one exists, which
      holds for ancestral graphs but is not a claim to assume for a partially
      oriented graph. A greedy shrink is no safer, since m-separation is not
      monotone in the conditioning set. Instead it delegates to a member MAG,
      which is exact -- every member encodes the same independences, so the
      separators coincide. Checked directly against `m_separated()` on the PAG
      over all 251 fixture PAGs x 6 pairs: the set separates, is minimal, and
      `NULL` really means no subset separates.

### 4. Queries

- [x] Ancestry, all four variants — pcalg's `possAn`/`possDe` error on some
      combinations of `possible` × `ds`; caugi covers the full matrix.
      Confirmed: `pcalg::possAn(type = "pag", possible = TRUE, ds = TRUE)`
      raises "Not yet implemented".
      **Validated** against `pcalg::possDe` over 1,984 queries on the 248
      selection-free fixture PAGs, both `ds` modes; the ancestor direction is
      pinned by the reversal identity over all 251
      (`tests/testthat/test-pag-possible-ancestry-oracle.R`).
      A fourth pcalg selection-bias defect surfaced here: on a graph that is
      only `A --- B`, `possDe` reports B as a possible descendant of A.
  - [x] definite ancestors/descendants (`-->` paths only) — already present as
        `ancestors()` / `descendants()`
  - [x] possible ancestors/descendants over any possibly-directed path
        (`definite_status = FALSE`)
  - [x] possible ancestors/descendants restricted to definite-status paths
        (`definite_status = TRUE`, the default)
- [x] `possible_parents_of()` / `possible_children_of()` on `Pag` (Rust; the
      R surface is the ancestry pair, which is what callers need)
- [x] `is_definite_collider()`, `is_definite_noncollider()`, `is_definite_status()`.
      Not ported from `pywhy_graphs`, whose `is_definite_noncollider` returns
      true for `a --> b o-- c` where `b` has no tail on either edge.
- [x] `is_possible_collider()` — a triangle, or an already-definite collider,
      following causality-lab's predicate.
- [x] `is_visible_edge()` — Zhang (2008) Def. 8 / Maathuis & Colombo (2015) Def. 3.1.
      Four independent implementations exist to cross-check against: `pcalg::visibleEdge`,
      causality-lab `_test_edge_visible`, causal-learn `defVisible`, pgmpy
      `MAG.is_visible_edge`.
- [x] `discriminating_path()`
- [x] `uncovered_pd_path()`
- [x] `districts()` / `district_of()` on a PAG = the definite c-components, the
      connected components over `<->` only. A circle mark leaves collider status
      open, so `o->` and `o-o` cannot be relied on to join a component.

### 5. Orientation rules R0–R10

- [x] `src/rust/src/graph/pag/orient.rs`. All of R0 and R1–R10, no subsets: R1–R4 give
      arrowhead completeness, R5–R7 handle selection bias, R8–R10 give tail
      completeness. An incomplete rule set makes S3 reject *valid* PAGs, because
      `mag_to_pag` would come out under-oriented — the rule set and the validator are
      complete together or not at all.
- [ ] ~~R-level `fci_closure(cg, rules = 0:10)`~~ **Not exposed, and the reason
      is substantive.** R4 fires on a discriminating path and must then decide
      whether the middle vertex is a collider, which needs either the separating
      sets FCI collects from data or a known MAG to consult. Neither is
      available from a partial graph alone, so a standalone closure could only
      ever return an arrowhead-incomplete result. The closure is therefore
      internal to `mag_to_pag`, where the source MAG supplies the answer. A
      user-facing version needs a sepset argument; revisit if FCI itself is
      ever implemented.
- [x] Port from causality-lab (`orient_by_rule_1` … `_10`) — cleanest split, one
      method per rule, and the only reference with a unit test per rule.
- [x] Reuse `alg/meek.rs` where the PAG rule coincides with a Meek rule; do not
      duplicate.
- [x] Out of scope: `CausalStructures.jl` also carries an R11 (Wang, Qin & Zhou
      2023, `A --o B` => `A --> B` absent selection bias) used only in its
      local-background-knowledge closure, which omits R5–R7. Not part of
      `mag_to_pag`; note it only so the numbering is not mistaken for a gap.

### 6. `pag_to_mag()`

- [x] Zhang's Theorem 2, tail-augmentation variant (the no-selection-bias version in
      `pcalg::pag2magAM` is not applicable): `o->` → `-->`, `--o` → `-->`, collect
      `o-o` into a PDAG, orient with the existing `dag_from_pdag`. Implemented in
      R in `R/operations.R`, reusing that primitive rather than reimplementing
      Dor-Tarsi in Rust.
- [x] Verify the output rather than trusting it. Construction as `class = "AG"`
      gives the ancestral check; `is_mag()` gives maximality. Tested over all 251
      fixture PAGs on four properties, the strongest being that the result
      reproduces its class's m-separation signature, so it is a member of the
      *right* class and not merely some valid MAG
      (`tests/testthat/test-pag-to-mag.R`).
- [ ] ~~Optional `into = <node>` argument~~ **Not needed.** It exists in
      `pag2magAM` only to serve the generalized backdoor criterion, and the design
      commitment is the complete GAC instead (task 8), which must not be evaluated
      on a single sampled MAG. Add it only if GBC is ever wanted alongside.

### 7. `mag_to_pag()`

- [x] Skeleton is taken directly from the MAG (Markov equivalent MAGs share
      adjacencies), so no skeleton search.
- [x] **No sepset search is needed.** Read the unshielded colliders straight off the
      MAG: for a non-adjacent pair `a`, `c` with common neighbour `b`, orient `b` as
      a collider exactly when the MAG has an arrowhead at `b` from both. Markov
      equivalent MAGs share their unshielded colliders, so this is exact, and it
      drops the exponential `has_separating_set` fallback the earlier plan carried.
      Adopted from `CausalStructures.jl` (`_mag_to_pag_edges`).
- [x] Start from the skeleton with every mark a circle, orient those colliders, then
      `fci_closure` to a fixed point. R4 (discriminating path) can likewise consult
      the MAG's own marks instead of a sepset, as `_pag_rule_r4!` does there.
- [x] **Watch for infinite recursion**: constructing the resulting `Pag` must skip
      PAG validation, or `is_pag` -> `pag_to_mag` -> `mag_to_pag` -> construct `Pag`
      -> `is_pag` loops. `CausalStructures.jl` keeps a `_pag_unchecked` constructor
      for precisely this.
- [x] `dag_to_pag()`. **Not** via `latent_project()`, which returns the ADMG
      projection and can carry both `-->` and `<->` between one pair; a MAG has
      exactly one edge per pair. The right step is `condition_marginalize()`,
      which is Richardson & Spirtes Def. 4.2.1 and already yields a MAG.
      **Validated against `pcalg::dag2pag` on 40 random DAGs with a latent, all
      agreeing.** The two routes share no code, so this also exercises R1-R10
      far beyond what the four-node fixture reaches.

### 8. Adjustment — complete GAC

Implemented in `src/rust/src/graph/pag/adjustment.rs`, once against the
`MarkGraph` mark view, with the MAG and PAG entry points differing only in
which m-separation decides the blocking condition (`GacGraph`). The MAG level
runs on `Ag::m_separated` (validated against `ggm::msep`), the PAG level on
`Pag::m_separated` (validated against the ground-truth classes), so the
criterion adds no separation code of its own.

- [x] `is_amenable(cg, X, Y)` — every proper possibly-directed path from X to Y starts
      with a visible edge out of X. Only `-->` can be visible, so a proper
      possibly-directed path leaving X through `o->`, `o-o` or `--o` already breaks
      amenability. **The reference has no such check**, relying on the invisible first
      edge staying in the proper back-door graph and blocking m-separation. That turns
      out to be sound with this m-separation (the whole possibly-causal path lies in
      the possible anteriors and every interior node is forbidden, so the skeleton
      step already connects X to Y), but the implication is not obvious and the
      predicate is worth having as a user-facing diagnostic, so it is explicit.
- [x] Generalized adjustment criterion (Perković, Textor, Kalisch & Maathuis 2018,
      JMLR 19(1)): amenability; Z contains no possible descendant of X on a proper
      possibly-causal path; all proper definite-status non-causal paths from X to Y
      are blocked by Z. Condition 3 is decided by m-separation in the proper
      back-door graph (Def. 6), as in the paper.
- [x] `minimal` / `all` / `canonical` set types, on a new class-agnostic
      `all_adjustment_sets(cg, X, Y, type = ...)` in `R/adjustment.R`, alongside
      `is_valid_adjustment()` and `is_amenable()`. DAG, ADMG, AG and PAG all
      dispatch; `canonical` is MAG/PAG-only, being a theorem about equivalence
      classes of ancestral graphs. `is_valid_adjustment_admg()` and
      `all_adjustment_sets_admg()` are untouched — the `_admg` suffix names a class,
      so extending those two to accept a PAG would make their names lie; they now
      read as the class-specific aliases of the general pair.
- [x] Did **not** route PAG adjustment through `pag_to_mag`. The criterion runs on
      the PAG's own marks throughout.
- [x] **Oracle for the tests: enumerate the class.** `tests/testthat/test-pag-adjustment.R`
      sweeps all 251 four-node PAGs × 12 ordered (x, y) pairs × 4 conditioning sets =
      **12,048 comparisons, 0 disagreements** against `all(vapply(enumerate_mags(pag),
      ...))`. No restriction on circle endpoints was needed: four nodes carry at most
      twelve, and the sweep runs in about nine seconds.
- [x] Second, external oracle: `tests/testthat/test-pag-adjustment-oracle.R` compares
      `all_adjustment_sets()` with `pcalg::adjustment()` (a wrapper over
      `dagitty::adjustmentSets()`, so no shared code) for all three set types on the
      248 selection-free four-node PAGs — **8,928 comparisons, 0 disagreements**,
      the canonical set included. The 3 PAGs with `---` edges are excluded, per the
      design commitment that `pcalg` cannot be an oracle under selection bias.
- [x] That same helper gives a second, independent check on `pag_to_mag` (its output
      must be in the enumerated class) and on `is_pag` (a valid PAG must have a
      non-empty class).

**Two deviations from `CausalStructures.jl`, both deliberate:**

1. Its PAG-level blocking check moralizes the back-door graph by marrying the
   parents and spouses of one node at a time, where its own MAG-level check uses
   the Richardson–Spirtes collider-path augmentation. Plain moralization is wrong
   on a collider chain: for `A <-> B <-> C <-> D` it never adds the `A - D` edge,
   so it reports `A ⊥ D | {B, C}` and accepts `{B, C}` as a valid adjustment set,
   when conditioning on both colliders in fact opens the path. Confirmed against
   `ggm::msep`. Both levels here use the augmented form. Named test:
   "conditioning on a chain of colliders is not a valid adjustment".
2. Its `PossDe`/`PossAn` traverse `---` edges, making both endpoints of a
   selection edge a possible descendant *and* a possible ancestor of the other.
   A possibly-directed path needs an arrowhead-or-circle at the far end, which
   `---` does not have, so `---` is not traversed here. On fixture PAG 40 this is
   the difference between accepting and rejecting `{N2, N3}`, and the
   every-member oracle agrees with accepting it. `PossAn` in the *canonical set*
   formula is read as the possible anterior set, which does cross `---`; the two
   coincide on every selection-free graph, so the paper's own formula is
   recovered wherever the paper applies.

### 9. Interop

- [x] `amat.pag` export, as `as_adjacency(cg, coding = "marks")` rather than a
      separate `caugi_to_pcalg()`: caugi already has `as_adjacency()` and the
      coding is the only thing that differs.
- [x] Two conventions to get right: for `amat.pag` the mark code refers to the
      **column** index (opposite of `amat.cpdag`), and the coding is
      `0 = none, 1 = circle, 2 = arrowhead, 3 = tail`. causality-lab uses the
      identical coding, so one converter serves both.
- [x] `as_caugi()` / `caugi_to()` for `dagitty` PAGs — its DSL writes circles as `@`
      (`pag { X @-> Y ; W @-@ Z }`) and `graphType()` returns `"pag"`.
- [x] Note for any future `MixedGraphs` bridge: its partially-undirected glyph is
      `o--` where caugi's is `--o`.

### 10. Plotting and formats

- [x] Circle endpoint marks in `R/plot-grobs.R` / `R/plot-routing.R`.
- [x] `format-dot.R`, `format-mermaid.R`, `format-graphml.R`: circle marks.
- [x] Check `caugi_layout` handles PAGs — `"sugiyama"` is directed-only, so `"auto"`
      must not pick it for a graph with circle marks.

### 11. Tests

The ground truth is **already built and committed**:
`tools/pag-ground-truth/generate.R` -> `tests/testthat/fixtures/pag-ground-truth-n4.rds`.

It derives the complete set of valid 4-node PAGs from the *definition* — enumerate
mixed graphs, keep the ancestral and maximal ones, group by full pairwise
m-separation, mark definite iff invariant across the class — using `ggm::msep` as
the only separation primitive. It touches no caugi code, no FCI, no R0–R10 and no
Zhang construction, so it is independent of every component `is_pag()` is built
from. Verified output: 15,625 candidates -> 3,057 ancestral -> 3,045 MAGs ->
**251 Markov equivalence classes = 251 distinct valid PAGs**, ~70s, offline.

Two self-checks inside the generator are the reason it can be trusted, and both
currently pass. If either fails the oracle is broken and must not be used:

- no equivalence class contains two different skeletons;
- classes correspond 1:1 to distinct PAGs (a PAG is a complete invariant of its
  class — this is what caught the `dsepAM` defect, which gave 248 classes for 251
  PAGs).

- [x] **Exhaustive `is_pag()` on 4 nodes.** The candidate space is 10^6 (each of the
      6 pairs is absent or carries one of 9 mark pairs). Assert
      `is_pag(G) == (key(G) %in% valid_keys)` for all 251 positives, plus the full
      10^6 sweep if it runs fast enough in Rust, otherwise a large random sample.
      This is a complete test of S3 at n = 4 and needs no reference implementation.
- [x] **Near-miss mutants.** For each valid PAG, mutate one edge (any mark pair, or
      add/remove). 13,554 mutants; **12,882 (95%) are invalid and 672 (5%) land back
      on a valid PAG**. Decide each by table lookup — never by assuming a mutation
      breaks validity, which would bake in 672 false assertions. These are the cases
      a buggy S3 accepts, so they carry most of the signal.
- [x] **Under- vs over-orientation, split out explicitly.** From the mutant set, keep
      those that turn a definite mark into a circle (under-oriented) and those that
      turn a circle into a definite mark (over-oriented) and that the table says are
      invalid. No other implementation rejects these, so they need named tests.
- [x] **n = 5 ground truth.** Generated with the caugi backend after it passed
      the task-3 differential test, capped at six edges: 1,180,409 candidates ->
      175,950 MAGs -> 15,795 classes, 1:1 with 15,795 valid PAGs. Only the 187
      carrying a selection glyph are committed (7.7 KB); the full set with its
      member MAGs is 2.7 MB of mostly redundant data.
      **This closed the `--o` gap**: 120 of those 187 carry one.
- [x] **Exhaustive m-separation oracle** from causality-lab's
      `test_is_m_separated`: their DAG over 8 observed and 5 latent variables,
      asserting `d_separated` in the DAG equals `m_separated` in the
      marginalization, over all 28 pairs x 64 conditioning subsets.
      Implemented as `condition_marginalize()` rather than their hand-built
      PAG, which is stronger: it pins the marginalization too.
- [x] **Per-rule tests** for R5–R10 from the same file (`test_orient_by_rule_5` …
      `_10`) — small explicit graphs hitting the triangulated and bridged cases.
      In `#[cfg(test)] mod tests` of `orient.rs`, calling each `rule_n()`
      directly and asserting the whole mark table so that what the rule leaves
      alone is pinned too. **This found a real bug in R8**, inherited from
      `CausalStructures.jl`: it asks for an arrowhead at `beta` and a tail *or
      circle* at `alpha`, which misses Zhang's `alpha --o beta --> gamma`
      antecedent and admits `alpha o-> beta --> gamma`, where `alpha` need not
      be an ancestor of `gamma`. Now a tail at `alpha` and either mark at
      `beta`, as Zhang and causality-lab have it. The bug was inert for
      everything else tested — all 251 n = 4 PAGs, the n = 5 selection
      fixture, and the `pcalg` differential test still pass unchanged — which
      is exactly why the per-rule tests were worth writing.
- [x] **Round-trip** `mag_to_pag(pag_to_mag(P)) == P` over all 251 fixtures.
- [x] **Differential test against `pcalg`**, done through `dag_to_pag` vs
      `pcalg::dag2pag` on 40 random DAGs with a latent, all agreeing. That
      exercises the same `mag_to_pag` path while also covering the
      marginalization, and needs no `dsepAMTest` (whose documented
      `suffStat$amat` argument is in fact `suffStat$g`).
- [x] ~~Golden PAGs baked in as static matrices~~ — the differential test
      calls `pcalg::dag2pag` live under `skip_if_not_installed()` instead,
      which covers 40 random DAGs rather than a handful of frozen ones. pcalg
      is in `Suggests`, so this costs nothing on CRAN.
- [x] `pcalg::visibleEdge` fixture: `matrix(c(0,3,0,0, 2,0,2,3, 0,2,0,3, 0,2,2,0), 4, 4)`
      = `a-->b`, `b<->c`, `b-->d`, `c-->d`.
- [ ] ~~`pcalg::adjustment` Example 4.1 fixture~~ — that fixture is a **CPDAG**,
      which `all_adjustment_sets()` does not accept. Superseded anyway by the
      8,928-comparison sweep against `pcalg::adjustment` over the PAG fixture.
- [x] `pcalg::backdoor` PAG fixture: Maathuis & Colombo (2015) Fig. 5a, 7 nodes,
      `L = 5`, expected backdoor set `{1, 2}`. Reproduces, and widened into a
      sweep over the whole fixture: the *verdicts* agree on all 2,976
      (PAG, x, y) triples. The **sets** differ in 12 of the 936 identified
      cases, because the two implementations pick a different admissible
      member MAG; both answers are genuine back-door sets, which
      `test-pag-backdoor-oracle.R` checks from the definition. Getting there
      needed the reference's restriction of `R*` to MAGs *without* selection
      variables, which I had dropped -- without it `enumerate_mags()` offers
      an all-`---` member first and the verdict flips.
- [x] Adjacency-matrix round-trip using causality-lab's 10-node / 11-edge fixture.
- [x] `ggm::MarkEqMag` as an independent oracle. Used on `markov_equivalent()`,
      which is implemented by comparing PAGs, so it validates `mag_to_pag` too.
      Three-way agreement over 400+ MAG pairs between caugi, the fixture's own
      m-separation grouping, and ggm's skeleton-plus-colliders-with-order
      criterion -- three different routes to the same question.
      Note `MarkEqMag` must be given adjacency matrices via `makeMG()`, not the
      flat triple form: triples omit isolated nodes and it then errors indexing
      one matrix by the other's node names.
- [x] Edge cases per `AGENTS.md`: empty graph, single node, all-circle complete
      graph, PAG that is already a MAG, PAG with only `---` edges.

### 12. Docs

- [x] Roxygen for every new exported function, with `@examples`.
- [x] `NEWS.md` under **New Features**: PAG class, `is_pag()`, `pag_to_mag()`,
      `mag_to_pag()`, `dag_to_pag()`, `fci_closure()`, PAG queries, PAG adjustment.
- [x] `_pkgdown.yml`: add the new functions to the right concept sections.
- [x] Review `vignettes/` per `AGENTS.md` — at minimum the graph-classes vignette and
      any "available classes" list needs `"PAG"` added.
- [x] Update the class list in `AGENTS.md` (move `"PAG"` from Planned to Supported).
- [x] `air format .` before each PR; `air format . --check` is clean. Do **not**
      run `cargo fmt`: it reformats `graph/aid.rs`, `graph/metrics.rs` and
      `graph/alg/adjustment.rs`, which are already non-conformant on `main`.
      Format single files with `rustfmt <path>` instead -- and note that
      `rustfmt src/lib.rs` is *not* a single file: it follows the `mod` tree
      and formats the whole crate, so it hits those three too. Check
      `git diff --stat` after running it on `lib.rs`.

## Still missing relative to `CausalStructures.jl`

Ordered by value. The first is the oracle the rest lean on.

- [x] `enumerate_mags(pag)`. Capped at 20 circle endpoints. Validated on the
      strongest available check: the fixture records each class's members, so
      the enumerated count must equal `length(classes[[k]])` exactly — it does,
      for all 251 four-node PAGs.
- [x] `markov_equivalent(mag1, mag2)` — same PAG, nodes aligned by name.
- [x] PAG adjustment: the complete GAC (task 8), at the MAG level too. Written
      once over `MarkGraph`, so the two levels share everything but their
      m-separation. Two deviations from their version, recorded under task 8.
- [x] D-SEP(X, Y) as `d_sep_set()`, ported from their `possible_d_sep` (a
      misnomer: what it computes is the Maathuis & Colombo D-SEP, not FCI's
      Possible-D-SEP). Their docstring example reproduces exactly.
- [ ] FCI's actual Possible-D-SEP, on a partially oriented graph using
      *possible* colliders. Only needed if FCI itself is implemented.
- [x] Generalized backdoor for MAGs and PAGs, as `backdoor_set()`. Ported from
      their `backdoor_set`, including the `R*` restriction to selection-free
      members; `possible_descendants` for the PAG forbidden set comes from
      caugi's own.
- [x] `pagcauses` (identifiable causes from a PAG).
- [ ] ~~The ID algorithm, `possible_joint_parent_sets`~~ — **out of scope.**
      Neither is about PAGs specifically: the ID algorithm is Shpitser and
      Pearl's identification for a causal diagram with latents, and belongs
      with the ADMG code if it is ever wanted.

Things caugi has that they do not: the exhaustive ground-truth fixture, the AID
metric, PAG plotting and format export, and `pcalg`/`dagitty` interop.

## Follow-ups

- [x] **`is_visible_edge()` accepts a MAG.** Done via a `visible_edge_in_mag()`
      shim, since `MarkGraph` is private to the `pag` module. caugi now agrees
      with pcalg's documented answers on all three edges of its own fixture.
      This also turned up a substantive doc error, now fixed: the claim that
      every directed edge in a circle-free class is visible is false.
- [x] **Dor-Tarsi was implemented twice.** The R `dag_from_pdag()` is now a
      wrapper over `Pdag::dag_extension()` in Rust, per the algorithms-in-Rust
      convention. Moving it turned up a **bug in the old R version**: it read
      Dor and Tarsi's condition (b) as "the undirected neighbours of the sink
      are pairwise adjacent", where the condition is that each undirected
      neighbour is adjacent to *all* other neighbours. On `A --> B <-- C` with
      `B --- D` it therefore oriented `D --> B`, adding two v-structures. None
      of the 23 existing tests covered a case where the two conditions differ;
      there is one now.

      The copy inside `Pag::to_mag` **stays**, and is not a duplicate to
      merge: it runs on the `o-o` component with the *weaker* condition (b),
      which is sound there precisely because R1 closure has already removed
      any `x o-o u` where `x` has an arrowhead from a node not adjacent to
      `u`. It also needs chordality of that component as an error condition,
      which the PDAG version does not. Recorded in a comment at both sites.

## Now-cheap follow-ups this PR created

- `to_cpdag()` for a PDAG. Its doc comment in `view.rs` says it would mean
  extending to a consistent DAG and taking that DAG's CPDAG, "which is not yet
  implemented". `Pdag::dag_extension()` is the missing half, so it is now two
  lines plus tests. Left out as unrelated to PAGs.

## Coverage gaps still open

- **No valid four-node PAG distinguishes the two `definite_status` modes.**
  Checked exhaustively: for every one of the 251 fixture PAGs and every node,
  `possible_descendants(ds = TRUE)` equals `possible_descendants(ds = FALSE)`.
  So the differential test against `pcalg::possDe` compares both modes but
  cannot discriminate between them, and the distinction rests on the Rust unit
  tests alone. The n = 5 fixture is the way to close this.
- **`--o` appears in no valid four-node PAG**, so R5-R7 and the selection-bias
  paths rest on the per-rule cases ported from causality-lab and
  `CausalStructures.jl`, plus the n = 5 fixture.
- **Visibility is thinly covered**: only 108 directed edges exist across the
  248 selection-free fixture PAGs, and the collider-path limb of the
  definition needs longer paths than four nodes allow.

## Which reference to trust

Neither external package is reliable enough to be a primary oracle. Both have
confirmed defects, all found on this branch and all verified against a third
source before being acted on. The order of reliance is therefore:

1. **Definitional oracles** — the ground-truth fixture (every valid PAG on four
   nodes, derived from the definition) and `enumerate_mags()` (a set is valid
   for a PAG iff valid in every member MAG). These rest on nothing but the
   definition and are the primary check for anything new.
2. **`CausalStructures.jl`** — the closest design peer and the reference to port
   from. Confirmed bugs: its PAG adjustment moralizes one node at a time and so
   misses collider-path augmentation (`A <-> B <-> C <-> D` wrongly accepts
   `{B,C}`); its possible-descendant/ancestor searches and its
   potentially-directed path search all traverse `---`, which cannot lie on a
   possibly-directed path.
3. **`pcalg`** — useful for selection-free graphs only. Confirmed defects, all
   from the same root: `dsepAM()` ignores undirected edges entirely (on a graph
   that is only `A --- B` it reports the two adjacent nodes m-separated);
   `possDe()` reports `B` a possible descendant of `A` there; and
   `pag2magAM()` documents the no-selection assumption outright. Every pcalg
   comparison on this branch is restricted to the 248 selection-free fixture
   PAGs for that reason.

`ggm::msep` is the exception: it handles `---` correctly on every case tested
and is what the ground-truth fixture was built from.

## Conventions settled during this work

- **Algorithms live in Rust**, with R providing only the wrapper. Recorded in
  `AGENTS.md`. Composing already-exported functions stays in R (`dag_to_pag()`
  is such a composition); a loop that walks the graph does not. Note three
  pre-existing R-level algorithms predate this and are untouched:
  `condition_marginalize()`, `dag_from_pdag()` and `exogenize()`.
- **A `"PAG"` object is fully validated.** The class is a guarantee, so
  `is_pag()` may short-circuit on it, and callers need not re-check.

## Known blockers and latent bugs found along the way

- **Adding an `#[extendr]` function: append its wrapper line to `R/extendr-wrappers.R`.**
  This repo's convention is an additive edit, one line per new function — see
  commit 40d98453, which added `rs_enumerate_dags` and `rs_count_dags` that way,
  leaving the header and every `invisible()` wrapper untouched. Do **not** try to
  regenerate the whole file: `rextendr::document()` and
  `rextendr::register_extendr()` are no-ops as of 0.4.0, and calling
  `wrap__make_caugi_wrappers` directly reformats ten unrelated lines as
  collateral (extendr-api 0.9 no longer emits `invisible()`), which does not
  belong in a feature PR.
- ~~**`as_caugi()` silently misreads `amat.pag` input for non-PAG classes.**~~ Fixed
  in `fix: decode mark-coded matrices in as_caugi regardless of class`. The 0–3
  mark decoding is gated on `class == "PAG"` (`R/as_caugi.R`). For `class = "AG"` the
  values `{0,2,3}` pass validation and then fall through to the generic branch, where
  every nonzero entry becomes a `-->` edge. That is silent data corruption for anyone
  passing a MAG in `amat.pag` form. Fix in task 9; it is why
  `test-ag-msep-oracle.R` builds its graphs with a local decoder instead.
- **`pcalg::dsepAM` ignores undirected edges** — see the design commitments above.
- **Dor-Tarsi is now implemented twice**: in R as `dag_from_pdag()` (pre-existing)
  and in Rust inside `Pag::to_mag` (added here, because PAG validation runs in
  Rust and could not call back into R). Under the Rust-only policy the R one
  should move down and both should share a single implementation. Not done here
  to keep the diff on PAG; worth a follow-up.

## Reference notes

| Implementation | Use it for |
| --- | --- |
| causality-lab (Python) | **Primary reference.** R1–R10 incl. selection bias, visibility, discriminating paths, m-separation, definite c-components. Has per-rule unit tests. |
| pywhy-graphs (Python) | `pag_to_mag` (Zhang Thm. 2), `pds`/`pds_path`, `uncovered_pd_path`, exporters. **Avoid** `definite_m_separated` (stub) and `check_pag_definition` (incomplete). |
| pcalg (R) | `amat.pag` coding, `dag2pag` fixtures, `visibleEdge`, `possAn`/`possDe`, `searchAM`, documented examples. No PAG validity checker. Assumes no selection bias in `pag2magAM`. |
| causal-learn (Python) | Second opinion on R0–R10 and `defVisible`. `ArrowConfusion`/`SHD` metrics work on PAGs. |
| dagitty (R) | PAG DSL, and the complete GAC via `adjustmentSets`. Most other verbs error on `pag`. |
| ggm (R) | `isAG`, `msep`, `MarkEqMag` — MAG-level oracles. No circle marks. |
| MixedGraphs (R) | Edge-type table design (note its `revchar` column). PAG is conversion-only. |
| pgmpy (Python) | MAG only; explicitly excludes circle endpoints. Just `is_visible_edge` as a cross-check. |
| **CausalStructures.jl** (Julia) | **Closest peer.** Same class hierarchy and validate-on-construction design. Has the complete round-trip PAG check, `mag_to_pag` (R1–R10), `mag_from_pag`, the real GAC (Perković et al.), generalized backdoor, possible-D-SEP, `enumerate_mags`, `markov_equivalent`, and an ID algorithm. Supports selection bias (its glyph for partially undirected is `o--`, where caugi writes `--o`). Its tests are hand-written per-rule cases plus brute-force class enumeration on selected graphs, with no exhaustive sweep over small PAGs — complementary to the ground-truth fixture here, which covers all of n = 4 but barely reaches R5–R10. |
