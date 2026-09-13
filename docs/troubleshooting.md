# Troubleshooting

Organised by symptom. Every entry starts with the one command that tells you which branch you're on.

## Karpenter won't launch a node

**Symptom:** a GPU pod stays `Pending`; `kubectl get nodeclaims` shows nothing, or a NodeClaim that never gets a NODE.

```bash
kubectl describe nodeclaim | grep -A15 Events
kubectl -n karpenter logs deploy/karpenter --since=10m | grep -iE 'error|insufficient|limit|quota'
```

| You see | It means | Fix |
|---------|----------|-----|
| `VcpuLimitExceeded` | Your G-family quota is too low for the instance Karpenter chose | [Request quota](00-prework/01-quota.md); check *both* On-Demand and Spot |
| `InsufficientInstanceCapacity` for every type | No g5/g6 capacity in any allowed AZ right now | Wait 3 min (Karpenter retries); temporarily add `g4dn` to `instance-family`; or try the other region |
| `would exceed limit … nvidia.com/gpu` | NodePool `limits` reached (a time-sliced node counts as 4) | Un-slice node A ([3.5](03-scheduling-and-sharing/05-reset.md)), delete something, or raise the limit |
| `no instance type satisfied resources` | The pod's CPU/memory request doesn't fit any allowed type | Lower the request or allow `2xlarge`+ |
| No NodeClaim at all, no log lines | The pod isn't tolerating the taint, or has a `nodeSelector` nothing matches | `kubectl describe pod` → Events: "untolerated taint" / "didn't match node selector" |
| `EC2NodeClass … not ready` | AMI alias didn't resolve, or subnet/SG tags missing | `kubectl describe ec2nodeclass gpu`; check `AMI_VERSION` exists for your K8s version |

## Node exists but `nvidia.com/gpu` never appears

```bash
kubectl -n gpu-operator get pods -o wide
kubectl get clusterpolicy cluster-policy -o jsonpath='{.status.state}{"\n"}'
kubectl get node <node> -o jsonpath='{.metadata.labels}' | jq 'with_entries(select(.key|startswith("nvidia.com")))'
```

| You see | It means | Fix |
|---------|----------|-----|
| `nvidia-driver-daemonset` in CrashLoopBackOff | The Operator is installing a driver over the AMI's | `helm upgrade … -f modules/02-gpu-operator/values.yaml` — `driver.enabled=false` |
| `nvidia-operator-validator` stuck `Init:…` | Toolkit/driver validation failing | `kubectl -n gpu-operator logs <validator-pod> -c driver-validation` — usually toolkit/CDI mismatch; confirm `toolkit.enabled=false`, `cdi.enabled=false` |
| No `nvidia.com/gpu.present=true` label | NFD didn't detect the PCI device | Is it actually a GPU instance? `kubectl get node <node> -L node.kubernetes.io/instance-type` |
| Device plugin `Running` but capacity still `<none>` | Plugin can't talk to kubelet | `kubectl -n gpu-operator logs <device-plugin-pod>`; a node reboot (`kubectl delete node` → Karpenter replaces it) is the fast path in a workshop |
| Everything Running, ClusterPolicy `notReady` | The cuda-validator pod failed | `kubectl -n gpu-operator logs -l app=nvidia-cuda-validator` |

## `nvidia-smi` says "couldn't communicate with the NVIDIA driver"

The container was scheduled but the GPU wasn't injected. On EKS this is almost always the CDI/toolkit combination:

```bash
helm get values gpu-operator -n gpu-operator
```

Expect `cdi.enabled: false`, `toolkit.enabled: false`, `driver.enabled: false`. If not, `helm upgrade` with the workshop values and delete the device-plugin pod on the node so it restarts.

## Time-slicing didn't take

```bash
kubectl get node "$NODE_A" -L nvidia.com/device-plugin.config,nvidia.com/gpu.replicas
kubectl -n gpu-operator logs -l app=nvidia-device-plugin-daemonset -c config-manager --tail=20
```

| You see | Fix |
|---------|-----|
| Label present, replicas still `1` | The ConfigMap key doesn't match the label value (`four-way`); or the ClusterPolicy patch didn't include `config.name` |
| Device plugin pod has only 1 container | The ClusterPolicy patch from [3.2](03-scheduling-and-sharing/02-time-slicing.md) didn't apply; re-run it |
| Pods `Pending` with "Insufficient nvidia.com/gpu" after labelling | The plugin restarted and briefly advertised 0; wait 30 s |

