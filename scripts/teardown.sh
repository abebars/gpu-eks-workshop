#!/usr/bin/env bash
# Reverse order of the labs: workloads → GPU nodes → Operator. Base stack is
# destroyed separately by `make base-down` (called from `make workshop-down`).
set -uo pipefail
cd "$(dirname "$0")/.." || exit
kubectl delete -f modules/04-vllm/ --ignore-not-found
kubectl delete -f modules/03-sharing/ --ignore-not-found
kubectl delete -f modules/01-gpu-nodes/gpu-smoke.yaml --ignore-not-found
kubectl delete nodepool gpu --ignore-not-found
echo "Waiting for Karpenter to terminate GPU nodes…"
kubectl wait --for=delete nodeclaims --all --timeout=10m 2>/dev/null || true
kubectl delete ec2nodeclass gpu --ignore-not-found
helm uninstall gpu-operator -n gpu-operator 2>/dev/null || true
kubectl delete namespace gpu-operator --ignore-not-found --timeout=120s || true
echo "Remaining EC2 instances tagged for this workshop (should be only the system nodes):"
aws ec2 describe-instances --region "${AWS_REGION:-us-east-1}" \
  --filters Name=instance-state-name,Values=running,pending Name=tag:karpenter.sh/nodepool,Values=gpu \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name]' --output table
