# Contributing to caugi

Thank you for your interest in contributing to `caugi`! This document provides guidelines and information to help you contribute effectively to the project.

## Table of Contents

- [Project Scope and Overview](#project-scope-and-overview)
- [Getting Started](#getting-started)
- [Development Environment Setup](#development-environment-setup)
- [Architecture](#architecture)
- [Code Style Guidelines](#code-style-guidelines)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Reporting Issues](#reporting-issues)

## Project Scope and Overview

`caugi` (pronounced "corgi") is a **Causal Graph Interface** package for R, providing a high-performance, tidy toolbox for building, coercing, and analyzing causal graphs. The package is designed to be:

- **Causality-first**: Focused on causal graph operations and algorithms
- **High-performance**: Leveraging Rust for performance-critical operations
- **Tidy**: Following tidyverse principles and conventions
- **Flexible**: Supporting multiple graph types and custom edge definitions

### Supported Graph Classes

Currently supported:
- `"UNKNOWN"` - Generic graphs
- `"DAG"` - Directed Acyclic Graphs
- `"PDAG"` - Partially Directed Acyclic Graphs
- `"UG"` - Undirected Graphs

Planned for future releases:
- `"PAG"` - Partial Ancestral Graphs
- `"MAG"` - Maximal Ancestral Graphs
- `"SWIG"` - Summary Graphs with Independent Errors
- `"ADMG"` - Acyclic Directed Mixed Graphs

### Key Features

- Fast querying of causal relationships (parents, ancestors, neighbors, etc.)
- Structural queries (acyclicity, CPDAG validation, etc.)
- Graph manipulation operations (add/remove edges and nodes)
- Graph metrics (Structural Hamming Distance, Adjustment Identification Distance)
- Custom edge type registration
- Lazy building for efficient batch operations

## Getting Started

### Prerequisites

To contribute to `caugi`, you'll need:

1. **R** (>= 4.2)
2. **Rust toolchain** (rustc >= 1.80.0 and Cargo)
3. **System dependencies**: xz

### Installing R Dependencies

```r
# Install devtools and related packages
install.packages(c("devtools", "testthat", "rextendr", "styler"))

# Install package dependencies
devtools::install_deps()
```

### Installing Rust

If you don't have Rust installed, get it from [rustup.rs](https://rustup.rs/):

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

## Development Environment Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/frederikfabriciusbjerre/caugi.git
   cd caugi
   ```

2. **Load the package in R**:
   ```r
   devtools::load_all()
   ```

3. **Build Rust code** (if needed):
   ```r
   rextendr::document()
   ```

The Rust compilation happens automatically via `rextendr` when you load or build the package.

## Architecture

`caugi` is built as a hybrid R/Rust codebase:

- **R Package**: Front-end API using S7 objects, following tidyverse principles
- **Rust Backend**: Core graph algorithms and data structures for performance
- **Graph Storage**: Compressed Sparse Row (CSR) format for efficient querying
- **Lazy Building**: Graph mutations are batched in R and built in Rust on demand

### Project Structure

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

### How It Works

1. **CSR Format**: Graphs are stored in Compressed Sparse Row format in Rust, which makes queries very fast but mutations more expensive.

2. **Lazy Building**: When you mutate a graph (e.g., add edges), the changes are stored in R but not immediately applied in Rust. The graph rebuilds itself in Rust when you query it, or you can force a rebuild with `build(cg)`.

3. **R + Rust Integration**: The `extendr` framework handles the communication between R and Rust, with automatic type conversions and memory management.

## Code Style Guidelines

### R Code

- **Follow the tidyverse style guide**: Use `styler::style_pkg()` before committing
- **Naming conventions**:
  - Functions: `snake_case`
  - S7 classes: `snake_case`
  - Internal functions: prefix with `.` (e.g., `.internal_function`)
- **Documentation**: All exported functions must have comprehensive Roxygen2 documentation:
  - `@title` - Brief title
  - `@description` - Detailed description
  - `@param` - Parameter descriptions
  - `@returns` - Return value description
  - `@examples` - Working examples

Example:
```r
#' @title Get parent nodes
#' @description Returns all parent nodes of the specified node(s) in the graph.
#' @param graph A caugi graph object
#' @param nodes Character vector of node names
#' @returns A character vector of parent node names
#' @examples
#' cg <- caugi(A %-->% B, B %-->% C)
#' parents(cg, "C")
#' @export
parents <- function(graph, nodes) {
  # implementation
}
```

### Rust Code

- **Follow Rust standard style**: Run `cargo fmt` in `src/rust/` before committing
- **Documentation**: Use Rust doc comments (`///`) for public functions and modules
- **Performance-focused**: Prioritize performance and memory efficiency
- **Error handling**: Use `Result` types appropriately and provide meaningful error messages
- **Extendr integration**: Functions exposed to R should use `#[extendr]` macros

Example:
```rust
/// Computes the parents of the given nodes in the graph.
///
/// # Arguments
/// * `node_ids` - Vector of node indices
///
/// # Returns
/// A vector of parent node indices
#[extendr]
pub fn get_parents(node_ids: Vec<usize>) -> Vec<usize> {
    // implementation
}
```

## Testing

### Running Tests

```r
# Run all tests
devtools::test()

# Run tests for a specific file
testthat::test_file("tests/testthat/test-queries.R")

# Run package check (includes tests, examples, documentation)
devtools::check()
```

### Writing Tests

- **Test file naming**: `test-<feature>.R` (e.g., `test-queries.R`)
- **Use testthat**: Follow existing patterns with `test_that()` blocks
- **Test edge cases**: Consider empty graphs, single nodes, and complex structures
- **Test both R and Rust paths**: Ensure lazy building works correctly

Example test structure:
```r
test_that("parents() returns correct parents", {
  cg <- caugi(A %-->% B, C %-->% B, class = "DAG")
  
  result <- parents(cg, "B")
  expect_equal(sort(result), c("A", "C"))
  
  # Test with empty result
  result_empty <- parents(cg, "A")
  expect_equal(length(result_empty), 0)
})
```

### Important Testing Considerations

1. **Lazy building**: Remember that graph mutations are batched. Test both before and after explicit `build()` calls if relevant.
2. **Graph class invariants**: When testing graph classes, ensure that operations maintain the class invariants (e.g., DAGs remain acyclic).
3. **Edge registry**: If modifying the edge registry system, test thoroughly including edge cases.

## Submitting Changes

### Before Submitting a Pull Request

1. **Style your code**:
   ```r
   # Style R code
   styler::style_pkg()
   ```
   ```bash
   # Style Rust code (run from src/rust/)
   cargo fmt
   ```

2. **Run tests**:
   ```r
   devtools::test()
   ```

3. **Check the package**:
   ```r
   devtools::check()
   ```
   Ensure there are no errors or warnings.

4. **Update documentation** if you've added or modified exported functions:
   ```r
   devtools::document()
   ```

5. **Write tests** for new features or bug fixes.

### Pull Request Guidelines

- **Create focused PRs**: Each PR should address a single feature, bug fix, or improvement
- **Write clear commit messages**: Use descriptive commit messages that explain what and why
- **Reference issues**: If your PR addresses an issue, reference it in the PR description (e.g., "Fixes #123")
- **Update documentation**: Include documentation updates for user-facing changes
- **Add tests**: New features should include tests
- **Maintain backward compatibility**: Avoid breaking changes to the public API when possible

### Code Review Process

All contributions go through code review. Be prepared to:
- Respond to feedback and make requested changes
- Discuss design decisions and implementation approaches
- Iterate on your implementation based on maintainer guidance

## Reporting Issues

Found a bug or have a feature request? Please [open an issue](https://github.com/frederikfabriciusbjerre/caugi/issues) on GitHub.

### Bug Reports

When reporting a bug, please include:
- A clear, descriptive title
- A minimal reproducible example
- Your R version and sessionInfo()
- Your operating system
- Expected vs. actual behavior

Example:
```r
# Minimal reproducible example
library(caugi)

cg <- caugi(A %-->% B, class = "DAG")
# Expected: should return "B"
# Actual: returns error
result <- children(cg, "A")

# Session info
sessionInfo()
```

### Feature Requests

When requesting a feature:
- Describe the use case and motivation
- Provide examples of how the feature would be used
- Discuss any alternative approaches you've considered

## Code of Conduct

This project follows a standard code of conduct. Please be respectful and constructive in all interactions with other contributors and maintainers.

## Additional Resources

- [Package documentation](https://frederikfabriciusbjerre.github.io/caugi/)
- [Performance vignette](https://frederikfabriciusbjerre.github.io/caugi/articles/performance.html)
- [Issue tracker](https://github.com/frederikfabriciusbjerre/caugi/issues)
- [extendr documentation](https://extendr.github.io/)

## Questions?

If you have questions about contributing, feel free to:
- Open an issue for discussion
- Ask in your pull request
- Contact the maintainers

Thank you for contributing to `caugi`! 🐶
