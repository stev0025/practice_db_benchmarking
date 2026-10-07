# PROGRESS: where we are (agents: update after every session)

**Current position:** Session 0 done (lab built, data loaded). **Next: Session 1** → `sessions/01-columnar/README.md`

| # | Session | Status | Date | Notes (struggles, answer quality, follow-ups) |
|---|---|---|---|---|
| 0 | Prep: lab + data | ✅ done | 2026-10-06 | ClickHouse loaded 10M rows in ~4s; Postgres COPY of 15 cols took ~34s |
| 1 | Why columnar is fast | ⏳ next | | |
| 2 | Where time goes | ☐ | | |
| 3 | Benchmarking without lying | ☐ | | |
| 4 | Capacity sizing | ☐ | | |
| 5 | Distributed (cluster/) | ☐ | | |
| 6 | Kernel + first chaos | ☐ | | |
| P2 | Phase 2 break-fix | ☐ | | see PLAN.md |

## State of the lab right now
- `make up` running: `ch` (ClickHouse 25.8) + `pg` (Postgres 16)
- `bench.hits` in ClickHouse = 10M rows (sample). Postgres `hits` = 10M rows, 15 columns.
- All 100 parquet files downloaded (`make load-full` is ready for Session 3/4).

## Learner observations (for future agents)
- (none yet)
