variable "cluster_name" {
  description = "EKS cluster name. Also used as the karpenter.sh/discovery tag value."
  type        = string
  default     = "gpu-workshop"
}

variable "region" {
  description = "AWS region. Request GPU quota in the same region."
  type        = string
  default     = "us-east-1"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version. The AL2023 NVIDIA AMI alias in Lab 1 resolves against this."
  type        = string
  default     = "1.36"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "system_instance_type" {
  description = "Instance type for the CPU-only system node group (Karpenter, Prometheus, Grafana, KEDA, k6)."
  type        = string
  default     = "m6i.xlarge"
}

variable "system_node_count" {
  type    = number
  default = 2
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint. null = your current public IP only."
  type        = list(string)
  default     = null
}

variable "grafana_admin_password" {
  description = "Grafana admin password. It's a workshop; keep it simple, tear it down after."
  type        = string
  default     = "gpu-workshop"
  sensitive   = true
}

variable "karpenter_version" {
  description = "Karpenter Helm chart version (must support the Kubernetes version above)."
  type        = string
  default     = "1.14.1"
}

variable "kube_prometheus_stack_version" {
  type    = string
  default = "90.0.0"
}

variable "keda_version" {
  type    = string
  default = "2.20.2"
}

variable "tags" {
  type = map(string)
  default = {
    workshop = "gpu-eks"
    owner    = "attendee"
  }
}
