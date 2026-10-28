# Format a numeric DSL node as a name

Like [`as.character()`](https://rdrr.io/r/base/character.html) (15
significant digits), but never in scientific notation, so `100000`
becomes `"100000"`, not `"1e+05"`.

## Usage

``` r
.dsl_number(x)
```

## Arguments

- x:

  A single number.

## Value

A string.
