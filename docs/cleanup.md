# Clean up

<div class="ws-meta" markdown>
<span>**Time:** 5 min of commands, ~10 min of AWS</span>
<span>**Why:** the base stack costs ≈ $0.55/hour idle; a forgotten GPU node ≈ $1/hour</span>
</div>

Tear down in the **reverse** order you built, so nothing is left orphaned: workloads → GPU nodes → Operator → base stack.

## One command

```bash
make workshop-down
```

That runs the steps below and then `terraform destroy`. If it fails part-way (it can — see the notes), run the individual steps.

## Step by step

### 1. Workloads

```bash
kubectl delete -f modules/04-vllm/ --ignore-not-found
kubectl delete -f modules/03-sharing/ --ignore-not-found
kubectl delete -f modules/01-gpu-nodes/gpu-smoke.yaml --ignore-not-found
```

### 2. GPU nodes

Deleting the NodePool makes Karpenter drain and terminate every node it created. Wait for the NodeClaims to go before deleting the EC2NodeClass — Karpenter needs it to terminate the instances cleanly.

```bash
kubectl delete nodepool gpu
kubectl wait --for=delete nodeclaims --all --timeout=10m
kubectl delete ec2nodeclass gpu
```

<div class="ws-output" markdown>
```text
nodepool.karpenter.sh "gpu" deleted
nodeclaim.karpenter.sh/gpu-lk7m2 condition met
ec2nodeclass.karpenter.k8s.aws "gpu" deleted
```
</div>

!!! warning "Check the EC2 console anyway"
    Filter instances by the tag `karpenter.sh/nodepool = gpu` (or `workshop = gpu-eks`) in your region. There should be none running. A NodeClaim that's stuck with a finalizer is the one case where Karpenter can leave an instance behind; terminate it by hand if so.

### 3. GPU Operator

```bash
helm uninstall gpu-operator -n gpu-operator
kubectl delete namespace gpu-operator
```

### 4. Base stack

```bash
make base-down
```

`terraform destroy` removes the EKS cluster, node group, Karpenter's IAM/SQS resources, the monitoring stack, the VPC and the NAT gateway. 10–15 minutes.

<div class="ws-output" markdown>
```text
Destroy complete! Resources: 96 destroyed.
```
</div>

??? note "If destroy hangs on the VPC"
    Almost always a leftover ENI or security group from a load balancer or a node that wasn't cleaned up. Check **EC2 → Network Interfaces** filtered by the VPC, delete the stragglers, re-run `make base-down`.

## Verify you're at zero

```bash
aws eks list-clusters --region "$AWS_REGION"
aws ec2 describe-instances --region "$AWS_REGION" \
  --filters Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,Tags[?Key==`Name`].Value|[0]]' --output table
```

<div class="ws-output" markdown>
```text
{
    "clusters": []
}
--------------------
| DescribeInstances |
--------------------
```
</div>

Empty and empty. Also worth a glance the next morning: **Billing → Cost Explorer**, filtered to today — you should see a small bump and then nothing.

## Keeping it

If you'd rather keep the cluster to play with: run steps 1–2 only. That leaves the base stack (≈ $0.55/hour) with no GPUs. `make lab1` and `make lab2` rebuild the labs in about 15 minutes whenever you want them back.

## Quota

You can leave the quota increase in place; it costs nothing until you launch instances. If you'd rather reduce it, that's a Service Quotas request like any other.
