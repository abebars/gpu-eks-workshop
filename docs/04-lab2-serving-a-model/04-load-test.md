# 4.4 Load test

<div class="ws-meta" markdown>
<span>**Time:** 6 min</span>
<span>**Creates:** ConfigMap `k6-load` (the script), Job `k6-baseline` (60 s, 24 virtual users)</span>
</div>

Before autoscaling anything, see what one replica does under more load than it can batch. The load generator is [k6](https://grafana.com/docs/k6/latest/), running as a Job on the **CPU** nodes — it has no GPU toleration, so it can never land on the node it's testing.

```yaml title="modules/04-vllm/k6-script.yaml"
--8<-- "modules/04-vllm/k6-script.yaml"
```

24 virtual users, each sending a chat completion and immediately sending the next one when it returns. The server admits 16 at a time (`--max-num-seqs`), so 8 requests are always **waiting**.

```bash
kubectl apply -f modules/04-vllm/k6-script.yaml
make baseline
```

`make baseline` applies `k6-baseline-job.yaml` (60 seconds) and follows its log. While it runs, in another terminal, watch vLLM's own view of the queue:

```bash
watch -n2 "curl -s localhost:8000/metrics | grep -E '^vllm:num_requests_(running|waiting)'"
```

(No `watch` on macOS? `brew install watch`, or `while true; do clear; curl -s localhost:8000/metrics | grep -E '^vllm:num_requests_(running|waiting)'; sleep 2; done`.)

<div class="ws-output" markdown>
```text
vllm:num_requests_running{engine="0",model_name="qwen2.5-1.5b"} 16.0
vllm:num_requests_waiting{engine="0",model_name="qwen2.5-1.5b"} 8.0
```
</div>

16 running, 8 waiting, for the whole minute. The replica is saturated by design. When k6 finishes:

<div class="ws-output" markdown>
```text
  █ TOTAL RESULTS

    checks_total.......: 418     6.9/s
    checks_succeeded...: 100.00% 418 out of 418
    checks_failed......: 0.00%   0 out of 418

    ✓ status is 200

    HTTP
    http_req_duration..............: avg=3.41s min=0.71s med=3.36s max=5.88s p(90)=4.72s p(95)=5.11s
    http_req_failed................: 0.00%  0 out of 418
    http_reqs......................: 418    6.9/s

    EXECUTION
    iterations.....................: 418    6.9/s
    vus............................: 24     min=24 max=24
```
</div>

Write down two numbers from *your* run: **`http_reqs` per second** (throughput) and **`p(95)`** (tail latency). Yours will differ from the above — L4 vs A10G, Spot vs On-Demand, prompt mix — and that's fine. These are the baseline for one replica. Everything in 4.5 is about moving them.

??? question "Why is p95 five seconds for a tiny model?"
    Because 8 of 24 requests spend their time in the queue before they even start generating. Time-to-first-token is what the queued users feel. Run the same test with `--max-num-seqs 64` and p95 drops — until KV cache fills and it climbs again. Batching depth is a latency/throughput dial, not a free lunch; the autoscaler is how you add *capacity* instead of turning the dial.

## What the GPU saw

Peek at the DCGM metric for node A during the test — this is the utilisation number Module 5 is built around:

```bash
curl -sG 'localhost:9090/api/v1/query' --data-urlencode 'query=max_over_time(DCGM_FI_DEV_GPU_UTIL[2m])' | jq -r '.data.result[] | "\(.metric.Hostname)  gpu_util_max=\(.value[1])%"'
```

<div class="ws-output" markdown>
```text
ip-10-0-23-77.ec2.internal  gpu_util_max=97%
ip-10-0-5-140.ec2.internal  gpu_util_max=0%
```
</div>

Node A pegged; node B (the notebook) at zero. Hold that thought.

[Next: 4.5 Autoscale →](05-autoscale.md)
