# 4.3 Smoke test

<div class="ws-meta" markdown>
<span>**Time:** 5 min</span>
</div>

The Service is cluster-internal. Port-forward it to your laptop in a **third terminal** and leave it running for the rest of the lab:

```bash
kubectl -n vllm port-forward svc/vllm 8000:80
```

## Is anyone home?

```bash
curl -s localhost:8000/v1/models | jq
```

<div class="ws-output" markdown>
```json
{
  "object": "list",
  "data": [
    {
      "id": "qwen2.5-1.5b",
      "object": "model",
      "created": 1789828385,
      "owned_by": "vllm",
      "max_model_len": 4096
    }
  ]
}
```
</div>

`id` is the `--served-model-name`. That's what goes in the request.

## Your first completion

```bash
curl -s localhost:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen2.5-1.5b",
    "messages": [{"role": "user", "content": "In one sentence, why is it hard to share a GPU between Kubernetes pods?"}],
    "max_tokens": 80,
    "temperature": 0.2
  }' | jq -r '.choices[0].message.content, "---", (.usage | tostring)'
```

<div class="ws-output" markdown>
```text
Sharing a GPU between Kubernetes pods is hard because GPUs are exposed to the scheduler as whole, indivisible devices, and the hardware provides no memory or fault isolation between processes unless it supports partitioning like MIG.
---
{"prompt_tokens":31,"total_tokens":74,"completion_tokens":43}
```
</div>

!!! checkpoint "Checkpoint 3 — a completion from your endpoint"
    Paste the sentence your model produced into the chat. Everyone's will be slightly different. That's the artifact.

    If you got `curl: (52) Empty reply` or a connection error, the port-forward died (they do) — restart it. If you got a JSON error about the model name, check `/v1/models`.

## Look at the metrics you'll autoscale on

vLLM exposes Prometheus metrics on the same port:

```bash
curl -s localhost:8000/metrics | grep -E '^vllm:(num_requests_running|num_requests_waiting|kv_cache_usage_perc|generation_tokens_total)'
```

<div class="ws-output" markdown>
```text
vllm:num_requests_running{engine="0",model_name="qwen2.5-1.5b"} 0.0
vllm:num_requests_waiting{engine="0",model_name="qwen2.5-1.5b"} 0.0
vllm:kv_cache_usage_perc{engine="0",model_name="qwen2.5-1.5b"} 0.0
vllm:generation_tokens_total{engine="0",model_name="qwen2.5-1.5b"} 43.0
```
</div>

`generation_tokens_total` is 43 — the completion you just got. The two `num_requests_*` gauges are the ones KEDA will watch. Confirm Prometheus is already scraping them (PodMonitor from 4.1):

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090 >/dev/null 2>&1 &
sleep 2
curl -s 'localhost:9090/api/v1/query?query=vllm:num_requests_running' | jq -r '.data.result[] | "\(.metric.pod)  running=\(.value[1])"'
```

<div class="ws-output" markdown>
```text
vllm-7b9d6c4f8-tq2xm  running=0
```
</div>

Prometheus has the series, labelled by pod. Leave that port-forward in the background; the autoscaler uses the in-cluster address, but you'll want it for [4.5](05-autoscale.md).

??? tip "Run the validator now if you want the full checklist"
    ```bash
    ./scripts/validate-lab2.sh
    ```
    It will flag the ScaledObject as missing — expected until 4.5.

[Next: 4.4 Load test →](04-load-test.md)
