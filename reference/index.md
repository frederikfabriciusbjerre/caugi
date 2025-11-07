# Package index

## The caugi object

- [`caugi()`](https://frederikfabriciusbjerre.github.io/caugi/reference/caugi.md)
  :

  Create a `caugi` from edge expressions.

## Queries

- [`ancestors()`](https://frederikfabriciusbjerre.github.io/caugi/reference/ancestors.md)
  :

  Get ancestors of nodes in a `caugi`

- [`children()`](https://frederikfabriciusbjerre.github.io/caugi/reference/children.md)
  :

  Get children of nodes in a `caugi`

- [`descendants()`](https://frederikfabriciusbjerre.github.io/caugi/reference/descendants.md)
  :

  Get descendants of nodes in a `caugi`

- [`edge_types()`](https://frederikfabriciusbjerre.github.io/caugi/reference/edge_types.md)
  :

  Get the edge types of a `caugi`.

- [`edges()`](https://frederikfabriciusbjerre.github.io/caugi/reference/edges.md)
  [`E()`](https://frederikfabriciusbjerre.github.io/caugi/reference/edges.md)
  :

  Get edges of a `caugi`.

- [`exogenous()`](https://frederikfabriciusbjerre.github.io/caugi/reference/exogenous.md)
  :

  Get all exogenous nodes in a `caugi`

- [`is_acyclic()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_acyclic.md)
  :

  Is the `caugi` acyclic?

- [`is_caugi()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_caugi.md)
  :

  Is it a `caugi` graph?

- [`is_cpdag()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_cpdag.md)
  :

  Is the `caugi` graph a CPDAG?

- [`is_dag()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_dag.md)
  :

  Is the `caugi` graph a DAG?

- [`is_empty_caugi()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_empty_caugi.md)
  :

  Is the `caugi` graph empty?

- [`is_pdag()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_pdag.md)
  :

  Is the `caugi` graph a PDAG?

- [`markov_blanket()`](https://frederikfabriciusbjerre.github.io/caugi/reference/markov_blanket.md)
  :

  Get Markov blanket of nodes in a `caugi`

- [`neighbors()`](https://frederikfabriciusbjerre.github.io/caugi/reference/neighbors.md)
  [`neighbours()`](https://frederikfabriciusbjerre.github.io/caugi/reference/neighbors.md)
  :

  Get neighbors of nodes in a `caugi`

- [`nodes()`](https://frederikfabriciusbjerre.github.io/caugi/reference/nodes.md)
  [`vertices()`](https://frederikfabriciusbjerre.github.io/caugi/reference/nodes.md)
  [`V()`](https://frederikfabriciusbjerre.github.io/caugi/reference/nodes.md)
  :

  Get nodes or edges of a `caugi`

- [`parents()`](https://frederikfabriciusbjerre.github.io/caugi/reference/parents.md)
  :

  Get parents of nodes in a `caugi`

- [`same_nodes()`](https://frederikfabriciusbjerre.github.io/caugi/reference/same_nodes.md)
  : Same nodes?

- [`subgraph()`](https://frederikfabriciusbjerre.github.io/caugi/reference/subgraph.md)
  : Get the induced subgraph

## Verbs

- [`build()`](https://frederikfabriciusbjerre.github.io/caugi/reference/build.md)
  : Build the graph now

- [`add_edges()`](https://frederikfabriciusbjerre.github.io/caugi/reference/caugi_verbs.md)
  [`remove_edges()`](https://frederikfabriciusbjerre.github.io/caugi/reference/caugi_verbs.md)
  [`set_edges()`](https://frederikfabriciusbjerre.github.io/caugi/reference/caugi_verbs.md)
  [`add_nodes()`](https://frederikfabriciusbjerre.github.io/caugi/reference/caugi_verbs.md)
  [`remove_nodes()`](https://frederikfabriciusbjerre.github.io/caugi/reference/caugi_verbs.md)
  :

  Manipulate nodes and edges of a `caugi`

## Adjustment and d-separation

- [`adjustment_set()`](https://frederikfabriciusbjerre.github.io/caugi/reference/adjustment_set.md)
  : Compute an adjustment set
- [`all_backdoor_sets()`](https://frederikfabriciusbjerre.github.io/caugi/reference/all_backdoor_sets.md)
  : Get all backdoor sets up to a certain size.
- [`d_separated()`](https://frederikfabriciusbjerre.github.io/caugi/reference/d_separated.md)
  : Are X and Y d-separated given Z?
- [`is_valid_backdoor()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_valid_backdoor.md)
  : Is a backdoor set valid?

## Simulation

- [`generate_graph()`](https://frederikfabriciusbjerre.github.io/caugi/reference/generate_graph.md)
  :

  Generate a `caugi` using Erdős-Rényi.

## Metrics

- [`aid()`](https://frederikfabriciusbjerre.github.io/caugi/reference/aid.md)
  : Adjustment Identification Distance
- [`hd()`](https://frederikfabriciusbjerre.github.io/caugi/reference/hd.md)
  : Hamming Distance
- [`shd()`](https://frederikfabriciusbjerre.github.io/caugi/reference/shd.md)
  : Structural Hamming Distance

## Edge Registry

- [`register_caugi_edge()`](https://frederikfabriciusbjerre.github.io/caugi/reference/register_caugi_edge.md)
  : Register a new edge type in the global registry.
- [`caugi_registry()`](https://frederikfabriciusbjerre.github.io/caugi/reference/registry.md)
  [`reset_caugi_registry()`](https://frederikfabriciusbjerre.github.io/caugi/reference/registry.md)
  [`seal_caugi_registry()`](https://frederikfabriciusbjerre.github.io/caugi/reference/registry.md)
  : caugi edge registry

## Methods

- [`length`](https://frederikfabriciusbjerre.github.io/caugi/reference/length.md)
  :

  Length of a `caugi`

- [`print`](https://frederikfabriciusbjerre.github.io/caugi/reference/print.md)
  :

  Print a `caugi`

## Conversions

- [`as_adjacency()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_adjacency.md)
  : Convert a caugi to an adjacency matrix

- [`as_bnlearn()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_bnlearn.md)
  : Convert a caugi to a bnlearn network

- [`as_caugi()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_caugi.md)
  :

  Convert to a `caugi`

- [`as_dagitty()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_dagitty.md)
  : Convert a caugi to a dagitty graph

- [`as_igraph()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_igraph.md)
  : Convert a caugi to an igraph object

## Operatoins

- [`moralize()`](https://frederikfabriciusbjerre.github.io/caugi/reference/moralize.md)
  : Moralize a DAG
- [`skeleton()`](https://frederikfabriciusbjerre.github.io/caugi/reference/skeleton.md)
  : Get the skeleton of a graph
