#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
ENV_DIR="${ENV_DIR:-environments/dev}"
CLUSTER_NAME="${CLUSTER_NAME:-java-cicd-dev-eks}"
AWS_REGION="${AWS_REGION:-ap-southeast-1}"
EXPECTED_ACCOUNT_ID="${EXPECTED_ACCOUNT_ID:-}"

if [[ -z "$ACTION" ]]; then
  echo "Usage: $0 {plan|up|down|status}"
  exit 1
fi

cd "$(dirname "$0")/$ENV_DIR"

echo "==> Working dir: $(pwd)"

# Optional safety guard so you don't hit the wrong AWS account
if [[ -n "$EXPECTED_ACCOUNT_ID" ]]; then
  ACTUAL_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
  if [[ "$ACTUAL_ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]]; then
    echo "ERROR: Wrong AWS account. Actual=$ACTUAL_ACCOUNT_ID Expected=$EXPECTED_ACCOUNT_ID"
    exit 1
  fi
fi

case "$ACTION" in
  plan)
    terraform init
    terraform fmt -recursive
    terraform validate
    terraform plan -out tfplan
    ;;

  up)
    terraform init
    terraform fmt -recursive
    terraform validate
    terraform plan -out tfplan
    terraform apply -auto-approve tfplan

    # Configure kubectl (best effort)
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION" || true

    # Quick visibility
    kubectl get nodes || true

    # Create namespaces (best effort)
    kubectl create namespace jenkins || true
    kubectl create namespace dev || true
    kubectl create namespace staging || true
    kubectl create namespace prod || true
    ;;

  down)
    terraform init
    terraform destroy -auto-approve
    ;;

  status)
    terraform output || true
    aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.status' --output text || true
    kubectl get nodes || true
    ;;

  *)
    echo "Invalid action: $ACTION"
    echo "Usage: $0 {plan|up|down|status}"
    exit 1
    ;;
esac:
