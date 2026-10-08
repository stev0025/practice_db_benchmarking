# Session 4: Interview questions

1. **Scaling:** You doubled cores from 8 to 16 and QPS rose only 1.3x. Give three possible causes and how you'd tell them apart.
2. **Sizing:** "1 TB/day raw, keep 1 year, 3 replicas." Walk through disk. What compression ratio do you assume and where did the number come from?
3. **Memory:** A GROUP BY hits `MEMORY_LIMIT_EXCEEDED`. List fixes in order of preference and the cost of each.
4. **OOM:** How do you distinguish ClickHouse's own limit from the kernel/cgroup OOM-killer?
5. **Headroom:** Why not size the cluster to run at 100% CPU at peak? What utilization do you target and why (link to the knee from Session 3)?

---
_Answers:_
