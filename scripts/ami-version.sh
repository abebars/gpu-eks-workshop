#!/usr/bin/env bash
# Resolves the CURRENT recommended EKS AL2023 NVIDIA AMI release for the
# cluster's Kubernetes version and prints the Karpenter alias version to pin.
#
#   AMI_VERSION=$(./scripts/ami-version.sh)       → e.g. v20260827
#
# We pin on purpose. "al2023@latest" would recycle every GPU node whenever
# AWS publishes a new AMI, possibly with a different NVIDIA driver.
set -euo pipefail
REGION="${AWS_REGION:-us-east-1}"
if [ -z "${K8S_VERSION:-}" ]; then
  K8S_VERSION=$(kubectl version -o json 2>/dev/null | jq -r '.serverVersion | "\(.major).\(.minor|gsub("[^0-9]";""))"' 2>/dev/null || true)
fi
if [ -z "$K8S_VERSION" ] || [ "$K8S_VERSION" = "null.null" ]; then
  echo "set K8S_VERSION (e.g. 1.36) or point kubectl at the cluster" >&2; exit 1
fi

release=$(aws ssm get-parameter \
  --name "/aws/service/eks/optimized-ami/${K8S_VERSION}/amazon-linux-2023/x86_64/nvidia/recommended/release_version" \
  --region "$REGION" --query 'Parameter.Value' --output text)
# release_version looks like "1.36.3-20260827"; the alias wants "v20260827"
echo "v${release##*-}"

if [ -f .workshop.env ] && ! grep -q AMI_VERSION .workshop.env; then
  echo "export AMI_VERSION=v${release##*-}" >> .workshop.env
fi
