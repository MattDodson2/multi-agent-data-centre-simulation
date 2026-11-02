# Experimental Analysis — Multi-Agent Data Centre Simulation

## Overview

This document evaluates a **NetLogo multi-agent simulation** of a data centre. Virtual servers receive requests independently, while autonomous service agents travel between servers and process queued work. The experiments examine how agent availability, the frequency of incoming requests, and the amount of time each request takes to process all affect queue backlogging, throughput and resource use.

## Model and measurement methodology

The simulation uses discrete time steps (*ticks*). At each tick, each server has a chance of receiving one new request, with the probability determined by the `request-arrival-prob` variable. An available service agent randomly selects a server with at least one unreserved request, reserves that request, travels to the server and processes it for a certain amount of time. The processing time is determined by a randomly generated integer that falls within the user's specified service-time range.

All experiments were run in **NetLogo 6.4.0** using **BehaviorSpace**, with **five repetitions per configuration** and **1,000 ticks per run**. Each table reports the **mean across the five runs**. The runs used distinct, reproducible random seeds derived from the BehaviorSpace run number. Only one experimental factor (or a paired minimum/maximum service-time range) changed within each experiment to maintain consistency.

### Reported metrics

| Metric | Definition |
|---|---|
| Mean queue length | `mean-queue-over-time`: mean of the average queue length per server, sampled over the 1,000 ticks of a run. |
| Maximum queue length | `max-queue`: largest server queue still remaining**at tick 1,000** (the end of the test run). |
| Tasks completed | `total-tasks`: total requests fully processed by all agents at tick 1,000. |
| Tasks per agent | `total-tasks / count service-agents`: mean completed tasks per available agent. |
| Processing utilisation | `avg-utilisation`: proportion of total agent-ticks spent **processing** expressed as a percentage. This excludes travelling and waiting times. |
| Rejected requests | `dropped-requests`: incoming requests declined because their destination server's queue was already full. |

**Interpretation note:** Processing utilisation is not the same as total agent activity. A low value can coexist with extensive travel time. The experiments do not record a fully detailed breakdown of travel versus time spent completely idle.

## Experiment 1 — Agent allocation

**Question:** How does the number of service agents affect throughput, congestion and per-agent productivity?

**Fixed parameters:** 9 servers; arrival probability = 2% per server per tick; service time = 1–5 ticks; queue capacity = 20 per server. Agent counts tested: **1, 2, 5, 10 and 20** (25 runs in total).

### Results

| Agents | Mean queue length | Final maximum queue | Tasks completed | Tasks per agent | Processing utilisation | Rejected requests |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 8.97 | 20.0 | 17.4 | 17.40 | 5.00% | 8.0 |
| 2 | 7.50 | 19.6 | 37.0 | 18.50 | 5.37% | 4.6 |
| 5 | 5.27 | 17.2 | 90.0 | 18.00 | 5.39% | 1.2 |
| 10 | 2.07 | 6.8 | 162.4 | 16.24 | 4.98% | 0.0 |
| 20 | 1.01 | 2.4 | 164.2 | 8.21 | 2.49% | 0.0 |

### Interpretation

Increasing the agent count reduced congestion and generally improved the throughput of tasks completed. Moving from **1 to 10 agents** reduced mean queue length from **8.97 to 2.07**, a reduction of around **77%**. Average rejected requests fell to zero in the 10-agent and 20-agent configurations of the experiment.

However, comparing the performance difference between the **10- and 20-agent** configurations does highlight a point of diminishing returns. Doubling the number of agents increased average completed tasks from **162.4 to 164.2** (about **1.1%**), while tasks per agent fell from **16.24 to 8.21**. The additional agents did however lower the mean queue length further, from 2.07 to 1.01. Therefore, the most "optimal" configuration depends on whether the system's priority is maximising throughput-per-agent or minimising queue lengths.

Based on these configurations, **10 agents** seems to be the preferable setting due to the relatively negligible improvement in performance and noticeable drop of agent utilisation when increasing the number of agents to 20, though this isn't a mathematically produced optimum.

## Experiment 2 — Workload scalability

**Question:** How does increasing request arrival probability affect congestion, completed work and rejection rates?

**Fixed parameters:** 9 agents; 9 servers; service time = 1–5 ticks; queue capacity = 20 per server. Arrival probabilities tested: **0.02, 0.10, 0.25, 0.50 and 1.00** (25 runs in total).

### Results

| Arrival probability | Mean queue length | Final maximum queue | Tasks completed | Tasks per agent | Processing utilisation | Rejected requests |
|---:|---:|---:|---:|---:|---:|---:|
| 0.02 | 1.59 | 5.0 | 152.8 | 16.98 | 5.14% | 0.0 |
| 0.10 | 17.40 | 20.0 | 158.0 | 17.56 | 5.21% | 571.4 |
| 0.25 | 19.03 | 20.0 | 155.4 | 17.27 | 5.10% | 1,944.0 |
| 0.50 | 19.52 | 20.0 | 161.2 | 17.91 | 5.27% | 4,149.4 |
| 1.00 | 19.79 | 20.0 | 162.6 | 18.07 | 5.46% | 8,657.2 |

### Interpretation

The data reveals a sharp transition from manageable queues to excessive overload somewhere **between arrival probabilities 0.02 and 0.10**. At 0.02, mean queue length was 1.59 and no requests were rejected, while at 0.10, mean queue length rose to 17.40 and the system rejected an average of 571.4 requests per run.

