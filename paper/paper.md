---
title: "caugi: fast and flexible causal graphs in R"
tags:
  - R
  - causal inference
  - causal discovery
  - graphs
  - networks
  - statistics
authors:
  - name: Frederik Fabricius Bjerre
    corresponding: true
    affiliation: "1, 2"
  - name: Bjarke Hautop Kristensen
    equal-contrib: true
    affiliation: 1
  - name: Johan Larsson
    orcid: 0000-0002-4029-5945
    equal-contrib: true
    affiliation: 2
  - name: Michael C Sachs
    orcid: 0000-0002-1279-8676
    equal-contrib: true
    affiliation: 1
affiliations:
  - name: Section of Biostatistics, University of Copenhagen, Denmark
    index: 1
    ror: 035b05819
  - name: Department of Mathematical Sciences, University of Copenhagen, Denmark
    index: 2
    ror: 035b05819
date: 11 May 2026
bibliography: paper.bib
---

# Summary

<!-- A description of the high-level functionality and purpose of the software
for a diverse, non-specialist audience. -->

`caugi` is a fast and flexible toolbox for causal graphs in `R`. It provides an
intuitive interface for defining, manipulating, and analyzing the graphs that
arise in causal inference and discovery, including directed acyclic graphs
(DAGs), partially directed acyclic graphs (PDAGs), acyclic directed mixed graphs
(ADMGs), and undirected graphs (UGs), each represented as a dedicated class. The
graph data structure is implemented in `Rust`, using a compressed sparse
row\ (CSR) representation, giving query and traversal operations the performance
needed for high-dimensional and iterative workflows. Alongside the core
representation, `caugi` implements a wide range of causal-graph algorithms, such
as separation tests, adjustment-set identification, and structural distance
metrics, together with a full-featured system for visualizing graphs.

# Statement of Need

<!-- A section that clearly illustrates the research purpose of the software
and places it in the context of related work. This should clearly state what
problems the software is designed to solve, who the target audience is, and its
relation to other work.-->

Graphs are fundamental in causality. It is the object by which researchers
conceptualize and communicate their models as well as the practical tool that
they use to perform inference and discovery. This makes it crucial that there
are software tools that allow researchers to transfer their ideas into code and
to perform their analyses through an intuitive as well as efficient interface.
The latter is important because causal inference and discovery can be
computationally intensive, particularly in high-dimensional settings and machine
learning-based approaches where graphs are iteratively updated and evaluated.
`caugi` is designed to meet these needs by providing a fast and flexible toolbox
for causal graphs in `R`.

The problem with many existing tools is that they

1) are not designed with causal graphs in mind and therefore lack the necessary
   functionality and efficiency for causal inference and discovery,

2) are not built with performance in mind and therefore struggle with larger
   graphs, or

3) lack an intuitive interface, for instance requiring users to define graphs
   through adjacency matrices or edge lists, which can be cumbersome and
   error-prone.

`caugi` addresses these issues with an efficient graph representation, a broad
set of algorithms for causal inference and discovery, and an interface built
around infix edge operators.

# State of the Field

<!-- A description of how this software compares to other commonly-used
packages in the research area. If related tools exist, provide a clear “build
vs. contribute” justification explaining your unique scholarly contribution and
why existing alternatives are insufficient. -->

