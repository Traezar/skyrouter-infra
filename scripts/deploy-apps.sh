#!/bin/bash
set -euo pipefail

# =============================================================================
# Deploy frontend and backend via Helm
# Run from the repo root: ./scripts/deploy-apps.sh
# Reads Terraform outputs from ./terraform/
# =============================================================================

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGION="${AWS_REGION:-ap-southeast-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TAG="${IMAGE_TAG:-latest}"
NAMESPACE="${NAMESPACE:-default}"
PROJECT="skyrouter-prod"
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# ---------- Read Terraform outputs ----------
echo "==> Reading Terraform outputs..."
pushd "${REPO_ROOT}/terraform" > /dev/null

BACKEND_ROLE_ARN=$(terraform output -raw backend_iam_role_arn 2>/dev/null || echo "")
FRONTEND_ROLE_ARN=$(terraform output -raw frontend_iam_role_arn 2>/dev/null || echo "")
RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "")
ECR_FRONTEND=$(terraform output -raw ecr_frontend_url 2>/dev/null || echo "${ECR_BASE}/${PROJECT}-frontend")
ECR_BACKEND=$(terraform output -raw ecr_backend_url 2>/dev/null || echo "${ECR_BASE}/${PROJECT}-backend")

popd > /dev/null

echo "   Backend IRSA:  $BACKEND_ROLE_ARN"
echo "   Frontend IRSA: $FRONTEND_ROLE_ARN"
echo "   RDS Endpoint:  $RDS_ENDPOINT"
echo "   Image Tag:     $TAG"

# ---------- Deploy Backend ----------
echo "==> Deploying backend..."
helm upgrade --install backend "${REPO_ROOT}/helm/backend" \
  --namespace "$NAMESPACE" \
  --set image.repository="$ECR_BACKEND" \
  --set image.tag="$TAG" \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$BACKEND_ROLE_ARN" \
  --set env.DB_HOST="$RDS_ENDPOINT" \
  --set env.AWS_REGION="$REGION" \
  --wait --timeout 5m

# ---------- Deploy Frontend ----------
echo "==> Deploying frontend..."
helm upgrade --install frontend "${REPO_ROOT}/helm/frontend" \
  --namespace "$NAMESPACE" \
  --set image.repository="$ECR_FRONTEND" \
  --set image.tag="$TAG" \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$FRONTEND_ROLE_ARN" \
  --wait --timeout 5m

echo ""
echo "==> Deployments complete!"
echo "    Check status: kubectl get pods -n $NAMESPACE"
echo "    Check ingress: kubectl get ingress -n $NAMESPACE"
