# 4.2 Walk the manifest

<div class="ws-meta" markdown>
<span>**Time:** 8 min, while vLLM initialises</span>
</div>

Every non-obvious line in this Deployment exists because of a GPU or an LLM. Here is the file; the numbered comments map to the sections below.

```yaml title="modules/04-vllm/deployment.yaml"
--8<-- "modules/04-vllm/deployment.yaml"
```

## (1) Placement

```yaml
tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
nodeSelector:
  karpenter.sh/nodepool: gpu
```

The toleration gets you *onto* GPU nodes; the `nodeSelector` makes sure you *only* go there. In production you'd tighten this to a product (`nvidia.com/gpu.product: NVIDIA-A10G`) or a tier label (`gpu-tier: exclusive`) — and, as you saw in Module 3, the `-SHARED` suffix means a product selector can never land you on a time-sliced card by accident.

`terminationGracePeriodSeconds: 60` and the `RollingUpdate` with `maxUnavailable: 0` are the other half of placement: a model server takes minutes to become ready, so you never take the old one away before the new one is serving, and when a Spot node is reclaimed you get a full minute to finish in-flight generations.

## (2) The command line

```yaml
args:
  - Qwen/Qwen2.5-1.5B-Instruct
  - --served-model-name=qwen2.5-1.5b
  - --max-model-len=4096
  - --max-num-seqs=16
  - --gpu-memory-utilization=0.90
  - --port=8000
```

The image's entrypoint is `vllm serve`, so `args` are appended to it.

| Flag | Why |
|------|-----|
| `--served-model-name` | The name clients put in `"model": …`, and the `model_name` label on every metric. Decouples your API from the Hugging Face path so you can swap models without breaking clients or dashboards. |
| `--max-model-len 4096` | Caps context (prompt + output). vLLM sizes the KV cache from this; the model's native 32k would be wasteful for a chat demo and slower to start. |
| `--max-num-seqs 16` | Max requests in one batch. Above this, requests **queue** (`vllm:num_requests_waiting`). We set it low on purpose so a 24-user load test visibly saturates one replica — that's the signal the autoscaler needs. Default is 256 on this class of GPU. |
| `--gpu-memory-utilization 0.90` | Fraction of GPU memory vLLM may claim (weights + KV cache + activations). Leave headroom for CUDA context and for DCGM; 0.90 on a dedicated node is fine, lower it if anything else shares the card. |

No `HF_TOKEN`: the model is ungated. For Llama-class models you'd add a Secret and `env: [{name: HF_TOKEN, valueFrom: secretKeyRef…}]`.

## (3) Probes tuned for a slow start

```yaml
startupProbe:
  httpGet: {path: /health, port: http}
  periodSeconds: 10
  failureThreshold: 90       # 90 × 10 s = 15 minutes
readinessProbe:
  httpGet: {path: /health, port: http}
  periodSeconds: 5
livenessProbe:
  httpGet: {path: /health, port: http}
  periodSeconds: 10
  failureThreshold: 6
```

!!! quirk "The probe that kills your model server"
    Without a **startupProbe**, the liveness probe starts counting the moment the container starts. A 7B model on a cold node can take 5–8 minutes to download and load; a liveness probe with the default `failureThreshold: 3 × periodSeconds: 10` kills it at 30 seconds, kubelet restarts it, and you get a CrashLoopBackOff that looks like an application bug. vLLM's own docs call this out. The startupProbe holds liveness and readiness off until `/health` answers once, for up to `failureThreshold × periodSeconds` — here 15 minutes, which covers a cold node plus a much bigger model than ours.

Readiness stays tight (5 s) so a replica that's genuinely wedged is pulled from the Service fast; liveness gets a full minute (`6 × 10 s`) of failures before a restart, because restarting a model server is the most expensive thing you can do to it.

## (4) Shared memory

```yaml
volumes:
  - name: shm
    emptyDir: {medium: Memory, sizeLimit: 2Gi}
```

PyTorch moves tensors between processes through `/dev/shm`. A container's default `/dev/shm` is **64 MB**, and vLLM will either crash or silently degrade. A memory-backed `emptyDir` at `/dev/shm` is the Kubernetes equivalent of `docker run --shm-size`. The bytes count against the container's memory limit — that's why the limit is 12 Gi and not 8.

## (5) The weights cache

```yaml
env: [{name: HF_HOME, value: /root/.cache/huggingface}]
volumes:
  - name: hf-cache
    emptyDir: {sizeLimit: 20Gi}
```

Weights land here on first start. With an `emptyDir` they're gone when the pod is — so **every new replica re-downloads 3 GB**. That's fine at 3 GB; it is not fine at 15 GB or 140 GB. [4.6](06-cold-start.md) walks through the alternatives (node-local hostPath, a PVC, S3 via Mountpoint, baking into the image).

## Resources

```yaml
requests: {cpu: "2", memory: 6Gi, nvidia.com/gpu: 1}
limits:   {memory: 12Gi, nvidia.com/gpu: 1}
```

The GPU is the only thing that has to match between requests and limits. CPU and memory are sized for a `g5.xlarge`/`g6.xlarge` (4 vCPU, 16 GiB): vLLM needs real CPU for tokenisation and scheduling, and real host memory for its CPU swap space and the shm volume. Requesting more than a `xlarge` can give you means Karpenter launches a bigger instance — check the request against your smallest allowed instance type.

## Service and PodMonitor

```yaml title="modules/04-vllm/service.yaml"
--8<-- "modules/04-vllm/service.yaml"
```

```yaml title="modules/04-vllm/podmonitor.yaml"
--8<-- "modules/04-vllm/podmonitor.yaml"
```

A plain ClusterIP Service on port 80 → 8000. The PodMonitor tells Prometheus to scrape **each pod** on `/metrics` every 15 s — per-replica series are what let you see one replica saturate while another idles. The base stack's Prometheus is configured to pick up PodMonitors from any namespace without label matching, so this works with no extra wiring.

By now the pod should be `1/1 Ready`:

```bash
kubectl -n vllm get pods
```

<div class="ws-output" markdown>
```text
NAME                    READY   STATUS    RESTARTS   AGE
vllm-7b9d6c4f8-tq2xm    1/1     Running   0          4m12s
```
</div>

[Next: 4.3 Smoke test →](03-smoke-test.md)
