# Session 2: Where time goes (30 min)

**Goal:** systematically diagnose *why* a query is slow. Is it waiting on disk I/O, hitting page cache, or maxing out CPU? Learn to trace query pipelines, inspect OS-level cache behavior, and use `system.query_log` like a performance engineer.

**Setup check (1 min):**
```bash
make status          # ch + pg up, bench.hits ~10M rows
```
Open two additional terminal windows alongside:
- Terminal 2: `htop`
- Terminal 3: `iostat -xz 1` (or `sudo iostat -xz 1`)

---

## Part A: The Execution Pipeline & Live Trace (8 min)

When ClickHouse executes a query, it constructs a Directed Acyclic Graph (DAG) of processing streams and spreads them across multiple threads.

### 1. Inspect the Pipeline
Run in `clickhouse-client` (`make ch`):
```sql
EXPLAIN PIPELINE
SELECT SearchPhrase, count() AS c
FROM bench.hits
WHERE SearchPhrase <> ''
GROUP BY SearchPhrase
ORDER BY c DESC
LIMIT 10;
```
👀 **Watch:** Look at the tree of processors. Notice the number of parallel streams (e.g., `(× 16)` on a 16-core machine).
- Where does data enter? (e.g. `MergeTreeSelect(pool: ...)`)
- Where does aggregation happen? (`AggregatingTransform (× 16)`)
- Where do the parallel streams merge into a single stream? (`Resize 16 → 1` or `MergingAggregated`)

### 2. Stream Live Trace Logs
ClickHouse can stream execution trace logs directly to your client connection without cluttering server log files.

In `make ch`, turn trace logs on for this session:
```sql
SET send_logs_level = 'trace';
```
Now run a query touching multiple parts or columns:
```sql
SELECT sum(AdvEngineID), uniq(UserID)
FROM bench.hits;
```
👀 **Watch:** Look at the real-time server messages scrolling by:
- `Selected N parts by partition key...`
- `Selected N marks by primary key...`
- Reading compressed blocks, decompressing with LZ4.
- Thread pools executing aggregation chunks.

Turn it back to normal when done:
```sql
SET send_logs_level = 'warning';
```

---

## Part B: Cold vs Warm & The OS Page Cache (8 min)

Postgres caches data in its own engine buffer pool (`shared_buffers`). ClickHouse takes a different approach: it relies heavily on the **Linux OS Page Cache** for raw column data, while maintaining small internal caches only for index marks (`mark_cache`) and uncompressed blocks (`uncompressed_cache`).

Let's prove this with `drop_caches` and `iostat`.

### 1. Cold Run (Bypass / Drop Page Cache)
On your host terminal, drop kernel caches:
```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

Now, watch `iostat -xz 1` in Terminal 3 while running this cold query in `make ch`:
```sql
SELECT uniq(URL), count()
FROM bench.hits;
```
👀 **Watch:**
- In `iostat`: check `r/s` (read requests/sec) and `rMB/s` (MB/s read from disk). The NVMe drive is active.
- In `clickhouse-client`: note elapsed time (e.g. ~0.4s – 1.0s).

### 2. Warm Run (In Memory)
Immediately run the exact same query again in `make ch`:
```sql
SELECT uniq(URL), count()
FROM bench.hits;
```
👀 **Watch:**
- In `iostat`: `rMB/s` stays near 0! Disk is untouched.
- In `htop`: all 16 CPU cores spike briefly to 100%.
- In `clickhouse-client`: elapsed time drops significantly.
The entire column was read from Linux page cache directly into RAM.

---

## Part C: Forensic Profiling with `system.query_log` (8 min)

Every completed query is recorded in `system.query_log` with fine-grained performance counters in the `ProfileEvents` map.

Flush the log buffer to ensure your recent queries appear:
```sql
SYSTEM FLUSH LOGS;
```

Inspect the last query executed:
```sql
SELECT
    query,
    query_duration_ms,
    formatReadableSize(read_bytes) AS read_bytes,
    read_rows,
    formatReadableSize(memory_usage) AS memory,
    -- ProfileEvents breakdown
    ProfileEvents['OSReadBytes'] AS os_disk_read_bytes,
    ProfileEvents['OSReadChars'] AS os_total_read_chars,
    ProfileEvents['RealTimeMicroseconds'] AS real_us,
    ProfileEvents['UserTimeMicroseconds'] AS user_us,
    ProfileEvents['SystemTimeMicroseconds'] AS sys_us
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query LIKE '%bench.hits%'
  AND query NOT LIKE '%system.query_log%'
ORDER BY event_time DESC
LIMIT 1
FORMAT Vertical;
```

### Deciphering the Metrics:
1. **Disk vs Page Cache:**
   - `OSReadBytes`: Bytes read from disk block devices via OS syscalls.
   - `OSReadChars`: Total bytes read via read/pread calls (including page cache hits).
   - If `OSReadChars > 0` and `OSReadBytes == 0` → 100% Page Cache hit (warm).
   - If `OSReadBytes ≈ OSReadChars` → Cold read (hit physical disk).

2. **CPU-bound vs I/O-bound:**
   - `UserTimeMicroseconds`: Total CPU time spent across all worker threads in user space.
   - `RealTimeMicroseconds`: Wall-clock time of the query.
   - CPU utilization ratio = `(UserTimeMicroseconds + SystemTimeMicroseconds) / RealTimeMicroseconds`.
   - On a 16-core machine, if ratio > 8–14 → **CPU-bound** (parallel decompression / vector execution).
   - If ratio < 1.0 while elapsed time is high → **I/O-bound or lock-blocked** (threads were stalled waiting on disk or synchronization).

---

## Part D: TODO(you): The Slow-Query Detective (6 min)

Open [`TODO_query_log.sql`](TODO_query_log.sql).
Fill in the query that analyzes recent queries from `system.query_log`, computes whether each was CPU-bound or I/O-bound, and identifies the heaviest queries.

Run it against your ClickHouse instance and observe the output.

---

## Wrap-up (2 min)

Answer [`QUESTIONS.md`](QUESTIONS.md) out loud or in writing, then tell the agent:
**"Session 2 done, grade my answers."**
