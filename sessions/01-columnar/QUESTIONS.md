# Session 1: Interview questions

Answer in your own words (out loud, or write below each one). Use numbers you measured today.

1. An interviewer asks: "Why is ClickHouse 10-100x faster than Postgres on analytics queries?"
   Give at least **3 distinct reasons** and point to something you saw in this session for each.

2. What is a **granule**, and why is ClickHouse's primary index called *sparse*? What's the trade-off
   compared to a B-tree index in Postgres? (Think: point lookups.)

3. You have a table ordered by `(CounterID, EventDate, UserID)`. A query filters only on `UserID`.
   What happens, and what are 2 ways to make it fast?

4. Why did some columns compress 100x+ and others barely 3x? How does `ORDER BY` affect compression?

5. A teammate inserts one row at a time, 1000 times/sec. Based on what you saw in `system.parts`
   and `system.part_log`, what goes wrong, and why?

---
_Answers:_
1. - because the sequence of data uses column stored instead of row stored. As analytic query usually care for a small number of column per query isntead of all 1000 columns, this helps a lot!
   - somehow clickHouse compressed something. I don't know how but it causes low memory footprint. plus it merges several part so it compressed better
   - I think it is good to maximize cores? pg query never hit 100% all core util. ch actually hit 100% all core util

2. - granule is a grouping of row data, and it only stores the index I believe? each granule by default has 8000 row
   - I think it's called sparse index because each ch's row doesn't have index, like pg does. it index per granule

3. - UserID is the 3rd sorting key. it will take a while.
   - you can actually re-create the table but sorted based on UserID
   - or hopefully you know what is the counterID, then you can also put where CounterID = x

4. I guess that's just compression work. an image is too hard to compress, but... actually I only roughly know how compression work

5. I think generally in ch (not sure in pg), you want to insert a big chunk of row at a time.
   ch has this... background task to merge several parts together into a big part.
   and that means the part_log also is added 1000 times/sec. hellish debugging
---
_Grading (agent), 2026-10-07:_

| Q | Score | Verdict |
|---|---|---|
| 1 | 6/10 | Columnar: good. Compression: right idea, but merging parts is not why it compresses (see below). Cores: true, but Postgres also parallelises; the point is vectorised execution + all cores. **Missing: sparse-index skipping** (you measured 114/1234 granules). No numbers quoted. |
| 2 | 5/10 | Sparse = one entry per granule: correct. But a granule is **8192 rows of column data**; the index only holds one *mark* per granule. **Trade-off not answered:** a point lookup must read a whole granule (8192 rows) to find 1 row; a B-tree goes straight to the row. So CH is weak at point lookups / updates. |
| 3 | 6/10 | "Re-create sorted by UserID" and "add CounterID to the filter" are both valid. Be exact: you measured **generic exclusion, 114/1234 granules**, and it only works well when the earlier key columns are low-cardinality. Missed other fixes: a **projection** with a different ORDER BY, or a **data-skipping index** (bloom_filter). |
| 4 | 2/10 | Honest, but too thin. **Redo it** after running the ratio query in Part B. Hint: sorted columns put equal/similar values next to each other, so LZ4 finds long repeats; high-entropy columns (hashes, random IDs, URLs) have nothing to repeat. |
| 5 | 6/10 | Batching + background merges: right. But the real failure is **too many parts: merges can't keep up, queries open files in every part, and eventually inserts are delayed/rejected ("Too many parts")**. part_log growth is a side effect. Fixes: batch 10k-100k+ rows per insert, or `async_insert`. |

Part D: good reasoning in row 3 (UserID ~unique, so CounterID after it, or not in the key at all, skips almost nothing: 1227/~1234). Row 2: you guessed 1, actual 10. Why 10? Check how many rows that UserID has.
Part D takeaway: the sort key only helps the first columns you filter on. Dropping CounterID cost nothing for the user-centred scenario.

**Redo before Session 2:** Q4 in writing, and Q2's trade-off in one sentence.

---
_Reference answers (agent, 2026-10-07). Read, close the file, then say each one out loud in your own words. Numbers are from this lab._

1. **Why is ClickHouse 10-100x faster than Postgres on analytics?**
   - **Column store:** a query on 1 of 105 columns reads ~1 column file per part, not whole rows.
   - **Compression:** each column is compressed on its own. Same 10M rows: Postgres (15 cols) 3.6 GB vs ClickHouse (105 cols) 1.31 GiB. Fewer bytes to read.
   - **Sparse index:** `ORDER BY` sorts rows on disk and one mark per 8192-row granule lets it skip data. `CounterID = 50` read 1 of ~1234 granules; `UserID` as 3rd key column read 114.
   - **All cores + vectorised:** one query saturated all 16 cores in htop, processing values in batches. (Postgres also uses parallel workers, but it still reads whole rows.)

2. **Granule and sparse index.** A granule is a block of 8192 consecutive rows (of every column); it is the smallest unit ClickHouse reads. The primary index stores one entry (mark) per granule, not per row, so it is tiny and lives in RAM. **Trade-off:** a point lookup ("get row with id=X") must read a whole 8192-row granule to return 1 row, while a Postgres B-tree jumps straight to it. So ClickHouse is great for scans/aggregates and poor at point lookups and single-row updates.

3. **Filter only on `UserID`, key is `(CounterID, EventDate, UserID)`.** The index can't binary-search (UserID is not a key prefix). It uses generic exclusion, which skips only some granules (114/1234 here) and works well only if CounterID/EventDate have few distinct values. Fixes: (a) also filter on `CounterID` (a key prefix) when you know it; (b) create a table, or a **projection**, ordered by `UserID` (our `hits_by_user`: 10 granules); (c) add a **data-skipping index** (e.g. bloom_filter) on `UserID`.

4. **Why 225x for some columns and 1x for others?** LZ4 finds repeated runs of bytes. Compression ratio depends on how repetitive a column is *in storage order*.
   - **225x:** `GoodEvent`, `CounterClass`, `OpenerName` (nearly constant, so long identical runs) and `CounterID`, `EventDate` (first key columns, sorted so equal values sit side by side).
   - **1.0-1.3x:** `WatchID` (unique ids, 76.6 MiB for 76.3 MiB raw), `HID`, and the timestamps `EventTime`, `LocalEventTime`, `ClientEventTime`. Nothing repeats, and they are not sorted overall (EventTime is only sorted inside each CounterID/EventDate/UserID group).
   - **How `ORDER BY` affects it:** it groups equal/similar values together, so the first key columns compress best. A different key changes every column's ratio. Choosing the key is a compression decision too.
   - (Non-key columns like `UserID` came out about the same in both tables: 14.2 vs 13.7 MiB, because the ids are random either way.)

5. **Inserting one row at a time, 1000/s.** Every INSERT creates a new immutable part (a directory with one file per column). 1000/s means thousands of tiny parts; background merges can't keep up, queries must open files in every part and slow down, and when the count passes the limit ClickHouse delays and then rejects inserts with "Too many parts". `system.part_log` also fills with a row per part and merge. Fix: batch 10k-100k+ rows per insert, or enable `async_insert` so the server batches for you. (Postgres is fine with small inserts: it's a row store built for OLTP.)
