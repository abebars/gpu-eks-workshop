# Engineering GPU Infrastructure for AI Workloads

Companion repo for the hands-on workshop **"Engineering GPU Infrastructure for AI Workloads — a hands-on introduction to GPU inference serving on Amazon EKS"** by [Ahmed Bebars](https://abebars.io).

**Attendee guide:** https://gpu-eks-workshop.ahmedbebars.io/

In ~3.5 hours you take an EKS cluster from zero GPUs to serving a real LLM (vLLM + Qwen2.5-1.5B) on Karpenter-provisioned g5/g6 nodes, with GPU time-slicing, KEDA autoscaling and DCGM/Prometheus/Grafana observability. Inference only; no training.

## Layout

```
.
├── docs/                    # the attendee guide (MkDocs Material) — what you read at the site
├── modules/
│   ├── 01-gpu-nodes/        # Karpenter EC2NodeClass + NodePool, smoke-test pod
│   ├── 02-gpu-operator/     # GPU Operator Helm values for EKS AL2023 NVIDIA AMIs
│   ├── 03-sharing/          # time-slicing ConfigMap, image pre-pull, shared-load, "forgotten notebook"
│   ├── 04-vllm/             # vLLM Deployment/Service/PodMonitor, KEDA ScaledObject, k6 load jobs
│   └── 05-observability/    # Grafana dashboard for vLLM serving
├── scripts/                 # preflight, quota, AMI pinning, per-lab validators
├── terraform/               # the base stack: VPC, EKS 1.36, system nodes, Karpenter, kube-prometheus-stack, KEDA
├── facilitator/             # run-of-show and pre-work email (for whoever is presenting)
└── Makefile                 # preflight · base-up · lab1 · lab2 · load-test · workshop-down
```

The manifests in `modules/` are embedded into the guide at build time, so the YAML you read on the site is the YAML you apply.

## Quick start

```bash
git clone https://github.com/abebars/gpu-eks-workshop && cd gpu-eks-workshop
export AWS_REGION=us-east-1
make check-quota          # needs 32 vCPUs of On-Demand G *and* Spot G — request a week ahead
make base-up              # ~20 min: VPC, EKS, Karpenter, monitoring, KEDA. No GPUs yet.
make preflight
```

Then follow the guide from [Module 1](https://gpu-eks-workshop.ahmedbebars.io/01-why-gpus-are-hard/). To rebuild everything unattended: `make workshop-up`. To tear down: `make workshop-down`.

## Versions this was written against

| Component | Version |
|-----------|---------|
| Amazon EKS | 1.36 (AL2023 NVIDIA-accelerated AMI, pinned by release date) |
| Karpenter | 1.14.x |
| NVIDIA GPU Operator | v26.7.0 (`driver.enabled=false`, `toolkit.enabled=false`, `cdi.enabled=false`) |
| vLLM | `vllm/vllm-openai:v0.28.0` |
| KEDA | 2.20.x |
| kube-prometheus-stack | 90.x |
| k6 | 2.2.0 |
| terraform-aws-modules/eks | ~> 21.0 |

## Building the guide locally

```bash
pip install -r requirements.txt
mkdocs serve          # http://127.0.0.1:8000
mkdocs build --strict
python3 docs/assets/diagrams/build.py   # regenerate diagrams (needs graphviz)
```

## License

Code and manifests: Apache-2.0. Guide text and diagrams: CC BY 4.0.
