# 3.5 Reset for Lab 2

<div class="ws-meta" markdown>
<span>**Time:** 2 min</span>
<span>**Changes:** node A back to exclusive; `shared-load` deleted; `forgotten-notebook` kept</span>
</div>

Lab 2 serves a latency-sensitive model. It must not land on a time-sliced node — and if it did, KEDA would happily stack replicas on the same card and you'd learn nothing about autoscaling. Put node A back the way you found it.

## Delete the four small pods

```bash
kubectl delete -f modules/03-sharing/shared-load.yaml
```

## Un-slice node A

Removing the label makes the config manager restart the plugin with no sharing config:

```bash
kubectl label node "$NODE_A" nvidia.com/device-plugin.config-
sleep 15
kubectl get nodes -l karpenter.sh/nodepool=gpu -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu,PRODUCT:.metadata.labels.nvidia\.com/gpu\.product,REPLICAS:.metadata.labels.nvidia\.com/gpu\.replicas'
```

<div class="ws-output" markdown>
```text
node/ip-10-0-23-77.ec2.internal unlabeled
NAME                         GPU   PRODUCT       REPLICAS
ip-10-0-23-77.ec2.internal   1     NVIDIA-L4     1
ip-10-0-5-140.ec2.internal   1     NVIDIA-A10G   1
```
</div>

Both nodes are exclusive again. Node A is empty; node B has the notebook.

## Confirm the image cache is warm

```bash
kubectl get ds vllm-image-prepull
```

<div class="ws-output" markdown>
```text
NAME                 DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR
vllm-image-prepull   2         2         2       2            2           karpenter.sh/nodepool=gpu
```
</div>

`READY 2/2`: the vLLM image is on both GPU nodes. If node B still shows `READY 1`, it's mid-pull; it'll finish during the first minutes of Lab 2.

## Where you are

| Node | Instance | GPU | Running |
|------|----------|-----|---------|
| A | g6.xlarge (or g5) | 1, exclusive | nothing — warm image, waiting for vLLM |
| B | g5.xlarge (or g6) | 1, exclusive | `forgotten-notebook`, 0% util |

Two GPU nodes, one useful. Lab 2 will use node A and, when it scales, need a third.

!!! tip "If you fell behind"
    It's fine to arrive at Lab 2 with node A still sliced or the shared-load pods still running — but run this page's two commands first, or vLLM's replicas will pile onto the shared card. `./scripts/validate-lab1.sh` still passing is the bar.

[Next: Lab 2 →](../04-lab2-serving-a-model/index.md)
