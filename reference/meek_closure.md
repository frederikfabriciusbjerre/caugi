# Apply Meek closure to a PDAG

Applies Meek's orientation rules (R1–R4) repeatedly to a PDAG until no
more orientations are implied.

## Usage

``` r
meek_closure(cg)
```

## Arguments

- cg:

  A `caugi` object. Must be PDAG-compatible.

## Value

A `caugi` object of class `"PDAG"` that is closed under Meek's rules.

## References

C. Meek (1995). Causal inference and causal explanation with background
knowledge. In *Proceedings of the Eleventh Conference on Uncertainty in
Artificial Intelligence (UAI-95)*, pp. 403–411. Morgan Kaufmann.

## See also

Other operations:
[`condition_marginalize()`](https://caugi.org/reference/condition_marginalize.md),
[`dag_from_pdag()`](https://caugi.org/reference/dag_from_pdag.md),
[`exogenize()`](https://caugi.org/reference/exogenize.md),
[`latent_project()`](https://caugi.org/reference/latent_project.md),
[`moralize()`](https://caugi.org/reference/moralize.md),
[`mutate_caugi()`](https://caugi.org/reference/mutate_caugi.md),
[`normalize_latent_structure()`](https://caugi.org/reference/normalize_latent_structure.md),
[`skeleton()`](https://caugi.org/reference/skeleton.md)

## Examples

``` r
pdag <- caugi(
  A %---% B,
  A %-->% C,
  C %-->% B,
  class = "PDAG"
)
mpdag <- meek_closure(pdag)
edges(mpdag)
#>      from   edge     to
#>    <char> <char> <char>
#> 1:      A    -->      B
#> 2:      A    -->      C
#> 3:      C    -->      B
```
