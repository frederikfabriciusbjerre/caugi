# Mutate `caugi` class

Mutate the `caugi` class from one graph class to another, if possible.
For example, convert a `DAG` to a `PDAG`, or a fully directed `caugi` of
class `UNKNOWN` to a `DAG`. Throws an error if not possible.

## Usage

``` r
mutate_caugi(cg, class)
```

## Arguments

- cg:

  A `caugi` object.

- class:

  A character string specifying the new class.

## Value

A `caugi` object of the specified class.

## Details

This function returns a copy of the object, and the original remains
unchanged.

## See also

Other operations:
[`condition_marginalize()`](https://caugi.org/dev/reference/condition_marginalize.md),
[`dag_from_pdag()`](https://caugi.org/dev/reference/dag_from_pdag.md),
[`exogenize()`](https://caugi.org/dev/reference/exogenize.md),
[`latent_project()`](https://caugi.org/dev/reference/latent_project.md),
[`moralize()`](https://caugi.org/dev/reference/moralize.md),
[`skeleton()`](https://caugi.org/dev/reference/skeleton.md)

## Examples

``` r
cg <- caugi(A %-->% B, class = "UNKNOWN")
cg_dag <- mutate_caugi(cg, "DAG")
```
