# 2.1 Verify the base stack

<div class="ws-meta" markdown>
<span>**Time:** 3 min</span>
</div>

Load the environment the pre-work wrote, and make sure `kubectl` is pointed at the right cluster. Every command in the labs assumes you're in the repo root with these variables set.

```bash
cd gpu-eks-workshop
source .workshop.env
echo "$CLUSTER_NAME in $AWS_REGION, node role $KARPENTER_NODE_ROLE"
kubectl config current-context
```

<div class="ws-output" markdown>
```text
gpu-workshop in us-east-1, node role KarpenterNodeRole-gpu-workshop
arn:aws:eks:us-east-1:123456789012:cluster/gpu-workshop
```
</div>

## The platform pieces are running

```bash
kubectl get deploy -n karpenter
kubectl get deploy -n monitoring
kubectl get deploy -n keda
```

<div class="ws-output" markdown>
```text
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
karpenter   2/2     2            2           14h

NAME                                        READY   UP-TO-DATE   AVAILABLE   AGE
kube-prometheus-stack-grafana               1/1     1            1           14h
kube-prometheus-stack-kube-state-metrics    1/1     1            1           14h
kube-prometheus-stack-operator              1/1     1            1           14h

NAME                              READY   UP-TO-DATE   AVAILABLE   AGE
keda-admission-webhooks           1/1     1            1           14h
keda-operator                     1/1     1            1           14h
keda-operator-metrics-apiserver   1/1     1            1           14h
```
</div>

## Karpenter has nothing to manage yet

```bash
kubectl get nodepools,ec2nodeclasses,nodeclaims
```

<div class="ws-output" markdown>
```text
No resources found
```
</div>

That's the state we want: Karpenter is running, but you have not told it *what* it may provision. That's the NodePool, and it's yours to write.

## And there are no GPUs

```bash
kubectl get nodes -o custom-columns='NAME:.metadata.name,INSTANCE:.metadata.labels.node\.kubernetes\.io/instance-type,GPU:.status.allocatable.nvidia\.com/gpu'
```

<div class="ws-output" markdown>
```text
NAME                          INSTANCE     GPU
ip-10-0-11-23.ec2.internal    m6i.xlarge   <none>
ip-10-0-42-118.ec2.internal   m6i.xlarge   <none>
```
</div>

!!! tip "Open a second terminal now"
    In the second pane, start a watch that you'll leave running for the rest of the lab:

    ```bash
    kubectl get nodeclaims,nodes -w
    ```

    Nothing will happen for a while. That's the point — you'll see the exact moment Karpenter acts.

[Next: 2.2 Create GPU capacity →](02-nodepool.md)
