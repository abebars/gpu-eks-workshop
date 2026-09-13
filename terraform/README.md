# Base stack

Everything **except** GPUs. Run it the evening before the workshop (`make base-up` from the repo root), ~20 minutes.

| Creates | Notes |
|---------|-------|
| VPC | 3 AZs, private + public subnets, one NAT gateway. Private subnets tagged `karpenter.sh/discovery=<cluster_name>`. |
| EKS | `kubernetes_version` (default 1.36). Public endpoint restricted to your current IP (or `api_allowed_cidrs`). Add-ons: vpc-cni, coredns, kube-proxy, eks-pod-identity-agent, metrics-server. |
| System node group | `system_node_count` × `system_instance_type` (2 × m6i.xlarge), AL2023 standard AMI. |
| Karpenter | Chart `karpenter_version` in namespace `karpenter`, Pod Identity, SQS interruption queue, node IAM role (`karpenter_node_iam_role_name` output). **No NodePool** — Lab 1. |
| kube-prometheus-stack | `values/kube-prometheus-stack.yaml`: open ServiceMonitor/PodMonitor selectors, Grafana with DCGM dashboard 12239 pre-imported, sidecar for ConfigMap dashboards. |
| KEDA | Chart `keda_version` in namespace `keda`. |

## Outputs the labs depend on

- `cluster_name`, `region` → `.workshop.env`
- `karpenter_node_iam_role_name` → `EC2NodeClass.spec.role`
- `configure_kubectl` → `make kubeconfig`
- `grafana_admin_password` → `make grafana`

## Notes

- Your public IP is looked up from `checkip.amazonaws.com` at plan time. If it changes (VPN, café), `terraform apply -var 'api_allowed_cidrs=["<new ip>/32"]'` or set it in `terraform.tfvars`.
- State is local (`terraform.tfstate`). Don't lose it before `make workshop-down`.
- Status: written against terraform-aws-modules/eks **v21**, helm provider **v3**. Validate with `terraform init && terraform validate`; the CI workflow does the same.
