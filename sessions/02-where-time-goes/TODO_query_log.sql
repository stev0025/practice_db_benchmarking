-- Session 2: Forensic Query on system.query_log
--
-- Task: Write a query against system.query_log to find the 5 heaviest queries
-- by read_bytes, and classify whether each query was primarily CPU-bound or IO-bound.
--
-- Instructions:
-- 1. Replace the TODO(you) placeholders below.
-- 2. Run the query in clickhouse-client (`make ch` or via docker exec).
-- 3. Remember to run `SYSTEM FLUSH LOGS;` first so recent queries are visible in the table.

SYSTEM FLUSH LOGS;

SELECT
    substring(query, 1, 50) AS query_preview,
    query_duration_ms,
    formatReadableSize(read_bytes) AS read_bytes_formatted,
    read_rows,
    formatReadableSize(ProfileEvents['OSReadBytes']) AS disk_read,
    formatReadableSize(ProfileEvents['OSReadChars']) AS total_read,

    -- TODO(you): Calculate effective CPU cores utilized during execution.
    -- Hint: Total CPU time (User + System) divided by wall-clock time (RealTimeMicroseconds).
    -- Remember ProfileEvents keys: 'UserTimeMicroseconds', 'SystemTimeMicroseconds', 'RealTimeMicroseconds'.
    ProfileEvents['UserTimeMicroseconds'] AS user_us,
    ProfileEvents['SystemTimeMicroseconds'] AS sys_us,
    ProfileEvents['RealTimeMicroseconds'] AS real_us,

    round(
        /* TODO(you): (UserTime + SystemTime) / RealTime */
        (user_us + sys_us) / real_us
    , 2) AS effective_cores_used,

    -- TODO(you): Classify whether the query was CPU-bound or IO-bound.
    -- Hint: If effective_cores_used >= 2.0 (or high thread usage) and disk_read is low relative to total_read,
    -- it is CPU-bound. If disk_read > 0 and effective_cores_used < 1.5, it was waiting on disk I/O.
    CASE
        /* TODO(you): WHEN ... THEN 'CPU-bound'
                      WHEN ... THEN 'IO-bound'
                      ELSE 'Mixed / Other' */
        WHEN effective_cores_used >= 2.0 THEN 'CPU-bound'
        WHEN (effective_cores_used < 1.5 AND ProfileEvents['OSReadBytes'] > 0) THEN 'IO-bound'
        ELSE 'Mixed / Other'
    END AS bottleneck

FROM system.query_log
WHERE type = 'QueryFinish'
  AND query LIKE '%bench.hits%'
  AND query NOT LIKE '%system.query_log%'
-- TODO(you): Order by the heaviest queries by bytes read, top 5
ORDER BY /* TODO(you) */ read_bytes DESC
LIMIT 5
FORMAT PrettyCompact;
