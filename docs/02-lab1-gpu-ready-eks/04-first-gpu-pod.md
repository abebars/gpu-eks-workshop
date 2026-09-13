# 2.4 Your first GPU pod

<div class="ws-meta" markdown>
<span>**Time:** 15 min (most of it waiting for EC2)</span>
<span>**Creates:** one GPU node, one pod that runs `nvidia-smi` and exits</span>
</div>

Everything is in place. Now ask for a GPU and watch the whole stack respond.

## The pod

```yaml title="modules/01-gpu-nodes/gpu-smoke.yaml"
--8<-- "modules/01-gpu-nodes/gpu-smoke.yaml"
```

Two lines make this a GPU pod: the **toleration** for the NodePool's taint, and **`nvidia.com/gpu: 1`** in limits. The image is NVIDIA's CUDA *base* image — no CUDA toolkit inside, just enough to run `nvidia-smi`, which talks to the driver the toolkit mounted in from the host.

## Apply and watch

```bash
kubectl apply -f modules/01-gpu-nodes/gpu-smoke.yaml
kubectl get pod gpu-smoke -w
```

In your second pane you already have `kubectl get nodeclaims,nodes -w` running. Here is the sequence you'll see, with typical timings for us-east-1:

<div class="ws-output" markdown>
```text
# pane 1
NAME        READY   STATUS    RESTARTS   AGE
gpu-smoke   0/1     Pending   0          0s
gpu-smoke   0/1     Pending   0          2m41s     ← node registered, pod bound
gpu-smoke   0/1     ContainerCreating   0   2m43s   ← waiting for nvidia.com/gpu + image pull
gpu-smoke   0/1     Completed           0   3m20s

# pane 2
NAME                        TYPE        CAPACITY   ZONE         NODE                         READY   AGE
nodeclaim.karpenter.sh/gpu-lk7m2  g6.xlarge  spot   us-east-1b                              Unknown  0s
nodeclaim.karpenter.sh/gpu-lk7m2  g6.xlarge  spot   us-east-1b   ip-10-0-23-77.ec2.internal  Unknown  2m38s
node/ip-10-0-23-77.ec2.internal                                                              NotReady 2m38s
node/ip-10-0-23-77.ec2.internal                                                              Ready    2m52s
nodeclaim.karpenter.sh/gpu-lk7m2  g6.xlarge  spot   us-east-1b   ip-10-0-23-77.ec2.internal  True     3m05s
```
</div>

Read that timeline once more, because it's the cold-start story you'll be optimising in Lab 2:

1. **0s** — the pod is unschedulable (no node has `nvidia.com/gpu`). Karpenter notices within a second, simulates the pod against the `gpu` NodePool, and creates a **NodeClaim** for the cheapest instance type that fits. Spot `g6.xlarge` here; yours may be `g5.xlarge` or On-Demand, depending on what EC2 had.
2. **~2.5 min** — EC2 launched the instance, the AL2023 NVIDIA AMI booted, `nodeadm` joined it to the cluster. The node shows `NotReady` while the CNI comes up.
3. **~3 min** — NFD finds the GPU, the Operator labels the node, the device plugin DaemonSet starts and registers `nvidia.com/gpu: 1`. Only *now* is the NodeClaim `READY True` — that's the initialisation rule from 2.2.
4. The scheduler binds the pod, kubelet pulls the image (small), the container runs `nvidia-smi` and exits.

While you wait, watch Karpenter's own decision log — it tells you exactly why it picked what it picked:

```bash
kubectl -n karpenter logs deploy/karpenter --since=5m | grep -E '"message":"(computed new nodeclaim[^"]*|launched nodeclaim|registered nodeclaim|initialized nodeclaim)"' | jq -r '[.time, .message, .["instance-type"] // "", .["capacity-type"] // "", .zone // ""] | @tsv'
```

<div class="ws-output" markdown>
```text
2026-09-17T13:52:04Z  computed new nodeclaim(s) to fit pod(s)
2026-09-17T13:52:05Z  launched nodeclaim     g6.xlarge   spot   us-east-1b
2026-09-17T13:54:43Z  registered nodeclaim   g6.xlarge   spot   us-east-1b
2026-09-17T13:55:09Z  initialized nodeclaim  g6.xlarge   spot   us-east-1b
```
</div>

