# 4.5 Autoscale

<div class="ws-meta" markdown>
<span>**Time:** 15 min (most of it watching a node boot)</span>
<span>**Creates:** KEDA `ScaledObject/vllm` (which creates `HPA/keda-hpa-vllm`), Job `k6-load` (15 min), a third GPU node</span>
</div>

CPU is a useless signal for a GPU server: the GPU can be saturated while the container's CPU sits at 20%. You scale a model server on **work in flight** — and the metrics for that are already in Prometheus. KEDA turns a PromQL query into an HPA.

## The ScaledObject

```yaml title="modules/04-vllm/scaledobject.yaml"
--8<-- "modules/04-vllm/scaledobject.yaml"
```

- **`query`** — running + waiting across all replicas of this model. Why not just the queue? Because `waiting` is **0** until a replica hits `--max-num-seqs`, then jumps; it's a saturation alarm, not a load signal. In-flight requests is smooth and proportional. (KV-cache usage is the other good choice for memory-bound models.)
- **`threshold: "12"`** with `metricType: AverageValue` — target 12 in-flight *per replica*. HPA math: `desired = ceil(24 / 12) = 2`.
- **`minReplicaCount: 1`, `maxReplicaCount: 2`** — a hard cap. Between this and the NodePool's `limits.nvidia.com/gpu`, nothing in this lab can run away.
- **`behavior`** — scale up immediately, one pod at a time; scale down only after 5 quiet minutes. A GPU replica costs minutes to start; you never want to flap.

```bash
kubectl apply -f modules/04-vllm/scaledobject.yaml
kubectl -n vllm get scaledobject,hpa
```

<div class="ws-output" markdown>
```text
NAME                            SCALETARGETKIND      SCALETARGETNAME   MIN   MAX   READY   ACTIVE   FALLBACK   AGE
scaledobject.keda.sh/vllm       apps/v1.Deployment   vllm              1     2     True    False    False      6s

NAME                                                REFERENCE         TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/keda-hpa-vllm   Deployment/vllm   0/12 (avg)     1         2         1          6s
```
</div>

`READY True`: KEDA reached Prometheus and the query returned. `ACTIVE False`: no load, nothing to do. Note that KEDA **created and owns** the HPA — never add a second autoscaler for the same Deployment. KEDA's admission webhook refuses a ScaledObject for a workload that already has an HPA, and two autoscalers on one Deployment would fight.

!!! quirk "KEDA's Prometheus address"
    `serverAddress` is the in-cluster Service of the base stack's Prometheus: `http://kube-prometheus-stack-prometheus.monitoring.svc:9090`. If your ScaledObject shows `READY False`, `kubectl -n vllm describe scaledobject vllm` — nine times out of ten it's this URL or a query that returns no series (check the `model_name` label matches `--served-model-name`).

## Put it under load

Set up your watches first — three panes, or one `watch`:

```bash
watch -n5 'kubectl -n vllm get hpa; echo; kubectl -n vllm get pods -o wide; echo; kubectl get nodeclaims'
```

(macOS without `watch`: run the three `kubectl get … -w` commands in three panes instead.)

Then start the 15-minute load job (long enough for a cold node to join *and* serve for a few minutes):

```bash
make load-test
```

Here's the sequence, with typical times from the start of the load:

<div class="ws-output" markdown>
```text
# 0:30 — HPA sees 24 in flight / 12 target → wants 2
NAME            REFERENCE         TARGETS        MINPODS   MAXPODS   REPLICAS
keda-hpa-vllm   Deployment/vllm   24/12 (avg)    1         2         2

# 0:45 — replica 2 is Pending: node A has vllm-1, node B has the notebook
NAME                    READY   STATUS    RESTARTS   AGE     NODE
vllm-7b9d6c4f8-tq2xm    1/1     Running   0          21m     ip-10-0-23-77.ec2.internal
vllm-7b9d6c4f8-zr8hk    0/1     Pending   0          15s     <none>

# 0:50 — Karpenter launches node C
NAME        TYPE        CAPACITY    ZONE         NODE                          READY   AGE
gpu-lk7m2   g6.xlarge   spot        us-east-1b   ip-10-0-23-77.ec2.internal    True    78m
gpu-9wq4d   g5.xlarge   spot        us-east-1a   ip-10-0-5-140.ec2.internal    True    41m
gpu-c3ptx   g6.xlarge   on-demand   us-east-1c                                 Unknown 4s

# ~3:30 — node C initialised; replica 2 goes ContainerCreating (image pull, no warm cache this time)
# ~7:00 — image pulled; vLLM starts, downloads weights
# ~9:00 — replica 2 Ready; HPA target drops to 12/12
```
</div>

Every step of that chain is something you built: the PodMonitor feeds Prometheus, Prometheus feeds KEDA, KEDA drives the HPA, the HPA raises replicas, the Pending pod wakes Karpenter, the NodePool tells it what to buy, the EC2NodeClass what to boot, the Operator's DaemonSets make the GPU appear, and the startupProbe keeps kubelet patient while vLLM loads.

While replica 2 is starting, go to [4.6](06-cold-start.md) and time it. Come back here when it's `Ready`.

## When replica 2 is serving

Confirm both replicas take traffic:

```bash
curl -s 'localhost:9090/api/v1/query?query=vllm:num_requests_running' | jq -r '.data.result[] | "\(.metric.pod)  running=\(.value[1])"'
```

<div class="ws-output" markdown>
```text
vllm-7b9d6c4f8-tq2xm  running=12
vllm-7b9d6c4f8-zr8hk  running=12
```
</div>

24 in flight split across two replicas, **nothing waiting**. When the k6 job finishes, its summary is the blend of ~9 minutes on one replica and ~6 on two:

<div class="ws-output" markdown>
```text
    http_req_duration..............: avg=2.24s min=0.63s med=1.98s max=5.93s p(90)=3.71s p(95)=4.35s
    http_reqs......................: 6412   10.7/s
```
</div>

The blended p95 is worse than two-replica steady state because the first nine minutes were one replica. That's the honest cost of a cold scale-out, and the whole point of the next page. (Re-run `make baseline` now with both replicas up if you want the clean two-replica number.)

## And back down

Five minutes after the load stops, the HPA's scale-down window expires:

<div class="ws-output" markdown>
```text
keda-hpa-vllm   Deployment/vllm   0/12 (avg)    1   2   1
```
</div>

Replica 2 is gone. Node C is now **empty** — and with `consolidateAfter: 2h` it will sit there for two hours costing money. In Module 5 you fix that live.

??? tip "Watch it in Grafana instead"
    `make grafana` port-forwards Grafana to http://localhost:3000. Open **Dashboards → GPU Workshop: vLLM serving**. Module 5 does the full tour; you can peek now.

[Next: 4.6 Cold start, live →](06-cold-start.md)
