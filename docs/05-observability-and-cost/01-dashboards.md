# 5.1 Open the dashboards

<div class="ws-meta" markdown>
<span>**Time:** 5 min</span>
</div>

Grafana is cluster-internal. Port-forward it (the Makefile prints the password from the Terraform output):

```bash
make grafana
```

<div class="ws-output" markdown>
```text
Grafana → http://localhost:3000  (user: admin, password: gpu-workshop)
Forwarding from 127.0.0.1:3000 -> 3000
```
</div>

Open <http://localhost:3000>, sign in, then **Dashboards** in the left menu.

## NVIDIA DCGM Exporter Dashboard

The base stack imported the community dashboard **ID 12239**. Open it and set the time range to **Last 1 hour**. You're looking at three GPU nodes' worth of history:

- **GPU Utilization** — node A pegged at ~100% during the baseline test and again during the autoscale test; node C joining part-way through the second one; **node B flat at 0% the entire time**.
- **GPU Framebuffer Mem Used** — node A and C at ~21 GB (vLLM's `--gpu-memory-utilization 0.90` pre-allocation); node B at ~0.
- **GPU Temperature / Power** — rising with load; nowhere near limits on an A10G/L4 in EC2.

??? note "If the dashboard is empty or missing"
    - Missing entirely: **Dashboards → New → Import**, enter `12239`, pick the *Prometheus* data source, **Import**.
    - Present but no data: the dcgm-exporter ServiceMonitor isn't being scraped. Check **Status → Targets** in Prometheus (`localhost:9090/targets` from the port-forward you set up in 4.3) for `nvidia-dcgm-exporter`. The base stack sets `serviceMonitorSelectorNilUsesHelmValues: false` so it should be there; if not, that's the value to look at.

## GPU Workshop: vLLM serving

The dashboard you applied as a ConfigMap in 4.1 (the Grafana sidecar loads anything labelled `grafana_dashboard: "1"`). Open it; last 30 minutes.

Walk the panels against what you did in Lab 2:

| Panel | What you should see |
|-------|--------------------|
| **vLLM replicas** | 1 → 2 → 1 over the lab |
| **Requests in flight** | 24 flat during both load tests — this is the KEDA signal |
| **Requests: running vs waiting (per replica)** | Baseline: one replica, 16 running / 8 waiting. Autoscale: after replica 2 joins, 12/12 running and **0 waiting** |
| **Latency p95** | TTFT drops sharply when replica 2 joins; E2E p95 follows |
| **GPU utilization by node (DCGM)** | The same picture as the DCGM dashboard, one line per node |
| **GPU pod attribution (DCGM)** | `vllm/vllm-…` at ~100% during load; `default/forgotten-notebook` at **0** — that's the next page |
| **Tokens/s per replica** | Generation tokens/s roughly halves per replica when the second one joins — same total, shared |

!!! quirk "Where did per-pod attribution go?"
    If you left node A time-sliced in Module 3, the **GPU pod attribution** panel would be empty for it: DCGM cannot attribute a shared GPU to individual containers. That's a real operational cost of time-slicing — you keep node-level metrics but lose the ability to answer "who". It's one more reason sharing belongs in dev/test pools, not in the pool your on-call rotation is watching.

## Explore

For anything not on a dashboard, **Explore** with the Prometheus data source. Three queries to try — each is one line you could paste into an alert:

```promql
# per-node GPU utilisation, averaged over 5 minutes
avg by (Hostname) (avg_over_time(DCGM_FI_DEV_GPU_UTIL[5m]))
```

```promql
# p95 time-to-first-token across all replicas
histogram_quantile(0.95, sum(rate(vllm:time_to_first_token_seconds_bucket[2m])) by (le))
```

```promql
# tokens generated per second, per replica
sum by (pod) (rate(vllm:generation_tokens_total[1m]))
```

[Next: 5.2 Find the idle GPU →](02-idle-gpu.md)
