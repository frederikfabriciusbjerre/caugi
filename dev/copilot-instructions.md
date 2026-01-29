# Copilot Instructions for caugi

## Repository Overview

`caugi` (pronounced “corgi”) is a **Causal Graph Interface** package for
R, providing a high-performance, tidy toolbox for building, coercing,
and analyzing causal graphs. The package is built as a hybrid R/Rust
codebase, leveraging Rust for performance-critical operations and R for
the user-facing API.

### Architecture

- **R Package**: Front-end API using S7 objects, tidyverse principles
- **Rust Backend**: Core graph algorithms implemented in Rust using the
  `extendr` framework
- **Graph Storage**: Compressed Sparse Row (CSR) format for efficient
  querying
- **Lazy Building**: Graph mutations are batched in R and built in Rust
  on demand

## Code Style Guidelines

### R Code

- **Follow tidyverse style guide**: Run `air format .` to format all R
  code before committing (configured via `air.toml`). Use
  `air format . --check` to check without modifying files.
- **Roxygen2 documentation**: All exported functions must have
  comprehensive documentation with `@title`, `@description`, `@param`,
  `@returns`, and `@examples`
- **Naming conventions**:
  - Functions: `snake_case`
  - S7 classes: `snake_case`
  - Internal functions: prefix with `.` (e.g., `.internal_function`)

### Rust Code

- **Follow Rust standard style**: Run `cargo fmt` before committing Rust
  code
- **Documentation**: Use Rust doc comments (`///`) for public functions
  and modules
- **Performance-focused**: Prioritize performance and memory efficiency
  in Rust code
- **Error handling**: Use `Result` types appropriately and provide
  meaningful error messages

## Project Structure

    caugi/
    ├── R/                      # R source files
    │   ├── caugi.R            # Main caugi object constructor
    │   ├── edge_operators.R   # Edge operator definitions
    │   ├── queries.R          # Graph query functions
    │   ├── metrics.R          # Graph metrics (SHD, AID)
    │   ├── adjustment.R       # Adjustment set functions
    │   ├── DSL-parser.R       # DSL parsing logic
    │   ├── format-dot.R       # DOT format output
    │   ├── format-mermaid.R   # Mermaid format output
    │   ├── simulation.R       # Graph simulation
    │   ├── verbs.R            # Tidyverse-style verbs
    │   ├── operations.R       # Graph operations
    │   ├── as_caugi.R         # Coercion to caugi
    │   ├── caugi_to.R         # Coercion from caugi
    │   └── ...
    ├── src/
    │   ├── rust/              # Rust source code
    │   │   ├── src/
    │   │   │   ├── lib.rs     # Main library and extendr bindings
    │   │   │   ├── edges/     # Edge type definitions
    │   │   │   └── graph/     # Graph data structures and algorithms
    │   │   │       ├── alg/   # Core graph algorithms
    │   │   │       ├── dag/   # DAG-specific functionality
    │   │   │       ├── pdag/  # PDAG-specific functionality
    │   │   │       ├── admg/  # ADMG-specific functionality
    │   │   │       └── layout/ # Graph layout algorithms (Sugiyama, force-directed, etc.)
    │   │   └── Cargo.toml
    │   └── entrypoint.c       # C entrypoint for R
    ├── tests/
    │   └── testthat/          # Test files (test-*.R)
    ├── man/                   # Generated documentation
    └── vignettes/             # Package vignettes

## Development Workflow

### Building and Testing

