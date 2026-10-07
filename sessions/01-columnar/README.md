# Session 1: Why columnar is fast (30 min)

**Goal:** see with your own eyes *why* ClickHouse scans 10M rows in milliseconds: column files,
compression, and the sparse primary index that skips data without reading it.

**Setup check (1 min):**
```bash
make status          # ch + pg up, bench.hits ~10M rows
```
Open a 2nd terminal with `htop` and keep it visible the whole session.

---

## Part A: The contrast (5 min)

Same data, same query, same machine. Run in **psql** (`make pg`):
```sql
\timing on
SELECT SearchPhrase, count(*) c FROM hits WHERE SearchPhrase <> ''
GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10;
```
Then in **ClickHouse** (`make ch`):
```sql
SELECT SearchPhrase, count() c FROM bench.hits WHERE SearchPhrase <> ''
GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10;
```
👀 **Watch:** the timing, and the htop CPU bars during each one. Run each twice (why is the 2nd run different?).
The ClickHouse client prints `Processed X rows, Y MB`. Note **Y** and compare it to the table's total size (Part B).

Now sizes. The Postgres table has **15 columns**, the ClickHouse table **105**:
```sql
-- psql
SELECT pg_size_pretty(pg_total_relation_size('hits'));
-- clickhouse
SELECT formatReadableSize(sum(data_compressed_bytes)) AS on_disk,
       formatReadableSize(sum(data_uncompressed_bytes)) AS raw
FROM system.parts WHERE active AND table = 'hits';
```

## Part B: Look at the files (8 min)

A MergeTree table is a set of immutable **parts** (directories). Each part stores **one file per column**.
```sql
SELECT name, rows, marks, formatReadableSize(bytes_on_disk) size, path
FROM system.parts WHERE active AND table = 'hits';
```
Copy one `path`, swap `/var/lib/clickhouse/` for `single/volumes/ch/`, and look:
```bash
P=single/volumes/ch/store/bcb/bcba7b12-.../all_1_6_1     # <- paste yours
ls -la $P | head -30
ls $P | grep -c '\.bin'        # how many column files? (compare with 105 columns)
cat $P/count.txt; head $P/columns.txt
```
👀 You'll see `URL.bin` (data) + `URL.cmrk2` (marks: granule → byte offset), `primary.cidx`, `columns.txt`.
Some columns also have `*.sparse.idx.bin`: mostly-default columns get stored sparsely. A query that touches 1 column
opens about 1 file per part. Postgres has to read whole rows, with all 15 columns interleaved on 8 KB pages.

Which columns are heaviest, and how well do they compress?
```sql
SELECT name, type,
       formatReadableSize(data_compressed_bytes) AS disk,
       formatReadableSize(data_uncompressed_bytes) AS raw,
       round(data_uncompressed_bytes / data_compressed_bytes, 1) AS ratio
FROM system.columns WHERE table = 'hits' ORDER BY data_compressed_bytes DESC LIMIT 15;
```
👀 Find a column with ratio > 100 and one with ratio < 4. *Why* the difference? (Hint: think about what
the values look like when sorted by `ORDER BY`.)

Parts merge in the background. Watch them:
```sql
SELECT event_time, event_type, part_name, rows, merge_reason
FROM system.part_log WHERE table = 'hits' ORDER BY event_time;
```

## Part C: The sparse primary index (8 min)

Rows are sorted by `ORDER BY (CounterID, EventDate, UserID, EventTime, WatchID)` and cut into **granules**
of 8192 rows. The primary index stores **one entry per granule** (not per row like a B-tree), so it fits in RAM.
```sql
SHOW CREATE TABLE bench.hits;   -- find ORDER BY / PRIMARY KEY
SELECT sum(marks) FROM system.parts WHERE active AND table='hits';   -- ≈ number of granules
```
Now **predict first, then run**. Write your guess for "granules read" before each:
```sql
EXPLAIN indexes = 1 SELECT count() FROM bench.hits WHERE CounterID = 62;              -- 1st key column
EXPLAIN indexes = 1 SELECT count() FROM bench.hits WHERE UserID = 445678954406699182; -- 3rd key column
EXPLAIN indexes = 1 SELECT count() FROM bench.hits WHERE URL LIKE '%google%';          -- not in key
```
👀 Look at `Granules: X/Y`. Then run the real queries (without `EXPLAIN`) and compare `Processed N rows`.

## Part D: TODO(you): design your own ORDER BY (6 min)

Open [`TODO_order_by.sql`](TODO_order_by.sql). Fill it in, run it, and fill the prediction table.

## Wrap-up (2 min)

Answer [`QUESTIONS.md`](QUESTIONS.md) out loud or in writing, then tell the agent:
**"Session 1 done, grade my answers."**
