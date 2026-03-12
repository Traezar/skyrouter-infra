#!/bin/bash
set -euo pipefail

# =============================================================================
# Install EKS Cluster Addons
# Run AFTER terraform apply and kubeconfig update
# =============================================================================

CLUSTER_NAME="${CLUSTER_NAME:-skyrouter-prod-cluster}"
REGION="${AWS_REGION:-ap-southeast-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "==> Installing cluster addons for: $CLUSTER_NAME"

# ---------- 1. AWS Load Balancer Controller ----------
echo "==> Installing AWS Load Balancer Controller..."

# Get the ALB controller IRSA role ARN from Terraform
ALB_ROLE_ARN=$(cd ../terraform && terraform output -raw alb_controller_role_arn 2>/dev/null || echo "")

if [ -z "$ALB_ROLE_ARN" ]; then
  ALB_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/skyrouter-prod-alb-controller-irsa"
  echo "   Using default role ARN: $ALB_ROLE_ARN"
fi

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$ALB_ROLE_ARN" \
  --set region="$REGION" \
  --set vpcId=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
    --query 'cluster.resourcesVpcConfig.vpcId' --output text) \
  --wait

# ---------- 2. Metrics Server (for HPA) ----------
echo "==> Installing Metrics Server..."

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args[0]="--kubelet-preferred-address-types=InternalIP" \
  --wait

# ---------- 3. External Secrets Operator (for Secrets Manager) ----------
echo "==> Installing External Secrets Operator..."

helm repo add external-secrets https://charts.external-secrets.io
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --wait

# ---------- 4. Cluster Autoscaler ----------
echo "==> Installing Cluster Autoscaler..."

helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName="$CLUSTER_NAME" \
  --set awsRegion="$REGION" \
  --wait

# ---------- 5. Create namespaces ----------
echo "==> Creating namespaces..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "==> All addons installed successfully!"
echo "    Verify with: kubectl get pods -A"
