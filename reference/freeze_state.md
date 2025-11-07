# Internal: Freeze the state environment of a `caugi`

Internal functions to freeze and unfreeze the state environment of a
`caugi`, preventing further modifications. These functions are not
intended to be used directly by users.

## Usage

``` r
.freeze_state(e)

.unfreeze_state(e)
```

## Arguments

- e:

  The state environment to freeze/unfreeze.

## Value

The frozen/unfrozen environment.
