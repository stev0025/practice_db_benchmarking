#!/usr/bin/env python3
"""
ClickHouse Performance Benchmarking Harness
Usage:
    python3 bench/harness.py
"""

import sys
import time
import math
import requests
from typing import List, Dict, Any

CH_URL = "http://localhost:8123"

QUERIES = [
    # Q1: Fast selective query (uses primary index CounterID prefix)
    ("Q1_selective", "SELECT count() FROM bench.hits WHERE CounterID = 62;"),
    # Q2: Aggregation on non-primary column (SearchPhrase)
    ("Q2_group_by", "SELECT SearchPhrase, count() AS c FROM bench.hits WHERE SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10;"),
]


def execute_query(query: str) -> float:
    """Executes a single query over ClickHouse HTTP interface and returns elapsed time in milliseconds."""
    start = time.perf_counter()
    resp = requests.post(CH_URL, data=query.encode("utf-8"), params={"default_format": "Null"})
    if resp.status_code != 200:
        raise RuntimeError(f"Query failed [{resp.status_code}]: {resp.text}")
    elapsed_ms = (time.perf_counter() - start) * 1000.0
    return elapsed_ms


def calculate_percentile(sorted_data: List[float], p: float) -> float:
    """
    TODO(you): Calculate the p-th percentile from a sorted list of floats.
    p is between 0.0 and 1.0 (e.g. 0.50 for p50, 0.95 for p95, 0.99 for p99).
    """
    if not sorted_data:
        return 0.0
    # Hint: index = int(round(p * (len(sorted_data) - 1)))
    # return sorted_data[index]
    # TODO(you): fill in the calculation below:
    return 0.0


def calculate_stats(timings_ms: List[float]) -> Dict[str, float]:
    """Calculates min, max, mean, p50, p95, p99, stddev, and Coefficient of Variation (CoV)."""
    n = len(timings_ms)
    sorted_times = sorted(timings_ms)
    mean_val = sum(sorted_times) / n

    # Standard deviation
    variance = sum((x - mean_val) ** 2 for x in sorted_times) / (n - 1) if n > 1 else 0.0
    stddev = math.sqrt(variance)

    # TODO(you): Calculate Coefficient of Variation (CoV = stddev / mean * 100)
    # A benchmark with CoV > 10% is usually considered noisy / unstable.
    cov = 0.0  # TODO(you): replace with stddev / mean_val * 100

    p50 = calculate_percentile(sorted_times, 0.50)
    p95 = calculate_percentile(sorted_times, 0.95)
    p99 = calculate_percentile(sorted_times, 0.99)

    return {
        "min": sorted_times[0],
        "p50": p50,
        "p95": p95,
        "p99": p99,
        "max": sorted_times[-1],
        "mean": mean_val,
        "stddev": stddev,
        "cov": cov,
    }


def benchmark_query(name: str, sql: str, warmup_runs: int = 2, iterations: int = 10) -> Dict[str, Any]:
    print(f"\n>> Benchmarking: {name}")
    print(f"   Query: {sql[:65]}...")

    # TODO(you): Implement warmup runs.
    # Why? The first 1-2 runs populate the OS page cache and mark_cache.
    # Discard timings from warmup runs so they don't corrupt the warm benchmark results.
    # for _ in range(warmup_runs):
    #     execute_query(sql)
    # TODO(you): Execute warmup runs here:
    pass

    # Measured runs
    timings: List[float] = []
    for i in range(iterations):
        t = execute_query(sql)
        timings.append(t)
        sys.stdout.write(f"\r   Run {i+1}/{iterations}: {t:.2f} ms")
        sys.stdout.flush()
    print()

    stats = calculate_stats(timings)
    return stats


def print_report(results: List[Dict[str, Any]]) -> None:
    print("\n" + "=" * 80)
    print(f"{'Query':<15} | {'Min (ms)':<9} | {'p50 (ms)':<9} | {'p95 (ms)':<9} | {'p99 (ms)':<9} | {'CoV %':<8}")
    print("-" * 80)
    for r in results:
        print(f"{r['name']:<15} | {r['min']:<9.2f} | {r['p50']:<9.2f} | {r['p95']:<9.2f} | {r['p99']:<9.2f} | {r['cov']:<7.1f}%")
    print("=" * 80)


def main():
    print("Starting ClickHouse Benchmark Harness...")
    results = []
    for name, sql in QUERIES:
        stats = benchmark_query(name, sql, warmup_runs=2, iterations=10)
        stats["name"] = name
        results.append(stats)
    print_report(results)


if __name__ == "__main__":
    main()
