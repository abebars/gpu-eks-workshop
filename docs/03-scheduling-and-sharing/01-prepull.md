# 3.1 Warm the image cache

<div class="ws-meta" markdown>
<span>**Time:** 30 seconds now, ~4 min in the background</span>
<span>**Creates:** DaemonSet `vllm-image-prepull` on every GPU node</span>
</div>

The vLLM image is about 9 GB compressed. Pulling it is the single longest step in a GPU cold start (you'll measure that in Lab 2). Image warmers — a DaemonSet whose only job is to make kubelet pull an image — are a standard production technique, and we're going to use one now so Lab 2 starts fast.

```yaml title="modules/03-sharing/prepull-vllm-image.yaml"
--8<-- "modules/03-sharing/prepull-vllm-image.yaml"
```

The init container references the vLLM image and runs `true`. Kubelet has to pull the image to run it. The main container is `pause` — 8 MiB of memory to keep the pod alive so the image stays "in use" and is never garbage-collected. No GPU is requested, so it doesn't consume the resource it's warming.

```bash
kubectl apply -f modules/03-sharing/prepull-vllm-image.yaml
kubectl get ds vllm-image-prepull
```

<div class="ws-output" markdown>
```text
daemonset.apps/vllm-image-prepull created
NAME                 DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                AGE
vllm-image-prepull   1         1         0       1            0           karpenter.sh/nodepool=gpu    2s
```
</div>

`READY 0` for the next few minutes while it pulls. Don't wait for it. Go back to the [talk](index.md); check on it in [3.5](05-reset.md).

!!! tip "Why a DaemonSet and not a bigger disk / faster disk / a registry cache?"
    All of those help and Lab 2 covers them. The DaemonSet is the one that gives you a *warm* node before the first real pod lands, which is the difference between a 30-second and a 6-minute scale-out.

[Back to the talk →](index.md) · [Next: 3.2 Time-slice a node →](02-time-slicing.md)
