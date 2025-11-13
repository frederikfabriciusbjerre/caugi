# Copilot Instructions for caugi

## Repository Overview

`caugi` (pronounced "corgi") is a **Causal Graph Interface** package for R, providing a high-performance, tidy toolbox for building, coercing, and analyzing causal graphs. The package is built as a hybrid R/Rust codebase, leveraging Rust for performance-critical operations and R for the user-facing API.

### Architecture

- **R Package**: Front-end API using S7 objects, tidyverse principles
- **Rust Backend**: Core graph algorithms implemented in Rust using the `extendr` framework
- **Graph Storage**: Compressed Sparse Row (CSR) format for efficient querying
- **Lazy Building**: Graph mutations are batched in R and built in Rust on demand

## Code Style Guidelines

### R Code

- **Follow tidyverse style guide**: Use `styler::style_pkg()` before committing R code
- **Roxygen2 documentation**: All exported functions must have comprehensive documentation with `@title`, `@description`, `@param`, `@returns`, and `@examples`
- **Naming conventions**:
  - Functions: `snake_case`
  - S7 classes: `snake_case`
  - Internal functions: prefix with `.` (e.g., `.internal_function`)

### Rust Code

- **Follow Rust standard style**: Run `cargo fmt` before committing Rust code
- **Documentation**: Use Rust doc comments (`///`) for public functions and modules
- **Performance-focused**: Prioritize performance and memory efficiency in Rust code
- **Error handling**: Use `Result` types appropriately and provide meaningful error messages

## Project Structure

```
caugi/
├── R/                      # R source files
│   ├── caugi.R            # Main caugi object constructor
│   ├── edge_operators.R   # Edge operator definitions
│   ├── queries.R          # Graph query functions
│   ├── metrics.R          # Graph metrics (SHD, AID)
│   └── ...
├── src/
│   ├── rust/              # Rust source code
│   │   ├── src/
│   │   │   ├── lib.rs     # Main library and extendr bindings
│   │   │   ├── graph/     # Graph data structures and algorithms
│   │   │   └── edges/     # Edge type definitions
│   │   └── Cargo.toml
│   └── entrypoint.c       # C entrypoint for R
├── tests/
│   └── testthat/          # Test files (test-*.R)
├── man/                   # Generated documentation
└── vignettes/             # Package vignettes
```

## Development Workflow

### Building and Testing

1. **Build R package**: Use `devtools::load_all()` or standard R CMD build
2. **Build Rust**: Rust compilation happens automatically via `rextendr`
3. **Run tests**: `devtools::test()` or `testthat::test_local()`
4. **Check package**: `devtools::check()` runs R CMD check
5. **Code coverage**: Monitored via codecov

### Testing Requirements

- **Write tests for new features**: All new functions should have corresponding tests in `tests/testthat/`
- **Test file naming**: `test-<feature>.R` (e.g., `test-queries.R`)
- **Use testthat**: Follow existing patterns with `test_that()` blocks
- **Test edge cases**: Consider empty graphs, single nodes, and complex graph structures
- **Test both R and Rust paths**: Ensure lazy building works correctly

### Making Changes

1. **Minimal changes**: Make the smallest possible changes to accomplish the goal
2. **Lazy building**: Remember that graph mutations are batched - test both before and after explicit `build()` calls
3. **Edge registry**: Be careful when modifying the edge registry system
4. **Backward compatibility**: Maintain API compatibility when possible

## Special Considerations

### R + Rust Integration

- **extendr framework**: All Rust functions exposed to R use `#[extendr]` macros
- **Memory management**: Rust objects are wrapped in external pointers; be careful with lifetimes
- **Type conversions**: extendr handles automatic conversions between R and Rust types
- **Build system**: Uses `configure` scripts for cross-platform compilation

### Graph Classes

- Supported: `"UNKNOWN"`, `"DAG"`, `"PDAG"`
- Planned: `"PAG"`, `"MAG"`, `"SWIG"`, `"ADMG"`
- Always validate graph class invariants when adding new graph types

### Performance

- **Query optimization**: The CSR format makes queries fast but mutations expensive
- **Lazy evaluation**: Leverage the lazy building pattern for batched operations
- **Benchmarking**: Use `bench` package for performance tests (see vignettes)

## Dependencies

### R Dependencies
- Core: `S7`, `tibble`, `dplyr`, `data.table`, `fastmap`
- Suggested: `testthat`, `devtools`, `knitr`, `rmarkdown`, `rextendr`

### Rust Dependencies
- `extendr-api = "0.8.1"` - R bindings
- `bitflags = "2.9.3"` - Bitflag operations
- `gadjid` (optional) - For adjustment identification distance

### System Requirements
- Cargo (Rust package manager)
- rustc >= 1.85.0 (as specified in DESCRIPTION)

**Note**: The Cargo.toml specifies `rust-version = '1.85'` and `edition = '2024'`.

## Contribution Guidelines

For detailed contribution guidelines, see [CONTRIBUTING.md](/CONTRIBUTING.md) in the repository root.

Quick reference:
1. Follow the tidyverse style guide for R code
2. Run `styler::style_pkg()` for R and `cargo fmt` for Rust before PRs
3. Write tests for new features
4. Update documentation (Roxygen2 for R)
5. Ensure `devtools::check()` passes without errors or warnings

## Common Patterns

### Creating a caugi object
```r
cg <- caugi(
  A %-->% B + C,
  B %-->% D,
  C %-->% D,
  class = "DAG"
)
```

### Querying graphs
```r
parents(cg, "D")      # Get parents of node D
ancestors(cg, "D")    # Get all ancestors
is_acyclic(cg)        # Check if acyclic
```

### Testing pattern
```r
test_that("feature description", {
  cg <- caugi(A %-->% B)
  result <- some_function(cg)
  expect_equal(result, expected_value)
})
```

## Resources
- [Package documentation](https://frederikfabriciusbjerre.github.io/caugi/)
- [Performance vignette](https://frederikfabriciusbjerre.github.io/caugi/articles/performance.html)
- [Issue tracker](https://github.com/frederikfabriciusbjerre/caugi/issues)
