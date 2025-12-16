---
applyTo: "src/rust/src/graph/layout/**, R/plot.R, vignettes/visualization.Rmd, tests/testthat/test-*layout*.R"
---

# Layout Algorithm Instructions

## Architecture

**Hybrid R/Rust:**
- **Rust**: Computes coordinates → Vec<(f64, f64)> normalized to [0, 1]
- **R**: API wrapper, calls Rust via extendr, returns data.frame(name, x, y)

**Flow:** `caugi_layout()` dispatcher → `caugi_layout_*()` → Rust → data.frame

## Core Requirements

1. **Normalization**: All layouts return [0, 1] coordinates, largest dimension = 1.0
2. **Determinism**: Identical results on repeated calls
3. **API**: Each layout has `caugi_layout_*()` function accepting `...` for layout-specific args

## Existing Layouts

- **Sugiyama**: DAGs only, hierarchical (`sugiyama.rs`)
- **Fruchterman-Reingold**: General, fast, PCA rotated (`force_directed.rs`)
- **Kamada-Kawai**: Stress minimization, PCA rotated (`kamada_kawai.rs`)
- **Bipartite**: Two-group, auto-detects partition, rows/columns (`bipartite.rs`)

## Adding a New Layout

**1. Rust** (`src/rust/src/graph/layout/your_layout.rs`): Return `Vec<(f64, f64)>` in node order

**2. Register** (`mod.rs`): Add module, enum variant, FromStr impl, dispatch in `compute_layout()`

**3. R Function** (`R/plot.R`): `caugi_layout_your_layout()` → calls Rust → data.frame(name, x, y)

**4. Dispatcher** (`R/plot.R`): Add to `caugi_layout()` method choices and switch

**5. Tests** (`tests/testthat/`): Validate structure, [0,1] range, max=1.0, determinism, plot() integration

**6. Vignette** (`vignettes/visualization.Rmd`): Add section with examples and use cases

**7. NEWS.md**: Document new feature

## Testing Requirements

- ✓ Valid data.frame (name, x, y columns)
- ✓ Coordinates in [0, 1], at least one = 1.0
- ✓ Deterministic (repeated calls identical)
- ✓ Edge cases: empty graph, single node
- ✓ Works with plot() as string and function
- See `test-bipartite-layout.R` for examples

## Common Pitfalls

- Forgetting normalization in Rust
- Non-deterministic algorithms (seed if needed)
- Wrong coordinate order (must match node indices)
- Missing edge case handling
- Incomplete documentation
