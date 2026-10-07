# Session 3: Benchmarking without lying (30 min)

**Goal:** Understand how performance engineers benchmark databases without deceiving themselves or their users. Discover the throughput "knee", isolate cache pollution, handle run-to-run variance, and build a reproducible benchmark harness.

**Setup check (1 min):**
```bash
make status          # ch up, bench.hits ~10M rows
```
Keep `htop` visible in a separate terminal.

---

## Part A: The Concurrency Knee with `clickhouse-benchmark` (8 min)

ClickHouse comes with an industrial load generator: `clickhouse-benchmark`.
It runs queries repeatedly, measures percentiles, and can sweep concurrency automatically.

### 1. Single Concurrency Baseline
Run a query at concurrency 1 (`-c 1`) for 5 seconds (`-t 5`):
```bash
docker exec -i ch clickhouse-benchmark \
  -q "SELECT SearchPhrase, count() FROM bench.hits WHERE SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY count() DESC LIMIT 10" \
  -c 1 -t 5
```
👀 **Watch:** Notice the output metrics:
- `QPS`: queries per second
- `RPS`: rows processed per second
- `MiB/s`: uncompressed throughput
- Percentiles: 50%, 90%, 99%

### 2. The Concurrency Sweep (1 → 32)
What happens when 32 clients pound ClickHouse simultaneously?
Run with `-C 32` (gradually step concurrency up from 1 to 32):
```bash
docker exec -i ch clickhouse-benchmark \
  -q "SELECT count() FROM bench.hits WHERE CounterID = 62" \
  -c 1 -C 32 -t 3
```
👀 **Watch:**
- As concurrency increases from 1 to 4 to 8: **Throughput (QPS) rises**.
- At a certain point (near the core count of your machine, ~16 cores): **QPS hits a ceiling (the knee)**.
- Beyond the knee (concurrency 24 → 32): **Latency explodes** (p99 spikes 5x-10x) while QPS stays flat or drops due to CPU thread contention and cache line bouncing.

---

## Part B: The 4 Deadly Sins of Database Benchmarking (6 min)

In interviews and blog posts, 90% of benchmarks are flawed. Understand these 4 traps:

1. **The "Cold First Run" Trap:**
   - Run 1 reads cold NVMe disk blocks into Linux page cache (takes 500ms).
   - Runs 2–10 read from RAM page cache (takes 20ms).
   - *If you don't discard warmup runs, your average latency is completely bogus.*

2. **The "Average / Mean" Fallacy:**
   - 99 queries take 10ms. 1 query hits a background part merge or page fault and takes 2000ms.
   - Mean = 30ms (hides the fact that users experienced a 2-second stall).
   - *Always report percentiles: p50 (median), p95, p99, max.*

3. **Ignoring Run-to-Run Variance (Coefficient of Variation):**
   - $CoV = \frac{Standard\ Deviation}{Mean} \times 100\%$
   - If $CoV < 5\%$: Benchmark is stable and reproducible.
   - If $CoV > 15\%$: Background noise (throttling, merges, noisy neighbors) is corrupting the results. Discard and isolate.

4. **Coordinated Omission:**
   - If the benchmark client blocks waiting for a slow query response before sending the next one, it undercounts the queue delay experienced by real users during traffic spikes.

---

## Part C: TODO(you): The Benchmark Harness (10 min)

Open [`bench/harness.py`](../../bench/harness.py).

Fill in the 3 marked `TODO(you)` blocks:
1. **Warmup runs:** Execute the query `warmup_runs` times and discard the timings before starting the measured loop.
2. **Percentile math:** Implement `calculate_percentile` for p50, p95, p99.
3. **Coefficient of Variation:** Compute `cov = (stddev / mean) * 100`.

### Run Your Harness:
```bash
python3 bench/harness.py
```
👀 **Watch:** Check the formatted table output. Note the difference between `min`, `p50`, and `p99`, and inspect whether `CoV %` stays healthy (< 10%).

---

## Part D: Cold vs Warm Comparison Drill (4 min)

Using what you learned in Session 2, run your harness cold:
```bash
# 1. Drop OS cache
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

# 2. Run harness
python3 bench/harness.py
```
Notice how your warmup logic protected the p50 and p95 timings from being distorted by the initial cold cache miss!

---

## Wrap-up (2 min)

Answer [`QUESTIONS.md`](QUESTIONS.md) out loud or in writing, then tell the agent:
**"Session 3 done, grade my answers."**
