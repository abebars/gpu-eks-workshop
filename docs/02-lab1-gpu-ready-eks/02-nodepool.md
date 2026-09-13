# 2.2 Create GPU capacity

<div class="ws-meta" markdown>
<span>**Time:** 12 min</span>
<span>**Creates:** `EC2NodeClass/gpu`, `NodePool/gpu` — no EC2 instances yet</span>
</div>

Karpenter needs two objects: an **EC2NodeClass** (the *how*: AMI, subnets, security groups, disk, IAM role) and a **NodePool** (the *what*: instance types, capacity type, taints, limits, disruption policy). Neither launches anything by itself. Nodes appear only when a pod is pending that the NodePool could satisfy.

## Step 1 — Pin the AMI

The single most important line in the EC2NodeClass is the AMI selector. We resolve the *current* recommended AL2023 NVIDIA AMI release for our Kubernetes version and pin it.

```bash
export AMI_VERSION=$(./scripts/ami-version.sh)
echo "$AMI_VERSION"
```

<div class="ws-output" markdown>
```text
v20260827
```
</div>

??? note "What the script does"
    It reads one SSM public parameter that AWS maintains for every EKS version and AMI flavour:

    ```bash
    aws ssm get-parameter --region "$AWS_REGION" \
      --name "/aws/service/eks/optimized-ami/1.36/amazon-linux-2023/x86_64/nvidia/recommended/release_version" \
      --query 'Parameter.Value' --output text
    # → 1.36.3-20260827
    ```

    The date suffix is the AMI release; Karpenter's alias syntax is `al2023@v<date>`. To list *all* available releases (for rollbacks), swap `recommended/release_version` for a recursive `get-parameters-by-path` — the Karpenter docs show the full one-liner.

!!! quirk "Why not `al2023@latest`?"
    Because Karpenter treats a new AMI release as **drift**: every node on the old AMI gets replaced, rolling your entire GPU fleet on AWS's release schedule, not yours. On CPU fleets that's an inconvenience. On GPU fleets, the new AMI can carry a **new NVIDIA driver**, and a driver bump can break images built against the old CUDA version. The Karpenter docs say `@latest` is for pre-production only. Pin, and upgrade deliberately.

## Step 2 — The EC2NodeClass

Read it before you apply it. The annotated fields are the ones that matter for GPUs.

```yaml title="modules/01-gpu-nodes/ec2nodeclass.yaml"
--8<-- "modules/01-gpu-nodes/ec2nodeclass.yaml"
```

Three things to notice:

- **`alias: al2023@v…`** resolves to a *family* of AMIs, not one. Because the NodePool below only allows GPU instance types, Karpenter picks the **NVIDIA** variant automatically — the one with the driver and container toolkit baked in. Same alias, right AMI, no `if gpu then …` logic on your side.
- **`role`** is the node IAM role *name* from the base stack. Nodes assume it to join the cluster and pull images.
- **`blockDeviceMappings`**: 200 GiB gp3 at 500 MB/s throughput. The default is 20 GiB — the vLLM image alone is ~9 GB compressed and ~18 GB on disk. Image pull time on a fresh node is bounded by EBS throughput, so this is your first cold-start lever.

Apply it. The manifest has `${…}` placeholders; `envsubst` fills them from your environment.

```bash
envsubst < modules/01-gpu-nodes/ec2nodeclass.yaml | kubectl apply -f -
kubectl get ec2nodeclass gpu
```

<div class="ws-output" markdown>
```text
ec2nodeclass.karpenter.k8s.aws/gpu created
NAME   READY   AGE
gpu    True    4s
```
</div>

`READY True` means Karpenter resolved the AMI, subnets, security groups and IAM role. Look at what it resolved:

```bash
kubectl get ec2nodeclass gpu -o jsonpath='{range .status.amis[*]}{.name}{"\n"}{end}'
```

