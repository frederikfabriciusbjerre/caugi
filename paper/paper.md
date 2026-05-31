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

`caugi` (Causal Graph Interface) is a fast and flexible toolbox for causal graphs in `R`. 
It provides an intuitive interface for defining, manipulating, and analyzing the 
graphs that arise in causal inference and discovery. `caugi` is a causality-first package,
meaning that it is not built around generic graphs, but rather around different
classes of causal graphs, including directed acyclic graphs (DAGs), partially 
directed acyclic graphs (PDAGs), acyclic directed mixed graphs (ADMGs), and 
ancestral graphs (AG) to name some. `caugi` can represent many classes of causal
graphs, and the list is expanding. 

The graph data structure is implemented in `Rust`, yielding query and traversal
operations exceeding the run time of competing packages in `R`, still while giving 
the user an experience as writing graphs on a whiteboard. Alongside the core
representation, `caugi` implements a wide range of causal-graph algorithms, such
as separation tests, structural queries, adjustment-set identification, graph metrics, 
together with a full-featured system for visualizing graphs.

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
computationally intensive, particularly in high-dimensional settings.
`caugi` is designed to meet these needs by providing a fast and flexible toolbox
for causal graphs in `R`.

The problem with many existing tools is that they

1) are not designed with causal graphs in mind and therefore lack the necessary
   functionality for causal inference and discovery,

2) are not built with performance in mind and therefore struggle with larger
   graphs, or

3) lack an intuitive interface, for instance requiring users to define graphs
   through adjacency matrices or edge lists, which can be cumbersome and
   error-prone.

`caugi` addresses these issues with an intuitive graph representation, a broad
set of algorithms for causal inference and discovery, and an interface built
around edge operators.

# State of the Field

<!-- A description of how this software compares to other commonly-used
packages in the research area. If related tools exist, provide a clear “build
vs. contribute” justification explaining your unique scholarly contribution and
why existing alternatives are insufficient. -->

Graph packages in high-level languages such as `R` and `Python` span a wide
range of scopes, from general-purpose graph libraries to specialised
causal-inference toolkits. 

Where packages such as `igraph` [@csardi2006; @antonov2023] and `NetworkX`
[@hagberg2008] are plenty fast, they are general-purpose graph packages, and
building the correct abstractions on top of them has been done in for example `ggm`
[@marchetti2025] or `pgmpy` [@ankan2024]. It takes a lot of work to make these
abstractions correct and might require hacks, such as representing a partially
directed graph with directed edges going in both directions and alike.

Then, you have packages such as `pcalg` [@kalisch2012] or `bnlearn`
[@scutari2010]. These packages have in common that they both are built around
their own graph representations, but the purpose of the packages are not the
graph structures themselves, but rather algorithms regarding causal graphs.
`pcalg` represents their graphs with matrices, but how they are represented
differ between graph classes. `bnlearn` has a fast backend for some queries, but
it is not very memory efficient, and it will run out of memory for larger
graphs.

An honourable mention is `Tetrad` [@scheines1998], which is written in Java, and
is quite performant and expressive, but lacks a proper interface to `R` (as it
currently stands).

Then there are packages that have a bit more intuitive, causality-native
interface as `dagitty` [@textor2016] and `MixedGraphs` [@evans2025]. The latter
does not seem to have a very active community, but has been a source of
inspiration for `caugi`. While `dagitty` seems to have a larger user base, as
well as a quite expressive format, we have experienced that it had problems with
instability and memory regarding especially larger graphs. We have seen memory
issues for `bnlearn` as well.

So, we found that `caugi` fills a gap in the market, combining performance
comparable with `igraph` and `NetworkX` with the causality-native interface of
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
The CSR format scales memory proportionally to the number of edges and is 
particularly well-suited for more sparse graphs, which we often see in 
causality. This representation makes queries fast(er), but mutations (more) 
expensive. Any structural change in principle requires rebuilding the index. 

To avoid penalizing iterative workflows, `caugi` adopts a *lazy build* strategy.
Mutations are batched and the graph is only rebuilt when the user queries the graph.
Graphs *appear* mutable from the user's perspective, while remaining immutable internally 
and always consistent when queried.

# Examples

We first define a DAG:

```r
library(caugi)

dag <- caugi(
  U %-->% X + Y,
  W %-->% X,
  X %-->% M %-->% Y,
  class = "DAG"
)
```

Projecting out the unobserved confounder `U` yields an
ADMG on `W`, `M`, `X`, and `Y`; the bidirected edge between `X` and `Y` records
confounding left behind by the latent:

```r
obs <- latent_project(dag, latents = "U")
obs
#> <caugi object; 4 nodes, 4 edges; simple: TRUE; session=0x9271562a0>
#>   graph_class: ADMG
#>   nodes: W, X, M, Y
#>   edges: W-->X, X-->M, M-->Y, X<->Y
```

`X` and `Y` are not m-separated, since confounding persists in the ADMG:

```r
m_separated(obs, "X", "Y")
#> [1] FALSE
```

but we can find the minimal $d$-separator in the original DAG:

```r
minimal_separator(dag, "X", "Y")
#> [1] "U" "M"
```

We can easily plot side by side using the native plotting functions:

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

# Acknowledgements

The majority of algorithms in `caugi` have been implemented from scratch, but we
also rely on some external libraries, including `gadjid`\ [@henckel2024] for the
adjustment identification distance metric.

# References
