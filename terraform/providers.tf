provider "aws" {
  region = var.region
  default_tags {
    tags = var.tags
  }
}

# ECR Public (where the Karpenter chart lives) only issues tokens in us-east-1.
provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
}

provider "helm" {
  # Isolated from the operator's ambient ~/.helm — a laptop with unrelated,
  # stale repos registered (e.g. a dead upstream index) breaks chart lookup
  # here even though this project never references those repos.
  repository_config_path = "${path.module}/.helm/repositories.yaml"
  repository_cache       = "${path.module}/.helm/cache"

  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
    }
  }
}
