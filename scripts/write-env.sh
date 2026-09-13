#!/usr/bin/env bash
# Writes .workshop.env from terraform outputs. Sourced by every lab step.
set -euo pipefail
cd "$(dirname "$0")/../terraform"
{
  echo "export CLUSTER_NAME=$(terraform output -raw cluster_name)"
  echo "export AWS_REGION=$(terraform output -raw region)"
  echo "export KARPENTER_NODE_ROLE=$(terraform output -raw karpenter_node_iam_role_name)"
} > ../.workshop.env
echo "wrote .workshop.env:"
cat ../.workshop.env
