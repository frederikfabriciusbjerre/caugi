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
    orcid: 0009-0007-3733-1769
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

`caugi` (Causal Graph Interface) is a fast and flexible toolbox for causal graphs in `R`. 
It provides an intuitive interface for defining, manipulating, and analyzing the 
graphs that arise in causal inference and discovery. `caugi` is a causality-first package,
meaning that it is not built around generic graphs, but rather around different
classes of causal graphs, including directed acyclic graphs (DAGs), partially 
directed acyclic graphs (PDAGs), acyclic directed mixed graphs (ADMGs), and 
ancestral graphs (AGs).

The graph data structure is implemented in `Rust`, yielding query and traversal
operations competitive in performance with other graph packages in `R` [@caugiperformance], while still giving 
the user an experience that resembles sketching a graph by hand. Alongside the core
representation, `caugi` implements a wide range of causal-graph algorithms, such
as separation tests, structural queries, adjustment-set identification, and graph metrics, 
together with a full-featured system for visualizing graphs.

# Statement of Need

<!-- A section that clearly illustrates the research purpose of the software
and places it in the context of related work. This should clearly state what
problems the software is designed to solve, who the target audience is, and its
relation to other work.-->

Graphs are a convenient, economical, and expressive way of conveying causal
assumptions and performing the inferences and other derivations that are
central to the field. For many researchers, graphs are both the object through
which causal models are conceptualized and communicated, and the practical
tool used to perform inference and discovery. This makes it essential to have
software that allows researchers to translate their ideas into code and to
carry out their analyses through an interface that is both intuitive and
efficient. Efficiency matters because causal inference and discovery can be
computationally intensive, particularly in high-dimensional settings.

Existing tools, however, often fall short in that they

1) are not designed with causal graphs in mind and therefore lack the necessary
   functionality for causal inference and discovery, such as support for the
   range of edge types (directed, bidirected, undirected) and graph classes that
   the field relies on,

2) are not designed with performance in mind and therefore struggle with larger
   graphs, or

3) lack an intuitive interface, for instance requiring users to define graphs
   through adjacency matrices or edge lists, which can be cumbersome and
   error-prone.

`caugi` addresses these issues with an intuitive graph representation, a broad
set of algorithms for causal inference and discovery, and an interface that
allows users to draw graphs with nodes as `R` symbols and edges as infix
operators.

# State of the Field

<!-- A description of how this software compares to other commonly-used
packages in the research area. If related tools exist, provide a clear “build
vs. contribute” justification explaining your unique scholarly contribution and
why existing alternatives are insufficient. -->

Graph packages in high-level languages such as `R` and `Python` span a wide
range of scopes, from general-purpose graph libraries to specialized
causal inference toolkits. 

Although packages such as `igraph` [@csardi2006; @antonov2023] and `NetworkX`
[@hagberg2008] are fast, their general-purpose design makes them harder to use
for causality-specific problems. Building the right abstractions on top of
them is possible, as demonstrated by `ggm` [@marchetti2025] and `pgmpy`
[@ankan2024], but the resulting abstractions can still require workarounds,
such as representing an undirected edge as a pair of directed edges pointing
in opposite directions.

Another group of packages, including `pcalg` [@kalisch2012] and `bnlearn`
[@scutari2010], feature their own graph representations, but their primary
purpose lies not in the graph structures themselves, but in the discovery
algorithms used to learn causal graphs. `pcalg` represents its graphs with
matrices, but the representation differs between graph classes. `bnlearn`
pairs a fast `C` backend with a rich suite of learning and inference
algorithms, but constructs its graphs as dense, node-by-node adjacency
structures whose memory footprint scales quadratically with the number of
nodes, limiting its use on larger graphs.

`Tetrad` [@scheines1998], written in Java, is a standalone software suite for
causal discovery that is performant and expressive, but currently lacks a
proper interface to `R`.

Closer to `caugi` in spirit are packages with a causality-native interface.
`dagitty` [@textor2016] offers an expressive syntax and a large user base, but
performs its computations through a JavaScript engine called from `R`, which
imposes a serialization boundary between the two languages and limits
performance on larger graphs [@caugiperformance]. Also worth noting is
`MixedGraphs` [@evans2025], which, while not available on CRAN, offers a
treatment of mixed graphs that was a source of inspiration for `caugi`.

Taken together, we believe that `caugi` fills a gap in the ecosystem, combining performance
comparable with `igraph` and `NetworkX` [@caugiperformance] with the
causality-native interface of
`dagitty` and `MixedGraphs`, such that it is easy to build causal discovery or
inference algorithms as seen in `pcalg` and `bnlearn`.

# Software Design

<!-- An explanation of the trade-offs you weighed, the design/architecture
you chose, and why it matters for your research application. This should
demonstrate meaningful design thinking beyond a superficial code structure
description. -->

`caugi` is an `R` package with a core written in `Rust`, exposed to `R` via the
`extendr` framework\ [@reimert2024]. This combines a familiar `R` interface for
working with causal graphs with the performance and memory safety of `Rust`.

The graph implementation is based on a compressed sparse row\ (CSR) format.
The CSR format scales memory proportionally to the number of edges, making it
particularly well suited to the sparse graphs common in causal inference. This
representation makes queries fast but mutations expensive, since any
structural change in principle requires rebuilding the CSR index.

To avoid penalizing iterative workflows, `caugi` adopts a *lazy build* strategy.
Mutations are batched and the graph is only rebuilt when the user queries the graph.
Graphs *appear* mutable from the user's perspective, while remaining immutable internally 
and always consistent when queried.

# Examples

We first define a DAG to represent our assumptions about cause-and-effect
relations among the nodes, where the parents of each node are assumed to be
sufficient for determining its distribution:

```r
library(caugi)

dag <- caugi(
  U %-->% X + Y,
  W %-->% X,
  X %-->% M %-->% Y,
  class = "DAG"
)
```

If the node `U` represents an unobserved (latent) confounder, the latent
projection operation yields an ADMG on `W`, `M`, `X`, and `Y` from which we can
read off dependencies among the observed variables; the bidirected edge between
`X` and `Y` records confounding left behind by the latent:

```r
obs <- latent_project(dag, latents = "U")
obs
#> <caugi object; 4 nodes, 4 edges; simple: TRUE; session=0x9271562a0>
#>   graph_class: ADMG
#>   nodes: W, X, M, Y
#>   edges: W-->X, X-->M, M-->Y, X<->Y
```

`X` and `Y` are not $m$-separated, since confounding persists in the ADMG,
meaning they are dependent in the distribution after marginalizing over `U`:

```r
m_separated(obs, "X", "Y")
#> [1] FALSE
```

but we can find the minimal $d$-separator in the original DAG, i.e., the set of
variables conditional on which `X` and `Y` are independent:

```r
minimal_separator(dag, "X", "Y")
#> [1] "U" "M"
```

We can easily visualize the graphs side-by-side using the native plotting functions:

```r
plot(dag, main = "DAG") + plot(obs, main = "ADMG")
```

![Structural DAG and observed ADMG after projecting out `U`.
\label{fig:example-plot}](figures/example-plot.pdf)

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

# References
