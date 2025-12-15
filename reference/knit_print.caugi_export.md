# Knit Print Method for caugi_export

Renders caugi export objects as code blocks in Quarto/R Markdown
documents. This method is automatically invoked when an export object is
the last expression in a code chunk.

## Arguments

- x:

  A `caugi_export` object.

- ...:

  Additional arguments (currently unused).

## Value

A `knit_asis` object for rendering by knitr.

## Details

This method enables seamless rendering of caugi graphs in Quarto and R
Markdown. The code block type is determined by the export format. Simply
use an export function (e.g., `to_dot(cg)`) as the last expression in a
chunk with `output: asis`:

    #| output: asis
    to_dot(cg)

## See also

Other export: [`caugi_dot()`](https://caugi.org/reference/caugi_dot.md),
[`caugi_export()`](https://caugi.org/reference/caugi_export.md),
[`export-classes`](https://caugi.org/reference/export-classes.md),
[`format-dot`](https://caugi.org/reference/format-dot.md),
[`to_dot()`](https://caugi.org/reference/to_dot.md),
[`write_dot()`](https://caugi.org/reference/write_dot.md)
