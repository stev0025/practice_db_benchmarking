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
1. 

2. 

3. 

4. 

5. 