As demand increased further, queues remained close to the capacity of 20 and rejected requests rose sharply. At probability **1.00**, each of the 9 servers received an arrival attempt every tick, or **9,000 attempted requests per run**. Of these, an average of **8,657.2** were rejected: approximately **96.2%**. Yet completed tasks changed only from **152.8** at probability 0.02 to **162.6** at probability 1.00 (about **6.4%** more).

The cap prevented queue lengths from growing without bound, but it did **not** increase processing capacity. The near-flat throughput alongside substantial rejection indicates a system-level bottleneck. Low processing utilisation (approximately 5%) is consistent with travel and allocation overhead but this data alone doesn't highlight a specific cause of this performance limitation.

## Experiment 3 — Processing complexity

**Question:** How do longer task durations affect throughput, congestion and processing utilisation?

**Fixed parameters:** 9 agents; 9 servers; arrival probability = 0.02; queue capacity = 20 per server. The three service-time ranges tested were **1–5**, **5–10** and **10–20 ticks** (15 runs in total).

### Results

| Service time | Mean queue length | Final maximum queue | Tasks completed | Tasks per agent | Processing utilisation | Rejected requests |
|---|---:|---:|---:|---:|---:|---:|
| 1–5 ticks | 1.59 | 5.0 | 152.8 | 16.98 | 5.14% | 0.0 |
| 5–10 ticks | 2.43 | 8.6 | 137.8 | 15.31 | 11.45% | 0.0 |
| 10–20 ticks | 3.80 | 9.8 | 120.8 | 13.42 | 20.70% | 0.0 |

### Interpretation

Longer tasks produced greater congestion and fewer completed requests. Raising the service-time range from **1–5** to **10–20 ticks** increased mean queue length from **1.59 to 3.80** (about **138%**) and reduced completed tasks from **152.8 to 120.8** (about **-21%**).

Processing utilisation rose from **5.14% to 20.70%**, meaning agents spent a greater portion of their time executing these longer tasks than they did in previous configurations. Despite the deterioration in queueing and throughput, **no requests were rejected** in the tested configurations.

## Cross-experiment findings

Three consistent lessons emerge from these experiments:

1. **More resources help, but returns diminish.** Increasing agent numbers reduced congestion, while gains in total completed tasks became small at higher agent counts.
2. **Limiting capacity protects queues from becoming overwhelming, at the cost of service quality .** At high arrival probabilities, the hard queue cap limited queue growth but caused high rejection rates because demand exceeded completed-work throughput.
3. **Processing utilisation requires context.** More processing time per task increased measured utilisation while reducing throughput, showing utilisation alone is not a complete measure of efficiency.

These findings support further investigation into the cost of **travelling between servers** and the effect of **random server selection** on throughput.

## Limitations and possible improvements

- **Small sample size:** Five runs per configuration provide an initial indication of performance, not a mathematically-based model showing a universal optimum.
- **Restricted configurations:** The experiments use nine servers and a limited selection of agent counts, arrival rates and processing times. Findings may change under other settings.
- **No aggregate travel metric exported:** The model records `travel-ticks` and `idle-ticks` per agent, but leaves out their averages and totals. The suspected travel bottleneck therefore remains a **hypothesis**, not a measured influence on the system's performance.
- **End-of-run maximum:** The reported maximum queue is a snapshot at tick 1,000, not the peak length the queue reached during the whole simulation.
- **Simple allocation policy:** Agents choose among eligible servers randomly. No shortest-distance, longest-queue-first, priority-queue or adaptive scheduling comparison was performed.
- **Simplified workload:** Arrivals and service times are abstracted figures and not measurements from a real data centre. The model does not consider factors like network failures, service priorities, hardware constraints, or other realistic influences on data centre performance.

My next experiments would export total **busy**, **travelling** and **idle** ticks to confirm if travel time is the cause of the throughput bottleneck as hypothesised. Additionally, I would compare my current **random allocation** policy with **nearest-server** and **longest-queue-first** strategies, while maintaining consistent arrival conditions, to assess potential optimisation techniques.

## Reproducibility and source data

All five CSV exports identify **NetLogo 6.4.0** and a stopping step of **1,000 ticks**. The experiments comprise of **65 runs** in total: 25 (agent allocation), 25 (workload scalability) and 15 (processing complexity). BehaviorSpace captured metrics **at the end of each run**; reported values are arithmetic means across repetitions.

The **0.02 arrival-probability** condition in Experiment 2 and the **1–5 tick** condition in Experiment 3 used identical settings and corresponding runs returned identical results, providing a useful repeatability check.

Raw exports (intended paths in the GitHub repository):

- `experiments/experiment-1-agent-allocation-table.csv`
- `experiments/experiment-2-workload-scalability-table.csv`
- `experiments/experiment-3A-short-tasks-table.csv`
- `experiments/experiment-3B-medium-tasks-table.csv`
- `experiments/experiment-3C-long-tasks-table.csv`

The CSVs retain the run-level results, including variation between repetitions. This document summarises those measurements rather than replacing the raw evidence.

## Conclusion

This simulation demonstrates how **agent numbers**, **incoming demand** and **task duration** jointly influence a queue-based, multi-agent service system. Under the baseline workload, increasing the number of agents improved congestion and throughput, though the throughput benefits began to diminish beyond 10 agents. Raising incoming demand caused significant queue congestion and substantial request rejection, while increasing task durations lowered throughput despite higher measured processing utilisation.

The experiments provide evidence of the model's performance in these conditions. They do not establish a universally optimal configuration or identify travel overhead as the sole cause of limited throughput. The results instead motivate more targeted experiments into movement optimisation and alternative task-allocation policies.