Graph packages in high-level langauges such as `R` and `Python` span a wide
range of scopes, from general-purpose graph libraries to specialised
causal-inference toolkits. \autoref{tab:packages-comparison} illustrates where
`caugi` sits in this landscape; a full feature-by-feature comparison, covering
supported graph classes, graph queries, causal-inference algorithms, and I/O and
performance benchmarks against the most widely used alternatives are reported in
the package's online documentation at [caugi.org](https://caugi.org).

  ----------------------------------------------------------------------------------------------------------------------------------------------
  Package               Language         Scope                            Notes
  --------------------- ---------------- -------------------------------- ----------------------------------------------------------------------
  `caugi`               `R` + `Rust`     Causal graphs                    Rust-backed CSR storage; typed DAG/PDAG/ADMG/UG classes;
                                                                          infix DSL

  `igraph`              `R`/`Py` + `C`   General-purpose                  C-backed graph engine; no causal-typed graph classes

  `bnlearn`             `R` + `C`        Bayesian networks                Single `bn` class for all graph types; full
                                                                          inference/learning stack

  `pcalg`               `R` + `C++`      Causal discovery                 Algorithm-first; causal graphs surfaced as untyped
                                                                          result objects

  `dagitty`             `R` + `JS`       Causal graphs                    DAG/PDAG/MAG/PAG via JS engine; lacks UG and ADMG classes

  `MixedGraphs`         `R` + `C++`      Mixed/ancestral graphs           Untyped `mixedgraph` container built via a string DSL
                                                                          (`graphCr`)

  `NetworkX`            `Python`         General-purpose                  Dict-of-dicts adjacency; no mixed-edge or causal-typed
                                                                          classes

  `pgmpy`               `Python`         Probabilistic graphical models   Typed DAG/PDAG/ADMG/MAG inheriting from `NetworkX` classes

  `Tetrad`              `Java`           Causal modeling & discovery      Universal `EdgeListGraph` container; broad algorithm suite
  ----------------------------------------------------------------------------------------------------------------------------------------------

  : Description of the scope and features of `caugi` compared to other graph
    packages in `R`, `Python`, and `Java`. The table is not exhaustive but
    serves to illustrate the landscape of graph packages and where `caugi` fits
    within it.\label{tab:packages-comparison}

