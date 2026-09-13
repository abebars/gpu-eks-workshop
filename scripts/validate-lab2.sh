#!/usr/bin/env bash
# Lab 2 checkpoint: vLLM is Ready, answers a chat completion, and is scraped.
set -uo pipefail
fail=0
pass() { printf '  ✅ %s\n' "$1"; }
bad()  { printf '  ❌ %s\n' "$1"; fail=1; }

echo "Lab 2 validation"
ready=$(kubectl -n vllm get deploy vllm -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${ready:-0}" -ge 1 ] && pass "vllm Deployment has $ready ready replica(s)" || bad "vllm has no ready replicas (kubectl -n vllm describe pod -l app=vllm)"

resp=$(kubectl -n vllm run curl-check --rm -i --restart=Never --image=curlimages/curl:8.10.1 --quiet -- \
  curl -s --max-time 60 http://vllm.vllm.svc/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"qwen2.5-1.5b","messages":[{"role":"user","content":"Reply with the single word: ready"}],"max_tokens":8}' 2>/dev/null)
if echo "$resp" | grep -q '"choices"'; then
  pass "chat completion returned: $(echo "$resp" | jq -r '.choices[0].message.content' 2>/dev/null | head -c 60)"
else
  bad "no completion from http://vllm.vllm.svc (got: ${resp:0:120})"
fi

if kubectl -n vllm get podmonitor vllm >/dev/null 2>&1; then pass "PodMonitor vllm exists"; else bad "PodMonitor vllm missing"; fi
if kubectl -n vllm get scaledobject vllm -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True; then
  pass "KEDA ScaledObject vllm is Ready (HPA keda-hpa-vllm)"
else
  bad "ScaledObject vllm not Ready (kubectl -n vllm describe scaledobject vllm)"
fi

[ "$fail" -eq 0 ] && echo "🎉 Lab 2 checkpoint reached." || { echo "Not there yet."; exit 1; }
