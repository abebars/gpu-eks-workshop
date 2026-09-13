# 4.1 Deploy vLLM

<div class="ws-meta" markdown>
<span>**Time:** 3 min to apply; the server is ready ~3–4 min later</span>
<span>**Creates:** namespace `vllm`, Deployment, Service, PodMonitor, a Grafana dashboard</span>
</div>

Apply everything, then read the manifest in [4.2](02-manifest.md) while the model loads.

```bash
kubectl apply -f modules/04-vllm/namespace.yaml
kubectl apply -f modules/04-vllm/deployment.yaml \
              -f modules/04-vllm/service.yaml \
              -f modules/04-vllm/podmonitor.yaml
kubectl apply -f modules/05-observability/vllm-dashboard-configmap.yaml
```

<div class="ws-output" markdown>
```text
namespace/vllm created
deployment.apps/vllm created
service/vllm created
podmonitor.monitoring.coreos.com/vllm created
configmap/gpu-workshop-vllm-dashboard created
```
</div>

```bash
kubectl -n vllm get pods -o wide -w
```

<div class="ws-output" markdown>
```text
NAME                    READY   STATUS              RESTARTS   AGE   NODE
vllm-7b9d6c4f8-tq2xm    0/1     ContainerCreating   0          3s    ip-10-0-23-77.ec2.internal
vllm-7b9d6c4f8-tq2xm    0/1     Running             0          9s    ip-10-0-23-77.ec2.internal
```
</div>

Two things worth noticing already:

- It went straight to node A (`ip-10-0-23-77`) — the exclusive, empty node from Module 3. Node B is full (the notebook). No Karpenter involved.
- `ContainerCreating` lasted **seconds**, not minutes. That's the pre-pull DaemonSet from 3.1 paying off: the 9 GB image was already on disk.

`Running` doesn't mean *ready*. vLLM is now downloading weights and initialising. Follow along:

```bash
kubectl -n vllm logs -f deploy/vllm
```

<div class="ws-output" markdown>
```text
INFO 09-17 14:31:02 [api_server.py] vLLM API server version 0.28.0
INFO 09-17 14:31:02 [api_server.py] args: Namespace(model='Qwen/Qwen2.5-1.5B-Instruct', served_model_name=['qwen2.5-1.5b'], max_model_len=4096, max_num_seqs=16, gpu_memory_utilization=0.9, ...)
INFO 09-17 14:31:09 [config.py] Using max model len 4096
model.safetensors: 100%|██████████| 3.09G/3.09G [00:52<00:00, 59.4MB/s]
INFO 09-17 14:32:08 [model_runner.py] Loading weights took 4.12 seconds
INFO 09-17 14:32:31 [worker.py] Available KV cache memory: 16.9 GiB
INFO 09-17 14:32:31 [kv_cache_utils.py] GPU KV cache size: 632,448 tokens
INFO 09-17 14:32:31 [kv_cache_utils.py] Maximum concurrency for 4,096 tokens per request: 154.41x
INFO 09-17 14:33:04 [core.py] init engine (profile, create kv cache, warmup model) took 45.19 seconds
INFO 09-17 14:33:05 [api_server.py] Starting vLLM API server on http://0.0.0.0:8000
INFO:     Application startup complete.
```
</div>

Read the numbers as they come past — they're the same on every LLM deployment you'll ever do:

- **`model.safetensors 3.09G … 59 MB/s`** — the weights download, from Hugging Face, through your NAT gateway. ~1 minute here. This happens on *every* new pod because the cache is an `emptyDir`. [4.6](06-cold-start.md) is about that.
- **`Available KV cache memory: 16.9 GiB`** — of the 24 GB, `--gpu-memory-utilization=0.90` reserved ~21 GB for vLLM; weights took ~3 GB; the rest is KV cache. That's what lets one replica serve many concurrent requests.
- **`init engine … took 45 s`** — CUDA graph capture and profiling. Pure startup cost, every time.

Press ++ctrl+c++ when you see `Application startup complete`, and move on to the manifest walk while the probes catch up.

[Next: 4.2 Walk the manifest →](02-manifest.md)
