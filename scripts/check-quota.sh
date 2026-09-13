#!/usr/bin/env bash
# Checks the two EC2 vCPU quotas the workshop depends on and, with --request,
# files increase requests for both. Portable to macOS bash 3.2.
#
#   ./scripts/check-quota.sh            # show current values
#   ./scripts/check-quota.sh --request  # request 32 vCPUs for each
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
WANT="${WANT_VCPUS:-32}"

# quota-code|human name
QUOTAS="L-DB2E81BA|Running On-Demand G and VT instances
L-3819A6DF|All G and VT Spot Instance Requests"

ok=true
while IFS='|' read -r code name; do
  [ -z "$code" ] && continue
  value=$(aws service-quotas get-service-quota \
            --service-code ec2 --quota-code "$code" --region "$REGION" \
            --query 'Quota.Value' --output text 2>/dev/null || echo "?")
  value=${value%.*}
  if [ "$value" = "?" ]; then
    printf '  %-45s  %s\n' "$name" "could not read (check credentials/region)"
    ok=false
  elif [ "$value" -ge "$WANT" ]; then
    printf '  %-45s  %3s vCPUs  ✅\n' "$name" "$value"
  else
    printf '  %-45s  %3s vCPUs  ❌ need %s\n' "$name" "$value" "$WANT"
    ok=false
    if [ "${1:-}" = "--request" ]; then
      aws service-quotas request-service-quota-increase \
        --service-code ec2 --quota-code "$code" --desired-value "$WANT" \
        --region "$REGION" --query 'RequestedQuota.[QuotaName,Status]' --output text 2>&1 \
        | sed 's/^/     → requested: /' || true
    fi
  fi
done <<EOF
$QUOTAS
EOF

echo
if $ok; then
  echo "GPU quota OK in $REGION."
else
  echo "GPU quota is NOT sufficient in $REGION."
  echo "Run: ./scripts/check-quota.sh --request   (or use the Service Quotas console)."
  echo "Pending requests: aws service-quotas list-requested-service-quota-change-history-by-quota --service-code ec2 --quota-code L-DB2E81BA --region $REGION"
  exit 1
fi
