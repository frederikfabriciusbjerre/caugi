# Check if nodes are NOT m-separated for all conditioning subsets

Tests whether two nodes fail to be m-separated for every possible
conditioning set formed from `other_nodes` combined with `cond_vars`. If
they are never separated, they must be adjacent in the resulting graph.

## Usage

``` r
.not_m_separated_for_all_subsets(cg, node_a, node_b, other_nodes, cond_vars)
```

## Arguments

- cg:

  A `caugi` object.

- node_a:

  First node name.

- node_b:

  Second node name.

- other_nodes:

  Other remaining nodes to form conditioning sets from.

- cond_vars:

  Conditioning variables (always included in conditioning).

## Value

`TRUE` if nodes are not m-separated for any subset (i.e., adjacent).
