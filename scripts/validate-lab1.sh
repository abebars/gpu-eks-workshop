#!/usr/bin/env bash
# Lab 1 checkpoint: a GPU node exists, the Operator is healthy on it, and the
# smoke pod printed nvidia-smi output.
set -uo pipefail
fail=0
pass() { printf '  ✅ %s\n' "$1"; }
bad()  { printf '  ❌ %s\n' "$1"; fail=1; }

echo "Lab 1 validation"
gpu_nodes=$(kubectl get nodes -l karpenter.sh/nodepool=gpu --no-headers 2>/dev/null | wc -l | tr -d ' ')
[ "$gpu_nodes" -ge 1 ] && pass "$gpu_nodes GPU node(s) from NodePool 'gpu'" || bad "no nodes from NodePool 'gpu' (kubectl get nodeclaims)"

alloc=$(kubectl get nodes -l karpenter.sh/nodepool=gpu -o jsonpath='{.items[*].status.allocatable.nvidia\.com/gpu}' 2>/dev/null)
[ -n "$alloc" ] && pass "allocatable nvidia.com/gpu on GPU node(s): $alloc" || bad "nvidia.com/gpu not advertised — is the device plugin running?"

for ds in nvidia-device-plugin-daemonset nvidia-dcgm-exporter gpu-feature-discovery; do
  ready=$(kubectl -n gpu-operator get ds "$ds" -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)
  [ "${ready:-0}" -ge 1 ] && pass "$ds ready on $ready node(s)" || bad "$ds has 0 ready pods"
done

drv=$(kubectl -n gpu-operator get ds nvidia-driver-daemonset --no-headers 2>/dev/null | wc -l | tr -d ' ')
[ "$drv" -eq 0 ] && pass "no nvidia-driver-daemonset (driver.enabled=false — correct on EKS)" || bad "nvidia-driver-daemonset exists — the Operator is trying to install a driver over the AMI's driver"

phase=$(kubectl get pod gpu-smoke -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$phase" = "Succeeded" ] && kubectl logs gpu-smoke 2>/dev/null | grep -q "NVIDIA-SMI"; then
  pass "gpu-smoke ran nvidia-smi: $(kubectl logs gpu-smoke | grep -oE 'NVIDIA (A10G|L4|L40S|T4)' | head -1)"
else
  bad "gpu-smoke is '$phase' (kubectl describe pod gpu-smoke)"
fi

[ "$fail" -eq 0 ] && echo "🎉 Lab 1 checkpoint reached." || { echo "Not there yet."; exit 1; }
