# Where to go next

Every technical claim in this guide was checked against the sources below. When something here and something there disagree, the source wins — and please [open an issue](https://github.com/abebars/gpu-eks-workshop/issues).

## Amazon EKS

- [EKS-optimised accelerated AMIs (AL2023 NVIDIA)](https://docs.aws.amazon.com/eks/latest/userguide/ml-eks-optimized-ami.html) — what's in the AMI, what isn't
- [NVIDIA device plugin vs. DRA on EKS](https://docs.aws.amazon.com/eks/latest/userguide/device-management-nvidia-dra-device-plugin.html) — AWS's current recommendation by capacity model
- [MIG on EKS](https://docs.aws.amazon.com/eks/latest/userguide/device-management-nvidia-mig.html)
- [Retrieve recommended AMI IDs via SSM](https://docs.aws.amazon.com/eks/latest/userguide/retrieve-ami-id.html)
- [EKS Auto Mode: accelerated instances](https://docs.aws.amazon.com/eks/latest/userguide/auto-accelerated.html)
- [EKS best practices: AI/ML compute](https://docs.aws.amazon.com/eks/latest/best-practices/aiml-compute.html)
- [EC2 instance quotas (vCPU-based)](https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-instance-quotas.html) · [Spot limits](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-spot-limits.html)
- [Accelerated instance types reference](https://docs.aws.amazon.com/ec2/latest/instancetypes/ac.html) · [G5](https://aws.amazon.com/ec2/instance-types/g5/) · [G6](https://aws.amazon.com/ec2/instance-types/g6/) · [G6e](https://aws.amazon.com/ec2/instance-types/g6e/)
- [Amazon EKS Workshop](https://www.eksworkshop.com/) — the AI/ML chapter has a vLLM chatbot lab that picks up where this one stops

## Karpenter

- [NodePools](https://karpenter.sh/docs/concepts/nodepools/) · [EC2NodeClasses](https://karpenter.sh/docs/concepts/nodeclasses/) — the `amiSelectorTerms` alias syntax and pinning
- [Managing AMIs](https://karpenter.sh/docs/tasks/managing-amis/) — the `@latest` warning
- [Disruption](https://karpenter.sh/docs/concepts/disruption/) — consolidation policies, budgets, interruption handling
- [Scheduling: accelerators](https://karpenter.sh/docs/concepts/scheduling/#acceleratorsgpu-resources) — why the device plugin must exist before the node
- [Getting started](https://karpenter.sh/docs/getting-started/getting-started-with-karpenter/) · [Compatibility matrix](https://karpenter.sh/docs/upgrading/compatibility/)

## NVIDIA

- [GPU Operator: getting started](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html) — pre-installed driver / toolkit sections
- [GPU Operator: time-slicing](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html) — including the caveats we quoted
- [GPU Operator: MIG](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-operator-mig.html) · [MIG supported GPUs](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/supported-gpus.html)
- [GPU Operator: CDI](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/cdi.html) · [Release notes](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/release-notes.html)
- [Kubernetes device plugin](https://github.com/NVIDIA/k8s-device-plugin) — sharing configs, MPS, GFD labels
- [DCGM exporter](https://github.com/NVIDIA/dcgm-exporter) · [GPU telemetry with kube-prometheus](https://docs.nvidia.com/datacenter/cloud-native/gpu-telemetry/latest/kube-prometheus.html) · [Grafana dashboard 12239](https://grafana.com/grafana/dashboards/12239-nvidia-dcgm-exporter-dashboard/)
- [DCGM profiling metrics](https://docs.nvidia.com/datacenter/dcgm/latest/learn/modules/profiling.html) — what `SM_ACTIVE` and `PIPE_TENSOR_ACTIVE` actually measure

## Kubernetes

- [Schedule GPUs](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/) · [Extended resources](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#extended-resources)
- [Dynamic Resource Allocation](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/)
- [Startup probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#define-startup-probes) · [emptyDir (memory-backed)](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir)
- [Horizontal Pod Autoscaling](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/)

## vLLM, KEDA, k6, Prometheus

- [vLLM: OpenAI-compatible server](https://docs.vllm.ai/en/latest/serving/openai_compatible_server.html) · [Kubernetes deployment](https://docs.vllm.ai/en/latest/deployment/k8s/) · [Metrics](https://docs.vllm.ai/en/latest/usage/metrics.html) · [Troubleshooting](https://docs.vllm.ai/en/latest/usage/troubleshooting.html)
- [KEDA: Prometheus scaler](https://keda.sh/docs/latest/scalers/prometheus/) · [ScaledObject spec](https://keda.sh/docs/latest/reference/scaledobject-spec/) · [Scaling deployments](https://keda.sh/docs/latest/concepts/scaling-deployments/)
- [k6 docs](https://grafana.com/docs/k6/latest/)
- [kube-prometheus-stack chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) · [PodMonitor / ServiceMonitor](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/developer/getting-started.md)

## Models

- [Qwen/Qwen2.5-1.5B-Instruct](https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct) — Apache-2.0, ungated. Try `Qwen/Qwen3-1.7B` next (add `--reasoning-parser qwen3` and think about `enable_thinking`).
