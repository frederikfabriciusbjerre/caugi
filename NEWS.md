# caugi (development version)

## New Features

- `plot()` now automatically bends edges around non-incident nodes that they
  would otherwise pass straight through, so edges between collinear nodes (e.g.
  within a tier) and edges crossing unrelated nodes stay visible. This is
  controlled by `edge_style$route` (default `TRUE`); disable it with
  `edge_style = list(route = FALSE)`, or per edge type/edge via the usual
  `edge_style` overrides.
- Add `==` and `!=` methods for `caugi` objects so `cg1 == cg2` returns a single
  logical comparing graph content (class, nodes, edges, `simple`) rather than
  session identity.
- Add first-class `"CPDAG"` graph class support across the constructor
  (`caugi()`), coercion (`as_caugi()`), and class mutation (`mutate_caugi()`).
  Construction validates the full CPDAG invariant (chordal chain components, an
  acyclic component DAG, Meek closure, and strong arrow protection).
  `generate_graph(class = "CPDAG")` now returns a graph with
  `@graph_class = "CPDAG"` instead of `"MPDAG"`, the precise label for the
  essential graph of a Markov equivalence class. Predicates defined on PDAGs and
  MPDAGs (`is_pdag()`, `is_mpdag()`, etc.) continue to accept CPDAGs unchanged.

## Improvements

* `caugi_layout_tiered()` gains a `jitter` argument (default `0`). When set to
  a positive value, nodes within the same tier are offset by alternating
  +`jitter` / −`jitter` in the perpendicular direction.
- Meek-closed PDAGs are now reported with `@graph_class = "MPDAG"` instead of
  `"PDAG"`. This affects the result of `meek_closure()` and
  `generate_graph(class = "CPDAG")`. Predicates and verbs defined on PDAGs
  (`is_pdag()`, `mutate_caugi()`, etc.) continue to accept MPDAGs unchanged.
- `adjustment_set(type = "backdoor")` now returns an inclusion-minimal backdoor
  adjustment set, computed in linear time as a minimal d-separator in the proper
  backdoor graph, rather than the full set of parents of the exposure.
  `"PDAG"`. This affects the result of `meek_closure()`. Predicates and verbs
  defined on PDAGs (`is_pdag()`, `mutate_caugi()`, etc.) continue to accept
  MPDAGs unchanged.
  `"PDAG"`. This affects the result of `meek_closure()` and
  `generate_graph(class = "CPDAG")`. Predicates and verbs defined on PDAGs
  (`is_pdag()`, `mutate_caugi()`, etc.) continue to accept MPDAGs unchanged.
- The performance vignette is now a true vignette (rather than a pkgdown-only
  article) and is rebuilt manually from a cross-language harness under
  `tools/benchmark/`. The harness compares `caugi` to `igraph`, `bnlearn`,
  `dagitty`, `ggm`, `pcalg`, `pgmpy`, and Tetrad on a `n ∈ {100, 1000, 10000}`
  grid. The d-separation benchmark now uses a minimal d-separator computed via
  `minimal_separator()` (previously used a backdoor adjustment set, which is
  not in general a d-separating set).

## Bug Fixes

