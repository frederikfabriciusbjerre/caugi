# Changelog

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
