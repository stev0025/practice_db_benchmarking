# Shortcuts. Run `make help` to list them.
SINGLE := docker compose -f single/docker-compose.yml

.PHONY: help up down nuke load-sample load-full ch pg status

help:            ## list targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

up:              ## start single-node ClickHouse + Postgres
	mkdir -p single/volumes/ch single/volumes/pg
	$(SINGLE) up -d
	@until docker exec ch clickhouse-client -q 'SELECT 1' >/dev/null 2>&1; do sleep 1; done
	@until docker exec pg pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done
	@echo "ready. dashboard: http://localhost:8123/dashboard"

down:            ## stop containers (data kept)
	$(SINGLE) down

nuke:            ## stop containers AND delete all data volumes
	$(SINGLE) down -v
	docker run --rm -v $(CURDIR)/single:/s alpine rm -rf /s/volumes

load-sample:     ## 10M rows -> ClickHouse + Postgres
	./data/load.sh sample

load-full:       ## 100M rows -> ClickHouse only
	./data/load.sh full

ch:              ## open clickhouse-client shell
	docker exec -it ch clickhouse-client

pg:              ## open psql shell
	docker exec -it pg psql -U postgres -d bench

status:          ## containers + table sizes
	@docker ps --format 'table {{.Names}}\t{{.Status}}'
	@docker exec ch clickhouse-client -q "SELECT database, table, sum(rows) rows, formatReadableSize(sum(data_compressed_bytes)) compressed, formatReadableSize(sum(data_uncompressed_bytes)) raw, count() parts FROM system.parts WHERE active AND database='bench' GROUP BY ALL FORMAT PrettyCompact" 2>/dev/null || true
