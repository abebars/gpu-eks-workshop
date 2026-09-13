# 3.3 Four pods, one GPU

<div class="ws-meta" markdown>
<span>**Time:** 4 min</span>
<span>**Creates:** Deployment `shared-load`, 4 replicas, each requesting `nvidia.com/gpu: 1`</span>
</div>

Four pods, each asking for a GPU. Yesterday that would have meant four nodes. Now it means one.

```yaml title="modules/03-sharing/shared-load.yaml"
--8<-- "modules/03-sharing/shared-load.yaml"
```

Each replica prints which GPU it sees and then runs a 4096×4096 matrix multiply in a loop — a deliberately dumb way to keep a GPU busy. It reuses the vLLM image only because that image has PyTorch in it and is already on the node courtesy of 3.1. If the pre-pull hasn't finished yet, the pods wait for the same pull; no harm done.

```bash
kubectl apply -f modules/03-sharing/shared-load.yaml
kubectl get pods -l app=shared-load -o wide -w
```

<div class="ws-output" markdown>
```text
NAME                           READY   STATUS    RESTARTS   AGE   NODE
shared-load-6d9f7c5b8-4kx2p    1/1     Running   0          14s   ip-10-0-23-77.ec2.internal
shared-load-6d9f7c5b8-9mwqz    1/1     Running   0          14s   ip-10-0-23-77.ec2.internal
shared-load-6d9f7c5b8-c7lts    1/1     Running   0          14s   ip-10-0-23-77.ec2.internal
shared-load-6d9f7c5b8-vp8hn    1/1     Running   0          14s   ip-10-0-23-77.ec2.internal
```
</div>

Same node, four times. Press ++ctrl+c++ and check what each pod thinks it has:

```bash
kubectl logs -l app=shared-load --prefix
```

<div class="ws-output" markdown>
```text
[pod/shared-load-6d9f7c5b8-4kx2p/matmul] pod=shared-load-6d9f7c5b8-4kx2p sees GPU: NVIDIA L4
[pod/shared-load-6d9f7c5b8-9mwqz/matmul] pod=shared-load-6d9f7c5b8-9mwqz sees GPU: NVIDIA L4
[pod/shared-load-6d9f7c5b8-c7lts/matmul] pod=shared-load-6d9f7c5b8-c7lts sees GPU: NVIDIA L4
[pod/shared-load-6d9f7c5b8-vp8hn/matmul] pod=shared-load-6d9f7c5b8-vp8hn sees GPU: NVIDIA L4
```
</div>

Each pod believes it has a whole L4. None of them does.

## See the sharing from the host

`nvidia-smi` inside a container only sees that container's processes. To see all four, ask the *node*. `kubectl debug node` gives you a privileged pod in the host's PID namespace, pinned to the node with `nodeName` (so the taint doesn't apply):

```bash
kubectl debug node/"$NODE_A" -it --profile=sysadmin \
  --image=nvidia/cuda:12.8.1-base-ubuntu22.04 -- nvidia-smi
```

<div class="ws-output" markdown>
```text
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.82.07              Driver Version: 580.82.07      CUDA Version: 13.0     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|=========================================+========================+======================|
|   0  NVIDIA L4                      On  |   00000000:31:00.0 Off |                    0 |
| N/A   58C    P0             71W /   72W |    2532MiB /  23034MiB |    100%      Default |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|=========================================================================================|
|    0   N/A  N/A           41233      C   python3                                 622MiB |
|    0   N/A  N/A           41260      C   python3                                 622MiB |
|    0   N/A  N/A           41287      C   python3                                 622MiB |
|    0   N/A  N/A           41314      C   python3                                 622MiB |
+-----------------------------------------------------------------------------------------+
```
</div>

Four `python3` processes on GPU 0, `GPU-Util 100%`, and — look at **Memory-Usage** — they share the same 23 GB pool with nothing enforcing a per-process limit. Bump one pod's tensor size to 30 GB and the other three die with it. That's the "no memory isolation" line from the talk, in one screen.

!!! quirk "This debug pod never asked for a GPU"
    It's privileged, and a privileged container sees every device on the node. `nvidia.com/gpu` accounting is a *scheduling* construct, not a security boundary. That's one more reason GPU nodes get their own taint, their own namespace policies, and no `privileged: true` from tenants.

Clean up the debug pod when you're done — `kubectl debug` leaves it behind:

```bash
kubectl get pods -o name | grep node-debugger | xargs kubectl delete
```

## What the scheduler sees

```bash
kubectl describe node "$NODE_A" | grep -E '^[[:space:]]*nvidia.com/gpu[[:space:]]'
```

<div class="ws-output" markdown>
```text
  nvidia.com/gpu:     4
  nvidia.com/gpu:     4
  nvidia.com/gpu     4           4
```
</div>

Capacity 4, allocatable 4, allocated 4 (requests / limits). From Kubernetes' point of view the node is **full**. Which sets up the next step.

!!! checkpoint "Checkpoint 2 — four pods on one GPU"
    You should have four `shared-load` pods `Running` on the same node and a `nvidia-smi` showing four processes. If your pods are `Pending`, the node label from 3.2 didn't take — re-run the `custom-columns` command there and check `REPLICAS`.

[Next: 3.4 The fifth pod →](04-fifth-pod.md)
