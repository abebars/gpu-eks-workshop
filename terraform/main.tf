# ------------------------------------------------------------------------------
# Base stack for the GPU workshop.
#
# Deliberately boring: VPC, EKS control plane, a small CPU-only node group,
# Karpenter, kube-prometheus-stack (with the DCGM dashboard pre-imported) and
# KEDA. NOTHING GPU-related lives here — no NodePool, no GPU Operator. Those
# are built by hand in the labs.
# ------------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  name      = var.cluster_name
  azs       = slice(data.aws_availability_zones.available.names, 0, 3)
  api_cidrs = var.api_allowed_cidrs != null ? var.api_allowed_cidrs : ["${chomp(data.http.my_ip.response_body)}/32"]
}

# ------------------------------------------------------------------------------
# VPC
# ------------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true # one NAT is plenty for a workshop and a third of the cost

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    # Karpenter's EC2NodeClass discovers subnets by this tag (Lab 1).
    "karpenter.sh/discovery" = local.name
  }
}

# ------------------------------------------------------------------------------
# EKS
# ------------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  endpoint_public_access       = true
  endpoint_public_access_cidrs = local.api_cidrs

  # Whoever runs terraform gets cluster-admin via an EKS access entry.
  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
    metrics-server = {} # community add-on; needed for `kubectl top` and plain CPU HPAs
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    system = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [var.system_instance_type]

      min_size     = var.system_node_count
      max_size     = var.system_node_count + 1
      desired_size = var.system_node_count

      labels = {
        "workshop.abebars.io/pool" = "system"
      }
    }
  }

  # Karpenter's EC2NodeClass discovers the node security group by this tag (Lab 1).
  node_security_group_tags = {
    "karpenter.sh/discovery" = local.name
  }
}

# ------------------------------------------------------------------------------
# Karpenter — IAM (Pod Identity), node role, interruption queue, then the chart.
# No NodePool here: attendees write it in Lab 1.
# ------------------------------------------------------------------------------
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.0"

  cluster_name = module.eks.cluster_name
  namespace    = "karpenter"

  # A stable, predictable role name: it goes into EC2NodeClass.spec.role in Lab 1.
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "KarpenterNodeRole-${module.eks.cluster_name}"

  # Pod Identity is the v21 default; the association is created for the
  # "karpenter" service account in the namespace above.
  create_pod_identity_association = true

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true
  name             = "karpenter"

  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = var.karpenter_version
  wait                = true

  values = [yamlencode({
    # Resolve the EKS endpoint through the VPC resolver, not CoreDNS, so
    # Karpenter keeps working even when cluster DNS is unhappy.
    dnsPolicy = "Default"
    # One replica for the workshop so `kubectl logs deploy/karpenter` is the
    # leader. Production: 2 (the chart default) with leader election.
    replicas = 1
    settings = {
      clusterName       = module.eks.cluster_name
      clusterEndpoint   = module.eks.cluster_endpoint
      interruptionQueue = module.karpenter.queue_name
    }
    controller = {
      resources = {
        requests = { cpu = "1", memory = "1Gi" }
        limits   = { memory = "1Gi" }
      }
    }
  })]

  depends_on = [module.eks, module.karpenter]
}

# ------------------------------------------------------------------------------
# kube-prometheus-stack — Prometheus + Grafana, wide open to ServiceMonitors and
# PodMonitors from any chart, with the NVIDIA DCGM dashboard pre-imported.
# ------------------------------------------------------------------------------
resource "helm_release" "kube_prometheus_stack" {
  namespace        = "monitoring"
  create_namespace = true
  name             = "kube-prometheus-stack"

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_version
  wait       = true
  timeout    = 900

  values = [templatefile("${path.module}/values/kube-prometheus-stack.yaml", {
    grafana_admin_password = var.grafana_admin_password
  })]

  depends_on = [module.eks]
}

# ------------------------------------------------------------------------------
# KEDA — installed empty. The ScaledObject is Lab 2.
# ------------------------------------------------------------------------------
resource "helm_release" "keda" {
  namespace        = "keda"
  create_namespace = true
  name             = "keda"

  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = var.keda_version
  wait       = true

  depends_on = [module.eks]
}
