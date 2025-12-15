# S7 Base Class for Caugi Exports

A base class for all caugi export formats. Provides common structure and
behavior for different export formats (DOT, GraphML, etc.).

## Usage

``` r
caugi_export(content = character(0), format = character(0))
```

## Arguments

- content:

  A character string containing the exported graph.

- format:

  A character string indicating the export format.

## See also

Other export: [`caugi_dot()`](https://caugi.org/reference/caugi_dot.md),
[`export-classes`](https://caugi.org/reference/export-classes.md),
[`format-dot`](https://caugi.org/reference/format-dot.md),
[`knit_print.caugi_export`](https://caugi.org/reference/knit_print.caugi_export.md),
[`to_dot()`](https://caugi.org/reference/to_dot.md),
[`write_dot()`](https://caugi.org/reference/write_dot.md)