Canonical citations, source-code locations, and project websites for the
packages above are listed in \autoref{tab:packages-citations}. An empty space
indicates that no separate URL of that kind exists for the package.

  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Package                          Citation                        Source Code                                                            Project Site
  -------------------------------- ------------------------------- ---------------------------------------------------------------------- ------------------------------------------------------------------------------------------
  `igraph`                         @csardi2006; @antonov2023       [github.com/igraph/rigraph](https://github.com/igraph/rigraph)         [r.igraph.org](https://r.igraph.org)

  `bnlearn`                        @scutari2010                                                                                           [bnlearn.com](https://www.bnlearn.com)

  `pcalg`                          @kalisch2012                    [pcalg.r-forge.r-project.org](https://pcalg.r-forge.r-project.org)     [CRAN.R-project.org/package=pcalg](https://CRAN.R-project.org/package=pcalg)

  `dagitty`                        @textor2016                     [github.com/jtextor/dagitty](https://github.com/jtextor/dagitty)       [dagitty.net](https://www.dagitty.net)

  `MixedGraphs`                    @evans2025                      [github.com/rje42/MixedGraphs](https://github.com/rje42/MixedGraphs)

  `NetworkX`                       @hagberg2008                    [github.com/networkx/networkx](https://github.com/networkx/networkx)   [networkx.org](https://networkx.org)

  `pgmpy`                          @ankan2024                      [github.com/pgmpy/pgmpy](https://github.com/pgmpy/pgmpy)               [pgmpy.org](https://pgmpy.org)

  `Tetrad`                         @scheines1998                   [github.com/cmu-phil/tetrad](https://github.com/cmu-phil/tetrad)       [cmu.edu/dietrich/philosophy/tetrad](https://www.cmu.edu/dietrich/philosophy/tetrad/)
  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

  : Canonical citations, source-code locations, and project websites for the
    graph packages mentioned in the previous
    table.\label{tab:packages-citations}

Three features distinguish `caugi` from the packages above:

1) dedicated causal-graph classes (DAG, PDAG, ADMG, UG) with type-level
   invariants,

2) a `Rust` backend that combines speed with memory safety, and

3) an interface based on infix edge operators rather than adjacency matrices,
   arc lists, or string DSLs.

None of the packages we surveyed combines all three.

# Software Design

<!-- An explanation of the trade-offs you weighed, the design/architecture
you chose, and why it matters for your research application. This should
demonstrate meaningful design thinking beyond a superficial code structure
description. -->

`caugi` is an `R` package with a core written in `Rust`, exposed to `R` via the
`extendr` framework\ [@reimert2024]. This combines a familiar `R` interface for
working with causal graphs with the performance and memory safety of `Rust`.

The graph implementation is based on a compressed sparse row\ (CSR) format.
Causal-graph packages in `R` more commonly use adjacency matrices (as in
`pcalg`, `ggm`, and `dagitty`) or arc lists (as in `bnlearn`). Both alternatives
have their strengths, but the CSR format scales memory proportionally to the
number of edges and is particularly well-suited for the operations that dominate
causal inference and discovery, such as iterating over the neighbors of a node
or traversing the graph.

The CSR layout makes queries fast but mutations expensive: any structural change
in principle requires rebuilding the index. To avoid penalizing iterative
workflows, `caugi` adopts a *lazy build* strategy. Mutations are batched on the
`R` side as a pending edit and the underlying graph is rebuilt only when needed:
either when the user explicitly calls `build()`, or when a query is issued
against the graph. Each rebuild is $\mathcal{O}(|V| + |E|)$, so the cost of
mutation is spread across a batch of edits. Graphs *appear* mutable from the
user's perspective, while remaining immutable internally and always consistent
when queried.

# Examples

You create a `caugi` graph object through the `caugi()` function, which uses
infix operators to define edges. For instance, the following code creates a
simple directed acyclic graph\ (DAG) with four nodes and four edges, encoding a
confounding structure in which `A` is a common cause of treatment `B` and
outcome `C`, with `D` as a descendant of the treatment:

```r
library(caugi)

cg <- caugi(
  A %-->% B %-->% C + D,
  A %-->% C,
  class = "DAG"
)

cg
#> <caugi object; 4 nodes, 4 edges; simple: TRUE; session=0x62d5bd0f4500>
#>   graph_class: DAG
#>   nodes: A, B, C, D
#>   edges: A-->B, A-->C, B-->C, B-->D
```

In the example above, `A %-->% B` creates the edge `-->` from `A` to `B`. The
syntax `B %-->% C + D` is equivalent to `B %-->% C` *and* `B %-->% D`, and
`A %-->% B %-->% C` chains two edges. To visualize the graph, you can simply
call `plot()` on the graph object, with the result shown in
\autoref{fig:example-plot}.

```r
plot(cg)
```

![A simple DAG built with `caugi`. \label{fig:example-plot}](figures/example-plot.pdf)

`caugi` supports a wide range of queries and algorithms that operate directly on
the graph object. For instance, to identify a valid back-door adjustment set for
estimating the causal effect of `B` on `C`, we can use `adjustment_set()`:

```r
adjustment_set(cg, "B", "C", type = "backdoor")
#> [1] "A"
```

The set `{A}` blocks the back-door path `B <-- A --> C`, yielding a valid
adjustment set for the causal effect of `B` on `C`.

# Research Impact Statement

<!-- Evidence of realized impact (publications, external use, integrations) or
credible near-term significance (benchmarks, reproducible materials,
community-readiness signals). The evidence should be compelling and specific,
not aspirational. -->

`caugi` provides the underlying graph representation for two downstream `R`
packages: `causalDisco`\ [@kristensen2026], a CRAN-released toolbox for causal
discovery on observational data, and `meraconstraints`\ [@sachs2026b], which
derives complete equality constraints in hidden-variable causal models and
underpins recent methodological work by @sachs2026.^[We note that some authors
of this paper are also involved in the development of the packages and paper
mentioned above.] The package also ships with a versioned public API, a test
suite under continuous integration, a JSON serialization schema for
interoperability with external tools, and a performance vignette benchmarking
`caugi` against widely used alternatives in `R`, `Python`, and `Java`. All of
these materials are available at [caugi.org](https://caugi.org).

# AI Usage Disclosure

<!-- Transparent disclosure of any use of generative AI in the software
creation, documentation, or paper authoring. If no AI tools were used, state
this explicitly. If AI tools were used, describe how they were used and how the
quality and correctness of AI-generated content was verified. -->

The codebase was originally written without the use of AI tools. Since then,
however, we have used AI tools for a variety of purposes, including

- reviewing pull requests,
- writing algorithms from pseudocode specifications and manual guidance,
- writing unit tests,
- triaging and fixing bugs, and
- refactoring code.

# Acknowledgements

The majority of algorithms in `caugi` have been implemented from scratch, but we
also rely on some external libraries, including `gadjid`\ [@henckel2024] for the
adjustment identification distance metric.

# References
