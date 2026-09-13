# 5.2 Find the idle GPU

<div class="ws-meta" markdown>
<span>**Time:** 10 min</span>
<span>**Ends with:** the notebook gone, `consolidateAfter` tightened, and Karpenter reclaiming two empty nodes while you watch</span>
</div>

You have three GPU nodes. One is serving, one is empty since the scale-down, and one has had a pod on it for an hour doing nothing. Find that one without knowing its name.

## The query

Prometheus (still port-forwarded on 9090 from Lab 2), or Grafana → Explore:

```bash
curl -sG 'localhost:9090/api/v1/query' --data-urlencode \
  'query=avg_over_time(DCGM_FI_DEV_GPU_UTIL{pod!="", namespace!="gpu-operator"}[10m]) < 5' \
  | jq -r '.data.result[] | "\(.metric.namespace)/\(.metric.pod)  on \(.metric.Hostname)  util_10m=\(.value[1])%"'
```

<div class="ws-output" markdown>
```text
default/forgotten-notebook  on ip-10-0-5-140.ec2.internal   util_10m=0%
vllm/vllm-7b9d6c4f8-tq2xm   on ip-10-0-23-77.ec2.internal  util_10m=0%
```
</div>

Two GPUs with a pod attached and under 5% utilisation over the last ten minutes. That is the alert from the talk, run by hand — and it's honest: the load test ended a while ago, so **your serving replica is idle too**. Both lines cost a dollar an hour. The difference is that one of them is a decision you made (`minReplicaCount: 1` — you're paying for readiness; for a dev environment you'd set it to 0 and let KEDA scale from zero) and the other is nobody's decision at all.

Is the second one really idle, or is it a batch job between phases? Ask the pod:

```bash
kubectl get pod forgotten-notebook -o custom-columns='NAME:.metadata.name,TEAM:.metadata.labels.team,AGE:.metadata.creationTimestamp,GPU:.spec.containers[0].resources.limits.nvidia\.com/gpu,CMD:.spec.containers[0].command'
```

<div class="ws-output" markdown>
```text
NAME                 TEAM           AGE                    GPU   CMD
forgotten-notebook   data-science   2026-09-17T15:04:40Z   1     [sleep infinity]
```
</div>

`sleep infinity` holding a whole GPU, owned by a team that isn't in the room. In real life this is a Jupyter kernel that finished a notebook two days ago. You have three options and you'll use them in this order in production:

1. **Talk to the owner** (the `team` label — this is why you enforce labels).
2. **Move it to a shared pool** — a time-sliced NodePool where it costs a quarter of a GPU, using a `nodeSelector` on `gpu-tier: shared`.
3. **Evict it** — with a `priorityClass` that lets real workloads preempt it, or an idle-reaper that deletes GPU pods under 5% for an hour.

Today, option 3, by hand:

```bash
kubectl delete pod forgotten-notebook
```

## Now let Karpenter do its job

Node B is empty. Node C has been empty since replica 2 scaled down. Both are waiting out the workshop's 2-hour `consolidateAfter`. Tighten it to a production-ish value and watch:

```bash
kubectl patch nodepool gpu --type merge -p '{"spec":{"disruption":{"consolidateAfter":"1m"}}}'
kubectl get nodeclaims -w
```

<div class="ws-output" markdown>
```text
NAME        TYPE        CAPACITY    ZONE         NODE                          READY   AGE
gpu-lk7m2   g6.xlarge   spot        us-east-1b   ip-10-0-23-77.ec2.internal    True    96m
gpu-9wq4d   g5.xlarge   spot        us-east-1a   ip-10-0-5-140.ec2.internal    True    58m
gpu-c3ptx   g6.xlarge   on-demand   us-east-1c   ip-10-0-31-9.ec2.internal     True    22m
gpu-9wq4d   g5.xlarge   spot        us-east-1a   ip-10-0-5-140.ec2.internal    True    59m
gpu-c3ptx   g6.xlarge   on-demand   us-east-1c   ip-10-0-31-9.ec2.internal     True    23m
gpu-9wq4d   g5.xlarge   spot        us-east-1a   ip-10-0-5-140.ec2.internal    True    60m    (Terminating)
gpu-c3ptx   g6.xlarge   on-demand   us-east-1c   ip-10-0-31-9.ec2.internal     True    24m    (Terminating)
```
</div>

Within a minute or two both empty nodes are cordoned, drained and terminated. Node A stays — it has a vLLM replica on it and the policy is `WhenEmpty`. Karpenter's log tells the story:

```bash
kubectl -n karpenter logs deploy/karpenter --since=5m | grep -iE 'disrupt|deleted nodeclaim' | jq -r '[.time, .message] | @tsv'
```

<div class="ws-output" markdown>
```text
2026-09-17T15:24:31Z  disrupting nodeclaim(s) via delete, terminating 1 nodes (0 pods) ip-10-0-5-140.ec2.internal/g5.xlarge/spot
2026-09-17T15:25:48Z  deleted nodeclaim
2026-09-17T15:25:49Z  disrupting nodeclaim(s) via delete, terminating 1 nodes (0 pods) ip-10-0-31-9.ec2.internal/g6.xlarge/on-demand
2026-09-17T15:27:02Z  deleted nodeclaim
```
</div>

!!! quirk "The budget you set in Lab 1"
    `disruption.budgets: [{nodes: "1"}]` means at most one node disrupted at a time — you'll see the two deletions staggered rather than simultaneous. On a 3-node GPU fleet that's the difference between "graceful" and "the whole pool went away at once".

Two GPU nodes gone, ~$2/hour saved, one command. That's lever #1 from the talk, and it's the same mechanism — `WhenEmpty` + `consolidateAfter` — you'd ship on Monday with a value between 5 and 30 minutes depending on how bursty your traffic is and how much a 9-minute cold start costs you.

## What's left

```bash
kubectl get nodes -l karpenter.sh/nodepool=gpu
kubectl -n vllm get pods
```

<div class="ws-output" markdown>
```text
NAME                         STATUS   ROLES    AGE   VERSION
ip-10-0-23-77.ec2.internal   Ready    <none>   98m   v1.36.1-eks-abc1234

NAME                    READY   STATUS    RESTARTS   AGE
vllm-7b9d6c4f8-tq2xm    1/1     Running   0          55m
```
</div>

One node, one model, still answering requests. Exactly what you're paying for.

[Next: 5.3 Cost levers →](03-cost-levers.md)
