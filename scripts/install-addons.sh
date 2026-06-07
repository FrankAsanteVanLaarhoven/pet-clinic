#!/usr/bin/env bash
# Install cluster addons: External Secrets Operator + AWS Load Balancer Controller.
# Run AFTER install-argocd.sh. Reads IRSA role ARNs from terraform output.
# Usage: ./scripts/install-addons.sh [env]
set -euo pipefail

ENV="${1:-dev}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform/environments/${ENV}"
CLUSTER_NAME="petclinic-${ENV}"
REGION="eu-central-1"

echo "==> Reading IRSA role ARNs from terraform output"
ESO_ROLE_ARN=$(terraform -chdir="$TF_DIR" output -raw eso_role_arn 2>/dev/null)
ALB_ROLE_ARN=$(terraform -chdir="$TF_DIR" output -raw alb_controller_role_arn 2>/dev/null)

if [ -z "$ESO_ROLE_ARN" ] || [ -z "$ALB_ROLE_ARN" ]; then
  echo "ERROR: Could not read IRSA ARNs from terraform output."
  echo "       Run 'terraform apply' in ${TF_DIR} first."
  exit 1
fi
echo "  ESO role:             $ESO_ROLE_ARN"
echo "  ALB Controller role:  $ALB_ROLE_ARN"

echo "==> Adding Helm repos"
helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update

# ── External Secrets Operator ─────────────────────────────────────────────────
echo "==> Installing External Secrets Operator v0.10"
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --version "0.10.7" \
  --set installCRDs=true \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ESO_ROLE_ARN}" \
  --wait \
  --timeout 5m

echo "==> Applying ClusterSecretStore + ExternalSecrets"
kubectl apply -f "${REPO_ROOT}/k8s/base/external-secrets/cluster-secret-store.yaml"
kubectl apply -f "${REPO_ROOT}/k8s/base/external-secrets/rds-credentials.yaml"
kubectl apply -f "${REPO_ROOT}/k8s/base/external-secrets/openai-api-key.yaml"

echo "==> Waiting for ExternalSecrets to sync"
kubectl wait externalsecret rds-credentials \
  -n petclinic-dev \
  --for=condition=Ready \
  --timeout=60s 2>/dev/null || echo "  (rds-credentials not ready yet — check ESO logs)"
kubectl wait externalsecret openai-api-key \
  -n petclinic-dev \
  --for=condition=Ready \
  --timeout=30s 2>/dev/null || echo "  (openai-api-key not ready yet — check ESO logs)"

# ── AWS Load Balancer Controller ──────────────────────────────────────────────
echo "==> Installing AWS Load Balancer Controller v2.8"
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --version "1.8.4" \
  --set clusterName="${CLUSTER_NAME}" \
  --set region="${REGION}" \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ALB_ROLE_ARN}" \
  --set replicaCount=1 \
  --wait \
  --timeout 5m

echo ""
echo "==> Addon installation complete"
echo "  External Secrets Operator: $(kubectl get deploy -n external-secrets external-secrets -o jsonpath='{.status.readyReplicas}' 2>/dev/null)/1 replicas ready"
echo "  ALB Controller:            $(kubectl get deploy -n kube-system aws-load-balancer-controller -o jsonpath='{.status.readyReplicas}' 2>/dev/null)/1 replicas ready"
echo ""
echo "  Once ArgoCD syncs api-gateway-${ENV}, an ALB will be provisioned."
echo "  Get its DNS: kubectl get ingress -n petclinic-${ENV}"
