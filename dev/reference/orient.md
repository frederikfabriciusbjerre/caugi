# Apply and check background knowledge

`orient()` returns the tightest graph that agrees with both `cg` and
`bk`: an MPDAG, or a DAG if every edge is directed. It errors with class
`caugi_inconsistent` if no DAG agrees with both.

`holds()` checks each statement of `edges(bk, expand = TRUE)`: `TRUE` if
it holds in every DAG `cg` stands for, `FALSE` if in none, and `NA`
otherwise.

## Usage

``` r
orient(cg, bk)

holds(cg, bk)
```

## Arguments

- cg:

  A `caugi` with only `-->` and `---` edges, such as a DAG, PDAG, CPDAG
  or MPDAG.

- bk:

  Background knowledge, made by
  [`knowledge()`](https://caugi.org/dev/reference/knowledge.md).

## Value

`orient()`: a `caugi`. `holds()`: `edges(bk, expand = TRUE)` with a
logical column `holds`.

## References

E. Perkovic, M. Kalisch and M. H. Maathuis (2017). Interpreting and
using CPDAGs with background knowledge. In *Proceedings of the 33rd
Conference on Uncertainty in Artificial Intelligence (UAI-17)*.

## See also

Other knowledge:
[`is_knowledge()`](https://caugi.org/dev/reference/is_knowledge.md),
[`knowledge()`](https://caugi.org/dev/reference/knowledge.md),
[`required()`](https://caugi.org/dev/reference/required.md),
[`set_tiers()`](https://caugi.org/dev/reference/set_tiers.md),
[`tiers()`](https://caugi.org/dev/reference/tiers.md)

## Examples

``` r
cpdag <- caugi(A %---% B, B %---% C, class = "CPDAG")
bk <- knowledge(A %-->% B)
holds(cpdag, bk) # NA: some DAGs have A --> B, some B --> A
orient(cpdag, bk) # A --> B --> C
#> <caugi object; 3 nodes, 2 edges; simple: TRUE; session=0x5b62049f8140>
#>   graph_class: DAG
#>   nodes: A, B, C
#>   edges: A-->B, B-->C
```
