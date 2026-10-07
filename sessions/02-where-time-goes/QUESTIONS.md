# Session 2: Interview questions

Answer in your own words (out loud, or write below each one). Use numbers and metrics you observed today.

1. **"A query is slow, walk me through it."**
   A critical production query is taking 3 seconds instead of its usual 50ms. Walk through your systematic diagnostic process. What tables and system metrics do you check first, and in what order?

2. **Cold vs Warm & Caching Architecture:**
   How does ClickHouse handle caching compared to a traditional RDBMS like PostgreSQL? If you drop the OS page cache (`echo 3 > /proc/sys/vm/drop_caches`), what happens, and what internal caches does ClickHouse maintain?

3. **Multi-threading & Pipeline:**
   What does `(× 16)` in `EXPLAIN PIPELINE` represent? Does ClickHouse always parallelize every query across all available cores? Which setting governs this, and when would you want to restrict it?

4. **Forensic Profiling with `ProfileEvents`:**
   In `system.query_log`, which specific `ProfileEvents` counters distinguish an I/O-bound query from a CPU-bound query? How do `OSReadBytes` and `OSReadChars` help you identify page cache hits vs physical disk reads?

5. **Spill to Disk / Memory Pressure:**
   If a heavy `GROUP BY` query exhausts the per-query memory limit (`max_bytes_before_external_group_by` / `max_server_memory_usage`), what happens, and how can ClickHouse be configured to handle it without crashing or failing?

---
_Answers:_
1. I will query the system.query_log database (or table?) and use 'where' to filter that particular query. 2 usual suspects are IO and CPU bottleneck.
   for CPU, I will select these column: real time, system time, user time (dunno why these 3 honestly!). see if the ratio (sys + user) / real > # of CPU
   for IO, I will check the OSReadBytes (disk read) vs OSReadChars (total read). if disk read is similar to total read, we were cold reading
   I might even just check iostat & htop. no need to redo the query as it definitely non query problem
   or... maybe redo the query and raise log level. from warning to trace

2. ClickHouse doesn't seem to have it's own app memory, instead it uses Linux OS page cahce. If you drop the page cache, ch is forced to do cold reading. dunno about  internal cache

3. EXPLAIN PIPELINE explains the DAG task pipeline to execute the query. the x 16 means the tasks are divided for 16 runners / CPU core. Dunno for the rest of question

4. OSReadBytes (for disk read) and OSReadChars (for total read). Naming sucks hard. disk read is how much data is retrieved from the disk, while total read is total data read from both disk and memory. a hot cache hit happens when almost 0 disk read

5. wow I don't know

---
_Grading (agent), 2026-10-07:_

| Q | Score | Verdict |
|---|---|---|
| 1 | 7.5/10 | Strong instinct to check `system.query_log` first, and right formulas for CPU ratio and disk vs cache! `system` is the database, `query_log` is the table. Clarified below: why the 3 time metrics exist and the standard interview diagnostic order. |
| 2 | 5.5/10 | Nailed the OS page cache role and what dropping it does. Missed ClickHouse's internal caches: **`mark_cache`** (keeps tiny `.mrk2` index marks in RAM so it never touches disk to plan) and optional **`uncompressed_cache`** (keeps decompressed blocks for hot repeated queries). |
| 3 | 5/10 | Correct on DAG and `(× 16)` = 16 parallel threads. Governed by **`max_threads`** (defaults to CPU core count). Why restrict it: under high concurrency (e.g. 50 queries at once), 50 × 16 = 800 threads thrashing the CPU; set `max_threads = 2` or `4` to prevent overload. |
| 4 | 8.5/10 | Spot on! `OSReadBytes` = physical storage read; `OSReadChars` = total bytes requested from filesystem (cache + disk). Cache hit = `OSReadBytes ≈ 0` and `OSReadChars > 0`. |
| 5 | 1/10 | Honest! By default ClickHouse throws `MEMORY_LIMIT_EXCEEDED` and kills the query. Fix: **External aggregation** (`max_bytes_before_external_group_by`) spills intermediate hash tables to disk temporary storage and merges them without OOMing. |

