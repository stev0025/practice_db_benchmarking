# AGENTS.md: Read this first (any AI agent, any model)

This repo is a **personal training lab**, not a product. The learner (Steven) is preparing for a
**ClickHouse Cloud Performance Engineering** interview (~2 weeks from 2026-10-06). The role targets
distributed OLAP limits, benchmarking, capacity sizing, kernel/engine bottlenecks, chaos engineering.
Basic SQL/CRUD is explicitly NOT the goal.

## Learner profile
- Strong: Linux, cloud, Python. Has used `htop`, `iostat` a few times.
- Weak: database internals. "I know the query and that's about it."
- Knows little Prometheus/Grafana -> we use ClickHouse's built-in `/dashboard` + `system.*` tables instead.
- sudo is allowed on this machine (perf, tc netem, drop_caches, cgroups).
- Machine: 16 cores, 30 GB RAM, NVMe, Docker 29, Ubuntu.

## How to teach (non-negotiable)
1. **Make him SEE it.** Every concept is paired with a command whose output visibly proves it
   (granule counts, files on disk, htop saturating, latency knee on a plot). No theory dumps.
2. **Half-built.** Agent scaffolds everything; learner fills in key pieces marked `TODO(you)`.
   Don't fill in the TODOs for him unless he asks. Give hints first.
3. **30-minute sessions.** Each session README is timed. Keep it tight.
4. **End every session with interview questions** (in the session's `QUESTIONS.md`). Have him
   answer out loud/in writing, then grade answers honestly and correct misconceptions.
5. **After every session, update**: `PROGRESS.md` (status, what he struggled with, answers quality)
   and `INTERVIEW_CHEATSHEET.md` (crisp talking points he learned, in his own words where possible).
6. **Destroy, don't just add.** Phase 2 is break-fix: agents sabotage the setup silently and he
   diagnoses with `system.*` tables + OS tools only. Also wipe-and-rebuild drills. Resist the urge
   to keep piling on new files. Removing/breaking things is part of the curriculum.
7. Be concise. He'd rather run a command than read a paragraph.

## Phase 2 secrecy rules
- Sabotage scripts live in `sabotage/` (created when Phase 2 starts). **Never print their contents
  or name the fault** to the learner before he has diagnosed it. Give only the symptom.
- Log every sabotage you run (what, when, how to revert) in `sabotage/LOG.md` so the next agent
  can revert or grade. He has agreed not to read `sabotage/`.

## Where things are

> **Rule:** every agent doc, plan, note and skill for this project lives **inside this repo**.
> Don't put anything in `~/.gemini/...` or other global agent dirs. Project skills go in
> `.agents/skills/<name>/SKILL.md`, project rules in `AGENTS.md`. Scratch files go in `scratch/` (gitignored).

| Path | What |
|---|---|
| `PLAN.md` | The full 2-phase curriculum (source of truth for what comes next) |
| `README.md` | Human entry point (4-line how-to) |
| `.agents/skills/` | Project-scoped agent skills (empty for now) |
| `scratch/` | Agent scratch space, gitignored |
| `PROGRESS.md` | **Current status. Read this to know where to resume.** |
| `INTERVIEW_CHEATSHEET.md` | Growing doc of interview talking points |
| `Makefile` | `make help`, `up`, `down`, `nuke`, `load-sample`, `load-full`, `ch`, `pg`, `status` |
| `single/` | Compose: 1 ClickHouse 25.8 node (`ch`) + Postgres 16 (`pg`). Used in sessions 1-4 |
| `cluster/` | (Session 5) 2 shards x 2 replicas + 3 Keeper. Not built yet |
| `data/load.sh` | `sample` = 10M rows into CH + 15-col subset into PG; `full` = 100M rows CH only |
| `data/parquet/` | ClickBench `hits_0..99.parquet` (1M rows/file, 1 day/file, 14 GB total, gitignored) |
| `data/sql/` | `ch_hits.sql` (105-col ClickBench schema, `bench.hits`), `pg_hits.sql`, `clickbench_queries.sql` (43 standard queries) |
| `sessions/NN-*/` | Per-session `README.md` (steps), `TODO*` files, `QUESTIONS.md` |
| `bench/`, `tools/` | (Sessions 3, 6) Benchmark harness, perf/chaos helpers. Not built yet |

## Environment facts / gotchas
- ClickHouse container runs as host uid 1000 (`user:` in compose) so `single/volumes/ch` is readable
  without sudo, and the entrypoint doesn't try to chown the read-only parquet mount (that crashed it).
- `default` user, no password (`CLICKHOUSE_SKIP_USER_SETUP=1`). HTTP 8123, native 9000.
- Inside CH, parquet is at `file('parquet/hits_N.parquet')` (user_files path).
- Postgres: user `postgres`, pw `bench`, db `bench`. Tuned (shared_buffers 4GB, 8 parallel workers)
  so the comparison is not a strawman.
- `bench.hits` ORDER BY = `(CounterID, EventDate, UserID, EventTime, WatchID)` (ClickBench default).
- Postgres volume is owned by uid 70; `make nuke` deletes volumes via a throwaway container.
