#!/usr/bin/env bash
# Lab 1, unattended: NodePool + EC2NodeClass, GPU Operator, smoke pod.
# In the live session attendees do these by hand, step by step.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source .workshop.env
export AMI_VERSION="${AMI_VERSION:-$(./scripts/ami-version.sh)}"
echo "Pinning AL2023 NVIDIA AMI ${AMI_VERSION}"

envsubst < modules/01-gpu-nodes/ec2nodeclass.yaml | kubectl apply -f -
kubectl apply -f modules/01-gpu-nodes/nodepool.yaml

helm repo add nvidia https://helm.ngc.nvidia.com/nvidia >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install gpu-operator nvidia/gpu-operator --version v26.7.0 \
  -n gpu-operator --create-namespace -f modules/02-gpu-operator/values.yaml --wait

kubectl apply -f modules/01-gpu-nodes/gpu-smoke.yaml
echo "Waiting for the GPU node and the smoke pod (≈4 min)…"
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/gpu-smoke --timeout=15m
./scripts/validate-lab1.sh
