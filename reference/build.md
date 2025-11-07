# Build the graph now

If a `caugi` has been modified (nodes or edges added or removed), it is
marked as *not built*, i.e `cg@built = FALSE`. This function builds the
graph using the Rust backend and updates the internal pointer to the
graph. If the graph is already built, it is returned.

## Usage

``` r
build(cg, ...)
```

## Arguments

- cg:

  A `caugi` object.

- ...:

  Not used.

## Value

The built `caugi` object.

## See also

Other verbs:
[`caugi_verbs`](https://frederikfabriciusbjerre.github.io/caugi/reference/caugi_verbs.md)

## Examples

``` r
# initialize empty graph and build slowly
cg <- caugi(class = "PDAG")

cg <- cg |>
  add_nodes(c("A", "B", "C", "D", "E")) |> # A, B, C, D, E
  add_edges(A %-->% B %-->% C) |> # A --> B --> C, D, E
  set_edges(B %---% C) # A --> B --- C, D, E

cg <- remove_edges(cg, B %---% C) |> # A --> B, C, D, E
  remove_nodes(c("C", "D", "E")) # A --> B

# verbs do not build the Rust backend
cg@built # FALSE
#> [1] FALSE
build(cg)
#> # A tibble: 2 × 1
#>   name 
#>   <chr>
#> 1 A    
#> 2 B    
#> # A tibble: 1 × 3
#>   from  edge  to   
#>   <chr> <chr> <chr>
#> 1 A     -->   B    
cg@built # TRUE
#> [1] TRUE
```
