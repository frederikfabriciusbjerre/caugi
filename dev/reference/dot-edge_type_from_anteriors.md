# Infer edge type from anterior relationships

Given two adjacent nodes, infers the edge type (directed, bidirected, or
undirected) based on whether each node is in the anterior of the other
combined with the conditioning set.

## Usage

``` r
.edge_type_from_anteriors(node_a, node_b, cond_vars, anteriors_list)
```

## Arguments

- node_a:

  First node name.

- node_b:

  Second node name.

- cond_vars:

  Conditioning variables.

- anteriors_list:

  Pre-computed list of anteriors for all nodes.

## Value

A single-row `data.table` with `from`, `edge`, `to` columns.
