#!/usr/bin/env python
"""Python benchmark runner for the caugi performance article.

Currently times pgmpy. NetworkX/causaldag deps are installed via
pyproject.toml but intentionally unused here - they slot in as additional
rows by adding methods to PACKAGE_OPS without changing the script structure.
"""

from __future__ import annotations

import csv
import json
import statistics
import time
from pathlib import Path
from typing import Callable

import networkx as nx
from pgmpy.base import DAG

FIXTURES_DIR = Path("fixtures")
RESULTS_DIR = Path("results")
RESULTS_DIR.mkdir(parents=True, exist_ok=True)

# Each cell runs warmup iterations (discarded), then enough timed iterations
# to reach at least MIN_TOTAL_S of total measured time, capped at MAX_ITERS.
WARMUP = 3
MIN_ITERS = 5
MAX_ITERS = 10_000
MIN_TOTAL_S = 0.05


def load_edges(path: Path) -> list[tuple[str, str]]:
    with path.open() as f:
        return [tuple(line.rstrip("\n").split("\t")) for line in f if line.strip()]


def build_pgmpy(edges: list[tuple[str, str]], n_nodes: int) -> DAG:
    d = DAG()
    d.add_nodes_from(f"V{i}" for i in range(1, n_nodes + 1))
    d.add_edges_from(edges)
    return d


def time_op(fn: Callable[[], object]) -> tuple[float, float, int]:
    """Run fn() with warmup + adaptive iteration count.

    Returns (median_ns, min_ns, n_iter).
    """
    for _ in range(WARMUP):
        fn()

    samples_ns: list[float] = []
    start_total = time.perf_counter()
    for _ in range(MAX_ITERS):
        t0 = time.perf_counter_ns()
        fn()
        t1 = time.perf_counter_ns()
        samples_ns.append(float(t1 - t0))
        if (
            len(samples_ns) >= MIN_ITERS
            and (time.perf_counter() - start_total) >= MIN_TOTAL_S
        ):
            break
    return (
        float(statistics.median(samples_ns)),
        float(min(samples_ns)),
        len(samples_ns),
    )


def _as_node_list(v: object) -> list:
    return [v] if isinstance(v, str) else list(v)


def is_skipped(skip_rules: list, pkg: str, op: str, fx: dict) -> bool:
    """Match against the declarative skip table emitted in spec.json."""
    for r in skip_rules:
        if r.get("package") not in (pkg, "*"):
            continue
        if r.get("operation") not in (op, "*"):
            continue
        if "n_min" in r and fx["n"] < r["n_min"]:
            continue
        if "n_max" in r and fx["n"] > r["n_max"]:
            continue
        if "fixture_id" in r and r["fixture_id"] != fx["id"]:
            continue
        return True
    return False


def make_pgmpy_ops(d: DAG, fx: dict) -> dict[str, Callable[[], object]]:
    v = fx["test_node"]
    sub = _as_node_list(fx["subgraph_nodes"])
    ops = {
        "parents": lambda: d.get_parents(v),
        "children": lambda: d.get_children(v),
        "ancestors": lambda: d.get_ancestors([v]),
        "descendants": lambda: nx.descendants(d, v),
        "markov_blanket": lambda: d.get_markov_blanket(v),
        # Force materialisation of the subgraph view (pgmpy/NetworkX returns
        # a SubDiGraph view; copying matches caugi's full-rebuild semantics).
        "subgraph": lambda: DAG(d.subgraph(sub).edges()),
    }
    if fx.get("dsep") is not None:
        x = fx["dsep"]["x"]
        y = fx["dsep"]["y"]
        z = set(_as_node_list(fx["dsep"]["z"]))
        ops["d_separated"] = lambda: not d.is_dconnected(x, y, observed=z)
    return ops


def main() -> None:
    spec = json.loads((FIXTURES_DIR / "spec.json").read_text())
    skip_rules = spec.get("skip", []) or []

    rows = []
    for fx in spec["fixtures"]:
        print(f"[bench_python] {fx['id']} (n={fx['n']}, edges={fx['n_edges']})")
        edges = load_edges(FIXTURES_DIR / fx["edges_file"])
        d = build_pgmpy(edges, fx["n"])

        for op_name, fn in make_pgmpy_ops(d, fx).items():
            if is_skipped(skip_rules, "pgmpy", op_name, fx):
                print(f"[bench_python]   skip pgmpy/{op_name}")
                continue
            median_ns, min_ns, n_iter = time_op(fn)
            rows.append(
                {
                    "language": "Python",
                    "package": "pgmpy",
                    "operation": op_name,
                    "fixture_id": fx["id"],
                    "n": fx["n"],
                    "p": fx["p"],
                    "n_edges": fx["n_edges"],
                    "median_ns": median_ns,
                    "min_ns": min_ns,
                    "total_time_ns": median_ns * n_iter,
                    "n_iter": n_iter,
                    "mem_alloc_bytes": "",
                }
            )

    out_path = RESULTS_DIR / "python.csv"
    with out_path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"[bench_python] wrote {len(rows)} rows to {out_path}")


if __name__ == "__main__":
    main()
