#!/usr/bin/env bash
# Pre-flight for the GPU workshop. Green across the board = you're ready.
set -uo pipefail

REGION="${AWS_REGION:-us-east-1}"
fail=0
pass() { printf '  ✅ %s\n' "$1"; }
warn() { printf '  ⚠️  %s\n' "$1"; }
bad()  { printf '  ❌ %s\n' "$1"; fail=1; }

vercmp() { # vercmp <have> <min>  → 0 if have >= min. Pure bash; macOS sort has no -V.
  local IFS=. i a b
  # shellcheck disable=SC2206
  a=(${1%%[^0-9.]*}) b=(${2})
  for ((i = 0; i < 3; i++)); do
    if ((10#${a[i]:-0} > 10#${b[i]:-0})); then return 0; fi
    if ((10#${a[i]:-0} < 10#${b[i]:-0})); then return 1; fi
  done
  return 0
}

echo "Tools"
for t in aws kubectl helm terraform jq envsubst git curl; do
  if command -v "$t" >/dev/null 2>&1; then pass "$t: $(command -v "$t")"; else bad "$t not found in PATH"; fi
done

if command -v aws >/dev/null; then
  v=$(aws --version 2>&1 | sed -E 's#aws-cli/([0-9.]+).*#\1#')
  vercmp "$v" "2.15.0" && pass "aws CLI $v" || bad "aws CLI $v is old; need 2.15+"
fi
if command -v kubectl >/dev/null; then
  v=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' | sed 's/^v//')
  vercmp "$v" "1.35.0" && pass "kubectl $v" || bad "kubectl $v; need 1.35+ (cluster is 1.36, skew ±1 minor)"
fi
if command -v helm >/dev/null; then
  v=$(helm version --template '{{.Version}}' | sed 's/^v//')
  vercmp "$v" "3.14.0" && pass "helm $v" || bad "helm $v; need 3.14+"
fi
if command -v terraform >/dev/null; then
  v=$(terraform version -json | jq -r .terraform_version)
  vercmp "$v" "1.5.7" && pass "terraform $v" || bad "terraform $v; need 1.5.7+"
fi

echo
echo "AWS credentials ($REGION)"
if ident=$(aws sts get-caller-identity --output json 2>/dev/null); then
  pass "account $(echo "$ident" | jq -r .Account) as $(echo "$ident" | jq -r .Arn)"
else
  bad "aws sts get-caller-identity failed — configure credentials first"
fi

echo
echo "GPU quota ($REGION)"
if "$(dirname "$0")/check-quota.sh" >/tmp/quota.$$ 2>&1; then
  sed 's/^/  /' /tmp/quota.$$ | grep -E '✅|❌' || true
else
  sed 's/^/  /' /tmp/quota.$$ | grep -E '✅|❌' || true
  bad "quota too low — see 'Before the workshop → 1. Request GPU quota'"
fi
rm -f /tmp/quota.$$

echo
echo "Base stack"
if [ -f terraform/terraform.tfstate ] || [ -d terraform/.terraform ]; then
  name=$(cd terraform && terraform output -raw cluster_name 2>/dev/null || true)
  if [ -n "$name" ]; then
    pass "terraform output cluster_name=$name"
    if kubectl get nodes >/dev/null 2>&1; then
      pass "kubectl reaches the cluster ($(kubectl get nodes --no-headers | wc -l | tr -d ' ') nodes)"
      for d in karpenter/karpenter monitoring/kube-prometheus-stack-operator keda/keda-operator; do
        ns=${d%%/*}; dep=${d##*/}
        if kubectl -n "$ns" get deploy "$dep" >/dev/null 2>&1; then pass "$ns/$dep present"; else bad "$ns/$dep missing"; fi
      done
    else
      bad "kubectl cannot reach the cluster — run: $(cd terraform && terraform output -raw configure_kubectl 2>/dev/null)"
    fi
  else
    warn "base stack not applied yet — run 'make base-up' (≈20 min)"
  fi
else
  warn "base stack not initialised — run 'make base-up' (≈20 min)"
fi

echo
if [ "$fail" -eq 0 ]; then echo "🚀 Preflight passed."; else echo "Preflight found problems. Fix the ❌ items above."; exit 1; fi