1.  **Build R package**: Use
    [`devtools::load_all()`](https://devtools.r-lib.org/reference/load_all.html)
    or standard R CMD build
2.  **Build Rust**: Rust compilation happens automatically via
    `rextendr`
3.  **Run tests**:
    [`devtools::test()`](https://devtools.r-lib.org/reference/test.html)
    or
    [`testthat::test_local()`](https://testthat.r-lib.org/reference/test_package.html)
4.  **Check package**:
    [`devtools::check()`](https://devtools.r-lib.org/reference/check.html)
    runs R CMD check
5.  **Code coverage**: Monitored via codecov
6.  **Build documentation site**:
    [`pkgdown::build_site()`](https://pkgdown.r-lib.org/reference/build_site.html)
    builds the package website configured in `_pkgdown.yml`

### Testing Requirements

- **Write tests for new features**: All new functions should have
  corresponding tests in `tests/testthat/`
- **Test file naming**: `test-<feature>.R` (e.g., `test-queries.R`)
- **Use testthat**: Follow existing patterns with `test_that()` blocks
- **Test edge cases**: Consider empty graphs, single nodes, and complex
  graph structures
- **Test both R and Rust paths**: Ensure lazy building works correctly

### Making Changes

1.  **Minimal changes**: Make the smallest possible changes to
    accomplish the goal
2.  **Lazy building**: Remember that graph mutations are batched - test
    both before and after explicit
    [`build()`](https://caugi.org/dev/reference/build.md) calls
3.  **Edge registry**: Be careful when modifying the edge registry
    system
4.  **Backward compatibility**: Maintain API compatibility when possible
5.  **Update NEWS.md**: Add entries to `NEWS.md` for user-facing changes
    under the appropriate section:
    - **New Features**: New functions, methods, or capabilities
    - **Improvements**: Enhancements to existing functionality,
      performance, or documentation
    - **Bug Fixes**: Corrections to existing behavior
    - Use bullet points starting with `*` and include function names in
      backticks

## Special Considerations

### R + Rust Integration

- **extendr framework**: All Rust functions exposed to R use
  `#[extendr]` macros
- **Memory management**: Rust objects are wrapped in external pointers;
  be careful with lifetimes
- **Type conversions**: extendr handles automatic conversions between R
  and Rust types
- **Build system**: Uses `configure` scripts for cross-platform
  compilation

### Graph Classes

- Supported: `"UNKNOWN"`, `"DAG"`, `"PDAG"`, `"ADMG"`, `"UG"`
- Planned: `"PAG"`, `"MAG"`, `"SWIG"`
- Always validate graph class invariants when adding new graph types

### Performance

- **Query optimization**: The CSR format makes queries fast but
  mutations expensive
- **Lazy evaluation**: Leverage the lazy building pattern for batched
  operations
- **Benchmarking**: Use `bench` package for performance tests (see
  vignettes)

## Dependencies

### R Dependencies

- Core: `S7`, `data.table`, `fastmap`, `grid`, `stats`, `methods`
- Suggested: `testthat`, `devtools`, `knitr`, `rmarkdown`, `rextendr`,
  `bnlearn`, `dagitty`, `ggm`, `graph`, `gRbase`, `igraph`, `MASS`,
  `Matrix`

### Rust Dependencies

- `extendr-api = "0.8.1"` - R bindings
- `bitflags = "2.9.3"` - Bitflag operations
- `rust-sugiyama = "0.4.0"` - Sugiyama layout algorithm for graph
  visualization
- `fdg-sim = "0.9.1"` - Force-directed graph simulation for layout
- `serde = "1.0"` - Serialization framework
- `serde_json = "1.0"` - JSON serialization
- `quick-xml = "0.39"` - XML serialization
- `rustc-hash = "2.1"` - Fast hash functions
- `gadjid` (optional, default enabled) - For adjustment identification
  distance

### System Requirements

- Cargo (Rust package manager)
- rustc \>= 1.80.0 (as specified in DESCRIPTION)
- xz

**Note**: The Cargo.toml specifies `rust-version = '1.80'` and
`edition = '2021'`.

## Contribution Guidelines

For detailed contribution guidelines, see
[CONTRIBUTING.md](https://caugi.org/CONTRIBUTING.md) in the repository
root.

Quick reference:

1.  Follow the tidyverse style guide for R code
2.  Run `air format .` for R and `cargo fmt` for Rust before PRs
3.  Write tests for new features
4.  Update documentation (Roxygen2 for R)
5.  Update `NEWS.md` with user-facing changes
6.  Ensure
    [`devtools::check()`](https://devtools.r-lib.org/reference/check.html)
    passes without errors or warnings

## Common Patterns

### Creating a caugi object

``` r
cg <- caugi(
  A %-->% B + C,
  B %-->% D,
  C %-->% D,
  class = "DAG"
)
```

### Querying graphs

``` r
parents(cg, "D") # Get parents of node D
ancestors(cg, "D") # Get all ancestors
is_acyclic(cg) # Check if acyclic
```

### Plotting graphs

``` r
# Basic plotting with automatic layout selection
plot(cg)

# Compute layout coordinates explicitly
coords <- caugi_layout(cg, method = "sugiyama")

# Customize appearance
plot(
  cg,
  layout = "fruchterman-reingold",
  node_style = list(fill = "lightblue", padding = 3),
  edge_style = list(col = "darkgray", arrow_size = 4)
)
```

**Available layout methods:**

- `"auto"`: Automatically selects best layout (default)
- `"sugiyama"`: Hierarchical layout for DAGs (directed edges only)
- `"fruchterman-reingold"`: Fast force-directed layout (all edge types)
- `"kamada-kawai"`: High-quality stress minimization (all edge types)
- `"bipartite"`: Two-group layout with auto-detection or explicit
  partition
- `"tiered"`: Multi-tier layout with custom tier assignments

### Testing pattern

``` r
test_that("feature description", {
  cg <- caugi(A %-->% B)
  result <- some_function(cg)
  expect_equal(result, expected_value)
})
```

## Documentation

The package uses **pkgdown** to generate the documentation website at
[caugi.org](https://caugi.org/). The site structure is configured in
`_pkgdown.yml` and organizes functions by concept (queries, verbs,
adjustment, plotting, etc.).

- **Build site locally**:
  [`pkgdown::build_site()`](https://pkgdown.r-lib.org/reference/build_site.html)
- **Preview changes**: `pkgdown::build_site(preview = TRUE)`
- **Reference docs**: Auto-generated from Roxygen2 comments
- **Articles**: Vignettes from `vignettes/` directory

## Resources

- [Package documentation](https://caugi.org/)
- [Performance vignette](https://caugi.org/articles/performance.html)
- [Issue
  tracker](https://github.com/frederikfabriciusbjerre/caugi/issues)
