# caugi performance benchmarks

Cross-language benchmark harness for the **Performance** vignette at
`vignettes/performance.Rmd`. Inline `bench::mark()` calls in the vignette
have been replaced by precomputed results that this directory produces.

Comparators currently wired up:

  | Language | Library                                          |
  | -------- | ------------------------------------------------ |
  | R        | caugi, igraph, bnlearn, dagitty, ggm, pcalg      |
  | Python   | pgmpy (networkx, causaldag installed but unused) |
  | Java     | Tetrad (`io.github.cmu-phil:tetrad-lib`, version pinned in `build.gradle`) |

Adding a new comparator means appending rows to one of the per-language runners
--- the fixtures, schema, and aggregator stay the same.

## Prerequisites

Everything is provisioned by `devenv.nix` at the repo root. Enter the shell
once:

```sh
cd /path/to/caugi
devenv shell
```

This makes `R`, `uv`, `java`, `gradle`, and `task` available with the right
versions and pulls Python deps via `uv sync`. The Gradle Wrapper (`./gradlew`)
installs Gradle on first use.

## Running

All commands run from `tools/benchmark/`:

```sh
task fixtures   # generate shared graph fixtures + query specs
task r          # caugi/igraph/bnlearn/dagitty/ggm  -> results/r.csv
task python     # pgmpy                              -> results/python.csv
task tetrad     # Tetrad (Java)                      -> results/tetrad.csv
task aggregate  # merge into ../../vignettes/data/{benchmarks.rds, metadata.json}
task all        # everything above
task clean      # remove generated fixtures, results, and gradle caches
```

The aggregator writes to `vignettes/data/`; both files there are **tracked in
git**, so re-running `task all` produces the diff that updates the rendered
vignette.

## Layout

```
tools/benchmark/
├── Taskfile.yml            # orchestration
├── pyproject.toml          # uv-managed Python deps (networkx, pgmpy, causaldag)
├── uv.lock                 # uv lockfile
├── build.gradle            # Gradle build for the Java runner
├── settings.gradle         # Gradle root project name
├── gradlew, gradlew.bat    # Gradle Wrapper (do NOT remove)
├── gradle/wrapper/         # Wrapper jar + properties (tracked)
├── generate_fixtures.R     # produces fixtures/{id}.edges + fixtures/spec.json
├── bench_r.R               # R runner
├── bench_python.py         # Python runner
├── src/main/java/.../BenchTetrad.java
├── aggregate.R             # merges per-language CSVs
├── fixtures/               # generated, .gitignored
└── results/                # generated, .gitignored
```

### Interchange format

Every fixture is a tab-separated edge list (`from\tto`, one edge per line) plus
a `spec.json` describing per-fixture query parameters (test node, valid backdoor
adjustment set for d-separation, subgraph node selection). All runners read the
same files, so all packages are timed against the same graphs and the same
queries.

### Tuning the parameter grid

Edit `GRID` in `generate_fixtures.R`. The default grid covers
`n ∈ {100, 500, 1000}` and two density levels. Larger sizes (n = 5000, 10000)
work but pgmpy and dagitty become slow; if you scale up, consider restricting
which packages run those cells.

## When to re-run

Re-run `task all` whenever:

- caugi internals affecting query performance change (i.e. anything in
  `src/rust/` that touches the CSR build or query path);
- a comparator package is upgraded (bnlearn, dagitty, igraph, ggm, pcalg,
  pgmpy, Tetrad);
- the benchmark methodology changes (warmup counts, iteration policy, parameter
  grid).

The vignette displays the timestamp + host + versions captured in
`metadata.json` so readers can see how stale the numbers are.
