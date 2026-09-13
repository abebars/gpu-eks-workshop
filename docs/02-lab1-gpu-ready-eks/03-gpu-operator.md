# 2.3 Install the GPU Operator

<div class="ws-meta" markdown>
<span>**Time:** 8 min</span>
<span>**Creates:** namespace `gpu-operator`, the Operator, NFD, and DaemonSets that will wake up when a GPU node appears</span>
</div>

The NVIDIA GPU Operator manages every NVIDIA component on your nodes as Kubernetes DaemonSets: the device plugin, GPU Feature Discovery, DCGM exporter, and — on plain Linux nodes — the driver and container toolkit too. On EKS, those last two are the trap.

## The one setting that matters

```yaml title="modules/02-gpu-operator/values.yaml"
--8<-- "modules/02-gpu-operator/values.yaml"
```

!!! quirk "`driver.enabled=false` — the #1 GPU confusion on EKS"
    The EKS AL2023 NVIDIA AMI already has the driver. If you leave the Operator's default (`driver.enabled=true`), it deploys a `nvidia-driver-daemonset` that tries to load its *own* driver on top of the AMI's. Depending on versions you get a node stuck in `nvidia-driver-daemonset` CrashLoopBackOff, a validator that never passes, or — worst — a node that looks healthy and then wedges under load. Same story for the container toolkit: the AMI ships it and makes `nvidia` containerd's default runtime.

    The rule from Module 1: **the AMI owns everything below the container boundary. The Operator owns everything Kubernetes sees.**

??? note "Why `cdi.enabled=false`?"
    Since v25.10 the Operator defaults to Container Device Interface mode, where containerd injects GPUs natively and the Operator *stops* setting `nvidia` as the default runtime. The EKS AMI's `nodeadm` already sets `nvidia` as the default runtime, and the device plugin's CDI docs say the nvidia runtime *should not* be the default in that mode. Two components with opposite assumptions about the same containerd config is not something to debug at 9 a.m. with 30 people watching. We stay on the legacy path the AMI was built for: device plugin sets `NVIDIA_VISIBLE_DEVICES`, nvidia runtime injects the device. Revisit CDI when AWS documents the combination.

## Install

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update
helm upgrade --install gpu-operator nvidia/gpu-operator \
  --version v26.7.0 \
  --namespace gpu-operator --create-namespace \
  -f modules/02-gpu-operator/values.yaml \
  --wait
```

<div class="ws-output" markdown>
```text
"nvidia" has been added to your repositories
...
Release "gpu-operator" does not exist. Installing it now.
NAME: gpu-operator
LAST DEPLOYED: Thu Sep 17 09:41:12 2026
NAMESPACE: gpu-operator
STATUS: deployed
REVISION: 1
```
</div>

`--wait` returns in under a minute because, with no GPU nodes, the GPU DaemonSets have zero desired pods and are therefore "ready".

## What's running (and what isn't yet)

```bash
kubectl -n gpu-operator get pods -o wide
```

<div class="ws-output" markdown>
```text
NAME                                                          READY   STATUS    RESTARTS   AGE   NODE
gpu-operator-7c9b8f6d4-x2k9q                                  1/1     Running   0          58s   ip-10-0-11-23.ec2.internal
gpu-operator-node-feature-discovery-gc-5d6f8b9c7-hm4tz        1/1     Running   0          58s   ip-10-0-42-118.ec2.internal
gpu-operator-node-feature-discovery-master-6b7d9c8f5-qp3wl    1/1     Running   0          58s   ip-10-0-11-23.ec2.internal
gpu-operator-node-feature-discovery-worker-9k2mn              1/1     Running   0          58s   ip-10-0-11-23.ec2.internal
gpu-operator-node-feature-discovery-worker-t7x4c              1/1     Running   0          58s   ip-10-0-42-118.ec2.internal
```
</div>

Node Feature Discovery runs on every node and looks for NVIDIA PCI devices (`feature.node.kubernetes.io/pci-10de.present`). When it finds one, the Operator labels that node `nvidia.com/gpu.present=true`, and the GPU DaemonSets — which select on that label — schedule there. Right now there's nothing to find:

```bash
kubectl -n gpu-operator get daemonsets
```

<div class="ws-output" markdown>
```text
NAME                                             DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR
gpu-feature-discovery                            0         0         0       0            0           nvidia.com/gpu.deploy.gpu-feature-discovery=true
gpu-operator-node-feature-discovery-worker       2         2         2       2            2           <none>
nvidia-dcgm-exporter                             0         0         0       0            0           nvidia.com/gpu.deploy.dcgm-exporter=true
nvidia-device-plugin-daemonset                   0         0         0       0            0           nvidia.com/gpu.deploy.device-plugin=true
nvidia-operator-validator                        0         0         0       0            0           nvidia.com/gpu.deploy.operator-validator=true
```
</div>

`DESIRED 0` across the board. And note what is **not** in the list: no `nvidia-driver-daemonset`, no `nvidia-container-toolkit-daemonset`. That's `driver.enabled=false` and `toolkit.enabled=false` doing their job. If you ever see those two on EKS, someone has the wrong values file.

The Operator stores its desired state in a `ClusterPolicy` and reports an overall state on it. Keep this command handy — it's the first thing to check when GPU pods misbehave:

```bash
kubectl get clusterpolicy cluster-policy -o jsonpath='{.status.state}{"\n"}'
```

With no GPU node to validate against, the state is not meaningful yet. Come back to it in 2.4 once the node exists; it should say `ready`.

Now give it a GPU to discover.

[Next: 2.4 Your first GPU pod →](04-first-gpu-pod.md)
