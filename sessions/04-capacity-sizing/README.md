# Session 4: Capacity sizing (30 min)

**Goal:** Measure per-core throughput and compression ratio, find the memory cliff, then turn those numbers into a sizing estimate.

**Setup (1 min):** `make status` (ch up, `bench.hits` = 10M rows). Keep `htop` open.

Query used throughout (CPU-heavy scan + aggregate):
```sql
SELECT URL, count() c FROM bench.hits GROUP BY URL ORDER BY c DESC LIMIT 10
```

---

## Part A: Does throughput scale with cores? (10 min)

Limit the running container live (no restart):
```bash
docker update --cpus 1 ch
docker exec -i ch clickhouse-benchmark -c 1 -t 10 \
  -q "SELECT URL, count() c FROM bench.hits GROUP BY URL ORDER BY c DESC LIMIT 10"
```
Repeat for `--cpus 2`, `4`, `8`, `16`. Record QPS and p50 in `TODO_scaling.md`.

**Predict first:** write your guess for 1 -> 16 cores speedup before running.

👀 **Watch:** where does the curve flatten? Check `docker stats ch` to confirm the cgroup limit is real.

**TODO(you):** Compute rows/s *per core* at each step. Is it constant? If not, hypothesize why (memory bandwidth? hash table merge? Amdahl?).

Hint: `nproc` inside the container still says 16 and ClickHouse's `max_threads` still defaults to 16. What does that do to a 1-CPU cgroup? (Look at `system.query_log` `ProfileEvents['OSCPUWaitMicroseconds']` or `RealTimeMicroseconds` vs `UserTimeMicroseconds`.)

Reset: `docker update --cpus 16 ch`

---

## Part B: Compression ratio -> disk sizing (5 min)

```sql
SELECT table,
       formatReadableSize(sum(data_compressed_bytes))   AS compressed,
       formatReadableSize(sum(data_uncompressed_bytes)) AS raw,
       round(sum(data_uncompressed_bytes)/sum(data_compressed_bytes),2) AS ratio,
       sum(rows) AS rows
FROM system.parts WHERE active AND database='bench' GROUP BY table;
```
**TODO(you):** bytes per row compressed = ? Extrapolate to 1 TB/day of ingested raw events. Then find the 3 columns that cost the most (`system.columns`, `data_compressed_bytes`) and say why.

---

## Part C: The memory cliff (8 min)

```bash
docker update --memory 2g --memory-swap 2g ch
```
Run a high-cardinality GROUP BY and watch it die:
```sql
SELECT WatchID, count() FROM bench.hits GROUP BY WatchID ORDER BY count() DESC LIMIT 10
```
**TODO(you):**
1. Find the exact error (name + code) and the peak memory in `system.query_log` (`memory_usage`).
2. Fix it WITHOUT raising the container limit (Session 2 cheatsheet has the setting). Compare latency vs unlimited.
3. Was it the container OOM-killer or ClickHouse's own limit that fired? How do you tell? (`docker inspect ch | grep OOMKilled`, `max_server_memory_usage_to_ram_ratio`)

Reset: `docker update --memory 0 --memory-swap -1 ch`

---

## Part D: Sizing calculator (6 min)

Create `tools/sizing.py` (TODO(you)). Inputs: ingest TB/day, retention days, target query + p95, replicas. Outputs: disk, cores, RAM.
Use YOUR measured numbers: compression ratio (B), per-core scan rows/s (A), memory per GROUP BY (C).
Sanity-check: assumptions printed, and a 30% headroom factor.

---

Finish with `QUESTIONS.md`.
