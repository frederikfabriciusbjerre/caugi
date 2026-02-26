# Package index

## The caugi object

- [`caugi()`](https://caugi.org/dev/reference/caugi.md) :

  Create a `caugi` from edge expressions.

## Queries

- [`ancestors()`](https://caugi.org/dev/reference/ancestors.md) :

  Get ancestors of nodes in a `caugi`

- [`anteriors()`](https://caugi.org/dev/reference/anteriors.md) :

  Get anteriors of nodes in a `caugi`

- [`children()`](https://caugi.org/dev/reference/children.md) :

  Get children of nodes in a `caugi`

- [`descendants()`](https://caugi.org/dev/reference/descendants.md) :

  Get descendants of nodes in a `caugi`

- [`districts()`](https://caugi.org/dev/reference/districts.md) : Get
  districts (c-components) of an ADMG or AG

- [`edge_types()`](https://caugi.org/dev/reference/edge_types.md) :

  Get the edge types of a `caugi`.

- [`edges()`](https://caugi.org/dev/reference/edges.md)
  [`E()`](https://caugi.org/dev/reference/edges.md) :

  Get edges of a `caugi`.

- [`exogenous()`](https://caugi.org/dev/reference/exogenous.md) :

  Get all exogenous nodes in a `caugi`

- [`is_acyclic()`](https://caugi.org/dev/reference/is_acyclic.md) :

  Is the `caugi` acyclic?

- [`is_admg()`](https://caugi.org/dev/reference/is_admg.md) :

  Is the `caugi` graph an ADMG?

- [`is_ag()`](https://caugi.org/dev/reference/is_ag.md) :

  Is the `caugi` graph an AG?

- [`is_caugi()`](https://caugi.org/dev/reference/is_caugi.md) :

  Is it a `caugi` graph?

- [`is_cpdag()`](https://caugi.org/dev/reference/is_cpdag.md) :

  Is the `caugi` graph a CPDAG?

- [`is_dag()`](https://caugi.org/dev/reference/is_dag.md) :

  Is the `caugi` graph a DAG?

- [`is_empty_caugi()`](https://caugi.org/dev/reference/is_empty_caugi.md)
  :

  Is the `caugi` graph empty?

- [`is_mag()`](https://caugi.org/dev/reference/is_mag.md) :

  Is the `caugi` graph a MAG?

- [`is_pdag()`](https://caugi.org/dev/reference/is_pdag.md) :

  Is the `caugi` graph a PDAG?

- [`is_simple()`](https://caugi.org/dev/reference/is_simple.md) :

  Is the `caugi` graph simple?

- [`is_ug()`](https://caugi.org/dev/reference/is_ug.md) :

  Is the `caugi` graph an UG?

- [`m_separated()`](https://caugi.org/dev/reference/m_separated.md) :
  M-separation test for AGs and ADMGs

- [`markov_blanket()`](https://caugi.org/dev/reference/markov_blanket.md)
  :

  Get Markov blanket of nodes in a `caugi`

- [`neighbors()`](https://caugi.org/dev/reference/neighbors.md)
  [`neighbours()`](https://caugi.org/dev/reference/neighbors.md) :

  Get neighbors of nodes in a `caugi`

- [`nodes()`](https://caugi.org/dev/reference/nodes.md)
  [`vertices()`](https://caugi.org/dev/reference/nodes.md)
  [`V()`](https://caugi.org/dev/reference/nodes.md) :

  Get nodes or edges of a `caugi`

- [`parents()`](https://caugi.org/dev/reference/parents.md) :

  Get parents of nodes in a `caugi`

- [`posteriors()`](https://caugi.org/dev/reference/posteriors.md) :

  Get posteriors of nodes in a `caugi`

- [`same_nodes()`](https://caugi.org/dev/reference/same_nodes.md) : Same
  nodes?

- [`spouses()`](https://caugi.org/dev/reference/spouses.md) : Get
  spouses (bidirected neighbors) of nodes in an ADMG

- [`subgraph()`](https://caugi.org/dev/reference/subgraph.md) : Get the
  induced subgraph

- [`topological_sort()`](https://caugi.org/dev/reference/topological_sort.md)
  : Get a topological ordering of a DAG

## Verbs

- [`build()`](https://caugi.org/dev/reference/build.md) :

  Build the `caugi` graph

- [`add_edges()`](https://caugi.org/dev/reference/caugi_verbs.md)
  [`remove_edges()`](https://caugi.org/dev/reference/caugi_verbs.md)
  [`set_edges()`](https://caugi.org/dev/reference/caugi_verbs.md)
  [`add_nodes()`](https://caugi.org/dev/reference/caugi_verbs.md)
  [`remove_nodes()`](https://caugi.org/dev/reference/caugi_verbs.md) :

  Manipulate nodes and edges of a `caugi`

## Adjustment and d-separation

- [`adjustment_set()`](https://caugi.org/dev/reference/adjustment_set.md)
  : Compute an adjustment set
- [`all_adjustment_sets_admg()`](https://caugi.org/dev/reference/all_adjustment_sets_admg.md)
  : Get all valid adjustment sets in an ADMG
- [`all_backdoor_sets()`](https://caugi.org/dev/reference/all_backdoor_sets.md)
  : Get all backdoor sets up to a certain size.
- [`d_separated()`](https://caugi.org/dev/reference/d_separated.md) :
  Are X and Y d-separated given Z?
- [`is_valid_adjustment_admg()`](https://caugi.org/dev/reference/is_valid_adjustment_admg.md)
  : Is a set a valid adjustment set in an ADMG?
- [`is_valid_backdoor()`](https://caugi.org/dev/reference/is_valid_backdoor.md)
  : Is a backdoor set valid?
- [`minimal_d_separator()`](https://caugi.org/dev/reference/minimal_d_separator.md)
  : Compute a minimal d-separator

## Simulation

- [`generate_graph()`](https://caugi.org/dev/reference/generate_graph.md)
  :

  Generate a `caugi` using Erdős-Rényi.

- [`simulate_data()`](https://caugi.org/dev/reference/simulate_data.md)
  :

  Simulate data from a `caugi` DAG.

## Metrics

- [`aid()`](https://caugi.org/dev/reference/aid.md) : Adjustment
  Identification Distance
- [`hd()`](https://caugi.org/dev/reference/hd.md) : Hamming Distance
- [`shd()`](https://caugi.org/dev/reference/shd.md) : Structural Hamming
  Distance

## Edge Registry

- [`register_caugi_edge()`](https://caugi.org/dev/reference/register_caugi_edge.md)
  : Register a new edge type in the global registry.

- [`caugi_registry()`](https://caugi.org/dev/reference/registry.md)
  [`reset_caugi_registry()`](https://caugi.org/dev/reference/registry.md)
  [`seal_caugi_registry()`](https://caugi.org/dev/reference/registry.md)
  :

  `caugi` edge registry

## Methods

- [`length`](https://caugi.org/dev/reference/length.md) :

  Length of a `caugi`

- [`print`](https://caugi.org/dev/reference/print.md) :

  Print a `caugi`

## Conversions

- [`as_adjacency()`](https://caugi.org/dev/reference/as_adjacency.md) :
  Convert a caugi to an adjacency matrix

- [`as_bnlearn()`](https://caugi.org/dev/reference/as_bnlearn.md) :
  Convert a caugi to a bnlearn network

- [`as_caugi()`](https://caugi.org/dev/reference/as_caugi.md) :

  Convert to a `caugi`

- [`as_dagitty()`](https://caugi.org/dev/reference/as_dagitty.md) :
  Convert a caugi to a dagitty graph

- [`as_igraph()`](https://caugi.org/dev/reference/as_igraph.md) :
  Convert a caugi to an igraph object

## Operations

- [`condition_marginalize()`](https://caugi.org/dev/reference/condition_marginalize.md)
  : Marginalize and/or condition on variables in an ancestral graph (AG)

- [`dag_from_pdag()`](https://caugi.org/dev/reference/dag_from_pdag.md)
  : Extend a PDAG to a DAG using the Dor-Tarsi Algorithm

- [`exogenize()`](https://caugi.org/dev/reference/exogenize.md) :
  Exogenize a graph

- [`latent_project()`](https://caugi.org/dev/reference/latent_project.md)
  : Project latent variables from a DAG to an ADMG

- [`moralize()`](https://caugi.org/dev/reference/moralize.md) : Moralize
  a DAG

- [`mutate_caugi()`](https://caugi.org/dev/reference/mutate_caugi.md) :

  Mutate `caugi` class

- [`skeleton()`](https://caugi.org/dev/reference/skeleton.md) : Get the
  skeleton of a graph

## Importing and Exporting to and from Other Formats

- [`caugi_deserialize()`](https://caugi.org/dev/reference/caugi_deserialize.md)
  : Deserialize caugi Graph from JSON String
- [`caugi_dot()`](https://caugi.org/dev/reference/caugi_dot.md) : S7
  Class for DOT Export
- [`caugi_export()`](https://caugi.org/dev/reference/caugi_export.md) :
  S7 Base Class for Caugi Exports
- [`caugi_graphml()`](https://caugi.org/dev/reference/caugi_graphml.md)
  : S7 Class for GraphML Export
- [`caugi_mermaid()`](https://caugi.org/dev/reference/caugi_mermaid.md)
  : S7 Class for Mermaid Export
- [`caugi_serialize()`](https://caugi.org/dev/reference/caugi_serialize.md)
  : Serialize caugi Graph to JSON String
- [`export-classes`](https://caugi.org/dev/reference/export-classes.md)
  : Export Format Classes
- [`format-caugi`](https://caugi.org/dev/reference/format-caugi.md) :
  Caugi Native Format Serialization
- [`format-dot`](https://caugi.org/dev/reference/format-dot.md) : DOT
  Format Export and Import
- [`format-graphml`](https://caugi.org/dev/reference/format-graphml.md)
  : GraphML Format Export and Import
- [`format-mermaid`](https://caugi.org/dev/reference/format-mermaid.md)
  : Mermaid Format Export
- [`knit_print.caugi_export`](https://caugi.org/dev/reference/knit_print.caugi_export.md)
  : Knit Print Method for caugi_export
- [`read_caugi()`](https://caugi.org/dev/reference/read_caugi.md) : Read
  caugi Graph from File
- [`read_graphml()`](https://caugi.org/dev/reference/read_graphml.md) :
  Read GraphML File to caugi Graph
- [`to_dot()`](https://caugi.org/dev/reference/to_dot.md) : Export caugi
  Graph to DOT Format
- [`to_graphml()`](https://caugi.org/dev/reference/to_graphml.md) :
  Export caugi Graph to GraphML Format
- [`to_mermaid()`](https://caugi.org/dev/reference/to_mermaid.md) :
  Export caugi Graph to Mermaid Format
- [`write_caugi()`](https://caugi.org/dev/reference/write_caugi.md) :
  Write caugi Graph to File
- [`write_dot()`](https://caugi.org/dev/reference/write_dot.md) : Write
  caugi Graph to DOT File
- [`write_graphml()`](https://caugi.org/dev/reference/write_graphml.md)
  : Write caugi Graph to GraphML File
- [`write_mermaid()`](https://caugi.org/dev/reference/write_mermaid.md)
  : Write caugi Graph to Mermaid File

## Plotting

- [`add-caugi_plot-caugi_plot`](https://caugi.org/dev/reference/add-caugi_plot-caugi_plot.md)
  [`pipe-caugi_plot-caugi_plot`](https://caugi.org/dev/reference/add-caugi_plot-caugi_plot.md)
  : Compose Plots Horizontally
- [`caugi_layout()`](https://caugi.org/dev/reference/caugi_layout.md) :
  Compute Graph Layout
- [`caugi_layout_bipartite()`](https://caugi.org/dev/reference/caugi_layout_bipartite.md)
  : Bipartite Graph Layout
- [`caugi_layout_fruchterman_reingold()`](https://caugi.org/dev/reference/caugi_layout_fruchterman_reingold.md)
  : Fruchterman-Reingold Force-Directed Layout
- [`caugi_layout_kamada_kawai()`](https://caugi.org/dev/reference/caugi_layout_kamada_kawai.md)
  : Kamada-Kawai Stress Minimization Layout
- [`caugi_layout_sugiyama()`](https://caugi.org/dev/reference/caugi_layout_sugiyama.md)
  : Sugiyama Hierarchical Layout
- [`caugi_layout_tiered()`](https://caugi.org/dev/reference/caugi_layout_tiered.md)
  : Tiered Graph Layout
- [`caugi_plot()`](https://caugi.org/dev/reference/caugi_plot.md) : S7
  Class for caugi Plot
- [`divide-caugi_plot-caugi_plot`](https://caugi.org/dev/reference/divide-caugi_plot-caugi_plot.md)
  : Compose Plots Vertically
- [`plot`](https://caugi.org/dev/reference/plot.md) : Create a caugi
  Graph Plot Object

## Options

- [`caugi_default_options()`](https://caugi.org/dev/reference/caugi_default_options.md)
  : Default options for caugi
- [`caugi_options()`](https://caugi.org/dev/reference/caugi_options.md)
  : Get or set global options for caugi