**Overall Score:** 27.5 / 50 (~5.5 / 10). Solid performance engineering intuition on the OS metrics and query_log; internal memory/thread settings need locking down.

---
_Reference answers (agent, 2026-10-07). Read, close the file, then say each one out loud in your own words:_

1. **"A query is slow, walk me through it."**
   - **Step 1: Check status.** If still running: `SELECT * FROM system.processes`. If finished: `SELECT * FROM system.query_log WHERE query_id = '...' OR query LIKE '...'`.
   - **Step 2: Check data scan size.** Look at `read_rows` and `read_bytes`. Did someone query without the primary key prefix (scanned 100M rows instead of 10k)? Or did a recent merge / data load change the volume?
   - **Step 3: Identify the bottleneck via `ProfileEvents`:**
     - **Disk I/O bound:** `OSReadBytes` is high (cold disk read), `RealTimeMicroseconds` >> CPU time. Confirm with `iostat -xz 1`.
     - **CPU bound:** `OSReadBytes ≈ 0` (cached in page cache), but `(UserTime + SystemTime) / RealTime ≈ max_threads`. CPU is maxed out decompressing or hashing.
     - **Lock / queue bound:** Real time is high, but both CPU time and `OSReadBytes` are near zero (waiting on thread pool, Keeper, or network).
   - **Step 4: Check plan.** Run `EXPLAIN indexes = 1` (check granule pruning) and `EXPLAIN PIPELINE` (check processor bottlenecks).

2. **Cold vs Warm & Caching Architecture:**
   - ClickHouse avoids "double buffering" by letting the **Linux OS Page Cache** handle raw compressed column data (`.bin` files).
   - Dropping the page cache (`echo 3 > drop_caches`) forces ClickHouse to perform cold physical disk reads (visible on `iostat`).
   - ClickHouse's internal memory caches:
     - **`mark_cache`**: Pins `.mrk2` index marks in RAM (a few hundred MBs). Allows instant primary index evaluation without disk access.
     - **`uncompressed_cache`**: (Optional) caches already-decompressed blocks in RAM to skip LZ4 decompression on repeated queries.

3. **Multi-threading & Pipeline:**
   - `(× 16)` in `EXPLAIN PIPELINE` means ClickHouse is executing that pipeline stage across 16 parallel threads (one per physical core).
   - Governed by the setting **`max_threads`** (default: server core count).
   - Why restrict it: Under high concurrency (e.g. 50 simultaneous queries), giving each query 16 threads causes 800 threads to context-switch, destroying CPU cache locality. Restricting `max_threads = 2` or `4` increases overall system throughput.

4. **Forensic Profiling with `ProfileEvents`:**
   - **Page Cache vs Disk:** Linux syscalls distinguish between `OSReadChars` (all bytes requested through `read()`/`pread()`) and `OSReadBytes` (bytes physically read from the block device). A 100% page cache hit has `OSReadBytes = 0` and `OSReadChars > 0`.
   - **CPU vs I/O:** `UserTimeMicroseconds` (time executing user-space code) + `SystemTimeMicroseconds` (kernel syscalls) divided by `RealTimeMicroseconds` (elapsed wall clock). If ratio ≈ `max_threads`, it is CPU-bound. If ratio << 1 while disk read is active, it is I/O-bound.

5. **Spill to Disk / Memory Pressure:**
   - When a `GROUP BY` exceeds `max_memory_usage` (or server-wide `max_server_memory_usage`), ClickHouse aborts the query with `MEMORY_LIMIT_EXCEEDED`.
   - **The fix:** Configure `max_bytes_before_external_group_by` (e.g., set to half of RAM).
   - When the aggregation hash table reaches this limit, ClickHouse flushes intermediate chunks to `/var/lib/clickhouse/tmp/` on disk, processes remaining data, and runs a multi-way merge on disk. Slower than pure RAM, but query completes reliably without crashing.
