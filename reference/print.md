# Print a `caugi`

Print a `caugi`

## Arguments

- x:

  A `caugi` object.

- ...:

  Not used.

## Value

The input `caugi` object, invisibly.

## See also

Other caugi methods:
[`length()`](https://frederikfabriciusbjerre.github.io/caugi/reference/length.md)

## Examples

``` r
cg <- caugi(
  A %-->% B + C,
  nodes = LETTERS[1:5],
  class = "DAG"
)
print(cg)
#> # A tibble: 5 × 1
#>   name 
#>   <chr>
#> 1 A    
#> 2 B    
#> 3 C    
#> 4 D    
#> 5 E    
#> # A tibble: 2 × 3
#>   from  edge  to   
#>   <chr> <chr> <chr>
#> 1 A     -->   B    
#> 2 A     -->   C    
```
