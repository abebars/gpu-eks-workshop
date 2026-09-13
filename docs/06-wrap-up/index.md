# Module 6 · Wrap-up

<div class="ws-meta" markdown>
<span>**Time:** 15 min</span>
</div>

## What you built

Three and a half hours ago your cluster had never seen a GPU. Now:

- [x] A **Karpenter NodePool** that buys g5/g6 capacity on demand, Spot first, on a pinned AMI, with a hard GPU limit and a disruption policy chosen on purpose
- [x] The **NVIDIA GPU Operator**, configured the way EKS needs it (`driver.enabled=false`, `toolkit.enabled=false`) — and you know *why*
- [x] A node you **time-sliced** four ways, saw four processes share one card, and un-sliced again
- [x] **vLLM** serving a real model through an OpenAI-compatible endpoint with probes that don't kill it
- [x] **KEDA** scaling on requests in flight, and Karpenter adding a GPU node behind it while you timed every phase of the cold start
- [x] **DCGM → Prometheus → Grafana**, and a one-line query that finds idle GPUs
- [x] Two idle nodes reclaimed by changing one field

Everything reruns from the companion repo: `make workshop-up` builds all of it; `make workshop-down` tears it down.

## What we deliberately didn't cover

| Topic | One line | Start here |
|-------|----------|------------|
| **Distributed training** | EFA networking, NCCL, `p4`/`p5` capacity blocks, Kubeflow/Ray on EKS. A different workshop. | [EKS best practices: AI/ML](https://docs.aws.amazon.com/eks/latest/best-practices/aiml.html) |
| **Dynamic Resource Allocation** | The device-plugin successor: GPUs as first-class scheduler objects. GA in 1.34; AWS recommends it for static capacity today. | [Kubernetes DRA](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/) · [EKS NVIDIA DRA driver](https://docs.aws.amazon.com/eks/latest/userguide/device-management-nvidia-dra-device-plugin.html) |
| **MIG in practice** | Hardware partitioning on A100/H100. Same Operator, `nvidia.com/mig.config` label, `mig-1g.10gb` resources. | [GPU Operator: MIG](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-operator-mig.html) · [EKS: MIG](https://docs.aws.amazon.com/eks/latest/userguide/device-management-nvidia-mig.html) |
| **Multi-cluster GPU fleets** | Capacity in three regions, one control plane for scheduling. | Karmada / Kueue MultiKueue |
| **Inference gateways** | Model-aware routing, prefix-cache affinity, KV-aware load balancing — the layer above a Service. | [Kubernetes Gateway API Inference Extension](https://gateway-api-inference-extension.sigs.k8s.io/) · llm-d |
| **EKS Auto Mode for GPUs** | Everything from Lab 1, managed by AWS. Fewer knobs; the ones you keep are NodePool/NodeClass. | [EKS Auto Mode: accelerated instances](https://docs.aws.amazon.com/eks/latest/userguide/auto-accelerated.html) |

## Take-aways

- **[Production readiness checklist](checklist.md)** — every decision from today as a yes/no you can run against your own cluster.
- **[Where to go next](resources.md)** — the official docs everything in this guide was verified against.

## Before you go

1. **[Clean up](../cleanup.md).** Do it now, together — it takes five minutes and the GPU nodes are the expensive part.
2. **Feedback** — the link is in the chat. Two minutes. What should the next version of this workshop do differently?
3. **Stay in touch** — [abebars.io](https://abebars.io) · `#LevelUpWithAhmed`

## Q&A

Ask anything. The answers that need a terminal are welcome; the cluster is still up until step 1.
