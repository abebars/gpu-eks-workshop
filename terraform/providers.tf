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
