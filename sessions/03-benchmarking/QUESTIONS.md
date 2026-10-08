# Session 3: Interview questions

Answer in your own words (out loud, or write below each one). Use numbers and metrics you observed today.

1. **The Concurrency "Knee":**
   What happens to QPS and p99 latency when you scale client concurrency past the system's core capacity? Describe the shape of the curve and explain the physical hardware reason behind it.

2. **Why Percentiles over Averages?**
   A candidate presents a benchmark: *"Our query latency averaged 45ms across 1,000 runs."* Why is this statement insufficient or misleading in distributed OLAP systems? What percentiles would you demand, and why?

3. **Warmup & Cache Isolation:**
   Explain why evaluating query performance without explicit cache handling produces invalid benchmarks. How does ClickBench specifically structure its benchmark methodology regarding cold vs warm runs?

4. **Coefficient of Variation ($CoV$):**
   What is $CoV$ and why is it essential when reporting benchmark numbers? If your benchmark has a $CoV$ of 35%, what does that tell you, and what steps should you take?

5. **Coordinated Omission:**
   What is "coordinated omission" in load testing, and why does a simple closed-loop benchmark script underestimate real-world p99 latency under heavy load?

---
_Answers:_
1. Query per second & p99 (the 99th percentile of list of query latency). from 1 -> # of cores, I believe the QPS increases a lot & p99 drops, as we basically utilize 100% of our cores. but when concurrency raises like 2x of the # of cores, QPS decreases & p99 increases. concurrency at # of cores & 2x # of cores are basically the same on utilizing max core resources, but because kernel has this so called hardware interrupt that constantly balance the # of tasks between cores, that balacing actually causing unnecessary problems which affects negatively

2. average / mean is not enough. we actually might average out tail cases. we should use variety of statistic measurement: min, max, p50, p90, p99. Each of them have important things. p90 and p99 are important for 1% and 10% of cases where the latencies shot up. max might be just edge cases we won't really care versus p99

3. the first run of a unique query is often a cold query, as those necessary data is seldom still stored in RAM but in disk instead. But sometimes it is still hot in RAM. That's why to make benchmarking fair, we clear cache on any query benchmarking run. dunno how ClickBench structure though

4. CoV is how varied our data is. The higher CoV, the more varied, the less consistent we can get the p50 result. CoV 35% is quite inconsistent. Likely because the resources are utilized by kernel for other tasks. Try to kill unnecessary tasks. then try to benchmark again. hopefully the CoV drops to <15%

5. I dunno honestly. seems like coordinated omission is a single concurrency problem? Dunno much