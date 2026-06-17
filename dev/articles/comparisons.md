# Comparisons with Other Packages

In this vignette, we compare `caugi` to some of the most widely used
graph packages in R, Python, and Java.

## Overview

The following table summarizes the packages included in this comparison,
their general focus, and the languages they are packaged for.

| Package | Type | Language | URL |
|:---|----|----|:---|
| igraph | General-purpose | R, Python, C | <https://igraph.org> |
| graph | General-purpose | R | <https://github.com/Bioconductor/graph> |
| gRbase | Graphical models | R | <https://CRAN.R-project.org/package=gRbase> |
| pcalg | Causal graphs | R | <https://pcalg.r-forge.r-project.org> |
| dagitty | Causal graphs | R, Web | <https://www.dagitty.net> |
| bnlearn | Bayesian networks | R | <https://www.bnlearn.com> |
| ggm | Graphical Markov models | R | <https://CRAN.R-project.org/package=ggm> |
| MixedGraphs | Causal graphs | R | <https://github.com/rje42/MixedGraphs> |
| NetworkX | General-purpose | Python | <https://networkx.org> |
| pgmpy | Probabilitistc graphical models | Python | <https://github.com/pgmpy/pgmpy> |
| Tetrad | Causal graphs | Java, CLI, R[^1], Python | <http://www.phil.cmu.edu/tetrad> |

An overview of the packages included in this comparison {.table
style="width:100%;"}

## Scope

The comparison focuses on **graph representation and analysis**: which
graph classes each package can represent, which structural and
causal-graph algorithms it implements, and how it interoperates with
other tooling.

Two adjacent areas are intentionally out of scope:

- **Causal discovery** (PC, FCI, GES, GFCI, LiNGAM, etc.). `caugi` does
  not implement discovery algorithms.
- **Statistical inference and parameter learning** (CPT estimation,
  likelihood, parameter fitting): also out of scope for `caugi`.

## Graph Types Supported

| Package     | DAG    | CPDAG  | MPDAG  | MAG    | PAG    | ADMG   | SWIG | UG     | Mixed/general |
|:------------|:-------|:-------|:-------|:-------|:-------|:-------|:-----|:-------|:--------------|
| **caugi**   | ●      | ●[^2]  | ●      | ◐[^3]  | ○      | ●      | ○    | ●      | ●             |
| igraph      | ◐[^4]  | ○[^5]  | ○      | ○      | ○      | ○      | ○    | ◐[^6]  | ◐[^7]         |
| graph       | ◐[^8]  | ○      | ○      | ○      | ○      | ○      | ○    | ◐[^9]  | ◐[^10]        |
| gRbase      | ◐[^11] | ○      | ○      | ○      | ○      | ○      | ○    | ◐[^12] | ○             |
| pcalg       | ◐[^13] | ◐[^14] | ◐[^15] | ◐[^16] | ◐[^17] | ○      | ○    | ○      | ○             |
| dagitty     | ●      | ◐[^18] | ○      | ●      | ●      | ○      | ○    | ○      | ○             |
| bnlearn     | ●      | ◐[^19] | ○      | ○      | ○      | ○      | ○    | ◐[^20] | ◐[^21]        |
| ggm         | ◐[^22] | ◐[^23] | ○      | ◐[^24] | ○      | ◐[^25] | ○    | ◐[^26] | ◐[^27]        |
| MixedGraphs | ◐[^28] | ○      | ○      | ○      | ○      | ◐[^29] | ○    | ●      | ●             |
| NetworkX    | ◐[^30] | ○      | ○      | ○      | ○      | ○      | ○    | ◐[^31] | ◐[^32]        |
| pgmpy       | ●      | ◐[^33] | ○[^34] | ●      | ○      | ●      | ○    | ●      | ○[^35]        |
| Tetrad      | ●      | ◐[^36] | ◐[^37] | ◐[^38] | ●[^39] | ◐[^40] | ○    | ◐[^41] | ◐[^42]        |

Supported graph types for the packages in this comparison. `●` indicates
a dedicated class with type-level invariants; `◐` indicates
representability without a dedicated class or invariant enforcement; `○`
indicates unsupported graph types. {.table style="width:100%;"}

## Graph Queries and Structural Operations

| Package | Parents/children | Ancestors/descendants | d-sep | m-sep | Paths | Acyclicity | Markov blanket | Moralization | Skeleton | v-structures | MEC enumeration |
|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|
| **caugi** | ● | ● | ● | ● | ○ | ● | ● | ● | ● | ○ | ○ |
| igraph | ◐[^43] | ◐[^44] | ○ | ○ | ● | ● | ○ | ○ | ○ | ○ | ○ |
| graph | ◐[^45] | ◐[^46] | ○ | ○ | ◐[^47] | ○ | ○ | ○ | ○ | ○ | ○ |
| gRbase | ◐[^48] | ◐[^49] | ○ | ○ | ○ | ● | ○ | ● | ○ | ○ | ○ |
| pcalg | ◐[^50] | ◐[^51] | ◐[^52] | ◐[^53] | ○ | ◐[^54] | ○ | ○ | ◐[^55] | ◐[^56] | ● |
| dagitty | ● | ● | ● | ○ | ● | ● | ● | ● | ○ | ◐[^57] | ● |
| bnlearn | ● | ● | ◐[^58] | ○ | ● | ● | ● | ● | ● | ● | ● |
| ggm | ◐[^59] | ◐[^60] | ● | ● | ◐[^61] | ● | ○ | ○ | ○ | ○ | ◐[^62] |
| MixedGraphs | ● | ● | ○ | ● | ○ | ◐[^63] | ◐[^64] | ● | ● | ○ | ○ |
| NetworkX | ◐[^65] | ● | ◐[^66] | ○ | ● | ● | ○ | ● | ◐[^67] | ● | ○ |
| pgmpy | ● | ◐[^68] | ● | ● | ○ | ● | ● | ● | ○[^69] | ● | ○ |
| Tetrad | ● | ● | ◐[^70] | ● | ● | ◐[^71] | ● | ○ | ◐[^72] | ◐[^73] | ● |