!!! quirk "Spot said no?"
    If your NodeClaim shows `on-demand`, EC2 had no Spot capacity for any of the four allowed types in any AZ at that moment, and Karpenter fell back — exactly as designed. Run `kubectl -n karpenter logs deploy/karpenter --since=10m | grep -i 'insufficient capacity'` to see the offerings it skipped. Nothing to fix; this is the behaviour you want in production too. It's also why a single-instance-type NodePool is a liability.

## Read the output

```bash
kubectl logs gpu-smoke
```

<div class="ws-output" markdown>
```text
Thu Sep 17 13:55:41 2026
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.82.07              Driver Version: 580.82.07      CUDA Version: 13.0     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA L4                      On  |   00000000:31:00.0 Off |                    0 |
| N/A   34C    P8             16W /   72W |       0MiB /  23034MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
```
</div>

**Screenshot this. It's your checkpoint artifact.** Then look at three things in it:

- **Driver 580 / CUDA 13.0** came from the AMI, not from anything you installed. Your container's CUDA runtime must be ≤ 13.0 to work on this node. That's the version contract from Module 1.
- **`MIG M.: N/A`** — this GPU (L4, or A10G on a g5) does not support MIG. Remember that for Module 3.
- **`0MiB / 23034MiB`** — 24 GB of GPU memory, all of it yours. A 1.5B-parameter model in bf16 is ~3 GB of weights; the rest is KV cache. That's why Lab 2's model choice is comfortable.

## Look at the node

```bash
kubectl get nodes -l karpenter.sh/nodepool=gpu -o custom-columns='NAME:.metadata.name,INSTANCE:.metadata.labels.node\.kubernetes\.io/instance-type,CAPACITY:.metadata.labels.karpenter\.sh/capacity-type,GPU:.status.allocatable.nvidia\.com/gpu,PRODUCT:.metadata.labels.nvidia\.com/gpu\.product,GPU_MEM:.metadata.labels.nvidia\.com/gpu\.memory'
```

<div class="ws-output" markdown>
```text
NAME                         INSTANCE    CAPACITY   GPU   PRODUCT     GPU_MEM
ip-10-0-23-77.ec2.internal   g6.xlarge   spot       1     NVIDIA-L4   23034
```
</div>

Those `nvidia.com/gpu.*` labels come from GPU Feature Discovery. They're how you target a GPU *model* in a nodeSelector when the integer isn't enough.

Now the DaemonSets that were at `DESIRED 0` ten minutes ago:

```bash
kubectl -n gpu-operator get pods -o wide --field-selector spec.nodeName=$(kubectl get nodes -l karpenter.sh/nodepool=gpu -o jsonpath='{.items[0].metadata.name}')
```

<div class="ws-output" markdown>
```text
NAME                                             READY   STATUS      RESTARTS   AGE
gpu-feature-discovery-d8nqz                      1/1     Running     0          2m
gpu-operator-node-feature-discovery-worker-6pl2b 1/1     Running     0          2m
nvidia-cuda-validator-k9x4m                      0/1     Completed   0          2m
nvidia-dcgm-exporter-ml8vw                       1/1     Running     0          2m
nvidia-device-plugin-daemonset-7tqrc             1/1     Running     0          2m
nvidia-operator-validator-2wfjp                  1/1     Running     0          2m
```
</div>

The `nvidia-cuda-validator` pod ran a real CUDA kernel on the node and `Completed` — that's the Operator's own smoke test, and the ClusterPolicy is now `ready`:

```bash
kubectl get clusterpolicy cluster-policy -o jsonpath='{.status.state}{"\n"}'
```

Finally, `describe` the node and find the line you saw on the presenter's screen in Module 1:

```bash
kubectl describe node -l karpenter.sh/nodepool=gpu | grep -E '^(Capacity|Allocatable)|nvidia.com/gpu:|Taints'
```

<div class="ws-output" markdown>
```text
Taints:             nvidia.com/gpu=present:NoSchedule
Capacity:
  nvidia.com/gpu:     1
Allocatable:
  nvidia.com/gpu:     1
```
</div>

[Next: 2.5 Checkpoint →](05-checkpoint.md)
