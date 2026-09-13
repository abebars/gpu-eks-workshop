# 2.5 Checkpoint

<div class="ws-meta" markdown>
<span>**Time:** 5 min buffer + 10 min break</span>
</div>

Run the validator. It checks everything Lab 1 was supposed to produce.

```bash
./scripts/validate-lab1.sh
```

<div class="ws-output" markdown>
```text
Lab 1 validation
  ✅ 1 GPU node(s) from NodePool 'gpu'
  ✅ allocatable nvidia.com/gpu on GPU node(s): 1
  ✅ nvidia-device-plugin-daemonset ready on 1 node(s)
  ✅ nvidia-dcgm-exporter ready on 1 node(s)
  ✅ gpu-feature-discovery ready on 1 node(s)
  ✅ no nvidia-driver-daemonset (driver.enabled=false — correct on EKS)
  ✅ gpu-smoke ran nvidia-smi: NVIDIA L4
🎉 Lab 1 checkpoint reached.
```
</div>

!!! checkpoint "Checkpoint 1 — show your `nvidia-smi`"
    Post your `nvidia-smi` screenshot (or the validator output) in the chat, or hold your laptop up if we're in a room. **GPU model and driver version visible.** Helpers are sweeping for anyone with a ❌.

## If something is ❌

| Symptom | First thing to check |
|---------|---------------------|
| No nodes from the NodePool after 5 min | `kubectl describe nodeclaim` — look at events. Quota (`VcpuLimitExceeded`) and `InsufficientInstanceCapacity` across *all* four types are the usual suspects. See [Troubleshooting → Karpenter](../troubleshooting.md#karpenter-wont-launch-a-node). |
| Node exists but `nvidia.com/gpu` never appears | `kubectl -n gpu-operator get pods -o wide` — is the device plugin on the node? Is `nvidia-driver-daemonset` there when it shouldn't be? |
| `gpu-smoke` stuck in `ContainerCreating` | `kubectl describe pod gpu-smoke` — image pull vs. device allocation. |
| `nvidia-smi` prints "couldn't communicate with the NVIDIA driver" | The container got scheduled but not injected. Almost always the toolkit/CDI mismatch — confirm `cdi.enabled=false` and `toolkit.enabled=false` in `helm get values gpu-operator -n gpu-operator`. |

## What you just built

Say it back to yourself; you'll be asked in Module 3:

- Who put the **driver** on the node? *(the AMI)*
- Who made **`nvidia.com/gpu: 1`** appear on the node? *(the device plugin, deployed by the Operator, registered with kubelet)*
- What stopped **CoreDNS** from landing on your $1/hour node? *(the taint)*
- Why did the pod wait ~3 minutes? *(no node existed; Karpenter had to launch one and wait for it to initialise)*

## Leave things as they are

Don't delete the pod or the node. The node is now *empty* (the pod completed), and with `consolidationPolicy: WhenEmpty` Karpenter would reclaim it after `consolidateAfter` — which is why that's set to 2 hours for today. Module 3 puts the node back to work.

## ☕ Break — 10 minutes

We resume with [Module 3 →](../03-scheduling-and-sharing/index.md)