## vLLM pod problems

```bash
kubectl -n vllm describe pod -l app=vllm | grep -A20 Events
kubectl -n vllm logs -l app=vllm --tail=50
```

| You see | It means | Fix |
|---------|----------|-----|
| `Pending`, "Insufficient nvidia.com/gpu" | Every GPU is taken (notebook + shared-load?) | Run [3.5 Reset](03-scheduling-and-sharing/05-reset.md); or wait for Karpenter (limits!) |
| `ContainerCreating` for > 5 min | Image pull on a cold node | `kubectl describe pod` → "Pulling image". Normal on a fresh node; pre-pull next time |
| Restarting every ~30 s, log ends mid-startup | Probes killed it | Confirm the `startupProbe` is present (`kubectl -n vllm get deploy vllm -o yaml \| grep -A4 startupProbe`) |
| `CUDA out of memory` at startup | `--gpu-memory-utilization` too high for what else is on the card, or a shared node | Lower to 0.8; make sure the node isn't time-sliced |
| `RuntimeError: … shared memory` / `Bus error` | `/dev/shm` too small | The `shm` emptyDir volume is missing or under-sized |
| `401` / `gated repo` from Hugging Face | Wrong model, or a gated one | Qwen2.5 is ungated; for gated models add `HF_TOKEN` |
| Download at < 5 MB/s | NAT gateway or HF throttling | It'll finish; for production put weights in S3 in-region |

## KEDA doesn't scale

```bash
kubectl -n vllm describe scaledobject vllm | grep -A12 Conditions
kubectl -n vllm get hpa keda-hpa-vllm
kubectl -n keda logs deploy/keda-operator --since=5m | grep -i vllm
```

| You see | Fix |
|---------|-----|
| `READY False`, "error requesting metrics" | `serverAddress` wrong or Prometheus not reachable from the `keda` namespace; `curl` it from a debug pod |
| `READY True`, HPA `TARGETS <unknown>` | The query returns no series — the `model_name` label doesn't match `--served-model-name`, or the PodMonitor isn't being scraped (check `localhost:9090/targets`) |
| HPA wants 2 but replicas stay 1 | `maxReplicaCount` / NodePool `limits` / quota — one of the three caps is hit |
| Scaled up but never scales down | `scaleDown.stabilizationWindowSeconds` is 300 s; wait; check the load job actually finished (`kubectl -n vllm get jobs`) |

## Grafana / Prometheus

| Symptom | Fix |
|---------|-----|
| Port-forward dies | They do. Re-run `make grafana`. |
| DCGM dashboard empty | Prometheus **Status → Targets**: is `nvidia-dcgm-exporter` there? If not, the ServiceMonitor isn't selected — the base stack sets `serviceMonitorSelectorNilUsesHelmValues: false`; verify with `kubectl -n monitoring get prometheus -o yaml \| grep -A2 serviceMonitorSelector` |
| vLLM dashboard missing | `kubectl -n monitoring get cm gpu-workshop-vllm-dashboard` — the sidecar needs the `grafana_dashboard: "1"` label |
| Per-pod panels empty | Node is time-sliced (expected), or dcgm-exporter started before the pod (restart the exporter pod) |

## Credentials and tools

| Symptom | Fix |
|---------|-----|
| `error: You must be logged in to the server (Unauthorized)` | AWS credentials rotated; re-auth and `make kubeconfig` |
| `envsubst: command not found` | macOS: `brew install gettext && brew link --force gettext` |
| `kubectl` warns about version skew | Client must be within ±1 minor of 1.36 |
| `terraform apply` fails on `aws_eks_cluster` with an IAM error | Your principal lacks EKS/IAM permissions; this is an account problem, not a Terraform one |

## Nuclear options (in a workshop, fine)

- **Bad node:** `kubectl delete node <node>` — Karpenter replaces it in ~3 minutes.
- **Bad Operator install:** `helm uninstall gpu-operator -n gpu-operator && kubectl delete ns gpu-operator`, then reinstall from [2.3](02-lab1-gpu-ready-eks/03-gpu-operator.md).
- **Everything:** `make workshop-down && make workshop-up` — about 35 minutes end to end.