<div class="ws-output" markdown>
```text
amazon-eks-node-al2023-x86_64-nvidia-1.36-v20260827
amazon-eks-node-al2023-x86_64-neuron-1.36-v20260827
amazon-eks-node-al2023-x86_64-standard-1.36-v20260827
amazon-eks-node-al2023-arm64-standard-1.36-v20260827
```
</div>

The `-nvidia-` AMI is there, tagged (in `status.amis[].requirements`) as applying only to instance types with a GPU. If `READY` is `False`, `kubectl describe ec2nodeclass gpu` — the usual cause is an `AMI_VERSION` that doesn't exist for your Kubernetes version.

## Step 3 — The NodePool

```yaml title="modules/01-gpu-nodes/nodepool.yaml"
--8<-- "modules/01-gpu-nodes/nodepool.yaml"
```

The design decisions, in order of how often they bite people:

**Capacity type: Spot first, On-Demand fallback.** Karpenter prioritises `spot` when both are allowed. When EC2 returns *insufficient capacity* for a Spot offering, Karpenter caches that for three minutes and immediately tries the next option, including On-Demand. The fallback is a feature, not a workaround — and it only works if you *let* it (both values in the list, and quota for both).

**Instance diversity.** Two families (`g5` = A10G, `g6` = L4) × two sizes = four instance types across three AZs. Spot capacity for a single GPU type in a single AZ can evaporate; four types is the minimum for a workshop, and the Karpenter docs suggest far more (`minValues`) for production Spot fleets.

**`instance-gpu-count: 1`.** Keeps every node at exactly one GPU so the sharing lab is predictable. Multi-GPU nodes (`g5.12xlarge` has four) are for tensor-parallel models, not today.

**The taint.** `nvidia.com/gpu=present:NoSchedule` on every node this pool creates. Any pod that doesn't explicitly tolerate it — CoreDNS, your Grafana, a random `busybox` — can never land on a GPU node and quietly burn a dollar an hour. The GPU Operator's DaemonSets tolerate `nvidia.com/gpu` by default, so they still land.

**`limits.nvidia.com/gpu: "6"`.** A hard ceiling for the pool. If someone scales a Deployment to 50 replicas, Karpenter stops at the limit and the rest stay Pending. Set this on every GPU pool you ever create. Why 6 when the labs never run more than three physical GPUs? Because Karpenter counts what nodes *advertise*, and in Module 3 you'll make one node advertise four. A limit that ignores sharing is a limit you'll hit by surprise.

**Disruption: `WhenEmpty`, not `WhenEmptyOrUnderutilized`.** The default consolidation policy will happily replace a running node with a cheaper one when it decides the node is underutilised — which, for a model server that took eight minutes to load, means killing it mid-request to save twelve cents. GPU fleets get `WhenEmpty`. `consolidateAfter: 2h` is a workshop setting so an idle node survives the break and the talks; Module 5 tightens it live and you watch a node disappear.

```bash
kubectl apply -f modules/01-gpu-nodes/nodepool.yaml
kubectl get nodepool gpu
```

<div class="ws-output" markdown>
```text
nodepool.karpenter.sh/gpu created
NAME   NODECLASS   NODES   READY   AGE
gpu    gpu         0       True    3s
```
</div>

`NODES 0`. Your watch pane is still silent. Karpenter now *knows* how to build a GPU node; nothing has asked for one.

!!! quirk "Order matters: Operator before the first GPU pod"
    Karpenter doesn't consider a new node *initialised* until every extended resource it expects — here `nvidia.com/gpu` — has been registered by the node. That registration is done by the device plugin. The Karpenter docs are blunt about it: *without the respective device plugin DaemonSet, Karpenter will not see those nodes as initialized.* Create a GPU pod before the Operator exists and you get a node on your bill that never advertises a GPU, and a pod that stays Pending. Install the Operator first. That's the next step.

[Next: 2.3 Install the GPU Operator →](03-gpu-operator.md)