Overview of available graph queries and structural operations in the
packages in the comparison. {.table}

## Causal-Inference Algorithms

| Package | Back-door adj. | Generalized adj. | Optimal adj. | ID algorithm | Do-calculus | Counterfactuals | Interventions/mutilation |
|:---|:---|:---|:---|:---|:---|:---|:---|
| **caugi** | ● | ● | ◐[^74] | ○ | ○ | ○ | ○ |
| igraph | ○ | ○ | ○ | ○ | ○ | ○ | ○ |
| graph | ○ | ○ | ○ | ○ | ○ | ○ | ○ |
| gRbase | ○ | ○ | ○ | ○ | ○ | ○ | ○ |
| pcalg | ◐[^75] | ● | ● | ○ | ○ | ○ | ◐[^76] |
| dagitty | ◐[^77] | ○ | ○ | ○ | ○ | ○ | ◐[^78] |
| bnlearn | ○ | ○ | ○ | ○ | ○ | ● | ● |
| ggm | ○ | ○ | ○ | ○ | ○ | ○ | ○ |
| MixedGraphs | ○ | ○ | ○ | ○ | ○ | ○ | ◐[^79] |
| NetworkX | ○ | ○ | ○ | ○ | ○ | ○ | ○ |
| pgmpy | ● | ● | ○ | ○ | ○ | ○ | ● |
| Tetrad | ◐[^80] | ● | ◐[^81] | ○ | ○ | ○ | ○ |

Overview of available causal-inference algorithms in the packages in the
comparison. {.table}

## I/O and Interoperability

| Package     | DOT    | Mermaid | GraphML | JSON   | Coerce to/from other graph classes |
|:------------|:-------|:--------|:--------|:-------|:-----------------------------------|
| **caugi**   | ◐[^82] | ●       | ●       | ●[^83] | ●                                  |
| igraph      | ◐[^84] | ○       | ●       | ○      | ◐[^85]                             |
| graph       | ◐[^86] | ○       | ○       | ○      | ◐[^87]                             |
| gRbase      | ○      | ○       | ○       | ○      | ◐[^88]                             |
| pcalg       | ○      | ○       | ○       | ○      | ◐[^89]                             |
| dagitty     | ○      | ○       | ○       | ○      | ◐[^90]                             |
| bnlearn     | ◐[^91] | ○       | ○       | ○      | ●                                  |
| ggm         | ○      | ○       | ○       | ○      | ◐[^92]                             |
| MixedGraphs | ○      | ○       | ○       | ○      | ●                                  |
| NetworkX    | ◐[^93] | ○       | ●       | ●      | ◐[^94]                             |
| pgmpy       | ◐[^95] | ○       | ○       | ○      | ◐[^96]                             |
| Tetrad      | ◐[^97] | ○       | ○       | ●      | ○                                  |

Comparison of supported graph I/O formats and interoperability features.
{.table}

## Implementation and Ergonomics

| Package | Backend | Sparse storage | Built-in plotting | Layout algorithms | Pipeable/fluent API | Lazy mutation |
|:---|:---|:---|:---|:---|:---|:---|
| **caugi** | R + Rust | ● | ● | ● | ● | ● |
| igraph | C | ◐[^98] | ● | ● | ○ | ○ |
| graph | R + C | ●[^99] | ○[^100] | ○ | ○ | ○ |
| gRbase | R + C++ | ● | ◐[^101] | ○ | ○ | ○ |
| pcalg | R + C++ | ○ | ◐[^102] | ○ | ○ | ○ |
| dagitty | R + JS | ○ | ● | ◐[^103] | ○ | ○ |
| bnlearn | R + C | ◐[^104] | ◐[^105] | ◐[^106] | ○ | ○ |
| ggm | R | ○ | ● | ◐[^107] | ○ | ○ |
| MixedGraphs | R + C++ | ◐[^108] | ◐[^109] | ○ | ◐[^110] | ○ |
| NetworkX | Python | ◐[^111] | ◐[^112] | ● | ○ | ○ |
| pgmpy | Python (NetworkX) | ○ | ◐[^113] | ◐[^114] | ○ | ○ |
| Tetrad | Java | ● | ◐[^115] | ● | ○ | ○ |

Comparison of implementation details and ergonomic features of the
packages in the comparison. {.table}

## Contributing

If you find any errors in the comparison above or would like to add
another package for comparisons, please file an issue or submit a pull
request with the relevant information.

[^1]: Bindings for Tetrad exist in
    <https://github.com/cmu-phil/r-tetrad>, but not in the form of a
    formal R package. The authors instead recommend using the Python
    bindings from R instead.

