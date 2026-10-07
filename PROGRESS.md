# PROGRESS: where we are (agents: update after every session)

**Current position:** Session 2 done. **Next: Session 3** → `sessions/03-benchmarking/README.md` (to build)

| # | Session | Status | Date | Notes (struggles, answer quality, follow-ups) |
|---|---|---|---|---|
| 0 | Prep: lab + data | ✅ done | 2026-10-06 | ClickHouse loaded 10M rows in ~4s; Postgres COPY of 15 cols took ~34s |
| 1 | Why columnar is fast | ✅ done | 2026-10-07 | Avg ~5/10 on questions. Strong: part/granule/sparse-index intuition, derived generic exclusion himself. Weak: compression (Q4), granule vs mark vs block, point-lookup trade-off. Redo Q4. |
| 2 | Where time goes | ✅ done | 2026-10-07 | Score 27.5/50 (5.5/10). Strong: OS metrics, page cache cold vs warm (OSReadBytes vs OSReadChars), CPU vs Real time. Weak: internal caches (mark_cache), max_threads concurrency, spill to disk (external aggregation). |
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
- Learns best by running a query then reasoning out loud (derived binary vs generic exclusion himself). Keep the predict-then-run format.
- Mixes up vocabulary: part vs partition, granule vs block vs mark, database vs schema. Re-check terms early in next sessions.
- Repeated the clone-to-new-machine setup issues: data/parquet root-owned (Docker created it), load-full wipes the 10M sample. Consider `mkdir -p data/parquet` in Makefile `up`.
- Actually noticed htop maxing all cores on ClickHouse: good instinct, follow up in Session 2.
