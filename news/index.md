# Changelog

## caugi 0.5.0

### New Features

- Add [`plot()`](https://caugi.org/reference/plot.md) method for
  visualizing DAGs using the Sugiyama hierarchical layout algorithm. The
  plot is rendered using grid graphics and returns a `caugi_plot` object
  that can be customized with `node_style`, `edge_style`, and
  `label_style` arguments.
- Add [`caugi_layout()`](https://caugi.org/reference/caugi_layout.md)
  function to compute node coordinates for graph visualization using the
  Sugiyama layout algorithm.

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
