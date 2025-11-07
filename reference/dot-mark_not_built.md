# Mark a `caugi` as *not built*.

When a `caugi` is modified, it should be marked as not built. This
function sets the `built` attribute to `FALSE`. Thereby, the Rust
backend and the R frontend does not match, and at one point, the `caugi`
will need to be rebuild for it to be queried.

## Usage

``` r
.mark_not_built(cg)
```

## Arguments

- cg:

  A `caugi` object.

## Value

The same `caugi` object, but with the `built` attribute set to `FALSE`.
