# 3.2 Time-slice a node

<div class="ws-meta" markdown>
<span>**Time:** 5 min</span>
<span>**Changes:** your Lab 1 node goes from `nvidia.com/gpu: 1` to `nvidia.com/gpu: 4`</span>
</div>

Time-slicing is configured in two places: a **ConfigMap** that describes the sharing policy, and a **node label** that opts a node into it. The ClusterPolicy connects the two. Nothing changes on a node until it's labelled — which is exactly the control you want in a mixed fleet.

## Step 1 — The sharing config

```yaml title="modules/03-sharing/time-slicing-config.yaml"
--8<-- "modules/03-sharing/time-slicing-config.yaml"
```

`replicas: 4` means the device plugin advertises four `nvidia.com/gpu` for every physical GPU. `failRequestsGreaterThanOne: true` rejects any pod asking for `2` on a sliced node — two slices of the same card is not two GPUs, and the pod would find that out the hard way.

!!! quirk "Why two keys?"
    The device plugin's config manager has a *single* fallback: if the ConfigMap has exactly one key, it applies it to **every** node whether labelled or not. A ConfigMap with only `four-way` would slice your whole fleet the moment the Operator picked it up. The `exclusive` key exists so that unlabelled nodes stay exclusive.

```bash
kubectl apply -f modules/03-sharing/time-slicing-config.yaml
```

## Step 2 — Tell the Operator about it

```bash
kubectl patch clusterpolicies.nvidia.com/cluster-policy -n gpu-operator --type merge \
  -p '{"spec": {"devicePlugin": {"config": {"name": "time-slicing-config", "default": ""}}}}'
```

<div class="ws-output" markdown>
```text
clusterpolicy.nvidia.com/cluster-policy patched
```
</div>

`name` points at the ConfigMap; `default: ""` plus the two-key ConfigMap means **no** sharing applies unless a node asks for it by label. (Setting `default: four-way` would slice every GPU node in the cluster — sometimes what you want, never by accident.)

The Operator now re-renders the device-plugin DaemonSet with a *config-manager* sidecar that watches node labels. You'll see the plugin pod restart once on your GPU node:

```bash
kubectl -n gpu-operator get pods -l app=nvidia-device-plugin-daemonset -w
```

<div class="ws-output" markdown>
```text
NAME                                   READY   STATUS        RESTARTS   AGE
nvidia-device-plugin-daemonset-7tqrc   1/1     Terminating   0          52m
nvidia-device-plugin-daemonset-b2xk8   0/2     Init:0/1      0          1s
nvidia-device-plugin-daemonset-b2xk8   2/2     Running       0          9s
```
</div>

`2/2` — the second container is the config manager. Press ++ctrl+c++.

!!! quirk "The Operator does not watch the ConfigMap"
    Edit the ConfigMap later (say, `replicas: 8`) and nothing happens. The device plugin only re-reads its config when the *label* changes or the pod restarts. NVIDIA's docs say so explicitly. Treat sharing configs as immutable: make a new key (`eight-way`), then relabel.

## Step 3 — Opt your node in

```bash
export NODE_A=$(kubectl get nodes -l karpenter.sh/nodepool=gpu -o jsonpath='{.items[0].metadata.name}')
echo "$NODE_A"
kubectl label node "$NODE_A" nvidia.com/device-plugin.config=four-way
```

<div class="ws-output" markdown>
```text
ip-10-0-23-77.ec2.internal
node/ip-10-0-23-77.ec2.internal labeled
```
</div>

The config manager sees the label, writes the `four-way` config into place and restarts the plugin container. Ten seconds later:

```bash
kubectl get node "$NODE_A" -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu,REPLICAS:.metadata.labels.nvidia\.com/gpu\.replicas,PRODUCT:.metadata.labels.nvidia\.com/gpu\.product,STRATEGY:.metadata.labels.nvidia\.com/gpu\.sharing-strategy'
```

<div class="ws-output" markdown>
```text
NAME                         GPU   REPLICAS   PRODUCT            STRATEGY
ip-10-0-23-77.ec2.internal   4     4          NVIDIA-L4-SHARED   time-slicing
```
</div>

Three things changed and all three are visible to the scheduler and to anyone reading labels:

- **`nvidia.com/gpu: 4`** — one physical L4, four schedulable units.
- **`nvidia.com/gpu.product: NVIDIA-L4-SHARED`** — GFD appends `-SHARED` so a `nodeSelector` on the unsliced product name will *not* match this node. That's your safety rail for latency-sensitive workloads: select `NVIDIA-L4` and you can never land on a shared card by accident.
- **`nvidia.com/gpu.sharing-strategy: time-slicing`** — the explicit label if you'd rather select on that.

If the numbers didn't change after 30 seconds, `kubectl -n gpu-operator logs -l app=nvidia-device-plugin-daemonset -c config-manager` tells you why (usually a typo in the label value vs. the ConfigMap key).

[Next: 3.3 Four pods, one GPU →](03-four-pods.md)
