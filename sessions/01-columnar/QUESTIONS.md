# Session 1: Interview questions

Answer in your own words (out loud, or write below each one). Use numbers you measured today.

1. An interviewer asks: "Why is ClickHouse 10-100x faster than Postgres on analytics queries?"
   Give at least **3 distinct reasons** and point to something you saw in this session for each.
   - we do compression of data
   - there's this so called granule? basically the row is grouped per grnaule (group of row). Then query uses binary search
   - per column instead of per row (?)

2. What is a **granule**, and why is ClickHouse's primary index called *sparse*? What's the trade-off
   compared to a B-tree index in Postgres? (Think: point lookups.)
   - no idea. too much new terms here. At least granule is group of row

3. You have a table ordered by `(CounterID, EventDate, UserID)`. A query filters only on `UserID`.
   What happens, and what are 2 ways to make it fast?
   - I have no idea what happen

4. Why did some columns compress 100x+ and others barely 3x? How does `ORDER BY` affect compression?
   - I have no idea. maybe helping with the search as they are... in order? so binary search can be done?

5. A teammate inserts one row at a time, 1000 times/sec. Based on what you saw in `system.parts`
   and `system.part_log`, what goes wrong, and why?
   - no idea

---
_Answers:_
