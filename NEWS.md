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
