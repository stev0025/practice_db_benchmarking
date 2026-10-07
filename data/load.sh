#!/usr/bin/env bash
# Load the ClickBench 'hits' dataset.
#   ./data/load.sh sample   -> 10M rows (10 days) into ClickHouse AND Postgres (15-col subset)
#   ./data/load.sh full     -> 100M rows (100 days) into ClickHouse only (bench.hits is replaced)
#
# Source files: data/parquet/hits_N.parquet, 1M rows each, one day per file.
set -euo pipefail
cd "$(dirname "$0")"

MODE="${1:-sample}"
case "$MODE" in
  sample) LAST=9 ;;
  full)   LAST=99 ;;
  *) echo "usage: $0 sample|full"; exit 1 ;;
esac

for i in $(seq 0 "$LAST"); do
  [ -f "parquet/hits_$i.parquet" ] || curl -sfS -o "parquet/hits_$i.parquet" \
    "https://datasets.clickhouse.com/hits_compatible/athena_partitioned/hits_$i.parquet"
done

ch() { docker exec -i ch clickhouse-client "$@"; }

echo ">> ClickHouse: creating bench.hits and loading hits_{0..$LAST}.parquet"
ch -q "DROP TABLE IF EXISTS bench.hits SYNC"
ch --multiquery < sql/ch_hits.sql
# Parquet stores EventTime as unix seconds and EventDate as days-since-epoch; INSERT ... SELECT
# casts each column positionally to the table's type (Int64 -> DateTime, UInt16 -> Date).
time ch -q "INSERT INTO bench.hits SELECT * FROM file('parquet/hits_{0..$LAST}.parquet', Parquet)
            SETTINGS max_insert_threads = 8"
ch -q "SELECT 'clickhouse rows', count() FROM bench.hits"

if [ "$MODE" = sample ]; then
  echo ">> Postgres: loading 15-column subset (streamed from ClickHouse, no temp file)"
  docker exec -i pg psql -q -U postgres -d bench -c "DROP TABLE IF EXISTS hits"
  docker exec -i pg psql -q -U postgres -d bench -f /sql/pg_hits.sql
  time ch -q "SELECT WatchID, EventTime, EventDate, CounterID, UserID, RegionID, OS, IsMobile,
                     ResolutionWidth, AdvEngineID, TraficSourceID, SearchPhrase, URL, Referer, Title
              FROM bench.hits FORMAT CSV" \
    | docker exec -i pg psql -q -U postgres -d bench -c "COPY hits FROM STDIN WITH (FORMAT csv)"
  docker exec -i pg psql -q -U postgres -d bench -c "VACUUM ANALYZE hits"
  docker exec -i pg psql -U postgres -d bench -c "SELECT 'postgres rows', count(*) FROM hits"
fi
echo ">> done"
