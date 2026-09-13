#!/usr/bin/env bash
# Lab 2, unattended: vLLM + Service + PodMonitor + dashboard + KEDA ScaledObject.
# Does NOT run the load jobs (make baseline / make load-test).
set -euo pipefail
cd "$(dirname "$0")/.."
kubectl apply -f modules/04-vllm/namespace.yaml
kubectl apply -f modules/04-vllm/deployment.yaml -f modules/04-vllm/service.yaml \
  -f modules/04-vllm/podmonitor.yaml -f modules/04-vllm/k6-script.yaml -f modules/04-vllm/scaledobject.yaml
kubectl apply -f modules/05-observability/vllm-dashboard-configmap.yaml
kubectl -n vllm rollout status deploy/vllm --timeout=15m
./scripts/validate-lab2.sh
