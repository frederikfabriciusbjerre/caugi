# Construct the PAG of a MAG's Markov equivalence class

Returns the Partial Ancestral Graph of the Markov equivalence class of a
maximal ancestral graph. It has the same skeleton as `cg`, since Markov
equivalent MAGs share their adjacencies, and each endpoint carries an
arrowhead or a tail when every member of the class has that mark there,
and a circle otherwise.

## Usage

``` r
mag_to_pag(cg)
```

## Arguments

- cg:

  A `caugi` object of class `"AG"` that is maximal.

## Value

A `caugi` object of class `"PAG"`.

## Details

Starts from the skeleton with every mark a circle, orients the
unshielded colliders of `cg`, and closes under Zhang's complete
orientation rules R1-R10. No separating sets are needed: Markov
equivalent MAGs share their unshielded colliders, and R4 reads collider
status off `cg`.

## References

Zhang, J. (2008). On the completeness of orientation rules for causal
discovery in the presence of latent confounders and selection bias.
*Artificial Intelligence*, 172(16-17), 1873-1896.

## See also

Other operations:
[`condition_marginalize()`](https://caugi.org/dev/reference/condition_marginalize.md),
[`count_dags()`](https://caugi.org/dev/reference/count_dags.md),
[`dag_from_pdag()`](https://caugi.org/dev/reference/dag_from_pdag.md),
[`dag_to_pag()`](https://caugi.org/dev/reference/dag_to_pag.md),
[`enumerate_dags()`](https://caugi.org/dev/reference/enumerate_dags.md),
[`exogenize()`](https://caugi.org/dev/reference/exogenize.md),
[`latent_project()`](https://caugi.org/dev/reference/latent_project.md),
[`meek_closure()`](https://caugi.org/dev/reference/meek_closure.md),
[`moralize()`](https://caugi.org/dev/reference/moralize.md),
[`mutate_caugi()`](https://caugi.org/dev/reference/mutate_caugi.md),
[`normalize_latent_structure()`](https://caugi.org/dev/reference/normalize_latent_structure.md),
[`pag_to_mag()`](https://caugi.org/dev/reference/pag_to_mag.md),
[`skeleton()`](https://caugi.org/dev/reference/skeleton.md)

## Examples

``` r
mag <- caugi(A %-->% B, C %-->% B, class = "AG")
mag_to_pag(mag) # A o-> B <-o C: both arrowheads are invariant
#> <caugi object; 3 nodes, 2 edges; simple: TRUE; session=0x5b8a91e88720>
#>   graph_class: PAG
#>   nodes: A, C, B
#>   edges: Ao->B, Co->B

# A chain has no invariant marks: it is equivalent to the reversed chain
# and to the fork.
mag_to_pag(caugi(A %-->% B, B %-->% C, class = "AG"))
#> <caugi object; 3 nodes, 2 edges; simple: TRUE; session=0x5b8a9215a7b0>
#>   graph_class: PAG
#>   nodes: A, B, C
#>   edges: Ao-oB, Bo-oC
```
