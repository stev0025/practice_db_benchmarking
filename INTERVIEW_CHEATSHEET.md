# Interview Cheat Sheet

Grows after every session. Crisp, sayable-out-loud talking points. Numbers are **measured on this lab**
(16 cores, NVMe, ClickHouse 25.8, 10M-row ClickBench `hits`) unless stated otherwise.

## 1. Why columnar / MergeTree is fast
- **Row vs column store:** Postgres keeps whole rows together; ClickHouse keeps one file per column. An analytics query touching 1 of 105 columns opens ~1 file per part.
- **Compression:** same 10M rows: Postgres 15 cols = **3.6 GB**; ClickHouse 105 cols = **1.31 GiB** (4.96 GiB raw, ~3.8x). Each column compresses separately and sorted/similar values compress best.
- **Sparse primary index:** table `ORDER BY` sorts rows on disk. One index entry (mark) per **granule (8192 rows)**, so it fits in RAM. Skipping granules = skipping disk reads.
  - `CounterID = 50` (1st key col): **1/1234 granules**; `CounterID = 2` (absent): **0**, index proves absence.
  - `UserID = ...` as 3rd key col: **114/1234**, generic exclusion; works well only if earlier key columns are low-cardinality.
  - `URL LIKE '%google%'` (not in key): full scan of 10M rows, ~200 ms, but reads only the URL column.
  - UserID first in a new table: 10 granules. CounterID not in the key: 1227 (~full scan).
- **Trade-off:** point lookups are worse than a B-tree (must read a whole granule); inserts must be batched.
- **Parts:** each INSERT makes an immutable part; background merges combine them (`all_1_7_1` = blocks 1-7, merge level 1). Too many small parts = slow queries, "Too many parts" errors. Fix: batch inserts or `async_insert`.
- **Parallelism:** one query used all 16 cores in htop; Postgres never saturated them.
- **Rule of thumb for ORDER BY:** low-cardinality columns first, columns you filter on near the front. Only the key prefix really helps.
- _Still shaky: why columns compress 3x vs 100x+ (redo Q4)._

## 2. Where query time goes
_(filled after Session 2)_

## 3. Benchmarking methodology
_(filled after Session 3)_

## 4. Capacity sizing
_(filled after Session 4)_

## 5. Distributed ClickHouse
_(filled after Session 5)_

## 6. Kernel / OS bottlenecks & chaos engineering
_(filled after Session 6)_

## Incident patterns (Phase 2)
| Symptom | Where I looked | Root cause | Fix |
|---|---|---|---|
