# Production readiness checklist

Run this against your own GPU platform. Every line maps to something you did today; the link is where.

## Nodes

- [ ] AMI is **pinned** (`al2023@v<date>`), and there is a written procedure for upgrading it — [2.2](../02-lab1-gpu-ready-eks/02-nodepool.md)
- [ ] The NodePool allows **≥ 4 instance types** across **≥ 2 families** if it uses Spot — [2.2](../02-lab1-gpu-ready-eks/02-nodepool.md)
- [ ] **On-Demand fallback** is allowed and there is quota for it — [2.2](../02-lab1-gpu-ready-eks/02-nodepool.md), [quota](../00-prework/01-quota.md)
- [ ] `limits.nvidia.com/gpu` is set on **every** GPU NodePool — [2.2](../02-lab1-gpu-ready-eks/02-nodepool.md)
- [ ] `consolidationPolicy: WhenEmpty` (not `WhenEmptyOrUnderutilized`) for inference pools, with a deliberate `consolidateAfter` — [2.2](../02-lab1-gpu-ready-eks/02-nodepool.md), [5.2](../05-observability-and-cost/02-idle-gpu.md)
- [ ] Disruption **budgets** sized to the fleet — [5.2](../05-observability-and-cost/02-idle-gpu.md)
- [ ] `expireAfter` is a value someone chose, and workloads survive it — [Module 3](../03-scheduling-and-sharing/index.md)
- [ ] Root volume sized and **throughput-provisioned** for your largest image — [2.2](../02-lab1-gpu-ready-eks/02-nodepool.md)
- [ ] GPU nodes are **tainted**; only GPU workloads tolerate — [2.2](../02-lab1-gpu-ready-eks/02-nodepool.md)

## Drivers and the Operator

- [ ] `driver.enabled=false` and `toolkit.enabled=false` on EKS NVIDIA AMIs — [2.3](../02-lab1-gpu-ready-eks/03-gpu-operator.md)
- [ ] CDI mode is a **decision** (`cdi.enabled`), not a default you inherited — [2.3](../02-lab1-gpu-ready-eks/03-gpu-operator.md)
- [ ] Container images' CUDA version ≤ the AMI driver's supported CUDA — [2.4](../02-lab1-gpu-ready-eks/04-first-gpu-pod.md)
- [ ] Operator and device-plugin versions are pinned in Helm — [2.3](../02-lab1-gpu-ready-eks/03-gpu-operator.md)
- [ ] `nvidia-cuda-validator` passes on every new node (alert on ClusterPolicy state ≠ `ready`) — [2.4](../02-lab1-gpu-ready-eks/04-first-gpu-pod.md)

## Sharing

- [ ] Sharing config lives in a **versioned ConfigMap** with named keys; changes are new keys + relabel — [3.2](../03-scheduling-and-sharing/02-time-slicing.md)
- [ ] Shared and exclusive nodes are **separate NodePools** with template labels; workloads select by tier — [3.4](../03-scheduling-and-sharing/04-fifth-pod.md)
- [ ] `failRequestsGreaterThanOne: true` on time-sliced pools — [3.2](../03-scheduling-and-sharing/02-time-slicing.md)
- [ ] Latency-SLO workloads select the **unshared product name** (never `-SHARED`) — [3.2](../03-scheduling-and-sharing/02-time-slicing.md)
- [ ] No `privileged: true` for tenant workloads on GPU nodes — [3.3](../03-scheduling-and-sharing/03-four-pods.md)

## Serving

- [ ] **startupProbe** with `failureThreshold × periodSeconds` ≥ worst-case cold start — [4.2](../04-lab2-serving-a-model/02-manifest.md)
- [ ] `/dev/shm` is a memory-backed `emptyDir`, sized, counted in the memory limit — [4.2](../04-lab2-serving-a-model/02-manifest.md)
- [ ] `--served-model-name` decouples clients and dashboards from the model path — [4.2](../04-lab2-serving-a-model/02-manifest.md)
- [ ] `RollingUpdate` with `maxUnavailable: 0`; `terminationGracePeriodSeconds` ≥ longest generation — [4.2](../04-lab2-serving-a-model/02-manifest.md)
- [ ] A **PodDisruptionBudget** and ≥ 2 replicas for anything user-facing on Spot — [Module 3](../03-scheduling-and-sharing/index.md)
- [ ] Weights are **not downloaded on the critical path** for models > 10 GB — [4.6](../04-lab2-serving-a-model/06-cold-start.md)
- [ ] Images are pre-pulled or cached in-region (ECR pull-through) — [3.1](../03-scheduling-and-sharing/01-prepull.md), [4.6](../04-lab2-serving-a-model/06-cold-start.md)

## Autoscaling

- [ ] Scaling signal is **in-flight requests, queue depth, or KV-cache usage** — never CPU — [4.5](../04-lab2-serving-a-model/05-autoscale.md)
- [ ] Exactly **one** autoscaler per Deployment (KEDA owns the HPA) — [4.5](../04-lab2-serving-a-model/05-autoscale.md)
- [ ] `maxReplicaCount` and NodePool `limits` agree with each other and with quota — [4.5](../04-lab2-serving-a-model/05-autoscale.md)
- [ ] Scale-down stabilisation long enough that a replica which finished cold-starting after the burst still serves before it's removed (we used 5 min against a ~9 min cold start; production is usually 10–15) — [4.5](../04-lab2-serving-a-model/05-autoscale.md)
- [ ] There is a documented answer to "what happens on a Spot reclaim at 3 a.m.?" — [4.6](../04-lab2-serving-a-model/06-cold-start.md)

## Observability and cost

- [ ] dcgm-exporter scraped on every GPU node; the DCGM dashboard is live — [5.1](../05-observability-and-cost/01-dashboards.md)
- [ ] vLLM (or your server) scraped per pod — [4.1](../04-lab2-serving-a-model/01-deploy.md)
- [ ] The **idle-GPU alert** (`avg_over_time(DCGM_FI_DEV_GPU_UTIL[30m]) < 5` with a pod scheduled) pages someone — [5.2](../05-observability-and-cost/02-idle-gpu.md)
- [ ] `DCGM_FI_DEV_XID_ERRORS > 0` pages someone — [Module 5](../05-observability-and-cost/index.md)
- [ ] Every GPU pod carries an **owner/team label**, enforced by admission policy — [5.2](../05-observability-and-cost/02-idle-gpu.md)
- [ ] Monthly GPU spend and fleet-average utilisation are on a dashboard someone looks at — [Module 5](../05-observability-and-cost/index.md)
- [ ] There is a **teardown** discipline for dev clusters (`make workshop-down` or equivalent) — [Clean up](../cleanup.md)

## Quota and accounts

- [ ] G/VT (and P) **On-Demand and Spot** vCPU quotas are known per region, with headroom for one scale-out — [quota](../00-prework/01-quota.md)
- [ ] Quota increases are requested **before** the launch that needs them — [quota](../00-prework/01-quota.md)