[^2]: `caugi` has a dedicated `CPDAG` class whose invariants (chordal
    chain components, an acyclic component DAG, Meek closure, and strong
    arrow protection) are validated at construction via
    `class = "CPDAG"` (in
    [`caugi()`](https://caugi.org/dev/reference/caugi.md),
    [`as_caugi()`](https://caugi.org/dev/reference/as_caugi.md), and
    [`mutate_caugi()`](https://caugi.org/dev/reference/mutate_caugi.md)).
    `generate_graph(class = "CPDAG")` returns a graph typed `"CPDAG"`,
    and [`is_cpdag()`](https://caugi.org/dev/reference/is_cpdag.md) also
    validates the structure post-hoc for graphs of other classes.

[^3]: `caugi` accepts `class = "AG"` (ancestral graph) in the
    constructor and exports
    [`is_mag()`](https://caugi.org/dev/reference/is_mag.md) to validate
    maximality post-hoc, but there is no dedicated MAG class—MAGs are
    representable as AGs and checked rather than enforced.

[^4]: igraph has no dedicated DAG class.
    [`is_dag()`](https://caugi.org/dev/reference/is_dag.md) tests
    whether a directed graph is acyclic, but the package’s single
    `igraph` object class does not enforce DAG invariants. A directed
    graph that happens to be acyclic is representable, but the type is
    not distinguished at the object level.

[^5]: igraph has no CPDAG, MPDAG, MAG, PAG, ADMG, or SWIG class and no
    associated type-level operations (confirmed absent from R source and
    NAMESPACE).

[^6]: Undirected graphs are representable via `is_directed = FALSE`
    (e.g. `make_empty_graph(directed = FALSE)`), but there is no
    dedicated UG class enforcing undirectedness as a type invariant
    distinct from the general `igraph` object.

[^7]: igraph supports per-edge attributes but has no dedicated
    mixed-edge class with typed semantics. Representing a true mixed
    graph requires manual attribute manipulation with no type
    enforcement.

[^8]: `graph` has no dedicated DAG class. `graphNEL` and `graphAM` can
    hold directed graphs (via `edgemode = "directed"`) that happen to be
    acyclic, but the package enforces no acyclicity invariants and
    provides no DAG-specific construction or validation.

[^9]: No dedicated UG class. Undirected graphs are represented by
    setting `edgemode = "undirected"` on a general `graphNEL` /
    `graphAM` object; the package stores reciprocal edges internally but
    does not expose a named UG class.

[^10]: `MultiGraph` holds a shared node set with multiple edge sets,
    each independently directed or undirected. It does not support a
    single edge that is both directed and bidirected, and is not
    designed around causal mixed-edge semantics (e.g. MAG/PAG/ADMG).

[^11]: gRbase provides a `dag()` constructor and
    [`is_dag()`](https://caugi.org/dev/reference/is_dag.md) type-check,
    with the underlying representation being an igraph object or
    adjacency matrix. There is no dedicated DAG class enforcing
    acyclicity invariants at the object level.

[^12]: Same reasoning as `[^grbase-dag]`: `ug()` constructs an
    undirected graph and
    [`is_ug()`](https://caugi.org/dev/reference/is_ug.md) tests for it,
    but the result is a plain igraph or matrix.

[^13]: pcalg produces DAGs (via `randomDAG()` / `randDAG()` returning
    `graphNEL` objects, or the `ParDAG` / `GaussParDAG` class), and
    `isValidGraph(amat, type = "dag")` validates them. The dominant
    user-facing representation is an untyped `graphNEL` rather than a
    pcalg-owned DAG class.

[^14]: `dag2cpdag()` produces a CPDAG and
    `isValidGraph(amat, type = "cpdag")` validates one; `pcAlgo` objects
    carry a graph with attribute `"amat.cpdag"`. There is no dedicated
    exported CPDAG class.

[^15]: `addBgKnowledge()` augments a CPDAG with background knowledge and
    re-applies Meek’s rules to produce an MPDAG. As with CPDAG, no
    dedicated exported MPDAG class exists; the object is a bare
    adjacency matrix with convention-level typing only.

[^16]: MAG-type adjacency matrices (0/2/3 coding from Richardson &
    Spirtes 2002) are used throughout pcalg (e.g. `dsepAM()`,
    `backdoor()`, `adjustment(amat.type = "mag")`, `pcalg2dagitty()`),
    but there is no exported MAG class.

[^17]: `fciAlgo` objects hold a PAG as an adjacency matrix in the
    `@amat` slot. `fci()` / `rfci()` / `fciPlus()` / `dag2pag()` all
    return `fciAlgo`. The class is exported but is a *result* container
    for FCI-family algorithms, not a freely constructable PAG class.

[^18]: `dagitty` recognises only `"dag"`, `"pdag"`, `"mag"`, `"pag"` via
    `graphType()`. `equivalenceClass()` calls `dagToCpdag` internally
    and is documented as producing a CPDAG, but the result is typed
    `"pdag"`—no distinct CPDAG class or invariant enforcement. MPDAG is
    likewise representable as `"pdag"` without Meek-completion logic.
    `"ug"`, `"admg"`, `"swig"` are absent from both the R API and the JS
    engine.

[^19]: `cpdag()` computes the CPDAG of a DAG and `valid.cpdag()`
    validates structure, but bnlearn uses a single generic `bn` class
    for all graph types; no dedicated CPDAG class exists and CPDAG
    invariants are not enforced at the object level.

[^20]: [`skeleton()`](https://caugi.org/dev/reference/skeleton.md)
    produces a fully undirected graph and `valid.ug()` validates whether
    a `bn` object is completely undirected, but the result is still a
    plain `bn` object—no dedicated UG class with enforced undirected
    invariants exists.

[^21]: A `bn` object can hold a mix of directed and undirected arcs
    (representing a PDAG), making mixed graphs implicitly representable,
    but there is no explicit untyped mixed-edge graph class distinct
    from the PDAG interpretation.

[^22]: `ggm` represents DAGs as plain integer adjacency matrices
    (entries 0, 1, 10, 100) built with `DAG()`. There is no S3/S4 class
    enforcing DAG invariants; `isAcyclic()` must be called separately.

[^23]: `essentialGraph()` converts a DAG to its essential graph (=
    CPDAG), returning an adjacency matrix. There is no dedicated CPDAG
    class; the result is an untagged matrix.

[^24]: `MAG()` derives a maximal ancestral graph after
    marginalisation/conditioning, and `isAG()` validates ancestral-graph
    conditions. The representation is still an untagged adjacency
    matrix.

[^25]: `isADMG()` checks whether an adjacency matrix satisfies ADMG
    conditions. No dedicated ADMG constructor exists; the matrix
    encoding is the same general integer format used for all mixed
    graphs.

[^26]: Undirected graphs are built with `UG()`, which produces an
    adjacency matrix with edge-type value 10. No distinct UG class
    enforces undirected invariants.

[^27]: `makeMG()` combines directed, undirected, and bidirected
    components into one adjacency matrix; `grMAT()` converts
    graphNEL/igraph inputs to this format. The representation is a
    general integer adjacency matrix with no commitment to a specific
    typed mixed-graph semantics.

[^28]: `MixedGraphs` has no dedicated DAG class. `is_DAG()` checks that
    a `mixedgraph` carries only directed edges and is acyclic, but the
    constructor does not enforce DAG invariants. The `mixedgraph` object
    is an untyped container.

[^29]: `is_ADMG()` tests whether a `mixedgraph` contains only directed
    and bidirected edges and is acyclic, but there is no dedicated ADMG
    class. ADMG-typed objects from the companion `ADMGs` package can be
    converted to/from `mixedgraph` via `convert()`, but `MixedGraphs`
    itself does not expose an ADMG class.

[^30]: NetworkX’s `DiGraph` class stores directed edges and supports
    DAG-related algorithms (`is_directed_acyclic_graph`,
    `topological_sort`, `ancestors`, `descendants`), but the class
    itself does not enforce acyclicity as an invariant—a `DiGraph` can
    hold cycles. There is no dedicated `DAG` subclass.

[^31]: NetworkX’s `Graph` class stores undirected edges, making it
    suitable for UGs, but it carries no type-level semantic enforcement
    (no bidirected edges, no directed edges, etc.).

[^32]: NetworkX has no mixed-edge graph class. Its four classes
    (`Graph`, `DiGraph`, `MultiGraph`, `MultiDiGraph`) are all
    homogeneous-edge. The `pywhy-graphs` extension provides mixed-graph
    types but is a separate package.

[^33]: `pgmpy` has a single `PDAG` class (`pgmpy.base.PDAG`) documented
    as “also known as CPDAG”. It supports CPDAG construction from a DAG
    via `DAG.to_pdag()` (Chickering 2002) and `to_cpdag()` /
    `apply_meeks_rules()` methods. There is no separate dedicated CPDAG
    class, and PDAG does not enforce the invariant that the graph
    represents a complete Markov equivalence class.

[^34]: No dedicated MPDAG class.
    `PDAG.apply_meeks_rules(apply_r4 = True)` applies all four Meek
    rules and could produce an MPDAG, but there is no type-specific
    MPDAG class or MPDAG-specific construction pathway.

[^35]: `AncestralBase` stores mixed-edge graphs with arbitrary marks and
    is the parent of `MAG`. It is an internal base class, not a
    user-facing untyped mixed-edge graph class. Coverage of several
    typed mixed graphs (ADMG, MAG, PDAG) does not by itself satisfy this
    column.

[^36]: Tetrad has no dedicated `Cpdag` class. CPDAGs are represented as
    `EdgeListGraph` objects containing directed and undirected edges.
    The library validates CPDAG status at runtime via
    `Paths.isLegalCpdag()` and produces CPDAGs through
    `GraphTransforms.dagToCpdag()` / `GraphSearchUtils.basicCpdag()`.
    The CPDAG concept is operationally first-class but not a distinct
    enforced type.

[^37]: No dedicated `Mpdag` class. Tetrad validates MPAGs via
    `Paths.isLegalMpag()`, and `MeekRules.orientImplied(graph)` with a
    populated `Knowledge` object applies Meek rules under background
    constraints, but there is no single `dagToMpdag` factory.

[^38]: No dedicated `Mag` class. MAGs are represented as generic
    `EdgeListGraph` objects and validated post-hoc via
    `Paths.isLegalMag()`. Constructed through
    `GraphTransforms.dagToMag(dag)` and converted to PAGs via
    `GraphTransforms.magToPag()`.

[^39]: No dedicated `Pag` class. PAGs are `EdgeListGraph` instances with
    circle, tail, and arrowhead endpoints. Validated via
    `Paths.isLegalPag()`. Produced by `GraphTransforms.dagToPag()` and
    `GraphTransforms.magToPag()`.

[^40]: `SemGraph` (in `edu.cmu.tetrad.graph`) enforces directed +
    bidirected edges only and automatically manages error nodes for each
    endogenous variable, implementing ADMG-like semantics. However, it
    is scoped to structural-equation-model graphs (with explicit error
    nodes) rather than a general-purpose ADMG class.

[^41]: No dedicated undirected-graph class. Undirected edges can be
    added to `EdgeListGraph` via `addUndirectedEdge()`, and
    `GraphUtils.undirectedGraph(g)` converts all edges to undirected.
    There is no enforced `UG` type with invariant-checking.

[^42]: `EdgeListGraph` is the universal mixed-edge container and accepts
    all five endpoint combinations (directed, undirected, bidirected,
    partially-oriented, nondirected). It does not commit to any single
    graph semantics, but it is not branded as a distinct “mixed/general”
    class—it is simply the default implementation of the `Graph`
    interface.

[^43]: Parents and children are obtainable via
    `neighbors(graph, v, mode = "in" / "out")`, but there are no
    dedicated [`parents()`](https://caugi.org/dev/reference/parents.md)
    / [`children()`](https://caugi.org/dev/reference/children.md)
    exported functions.

[^44]: Ancestors and descendants are obtainable via
    `subcomponent(graph, v, mode = "in" / "out")`, but there are no
    dedicated
    [`ancestors()`](https://caugi.org/dev/reference/ancestors.md) /
    [`descendants()`](https://caugi.org/dev/reference/descendants.md)
    exported functions.

[^45]: No dedicated
    [`parents()`](https://caugi.org/dev/reference/parents.md) or
    [`children()`](https://caugi.org/dev/reference/children.md)
    functions. `inEdges()` returns the set of in-neighbours (functional
    equivalent of parents on a directed graph);
    [`edges()`](https://caugi.org/dev/reference/edges.md) returns
    out-neighbours (functional equivalent of children). Both are
    exported S4 generics.

[^46]: `acc()` returns all nodes reachable from a given node on a
    directed graph, equivalent to the descendant set. There is no
    [`ancestors()`](https://caugi.org/dev/reference/ancestors.md)
    equivalent exported by the package.

[^47]: `DFS()` (exported) provides depth-first graph traversal;
    `pathWeights()` computes weights along a user-specified path. No
    all-paths enumeration, shortest-path, or directed-path-existence
    function is provided; those require the companion `RBGL` package.

[^48]: [`parents()`](https://caugi.org/dev/reference/parents.md) and
    [`children()`](https://caugi.org/dev/reference/children.md) are
    exported (`R/graph-querygraph.R`). There is no corresponding
    [`descendants()`](https://caugi.org/dev/reference/descendants.md)
    function in the exported API;
    [`ancestors()`](https://caugi.org/dev/reference/ancestors.md) /
    `ancestralSet()` / `ancestralGraph()` cover the ancestor side but
    the symmetric descendent query is absent.

[^49]: [`ancestors()`](https://caugi.org/dev/reference/ancestors.md),
    `ancestralSet()`, and `ancestralGraph()` are exported. A dedicated
    [`descendants()`](https://caugi.org/dev/reference/descendants.md) is
    absent from the exported API.

[^50]: `searchAM(amat, x, type = "pa" / "ch")` returns parents and
    children for DAG, CPDAG, MAG, and PAG adjacency matrices. There is
    no standalone
    [`parents()`](https://caugi.org/dev/reference/parents.md) or
    [`children()`](https://caugi.org/dev/reference/children.md)
    function; retrieval goes through the general `searchAM()`
    dispatcher.

[^51]: `searchAM(amat, x, type = "an" / "de")` returns ancestors and
    descendants for DAG/CPDAG/MAG/PAG. `possAn()` and `possDe()` /
    `possibleDe()` return possible ancestors/descendants in PAGs. All
    operate on raw adjacency matrices via `searchAM()`.

[^52]: `dsep(a, b, S, g)` tests d-separation in a DAG (using a
    `graphNEL` object and moralization; Lauritzen 2004). `dsepTest()`
    wraps it for use as a CI oracle. There is no exported d-separation
    function for CPDAGs or PDAGs directly; `dsep()` is DAG-only.

[^53]: `dsepAM(X, Y, S, amat)` tests m-separation on MAG adjacency
    matrices. `dsepAMTest()` wraps it for algorithmic use. Coverage is
    MAG-only; there is no exported m-separation function for PAGs in
    pcalg’s own API.

[^54]: `isValidGraph(amat, type = "dag")` checks for directed cycles as
    part of DAG validation. There is no standalone
    [`is_acyclic()`](https://caugi.org/dev/reference/is_acyclic.md)
    function; acyclicity is only surfaced through `isValidGraph()`.

[^55]: The [`skeleton()`](https://caugi.org/dev/reference/skeleton.md)
    function *estimates* a skeleton from data using conditional
    independence tests (it is a causal discovery function). There is no
    separate exported function to extract or query the skeleton of an
    already-known graph.

[^56]: `udag2pdag()` and `dag2cpdag()` identify v-structures as part of
    the CPDAG-completion process, but there is no standalone exported
    function to enumerate or check v-structures of a given graph.

[^57]: No function enumerates v-structures as a set.
    `isCollider(x, u, v, w)` tests a single triple, but there is no
    exported `vStructures()` or equivalent. Skeleton (undirected version
    of the graph) is also absent as a dedicated function.

[^58]: `dsep()` tests d-separation on `bn` objects. When the input
    contains undirected arcs (PDAG/CPDAG), the function calls
    `cpdag.extension()` to produce a single consistent DAG extension
    first; d-separation is then tested on that DAG rather than natively
    on the PDAG.

[^59]: `pa()` returns parents and `ch()` returns children of a node set
    in a DAG. `bd()` returns the boundary (neighbours + parents). These
    operate on raw adjacency matrices and are undocumented for
    MAG/mixed-graph inputs; no
    [`descendants()`](https://caugi.org/dev/reference/descendants.md) or
    [`spouses()`](https://caugi.org/dev/reference/spouses.md) analogue
    is exported.

[^60]: `ancGraph()` / `anGraph()` compute the transitive closure
    (ancestor relation) of a DAG as a Boolean adjacency matrix rather
    than returning a node list. No
    [`descendants()`](https://caugi.org/dev/reference/descendants.md)
    function is exported.

[^61]: `findPath()` finds a single path between two nodes in an
    undirected graph (used internally by `fundCycles()`); it is not
    intended for direct user calls and does not enumerate all paths.

[^62]: `essentialGraph()` returns the CPDAG (encoding the full MEC) but
    does not enumerate the Markov-equivalent DAGs. `MarkEqRcg()` /
    `MarkEqMag()` test pairwise Markov equivalence; `RepMarDAG()` /
    `RepMarUG()` / `RepMarBG()` find a single representative.

[^63]: `is_cyclic()` is exported and checks directed cycles, and
    `topologicalOrder()` / `isTopological()` implicitly validate
    acyclicity, but `is_cyclic()` documentation notes it is “Not
    tested”—`◐` reflects this caveat.

[^64]: `mb()` finds the “Markov blanket for a vertex in an ancestral
    set” but requires the user to supply an explicit ancestral set `A`
    and the vertex must be childless in that set—a constrained helper
    rather than a standard graph-wide Markov-blanket function.

[^65]: `DiGraph.predecessors()` and `DiGraph.successors()` return
    parent/child iterators. There is no dedicated
    [`parents()`](https://caugi.org/dev/reference/parents.md) /
    [`children()`](https://caugi.org/dev/reference/children.md) API for
    a named causal DAG.

[^66]: `networkx.algorithms.d_separation` provides `is_d_separator`,
    `is_minimal_d_separator`, and `find_minimal_d_separator`. All three
    require a DAG and raise `NetworkXError` on cyclic or undirected
    graphs. They do not support PDAGs, MAGs, or any other mixed-edge
    graph type.

[^67]: NetworkX has no dedicated
    [`skeleton()`](https://caugi.org/dev/reference/skeleton.md)
    function. The moral graph (`nx.moral_graph`) is available, but
    skeleton extraction (dropping directionality without moralization)
    is not an exported function.

[^68]: `DAG.get_ancestors()` is implemented. There is no
    `DAG.get_descendants()` method; `nx.descendants()` from NetworkX can
    be called on the underlying `nx.DiGraph` directly, but it is not
    part of pgmpy’s exported API. `ADMG` does provide both
    `get_ancestors()` and `get_descendants()`.

[^69]: No [`skeleton()`](https://caugi.org/dev/reference/skeleton.md)
    method exists in any pgmpy graph class. The undirected skeleton is
    accessible via the inherited `nx.DiGraph.to_undirected()`, but this
    is not a pgmpy-level exported function.

[^70]: `Paths.isMSeparatedFrom(x, y, z, isPag)` implements
    d-/m-separation. The simpler overload’s Javadoc says “DAG only”, yet
    the `isPag` parameter explicitly switches PAG semantics.
    Per-graph-type documentation is inconsistent; users access
    d-separation as `isMSeparatedFrom(..., false)`. The back-door helper
    `Paths.isSatisfyBackDoorCriterion()` constructs a `Dag` internally
    and throws if input is not a DAG.

[^71]: There is no `isAcyclic()` method. Callers use
    `!graph.paths().existsDirectedCycle()` or `Paths.isLegalDag()` /
    `GraphUtils.isDag()`. Fully supported but requires negation of a
    cycle-detection predicate.

[^72]: No dedicated
    [`skeleton()`](https://caugi.org/dev/reference/skeleton.md) method.
    `GraphUtils.undirectedGraph(g)` converts all edges to undirected
    (producing the skeleton graph object), but it is a workaround.

[^73]: `GraphUtils.listColliderTriples(graph)` returns all definite
    collider triples. However, `EdgeListGraph.isDefCollider()` checks
    arrowhead endpoints without testing non-adjacency of the outer
    nodes, so the method returns both shielded and unshielded colliders
    rather than v-structures (unshielded colliders) exclusively.

[^74]: `adjustment_set(cg, X, Y, type = "optimal")` returns the O-set of
    Henckel/Perković/Maathuis (2019), but only for DAGs—the underlying
    Rust implementation errors on non-DAG graph classes. There is no
    O-set support for CPDAGs, MPDAGs, MAGs, or PAGs.

[^75]: `backdoor(amat, x, y, type)` implements the Generalized Backdoor
    Criterion (GBC) of Maathuis & Colombo (2015), which subsumes Pearl’s
    classical back-door criterion. For DAGs the GBC reduces to Pearl’s
    back-door, so back-door is available as a special case, but the
    function does not specifically enforce or name the classical
    back-door separately. Generalized adjustment is
    `adjustment(amat, amat.type, x, y, set.type)` (full GAC, Perkovic et
    al. 2015/2018), and optimal is `optAdjSet(graphEst, x.pos, y.pos)`
    (Henckel/Perkovic/Maathuis 2019, DAG/CPDAG/PDAG only).

[^76]: `rmvnorm.ivent(n, object, target, target.value)` simulates from
    an interventional distribution of a `GaussParDAG` by fixing target
    nodes — implements the do-operator semantics within the simulation
    framework but does not mutilate the graph object itself. There is no
    exported `mutilate()` or `do()` helper that returns a modified graph
    with incoming edges removed from intervention nodes.

[^77]: `adjustmentSets(effect = "total")` and `isAdjustmentSet()` both
    invoke `GraphTransformer.backDoorGraph()` in the JS engine—Pearl’s
    back-door graph construction, not the generalized Perkovic
    criterion. The R documentation cites Perkovic et al. (2015), but the
    JS implementation (`listMsasTotalEffect` in
    `jslib/graph/GraphAnalyzer.js`) applies the back-door graph
    uniformly across dag/pdag/mag/pag. Generalized adjustment scores `○`
    because no separate generalized-adjustment code path exists.
    `type = "canonical"` returns the ancestor-based canonical set but is
    not an optimality criterion in the Rotnitzky/Henckel sense.

[^78]: `backDoorGraph(x)` removes the first directed edge on every
    proper causal path (with PAG handling via `pagToPdag`
    conversion)—the back-door-graph helper, not a general `do()`-style
    mutilation that removes all incoming edges to an arbitrary
    intervention set. No `mutilate()` or `do()` function is exported.

[^79]: `mutilate()` removes edges adjacent to a specified vertex set and
    supports a `dir = -1` option that removes only incoming edges. It
    can mechanically produce the mutilated graph required by `do()`, but
    the function is documented as a general edge-deletion utility with
    no causal semantics, no treatment of bidirected edges in the
    do-calculus sense, and no convenience wrapper that enforces “remove
    all incoming edges to the intervention set.”

[^80]: `Paths.isSatisfyBackDoorCriterion(graph, x, y, z)` implements
    Pearl’s back-door criterion check, but the implementation constructs
    `new Dag(graph)` internally and throws if the input is not a DAG.
    Back-door adjustment *sets* are not separately enumerated; the
    generalized `RecursiveAdjustment.adjustmentSets()` subsumes the
    back-door case for DAGs.

[^81]: `OSet.oSetDag(graph, X, Y)` and
    `OSet.oSetCpdag(graph, X, Y, maxPathLength)` implement the
    Henckel–Perković–Maathuis O-set for DAGs and (amenable) CPDAGs
    respectively. The `Ida` and `PdagPagIda` classes wrap this as
    `IDA_TYPE.OPTIMAL`. Coverage is restricted to DAG/CPDAG; O-sets for
    MAGs/PAGs are not implemented.

[^82]: [`to_dot()`](https://caugi.org/dev/reference/to_dot.md) /
    [`write_dot()`](https://caugi.org/dev/reference/write_dot.md) write
    Graphviz DOT format, but caugi has no DOT reader—round-trip via DOT
    is not supported.

[^83]: [`caugi_serialize()`](https://caugi.org/dev/reference/caugi_serialize.md)
    /
    [`caugi_deserialize()`](https://caugi.org/dev/reference/caugi_deserialize.md)
    (and [`read_caugi()`](https://caugi.org/dev/reference/read_caugi.md)
    / [`write_caugi()`](https://caugi.org/dev/reference/write_caugi.md))
    read and write caugi’s own JSON-based serialization format
    (Rust-side: `src/rust/src/lib.rs`). It is not a standardized
    cross-package JSON schema.

[^84]: DOT (Graphviz) format is supported for writing only
    (`write_graph(format = "dot")`). Reading DOT format is not
    supported. `read_graph()` accepts: edgelist, pajek, ncol, lgl,
    graphml, dimacs, graphdb, gml, dl.

[^85]: igraph provides explicit coercion to/from `graphNEL` objects from
    the Bioconductor `graph` package via `as_graphnel()` and
    `graph_from_graphnel()`. No coercion helpers exist for dagitty,
    bnlearn, pcalg, or other causal R package object classes.

[^86]: Write only. `toDotWithRI()` and `toDotR()` serialise `graphNEL`
    objects to DOT (Graphviz) format. No DOT reader is provided in the
    `graph` package.

[^87]: Internal coercions are provided: `as(graphNEL, "graphAM")`,
    `as(graphAM, "graphNEL")`, `as(graphBAM, "graphNEL")`,
    `as(matrix, "graphNEL")`, `as(matrix, "graphAM")`, `graph2SparseM()`
    / `sparseM2Graph()` (requiring optional `SparseM`). No coercions to
    or from `igraph`, `dagitty`, or `bnlearn` objects are exported by
    `graph` itself.

[^88]: gRbase provides `as()` S4 coercion methods that convert among
    igraph, graphNEL (Bioconductor `graph`), dense adjacency matrix, and
    sparse `dgCMatrix` representations. There are no explicit coercion
    helpers for other *causal-graph* packages (dagitty, bnlearn, pcalg).

[^89]: `pcAlgo` and `fciAlgo` objects can be coerced to `graphAM` /
    `graphNEL` (from `graph`) via S4 coercion methods. The package wraps
    `graphNEL` as its primary DAG container, and `iplotPC()` converts to
    `igraph` for plotting. Incoming coercion (from igraph, bnlearn,
    dagitty, etc. into pcalg objects) is not provided.

[^90]: `convert(x, to = "igraph")` and `convert(x, to = "causaleffect")`
    produce igraph objects (one-way: dagitty → igraph only).
    `as.dagitty.bn()` converts bnlearn `bn` objects to dagitty (one-way
    the other direction). `lavaanToGraph()` converts lavaan models to
    dagitty. No coercion to/from `graphNEL`, `pcalg`, or other classes.

[^91]: `write.dot()` exports the network structure to Graphviz DOT
    format, but there is no corresponding `read.dot()`—DOT support is
    write-only.

[^92]: `grMAT()` converts graphNEL (from `graph`) and igraph objects
    *into* ggm adjacency matrices. `plotGraph()` also accepts
    graphNEL/igraph as input. There is no function to export a ggm
    adjacency matrix back to a graphNEL or igraph object; coercion is
    one-directional (into ggm’s format).

[^93]: DOT format read (`read_dot`) and write (`write_dot`) are
    available via `networkx.drawing.nx_pydot`, but `pydot` is an
    optional external dependency that must be installed separately. A
    pending deprecation warning has also been filed for `nx_pydot`
    (issue \#5723).

[^94]: NetworkX provides explicit conversion helpers to/from NumPy
    arrays, SciPy sparse arrays, and Pandas DataFrames. Conversion
    to/from other *graph* objects (igraph, graph-tool) is handled by
    those packages’ own `from_networkx()` / `to_networkx()` methods, not
    by NetworkX itself.

[^95]: `DAG.to_graphviz()` returns a `pygraphviz.AGraph` from which DOT
    text can be obtained via `.to_string()`. There is no direct
    [`to_dot()`](https://caugi.org/dev/reference/to_dot.md) /
    `from_dot()` API; reading DOT is not supported through pgmpy’s own
    API.

[^96]: pgmpy graph classes (`DAG`, `PDAG`, `ADMG`) inherit from
    `networkx.DiGraph`/`networkx.MultiDiGraph`, so they are directly
    usable as NetworkX objects. There are no explicit coercion helpers
    to or from other graph-package objects (igraph, R dagitty objects,
    bnlearn objects).

[^97]: `GraphSaveLoadUtils.graphToDot(graph)` writes Graphviz DOT format
    (string and file variants). There is no DOT reader, so round-trip is
    not supported. Write-only.

[^98]: The C igraph library uses adjacency-list storage internally. On
    the R side, `as_adjacency_matrix(sparse = TRUE)` and
    `graph_from_adjacency_matrix()` accept/return sparse `Matrix`
    objects (`dgCMatrix`), but the igraph object itself is an opaque
    external pointer backed by the C library’s adjacency-list
    representation, not an R-level sparse matrix.

[^99]: `graphNEL` uses an adjacency-list representation (sparse by
    nature). `graphBAM` (experimental) stores adjacency as a compact
    bit-array. `graph2SparseM()` / `sparseM2Graph()` convert to/from
    `SparseM` sparse matrices when that package is installed.

[^100]: No built-in plotting. DOT serialisation helpers (`toDotWithRI`,
    `toDotR`) are provided, but actual rendering requires the separate
    `Rgraphviz` package. No layout algorithms are implemented in `graph`
    itself.

[^101]: gRbase exports `iplot()` / `graph-iplot`, a thin wrapper around
    igraph’s `plot.igraph()`. There are no built-in layout algorithms:
    layout selection is delegated entirely to igraph.

[^102]: `pcAlgo` and `fciAlgo` objects have
    [`plot()`](https://caugi.org/dev/reference/plot.md) S4 methods that
    delegate to `Rgraphviz`. `iplotPC()` delegates to `igraph`’s plot.
    `plotSG()` also requires `Rgraphviz`. There are no native layout
    algorithms in pcalg itself.

[^103]: `graphLayout(x, method = "spring")` implements a single
    spring/force-directed layout algorithm. The documentation explicitly
    states `"currently, only 'spring' is supported"`.

[^104]: The `bn` class stores arcs as a 2-column character matrix
    (`$arcs`) plus per-node children/parents lists in `$nodes`. The
    exported `alst()` function exposes an adjacency-list view. This is
    effectively sparse but is not a formal CSR/CSC or `Matrix`-class
    sparse type.

[^105]: A rudimentary `plot.bn()` S3 method draws nodes in a circle with
    no external dependencies, but the package documentation describes it
    as “a last resort for when Rgraphviz is not available.” The
    full-featured `graphviz.plot()` requires the Bioconductor
    `Rgraphviz` package.

[^106]: All graph layout computation is delegated to Graphviz via the
    `Rgraphviz` package (algorithms: dot, neato, twopi, circo, fdp);
    bnlearn implements no native layout algorithms.

[^107]: `plotGraph()` and `drawGraph()` delegate layout to igraph
    (default `layout.auto`), so any igraph layout function can be passed
    via the `layout` argument. The layouts are not implemented natively
    in ggm.

[^108]: Edge data can be stored in adjacency-list format (`adjList`
    class), which is a sparse representation. However, the package also
    supports dense adjacency matrices (`adjMatrix` class) and does not
    commit to a single internal format. No CSR/CSC or other documented
    sparse-matrix format is enforced.

[^109]: `plot.mixedgraph()` is an S3 method but it delegates entirely to
    the `pcalg` / `Rgraphviz` stack by converting the graph to a
    `fciAlgo` object. Layout is determined by Rgraphviz; no layout
    algorithms are implemented within MixedGraphs. The function is
    listed under `Suggests` (`pcalg`, `Rgraphviz`), so plotting is
    unavailable without those packages.

[^110]: The package exports a `%G%` infix operator that automatically
    converts a `mixedgraph` into the format expected by the
    right-hand-side function (from another package), enabling
    cross-package chaining. This is a narrow inter-package bridge
    operator rather than a full tidyverse-style verb chain that takes
    and returns `mixedgraph` objects.

[^111]: NetworkX stores graphs internally as a dict-of-dicts-of-dicts
    (adjacency dictionary), which is *effectively* sparse for large,
    sparse graphs (only present edges are stored), but this is not a
    CSR/CSC/COO sparse matrix—it is a plain Python dictionary structure.
    Conversion to SciPy sparse arrays is available via
    `to_scipy_sparse_array`.

[^112]: NetworkX includes `nx.draw()`, `nx.draw_networkx()`, and related
    functions that render graphs via Matplotlib
    (`networkx.drawing.nx_pylab`). Matplotlib is an optional dependency
    — NetworkX raises `ImportError` when it is absent. The drawing
    module is described in the documentation as basic/non-primary
    functionality.

[^113]: `DAG.to_graphviz()` returns a pygraphviz `AGraph` (requires the
    optional `pygraphviz` dependency); `DAG.to_daft()` returns a `daft`
    PGM object. Neither is a
    [`plot()`](https://caugi.org/dev/reference/plot.md) method that
    renders to screen directly. No built-in `matplotlib`-based
    [`plot()`](https://caugi.org/dev/reference/plot.md) is present.

[^114]: Layout computation is delegated to pygraphviz (via
    `to_graphviz()`) or to NetworkX spring-layout variants (inside
    `to_daft()`). pgmpy does not implement its own layout algorithms.

[^115]: Tetrad’s GUI module (`tetrad-gui`) provides rich interactive
    graph visualization, but this is a Swing-based desktop application
    component, not a programmatic plotting API. From the library
    (`tetrad-lib`), `LayoutUtil` computes node coordinates
    (Kamada-Kawai, Fruchterman-Reingold, circle, square, causal-order
    layouts) and `GraphSaveLoadUtils.graphToDot()` exports to Graphviz
    for external rendering. There is no `plot(graph)` method in the
    library that renders directly to a file or screen without the GUI.
