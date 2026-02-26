# Changelog

## caugi (development version)

### New Features

- Add
  [`minimal_d_separator()`](https://caugi.org/dev/reference/minimal_d_separator.md),
  which computes a minimal d-separator between sets of nodes in a DAG,
  with support for mandatory inclusions and restrictions.
- Add [`posteriors()`](https://caugi.org/dev/reference/posteriors.md)
  query function, which is the dual of
  [`anteriors()`](https://caugi.org/dev/reference/anteriors.md). It
  returns all nodes reachable by following paths where every edge is
  either undirected or directed away from the source node. For DAGs,
  [`posteriors()`](https://caugi.org/dev/reference/posteriors.md) equals
  [`descendants()`](https://caugi.org/dev/reference/descendants.md). For
  PDAGs and AGs, it includes both descendants and nodes reachable via
  undirected edges.

### Improvements

- Rust remains the single source of truth for graph state. Graph
  properties (`simple`, `graph_class`, `nodes`, `edges`) are sourced
  from the `session`.
  - Session is always created, including empty graphs (n = 0), which
    simplifies property access.
  - Deprecated compatibility properties `@.state`, `@name_index_map`,
    `@built`, and `@ptr` now warn on access and return `NULL`.
  - Deprecated compatibility constructor arguments `build` and `state`
    in [`caugi()`](https://caugi.org/dev/reference/caugi.md) now warn
    and are ignored.
- Added `all.equal` and `compare_proxy` methods for caugi objects to
  support graph-content comparison in tests.
- Add `asp` parameter to
  [`plot()`](https://caugi.org/dev/reference/plot.md) for controlling
  aspect ratio. When `asp = 1`, the plot respects equal units on both
  axes, preserving the layout coordinates. Works like base R’s `asp`
  parameter (y/x aspect ratio)
  ([\#195](https://github.com/frederikfabriciusbjerre/caugi/issues/195)).
- Add `pdag_to_dag()` function that generates a random DAG consistent
  with a given CPDAG/PDAG structure if possible
  ([\#201](https://github.com/frederikfabriciusbjerre/caugi/issues/201)).

### Bug Fixes

- Fixed a bug causing
  [`plot()`](https://caugi.org/dev/reference/plot.md) to use incorrect
  layout if node names were not in the same order as in the graph object
  ([\#198](https://github.com/frederikfabriciusbjerre/caugi/issues/198)).

### Deprecations

- The parameter `all` in
  [`districts()`](https://caugi.org/dev/reference/districts.md) has been
  deprecated. Just use
  [`districts()`](https://caugi.org/dev/reference/districts.md) without
  arguments to get all districts.

## caugi 1.0.0

CRAN release: 2026-01-22

### New Features

- Add support for Ancestral Graphs (AGs), which combine directed
  (`-->`), bidirected (`<->`), and undirected (`---`) edges while
  satisfying ancestral graph constraints. New functions:
  [`is_ag()`](https://caugi.org/dev/reference/is_ag.md),
  [`is_mag()`](https://caugi.org/dev/reference/is_mag.md).
- Add `mode` argument to
  [`neighbors()`](https://caugi.org/dev/reference/neighbors.md)/[`neighbours()`](https://caugi.org/dev/reference/neighbors.md)
  to filter neighbors by edge direction or type (`"all"`, `"in"`,
  `"out"`, `"undirected"`, `"bidirected"`, `"partial"`). This is a
  structural query, and not a semantic query!
- [`neighbors()`](https://caugi.org/dev/reference/neighbors.md) now
  supports `class = "UNKNOWN"` graphs, including `mode`-based filtering.
- Add
  [`simulate_data()`](https://caugi.org/dev/reference/simulate_data.md)
  that enables simulation from DAGs using SEMs. Standard linear Gaussian
  SEMs are defaults, but more importantly custom SEMs are available.
- Add `"AUTO"` parameter for `class` in `caugi` objects. This
  automatically picks the graph class in order `DAG`, `UG`, `PDAG`,
  `ADMG`, `AG`.
- Add Ancestral Graphs (AG) with support for directed, bidirected, and
  undirected edges, plus new queries
  [`is_ag()`](https://caugi.org/dev/reference/is_ag.md) and
  [`is_mag()`](https://caugi.org/dev/reference/is_mag.md) and
  m-separation for AGs.
- Add [`exogenize()`](https://caugi.org/dev/reference/exogenize.md)
  function that exogenizes variables for any graph type. Current
  implementation is written in R, but it is so simple that it might be
  preferable over a Rust implementation. This might be changed later.
- Add
  [`latent_project()`](https://caugi.org/dev/reference/latent_project.md)
  function that does latent projection from DAGs to ADMGs.
- Add native caugi serialization format for saving and loading graphs.
  New functions:
  [`write_caugi()`](https://caugi.org/dev/reference/write_caugi.md),
  [`read_caugi()`](https://caugi.org/dev/reference/read_caugi.md),
  [`caugi_serialize()`](https://caugi.org/dev/reference/caugi_serialize.md),
  and
  [`caugi_deserialize()`](https://caugi.org/dev/reference/caugi_deserialize.md).
  The format is a versioned JSON schema that captures graph structure,
  class, and optional metadata (comments and tags).
- Add [`plot()`](https://caugi.org/dev/reference/plot.md) method for
  visualizing graphs using various layout algorithms. The plot is
  rendered using grid graphics and returns a `caugi_plot` object that
  can be customized with `node_style`, `edge_style`, and `label_style`
  arguments. The [`plot()`](https://caugi.org/dev/reference/plot.md)
  method accepts layouts as strings, functions, or pre-computed
  data.frames.
- Add
  [`caugi_layout()`](https://caugi.org/dev/reference/caugi_layout.md)
  function to compute node coordinates for graph visualization.
- Add dedicated layout functions:
  [`caugi_layout_sugiyama()`](https://caugi.org/dev/reference/caugi_layout_sugiyama.md),
  [`caugi_layout_fruchterman_reingold()`](https://caugi.org/dev/reference/caugi_layout_fruchterman_reingold.md),
  [`caugi_layout_kamada_kawai()`](https://caugi.org/dev/reference/caugi_layout_kamada_kawai.md),
  [`caugi_layout_bipartite()`](https://caugi.org/dev/reference/caugi_layout_bipartite.md),
  and
  [`caugi_layout_tiered()`](https://caugi.org/dev/reference/caugi_layout_tiered.md).
  Each function provides an API for its specific algorithm.
- Add [`to_dot()`](https://caugi.org/dev/reference/to_dot.md) and
  [`write_dot()`](https://caugi.org/dev/reference/write_dot.md)
  functions for exporting caugi graphs to DOT (graphviz) format. The
  resulting object is a new S7 class, `caugi_export`, which has a
  `knit_print()` method for rendering DOT graphs in R Markdown and
  Quarto documents.
- Add GraphML and Mermaid import/export support: `to_graphml`,
  `write_graphml`, `read_graphml`, `to_mermaid`, `write_mermaid`, and
  `read_mermaid`
- Add plot composition operators for creating multi-plot layouts: `+`
  and `|` for horizontal arrangement, `/` for vertical stacking.
  Compositions can be nested arbitrarily (e.g., `(p1 + p2) / p3`).
- Add
  [`caugi_options()`](https://caugi.org/dev/reference/caugi_options.md)
  function for setting global defaults for plot appearance, including
  composition spacing and default styles for nodes, edges, labels, and
  titles.
- Add
  [`caugi_default_options()`](https://caugi.org/dev/reference/caugi_default_options.md)
  function to query or reset to package default options.
- Add a new vignette, “Graph Visualization with caugi”, demonstrating
  the new plotting capabilities and customization options.

### Improvements

- Add favicons for the package website.
- Standardize
  [`is_caugi()`](https://caugi.org/dev/reference/is_caugi.md) validation
  calls internally.
- Adopt [air](https://github.com/posit-dev/air) as the R code formatter
  for the package.
- [`caugi_layout_tiered()`](https://caugi.org/dev/reference/caugi_layout_tiered.md)
  now returns a `tier` column and `orientation` attribute in the layout
  data.frame, allowing
  [`plot()`](https://caugi.org/dev/reference/plot.md) to automatically
  use tier information without requiring the `tiers` argument to be
  passed again.

### Bug Fixes

- Fix typo in error messages and documentation examples.
- Remove unused `index_name_map` parameter from internal `.cg_state()`
  function.
- Fix interpretation of directed edge endpoint positions in the Rust
  backend, improving correctness of direction-dependent
  algorithms/metrics (e.g. topological sorting and structural Hamming
  distance computations).
- Fix bug in `is_cpdag` function that returns `TRUE` on non-complete
  PDAGs.
- Fix bug in `shd` returning positive values for equivalent graphs given
  in shuffled order.

## caugi 0.4.0

- Add support for Acyclic Directed Mixed Graphs (ADMGs), which combine
  directed edges representing causal relationships with bidirected edges
  representing latent confounding.
- Add new functions for querying ADMGs:
  [`is_admg()`](https://caugi.org/dev/reference/is_admg.md),
  [`spouses()`](https://caugi.org/dev/reference/spouses.md),
  [`districts()`](https://caugi.org/dev/reference/districts.md), and
  [`m_separated()`](https://caugi.org/dev/reference/m_separated.md)
  (generalization of d-separation for graphs with bidirected edges).
- Add functions for adjustment set validation in ADMGs:
  [`is_valid_adjustment_admg()`](https://caugi.org/dev/reference/is_valid_adjustment_admg.md)
  and
  [`all_adjustment_sets_admg()`](https://caugi.org/dev/reference/all_adjustment_sets_admg.md)
  implementing the Generalized Adjustment Criterion.
- Add
  [`mutate_caugi()`](https://caugi.org/dev/reference/mutate_caugi.md)
  function that allows conversion from one graph type to another.
- Add custom printing method for `caugi` objects.
- Add optional `edges_df` argument to
  [`caugi()`](https://caugi.org/dev/reference/caugi.md) for easier
  construction from existing data frames containing the columns `from`,
  `edge`, and `to`.
- Improve error handling across all graph types (DAG, PDAG, UG, ADMG)
  with more descriptive error messages.
- Update
  [`as_adjacency()`](https://caugi.org/dev/reference/as_adjacency.md)
  and [`as_igraph()`](https://caugi.org/dev/reference/as_igraph.md) to
  support bidirected edges.
- Update [`as_caugi()`](https://caugi.org/dev/reference/as_caugi.md)
  documentation to include “ADMG” as a valid class type for conversion.

## caugi 0.3.2

- Change website to `caugi.org/`.
- Minor modifications to `CONTRIBUTING.md`.
- Minor `README` rewrite.

## caugi 0.3.1

CRAN release: 2025-12-04

- Remove the use of `lockBinding` and `unlockBinding` in the package to
  silence R CMD check notes.

## caugi 0.3.0

- Add `mutate_caugi` function that allows conversion from one graph type
  to another.
- Add custom printing method.
- Add optional `edges_df` argument to `caugi` for easier construction
  from existing data frames containing the columns `from`, `edge`, and
  `to`.
- Update *How to use `caugi` in a package* vignette to use new
  conversion functionality.
- Add `CONTRIBUTING.md` to github.

## caugi 0.2.1

- Update function documentation to make package CRAN ready.
- Update performance vignette and change it to article.
- Add Michael Sachs and Johan Larsson to Authors in DESCRIPTION.
- Patch S4 class reading for `as_caugi`.

## caugi 0.2.0

- Drop dependencies on `dplyr` and `tibble`.
- Improve performance by letting all data wrangling be done by
  `data.table`.
- Edges and nodes are now `data.tables`.

## caugi 0.1.0

- Add Undirected Graphs (UG) to `caugi`.
- Refactor Rust backend for DAGs.
- Add NEWS.md!
