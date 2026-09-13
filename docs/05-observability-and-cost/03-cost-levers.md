# 5.3 Cost levers

<div class="ws-meta" markdown>
<span>**Time:** 5 min, discussion</span>
</div>

Everything you built today maps to a lever. Here's the ranking again with the exact knob you touched, so you can take it to your own cluster.

| # | Lever | Typical impact | The knob | Where you did it |
|---|-------|----------------|----------|------------------|
| 1 | **Don't idle** | 30–60% | `consolidationPolicy: WhenEmpty` + short `consolidateAfter`; KEDA `minReplicaCount: 0` for dev; the `< 5% for 30m` alert | [5.2](02-idle-gpu.md), [4.5](../04-lab2-serving-a-model/05-autoscale.md) |
| 2 | **Spot, diversified** | 60–70% on the GPU line | `karpenter.sh/capacity-type: [spot, on-demand]` + ≥4 instance types + quota for both | [2.2](../02-lab1-gpu-ready-eks/02-nodepool.md) |
| 3 | **Right-size** | 20–75% per workload | time-slicing ConfigMap + node label; `g6` (L4) instead of `g5` (A10G) for inference; MIG on A100/H100 | [3.2](../03-scheduling-and-sharing/02-time-slicing.md) |
| 4 | **Bin-pack** | 10–30% | `limits.nvidia.com/gpu` on the NodePool; no gratuitous AZ spread; `instance-gpu-count` matched to the model | [2.2](../02-lab1-gpu-ready-eks/02-nodepool.md) |
| 5 | **Pin AMIs** | avoids one bad day per quarter | `amiSelectorTerms: [{alias: al2023@v…}]` | [2.2](../02-lab1-gpu-ready-eks/02-nodepool.md) |
| 6 | **Shorten cold starts** | lets you run leaner on 1 and 4 | pre-pull DaemonSet, EBS throughput, weights off the critical path | [3.1](../03-scheduling-and-sharing/01-prepull.md), [4.6](../04-lab2-serving-a-model/06-cold-start.md) |

## Three questions to take back

Answer them for **your** platform, not this one:

1. **What's the 30-day average `DCGM_FI_DEV_GPU_UTIL` across your fleet?** If you don't know, that's the first dashboard. If it's under 40%, lever 1 and 3 pay for a quarter of platform work in a month.
2. **What happens when a Spot GPU node is reclaimed at 3 a.m.?** If the answer involves a human, you need a second replica, a PDB, and `terminationGracePeriodSeconds` — before you turn on Spot, not after.
3. **Who owns the `forgotten-notebook`s?** If GPU pods don't carry a `team` label, nobody does. Admission policy (Kyverno/Gatekeeper) that requires the label on any pod requesting `nvidia.com/gpu` is a one-afternoon change.

## Cost of *this* workshop

For the record, roughly what your account will show for today, all On-Demand worst-case:

| | Hours | $ |
|---|---|---|
| Base stack (overnight + session) | ~16 | ~9 |
| GPU node A | ~2.5 | ~2.5 |
| GPU node B (the notebook) | ~1.2 | ~1.2 |
| GPU node C (the scale-out) | ~0.4 | ~0.4 |
| NAT data (3 image pulls, weights) | | ~1.5 |
| **Total** | | **~$15** |

…provided you run [Clean up](../cleanup.md) before you close the laptop. Which is the last thing we do together.

[Next: Module 6 · Wrap-up →](../06-wrap-up/index.md)
