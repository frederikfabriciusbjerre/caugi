
<!-- README.md is generated from README.Rmd. Please edit that file -->

# caugi <a href="https://caugi.org"><img src='man/figures/logo.svg' align="right" height="138" /></a>

<!-- badges: start -->

[![R-CMD-check](https://github.com/frederikfabriciusbjerre/caugi/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/frederikfabriciusbjerre/caugi/actions/workflows/R-CMD-check.yaml)
[![Code
coverage](https://codecov.io/gh/frederikfabriciusbjerre/caugi/graph/badge.svg)](https://app.codecov.io/gh/frederikfabriciusbjerre/caugi)
[![CRAN
downloads](https://cranlogs.r-pkg.org/badges/caugi)](https://cran.r-project.org/package=caugi)
[![extendr](https://img.shields.io/badge/extendr-%5E0.9.0-276DC2)](https://extendr.rs/extendr/extendr_api/)
[![CRAN
status](https://www.r-pkg.org/badges/version/caugi)](https://CRAN.R-project.org/package=caugi)
<!-- badges: end -->

> **Causal Graph Interface (for R)** — a fast and flexible toolbox for
> building, coercing and analyzing causal graphs.

## What is `caugi`?

`caugi` (pronounced “corgi”) stands for **Causal Graph Interface**. It
is a *causality-first* graph package that focuses on performance and
flexibility. If you are developing scripts or algorithms in the field of
causality or if you are learning about causal graphs for the first time,
`caugi` is made for you.

## Installation

Install the released version from CRAN:

``` r
install.packages("caugi")
```

or the development version from
[r-universe](https://frederikfabriciusbjerre.r-universe.dev/caugi):

``` r
install.packages(
  "caugi",
  repos = c("https://frederikfabriciusbjerre.r-universe.dev", "https://cloud.r-project.org")
)
```

On Windows and macOS, both come as ready-built binaries, so you do not
need Rust.

### Building from source

Building `caugi` from source, for example on Linux or with
`pak::pak("frederikfabriciusbjerre/caugi")`, requires Rust (rustc \>=
1.80). Visit [rustup.rs](https://rustup.rs/) for installation
instructions, or install Rust from your OS package manager.

## The basic object: `caugi`

A `caugi` graph object is the bread and butter of the `caugi` package.
It is easy to create, query, and modify.

``` r
library(caugi)
```

You can create simple graphs as well as a number of predefined graph
classes. Currently, we support the classes `"DAG"`, `"PDAG"`, `"MPDAG"`,
`"CPDAG"`, `"ADMG"`, `"AG"`, `"PAG"`, `"UG"` as well as an `"UNKNOWN"`
class. We plan on supporting `"MAG"` and `"SWIG"` as classes of their
own in future releases.

``` r
# a tiny DAG
cg <- caugi(
  A %-->% B + C,
  B %-->% D,
  C %-->% D,
  class = "DAG"
)

plot(cg)
```

![](man/figures/README-unnamed-chunk-5-1.png)<!-- -->

### Edge operators

The available edges in `caugi` are listed below:

- `%-->%` (directed)
- `%---%` (undirected)
- `%<->%` (bidirected)
- `%o->%` (partially directed)
- `%--o%` (partially undirected)
- `%o-o%` (partial)
- `%<--%`, `%<-o%` and `%o--%`, the same edges written the other way
  round: `B %<--% A` is stored as `A %-->% B`

You can register more types with `register_caugi_edge()`. caugi reasons
with an edge’s marks and class but keeps its glyph, so a custom glyph
can carry a meaning of your own. For example,
[causalDisco](https://github.com/disco-coders/causalDisco) writes a
forbidden edge in background knowledge as `!-->`. Registering that glyph
keeps forbidden edges apart from ordinary directed ones in a caugi
graph:

``` r
register_caugi_edge(
  glyph = "!-->",
  tail_mark = "tail",
  head_mark = "arrow",
  class = "directed",
  symmetric = FALSE
)

caugi(A %-->% B, B %!-->% C, class = "UNKNOWN")
#> <caugi object; 3 nodes, 2 edges; simple: FALSE; session=0x98c4281f0>
#>   graph_class: UNKNOWN
#>   nodes: A, B, C
#>   edges: A-->B, B!-->C

# reset the registry to default with original edges
reset_caugi_registry()
```

In queries, `B %!-->% C` counts as a directed edge; only its glyph tells
it apart.

We expect this feature to be needing further polishing in future
releases, and we would love your input if you use this feature!

## Queries, adjustment and conversion

Query the DAG from above, find an adjustment set for the effect of `B`
on `D`, and test d-separation:

``` r
parents(cg, "D")
#> [1] "B" "C"
adjustment_set(cg, X = "B", Y = "D")
#> [1] "C"
d_separated(cg, X = "B", Y = "C", Z = "A")
#> [1] TRUE
```

`as_caugi()` reads graphs from `igraph`, `dagitty`, `bnlearn`, `graph`,
`tidygraph`, adjacency matrices (including `pcalg`’s mark coding) and
edge lists, and `as_igraph()`, `as_dagitty()`, `as_bnlearn()` and
`as_adjacency()` convert back. See the
[reference](https://caugi.org/reference/) for all queries, adjustment,
metrics and conversions.

## How it works

`caugi` graphs are represented in a compact Compressed Sparse Row (CSR)
format in Rust. `caugi` works with a front-loading philosophy. Since the
`caugi` graph is stored in a CSR format, mutations of the graph is
computationally expensive compared to other graph storage systems, *but*
it allows for very fast querying. Additionally to the storage format of
the graph itself, `caugi` also stores additional information about node
relations in such a way that it allows for faster queries without
blowing up the object too much.

To accommodate for the cost of mutations, `caugi` graphs are built
lazily, but you can force a build by using the function `build()`.

## Why?

It’s fast, *dawg* 🐶 See the [article on
performance](https://caugi.org/articles/performance.html) on our website
for benchmarks.

## Contribution

Would you like to contribute? Great! Please see [Contributing to
caugi](https://caugi.org/CONTRIBUTING.html) for detailed guidelines on
code style, testing, and the development workflow. Quick tips: follow
the tidyverse style guide for R code, run `styler::style_pkg()` for R
and `cargo fmt` for Rust before PRs, and write tests for new features.

Did you find run into problems? That’s *paw-ful*! Please report an
[issue](https://github.com/frederikfabriciusbjerre/caugi/issues)!
