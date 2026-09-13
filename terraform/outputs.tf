output "cluster_name" {
  value = module.eks.cluster_name
}

output "region" {
  value = var.region
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "karpenter_node_iam_role_name" {
  description = "IAM role NAME for Karpenter-launched nodes — goes into EC2NodeClass.spec.role in Lab 1."
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_queue_name" {
  value = module.karpenter.queue_name
}

output "configure_kubectl" {
  description = "Run this to point kubectl at the cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "grafana_admin_password" {
  value     = var.grafana_admin_password
  sensitive = true
}

output "api_allowed_cidrs" {
  description = "CIDRs allowed to reach the EKS API. If your IP changes, re-apply with -var 'api_allowed_cidrs=[\"x.x.x.x/32\"]'."
  value       = local.api_cidrs
}
