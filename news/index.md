# Changelog

## caugi 0.5.0

### New Features

- Add [`simulate_data()`](https://caugi.org/reference/simulate_data.md)
  that enables simulation from DAGs using SEMs. Standard linear Gaussian
  SEMs are defaults, but more importantly custom SEMs are available.
- Add `"AUTO"` parameter for `class` in `caugi` objects. This
  automatically picks the graph class in order `DAG`, `UG`, `PDAG`,
  `ADMG`.
- Add [`exogenize()`](https://caugi.org/reference/exogenize.md) function
  that exogenizes variables for any graph type. Current implementation
  is written in R, but it is so simple that it might be preferable over
  a Rust implementation. This might be changed later.
- Add
  [`latent_project()`](https://caugi.org/reference/latent_project.md)
  function that does latent projection from DAGs to ADMGs.
- Add native caugi serialization format for saving and loading graphs.
  New functions:
  [`write_caugi()`](https://caugi.org/reference/write_caugi.md),
  [`read_caugi()`](https://caugi.org/reference/read_caugi.md),
  [`caugi_serialize()`](https://caugi.org/reference/caugi_serialize.md),
  and
  [`caugi_deserialize()`](https://caugi.org/reference/caugi_deserialize.md).
  The format is a versioned JSON schema that captures graph structure,
  class, and optional metadata (comments and tags).
- Add [`plot()`](https://caugi.org/reference/plot.md) method for
  visualizing graphs using the Sugiyama algorithm for DAGs and a
  force-directed algorithm for other graphs. The plot is rendered using
  grid graphics and returns a `caugi_plot` object that can be customized
  with `node_style`, `edge_style`, and `label_style` arguments. The
  [`plot()`](https://caugi.org/reference/plot.md) method accepts layouts
  as strings, functions, or pre-computed data.frames.
- Add [`caugi_layout()`](https://caugi.org/reference/caugi_layout.md)
  function to compute node coordinates for graph visualization using the
  Sugiyama layout algorithm.
- Add dedicated layout functions:
  [`caugi_layout_sugiyama()`](https://caugi.org/reference/caugi_layout_sugiyama.md),
  [`caugi_layout_fruchterman_reingold()`](https://caugi.org/reference/caugi_layout_fruchterman_reingold.md),
  [`caugi_layout_kamada_kawai()`](https://caugi.org/reference/caugi_layout_kamada_kawai.md),
  and
  [`caugi_layout_bipartite()`](https://caugi.org/reference/caugi_layout_bipartite.md).
  Each function provides a focused API for its specific algorithm.
- Add bipartite graph layout support with
  [`caugi_layout_bipartite()`](https://caugi.org/reference/caugi_layout_bipartite.md),
  which places nodes in two parallel lines (rows or columns) based on a
  user-provided partition.
- Add [`to_dot()`](https://caugi.org/reference/to_dot.md) and
  [`write_dot()`](https://caugi.org/reference/write_dot.md) functions
  for exporting caugi graphs to DOT (graphviz) format. The resulting
  object is a new S7 class, `caugi_export`, which has a `knit_print()`
  method for rendering DOT graphs in R Markdown and Quarto documents.
- Add GraphML and Mermaid import/export support: `to_graphml`,
  `write_graphml`, `read_graphml`, `to_mermaid`, `write_mermaid`, and
  `read_mermaid`
- Add plot composition operators for creating multi-plot layouts: `+`
  and `|` for horizontal arrangement, `/` for vertical stacking.
  Compositions can be nested arbitrarily (e.g., `(p1 + p2) / p3`).
- Add [`caugi_options()`](https://caugi.org/reference/caugi_options.md)
  function for setting global defaults for plot appearance, including
  composition spacing and default styles for nodes, edges, labels, and
  titles.
- Add
  [`caugi_default_options()`](https://caugi.org/reference/caugi_default_options.md)
  function to query or reset to package default options.
- Add a new vignette, “Graph Visualization with caugi”, demonstrating
  the new plotting capabilities and customization options.

### Improvements

- Add favicons for the package website.
- Standardize [`is_caugi()`](https://caugi.org/reference/is_caugi.md)
  validation calls internally.
- Adopt [air](https://github.com/posit-dev/air) as the R code formatter
  for the package.

### Bug Fixes

- Fix typo in error messages and documentation examples.
- Remove unused `index_name_map` parameter from internal
  [`.cg_state()`](https://caugi.org/reference/dot-cg_state.md) function.

## caugi 0.4.0

- Add support for Acyclic Directed Mixed Graphs (ADMGs), which combine
  directed edges representing causal relationships with bidirected edges
  representing latent confounding.
- Add new functions for querying ADMGs:
  [`is_admg()`](https://caugi.org/reference/is_admg.md),
  [`spouses()`](https://caugi.org/reference/spouses.md),
  [`districts()`](https://caugi.org/reference/districts.md), and
  [`m_separated()`](https://caugi.org/reference/m_separated.md)
  (generalization of d-separation for graphs with bidirected edges).
- Add functions for adjustment set validation in ADMGs:
  [`is_valid_adjustment_admg()`](https://caugi.org/reference/is_valid_adjustment_admg.md)
  and
  [`all_adjustment_sets_admg()`](https://caugi.org/reference/all_adjustment_sets_admg.md)
  implementing the Generalized Adjustment Criterion.
- Add [`mutate_caugi()`](https://caugi.org/reference/mutate_caugi.md)
  function that allows conversion from one graph type to another.
- Add custom printing method for `caugi` objects.
- Add optional `edges_df` argument to
  [`caugi()`](https://caugi.org/reference/caugi.md) for easier
  construction from existing data frames containing the columns `from`,
  `edge`, and `to`.
- Improve error handling across all graph types (DAG, PDAG, UG, ADMG)
  with more descriptive error messages.
- Update [`as_adjacency()`](https://caugi.org/reference/as_adjacency.md)
  and [`as_igraph()`](https://caugi.org/reference/as_igraph.md) to
  support bidirected edges.
- Update [`as_caugi()`](https://caugi.org/reference/as_caugi.md)
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