- Fix `dag_from_pdag()` failing with `` `from`, `edge`, `to` must be equal
  length. `` when a sink had multiple undirected neighbors (#298).
- Fixed a bug causing a partially undirected (`--o`) edges to
  be plotted as undirected edges.
- Fix `adjustment_set(type = "backdoor")` returning an invalid (often empty)
  set when a parent of the exposure lies on a backdoor path but is not an
  ancestor of the outcome (#308). The result is now always a valid backdoor
  adjustment set.

- Fixed `is_mag()` returning incorrect results for some ancestral graphs.
- Stripped non-build files (`tests/`, `examples/`, trybuild fixtures) from the
  vendored Rust dependencies so no vendored path exceeds 100 characters. This
  silences pak's "very long paths" warning and avoids installation failures on
  Windows without long-path support (#319).
  Adjacency was tested by binary-searching the concatenation of separately
  sorted neighbor buckets, which is not globally sorted, so some adjacent
  pairs were missed (#309).
- Fixed `to_dot()` and `to_mermaid()` (and `write_dot()`/`write_mermaid()`)
  silently converting partial `--o` and `o-o` edges into plain directed edges,
  dropping the circle endpoints (#307).

# caugi 1.2.0

## New Features

- Add `caugi_layout_circle()` and a `"circle"` method for `caugi_layout()` that
  places nodes evenly along the perimeter of a circle (#108).
- Add `list_caugi_edges()` function to list all available edge types.
- Add first-class `"MPDAG"` graph class support across constructor, class
  mutation, and class resolution. `class = "AUTO"` now resolves Meek-closed
  PDAGs to `"MPDAG"`.

## Improvements

- Improved performance of all queries. Speedups are more significant on larger
  graphs, but even on small graphs, queries are roughly 5x faster.
- `exogenize()` is now implemented in Rust for DAGs, which reduces overhead on larger graphs.
- `normalize_latent_structure()` is now implemented in Rust for DAGs for faster latent normalization workflows.
- `minimal_d_separator()` is renamed to `minimal_separator()` and now supports
  ADMG and AG inputs (previously DAG-only), returning a minimal m-separator.
  Implemented via the unified linear-time algorithm of van der Zander &
  Liśkiewicz (UAI 2020). The old name `minimal_d_separator()` remains as a
  deprecated alias.

## Bug Fixes

- Fix `m_separated()` on ADMGs: moralization now marries every pair in
  `pa(v) ∪ sp(v)`, not just `pa(v)`. The old code missed moral edges from
  bidirected co-parents and gave false positives (e.g. claimed `Z ⊥ Y | X` for
  `Z -> X -> Y`, `X <-> Y`).
- Fix `is_valid_adjustment_admg()` and `all_adjustment_sets_admg()` to verify
  the GAC's m-separation condition in the proper backdoor graph rather than
  via a per-neighbour decomposition. The old check trivially accepted neighbours
  of `X` that were themselves in `Z`, so it falsely classified `{C}` as a valid
  adjustment set in the M-bias ADMG `C -> X, C <-> X, C -> Y, C <-> Y, X -> Y`
  (#277).

# caugi 1.1.0

## New Features

- Add `normalize_latent_structure()`, which normalizes the latent structure of a
  DAG while preserving the marginal model over observed variables.
- Add `minimal_d_separator()`, which computes a minimal d-separator between
  sets of nodes in a DAG, with support for mandatory inclusions and restrictions.
- Add `posteriors()` query function, which is the dual of `anteriors()`. It
  returns all nodes reachable by following paths where every edge is either
  undirected or directed away from the source node. For DAGs, `posteriors()`
  equals `descendants()`. For PDAGs and AGs, it includes both descendants and
  nodes reachable via undirected edges.
- You can now specify whether to use an open or closed graph definition for the
  queries `ancestors()`, `anteriors()`, `descendants()`, and `posteriors()`.
  This can be set globally with `caugi_options()` or locally with the
  `open = TRUE/FALSE` argument. The default remains `open = TRUE`.
- Add `is_mpdag()` query to check whether a PDAG is closed under Meek's
  orientation rules (R1-R4), and `meek_closure()` to orient all implied edges
  until Meek closure.

## Improvements

- `caugi_options()` now supports nested key drilling: multiple unnamed arguments
  traverse nested options (e.g., `caugi_options("plot", "tier_style", "fill")`).
- Rust remains the single source of truth for graph state. Graph properties
  (`simple`, `graph_class`, `nodes`, `edges`) are sourced from the `session`.
  - A session is always created, including empty graphs (n = 0), which simplifies
    property access.
  - Deprecated compatibility properties `@.state`, `@name_index_map`, `@built`,
    and `@ptr` now warn on access and return `NULL`.
  - Deprecated compatibility constructor arguments `build` and `state` in
    `caugi()` now warn and are ignored.
- The `inplace` parameter in verb functions (`add_edges()`, `remove_edges()`,
  `set_edges()`, `add_nodes()`, `remove_nodes()`). All graph modifications now use
  copy-on-write semantics for consistency with R conventions. The parameter is
  deprecated and ignored with a warning.
- Added `all.equal` and `compare_proxy` methods for caugi objects to support
  graph-content comparison in tests.
- Add `asp` parameter to `plot()` for controlling the aspect ratio. When `asp = 1`,
  the plot respects equal units on both axes, preserving the layout
  coordinates. Works like base R's `asp` parameter (y/x aspect ratio) (#195).
- Add `pdag_to_dag()` function that generates a random DAG consistent with a
  given CPDAG/PDAG structure if possible (#201).

## Bug Fixes

- Fixed a bug causing `plot()` to use incorrect layout if node names were not
  in the same order as in the graph object (#198).
- Fixed `set_edges()` so that it correctly replaces symmetric edges in
  simple graphs.

## Deprecations

- The parameter `all` in `districts()` has been deprecated. Use `districts()`
  without arguments to get all districts.

# caugi 1.0.0

## New Features

- Add support for Ancestral Graphs (AGs), which combine directed (`-->`),
  bidirected (`<->`), and undirected (`---`) edges while satisfying ancestral
  graph constraints. New functions: `is_ag()`, `is_mag()`.
- Add `mode` argument to `neighbors()`/`neighbours()` to filter neighbors by edge
  direction or type (`"all"`, `"in"`, `"out"`, `"undirected"`, `"bidirected"`,
  `"partial"`). This is a structural query, and not a semantic query!
- `neighbors()` now supports `class = "UNKNOWN"` graphs, including `mode`-based
  filtering.
- Add `simulate_data()` that enables simulation from DAGs using SEMs. Standard
  linear Gaussian SEMs are defaults, but more importantly custom SEMs are
  available.
- Add `"AUTO"` parameter for `class` in `caugi` objects. This automatically
  picks the graph class in order `DAG`, `UG`, `PDAG`, `ADMG`, `AG`.
- Add Ancestral Graphs (AG) with support for directed, bidirected, and
  undirected edges, plus new queries `is_ag()` and `is_mag()` and m-separation
  for AGs.
- Add `exogenize()` function that exogenizes variables for any graph type.
  Current implementation is written in R, but it is so simple that it might be
  preferable over a Rust implementation. This might be changed later.
- Add `latent_project()` function that does latent projection from DAGs to
  ADMGs.
- Add native caugi serialization format for saving and loading graphs. New
  functions: `write_caugi()`, `read_caugi()`, `caugi_serialize()`, and
  `caugi_deserialize()`. The format is a versioned JSON schema that captures
  graph structure, class, and optional metadata (comments and tags).
- Add `plot()` method for visualizing graphs using various layout algorithms.
  The plot is rendered using grid graphics and returns a `caugi_plot` object
  that can be customized with `node_style`, `edge_style`, and `label_style`
  arguments. The `plot()` method accepts layouts as strings, functions, or
  pre-computed data.frames.
- Add `caugi_layout()` function to compute node coordinates for graph
  visualization.
- Add dedicated layout functions: `caugi_layout_sugiyama()`,
  `caugi_layout_fruchterman_reingold()`, `caugi_layout_kamada_kawai()`,
  `caugi_layout_bipartite()`, and `caugi_layout_tiered()`. Each function
  provides an API for its specific algorithm.
- Add `to_dot()` and `write_dot()` functions for exporting caugi graphs to DOT
  (graphviz) format. The resulting object is a new S7 class, `caugi_export`,
  which has a `knit_print()` method for rendering DOT graphs in R Markdown and
  Quarto documents.
- Add GraphML and Mermaid import/export support: `to_graphml`, `write_graphml`,
  `read_graphml`, `to_mermaid`, `write_mermaid`, and `read_mermaid`
- Add plot composition operators for creating multi-plot layouts: `+` and `|`
  for horizontal arrangement, `/` for vertical stacking. Compositions can be
  nested arbitrarily (e.g., `(p1 + p2) / p3`).
- Add `caugi_options()` function for setting global defaults for plot
  appearance, including composition spacing and default styles for nodes,
  edges, labels, and titles.
- Add `caugi_default_options()` function to query or reset to package default options.
- Add a new vignette, "Graph Visualization with caugi", demonstrating the new
  plotting capabilities and customization options.

## Improvements

- Add favicons for the package website.
- Standardize `is_caugi()` validation calls internally.
- Adopt [air](https://github.com/posit-dev/air) as the R code formatter for the package.
- `caugi_layout_tiered()` now returns a `tier` column and `orientation` attribute in the layout data.frame, allowing `plot()` to automatically use tier information without requiring the `tiers` argument to be passed again.

## Bug Fixes

- Fix typo in error messages and documentation examples.
- Remove unused `index_name_map` parameter from internal `.cg_state()` function.
- Fix interpretation of directed edge endpoint positions in the Rust backend,
  improving correctness of direction-dependent algorithms/metrics (e.g.
  topological sorting and structural Hamming distance computations).
- Fix bug in `is_cpdag` function that returns `TRUE` on non-complete PDAGs.
- Fix bug in `shd` returning positive values for equivalent graphs given in shuffled order.

# caugi 0.4.0

- Add support for Acyclic Directed Mixed Graphs (ADMGs), which combine directed
  edges representing causal relationships with bidirected edges representing
  latent confounding.
- Add new functions for querying ADMGs: `is_admg()`, `spouses()`, `districts()`,
  and `m_separated()` (generalization of d-separation for graphs with bidirected
  edges).
- Add functions for adjustment set validation in ADMGs:
  `is_valid_adjustment_admg()` and `all_adjustment_sets_admg()` implementing
  the Generalized Adjustment Criterion.
- Add `mutate_caugi()` function that allows conversion from one graph type to
  another.
- Add custom printing method for `caugi` objects.
- Add optional `edges_df` argument to `caugi()` for easier construction from
  existing data frames containing the columns `from`, `edge`, and `to`.
- Improve error handling across all graph types (DAG, PDAG, UG, ADMG) with more
  descriptive error messages.
- Update `as_adjacency()` and `as_igraph()` to support bidirected edges.
- Update `as_caugi()` documentation to include "ADMG" as a valid class type for
  conversion.

# caugi 0.3.2

- Change website to `caugi.org/`.
- Minor modifications to `CONTRIBUTING.md`.
- Minor `README` rewrite.

# caugi 0.3.1

- Remove the use of `lockBinding` and `unlockBinding` in the package to
  silence R CMD check notes.

# caugi 0.3.0

- Add `mutate_caugi` function that allows conversion from one graph type to another.
- Add custom printing method.
- Add optional `edges_df` argument to `caugi` for easier construction from existing data frames containing the columns `from`, `edge`, and `to`.
- Update _How to use `caugi` in a package_ vignette to use new conversion functionality.
- Add `CONTRIBUTING.md` to github.

# caugi 0.2.1

- Update function documentation to make package CRAN ready.
- Update performance vignette and change it to article.
- Add Michael Sachs and Johan Larsson to Authors in DESCRIPTION.
- Patch S4 class reading for `as_caugi`.

# caugi 0.2.0

- Drop dependencies on `dplyr` and `tibble`.
- Improve performance by letting all data wrangling be done by `data.table`.
- Edges and nodes are now `data.tables`.

# caugi 0.1.0

- Add Undirected Graphs (UG) to `caugi`.
- Refactor Rust backend for DAGs.
- Add NEWS.md!
