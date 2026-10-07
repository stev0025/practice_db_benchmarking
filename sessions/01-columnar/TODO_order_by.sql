-- Session 1, Part D: design your own ORDER BY
-- Scenario: a product team mostly asks "show me everything user X did, in time order".
-- Run this file in `make ch` (paste it), or:
--   docker exec -i ch clickhouse-client --multiquery < sessions/01-columnar/TODO_order_by.sql

DROP TABLE IF EXISTS bench.hits_by_user;

CREATE TABLE bench.hits_by_user
(
    UserID       Int64,
    EventTime    DateTime,
    CounterID    Int32,
    URL          String,
    SearchPhrase String
)
ENGINE = MergeTree
ORDER BY ( UserID, EventTime, CounterID );

INSERT INTO bench.hits_by_user
SELECT UserID, EventTime, CounterID, URL, SearchPhrase FROM bench.hits;

-- Now predict, THEN run. Fill in the table below.
EXPLAIN indexes = 1 SELECT count() FROM bench.hits         WHERE UserID = 445678954406699182;
EXPLAIN indexes = 1 SELECT count() FROM bench.hits_by_user WHERE UserID = 445678954406699182;
EXPLAIN indexes = 1 SELECT count() FROM bench.hits_by_user WHERE CounterID = 62;

-- | query                          | my guess (granules) | actual | why |
-- |--------------------------------|---------------------|--------|-----|
-- | hits         WHERE UserID=...  |   80                  |  652      |     |
-- | hits_by_user WHERE UserID=...  |     80                |    652    |     |
-- | hits_by_user WHERE CounterID=62|    a lot                 | 613490       |     |

-- BONUS: compare compression of the same column in both tables. Why does it differ?
-- SELECT table, name, formatReadableSize(data_compressed_bytes) FROM system.columns
-- WHERE database='bench' AND name IN ('UserID','URL') ORDER BY name, table;
