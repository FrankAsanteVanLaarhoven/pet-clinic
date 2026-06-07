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
GRAFANA_ROLE_ARN=$(terraform -chdir="$TF_DIR" output -raw grafana_role_arn 2>/dev/null)
KARPENTER_ROLE_ARN=$(terraform -chdir="$TF_DIR" output -raw karpenter_controller_role_arn 2>/dev/null)
KARPENTER_QUEUE_URL=$(terraform -chdir="$TF_DIR" output -raw karpenter_interruption_queue_url 2>/dev/null)

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
helm repo add open-policy-agent https://open-policy-agent.github.io/gatekeeper/charts 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
# karpenter chart is OCI-based — no repo add needed (use oci:// at install time)
helm repo update

# ── OPA Gatekeeper ────────────────────────────────────────────────────────────
echo "==> Installing OPA Gatekeeper v3.17"
helm upgrade --install gatekeeper open-policy-agent/gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace \
  --version "3.17.1" \
  --set replicas=1 \
  --set auditInterval=60 \
  --set constraintViolationsLimit=20 \
  --wait \
  --timeout 5m

echo "==> Applying Gatekeeper constraint templates (pass 1 — templates only, constraints may fail)"
kubectl apply -f "${REPO_ROOT}/k8s/base/gatekeeper/" 2>/dev/null || true

echo "==> Waiting for Gatekeeper Constraint CRDs to be established (up to 90s)"
for crd in requirenonroot requireresourcelimits requirepetcliniclabels; do
  timeout=90
  until kubectl get crd "${crd}.constraints.gatekeeper.sh" &>/dev/null; do
    timeout=$((timeout - 3)); [ $timeout -le 0 ] && break
    sleep 3
  done
  kubectl get crd "${crd}.constraints.gatekeeper.sh" &>/dev/null && \
    echo "  CRD ready: ${crd}" || echo "  WARNING: CRD not ready: ${crd}"
done

echo "==> Applying Gatekeeper constraints (pass 2)"
kubectl apply -f "${REPO_ROOT}/k8s/base/gatekeeper/"

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

# ── kube-prometheus-stack (Prometheus + Grafana) ──────────────────────────────
echo "==> Deploying kube-prometheus-stack via ArgoCD"
kubectl apply -f "${REPO_ROOT}/k8s/argocd/applications/addons/kube-prometheus-stack.yaml"

echo "==> Ensuring monitoring namespace exists"
kubectl create namespace monitoring 2>/dev/null || true

echo "==> Patching Grafana service account with IRSA annotation"
kubectl annotate serviceaccount grafana \
  -n monitoring \
  "eks.amazonaws.com/role-arn=${GRAFANA_ROLE_ARN}" \
  --overwrite 2>/dev/null || true

echo "==> Applying Grafana dashboards"
kubectl apply -f "${REPO_ROOT}/k8s/base/grafana/" 2>/dev/null || \
  echo "  (Grafana dashboards deferred — monitoring namespace not fully ready yet)"

# ── Karpenter ─────────────────────────────────────────────────────────────────
if [ -n "$KARPENTER_ROLE_ARN" ] && [ -n "$KARPENTER_QUEUE_URL" ]; then
  echo "==> Installing Karpenter v0.37"
  KARPENTER_QUEUE_NAME="${KARPENTER_QUEUE_URL##*/}"
  helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
    --namespace karpenter \
    --create-namespace \
    --version "0.37.0" \
    --set "settings.clusterName=${CLUSTER_NAME}" \
    --set "settings.interruptionQueue=${KARPENTER_QUEUE_NAME}" \
    --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=${KARPENTER_ROLE_ARN}" \
    --set controller.resources.requests.cpu=100m \
    --set controller.resources.requests.memory=256Mi \
    --set controller.resources.limits.cpu=1 \
    --set controller.resources.limits.memory=512Mi \
    --wait \
    --timeout 5m

  echo "==> Applying Karpenter NodePool + EC2NodeClass"
  NODE_ROLE_NAME=$(aws eks describe-nodegroup \
    --cluster-name "${CLUSTER_NAME}" \
    --nodegroup-name "${CLUSTER_NAME}-ng" \
    --region "${REGION}" \
    --query 'nodegroup.nodeRole' \
    --output text 2>/dev/null | awk -F'/' '{print $NF}' || echo "petclinic-dev-eks-node-role")
  # Patch role name into EC2NodeClass before applying
  sed "s/petclinic-dev-eks-node-role/${NODE_ROLE_NAME}/g" \
    "${REPO_ROOT}/k8s/karpenter/ec2nodeclass.yaml" | kubectl apply -f -
  kubectl apply -f "${REPO_ROOT}/k8s/karpenter/nodepool.yaml"
else
  echo "  (Karpenter IRSA ARN not set — skipping Karpenter install)"
fi

echo ""
echo "==> Addon installation complete"
echo "  OPA Gatekeeper:            $(kubectl get deploy -n gatekeeper-system gatekeeper-controller-manager -o jsonpath='{.status.readyReplicas}' 2>/dev/null)/1 replicas ready"
echo "  External Secrets Operator: $(kubectl get deploy -n external-secrets external-secrets -o jsonpath='{.status.readyReplicas}' 2>/dev/null)/1 replicas ready"
echo "  ALB Controller:            $(kubectl get deploy -n kube-system aws-load-balancer-controller -o jsonpath='{.status.readyReplicas}' 2>/dev/null)/1 replicas ready"
echo "  Prometheus stack:          deploying via ArgoCD (check: kubectl get app kube-prometheus-stack -n argocd)"
echo "  Karpenter:                 $(kubectl get deploy -n karpenter karpenter -o jsonpath='{.status.readyReplicas}' 2>/dev/null)/1 replicas ready"
echo ""
echo "  Once ArgoCD syncs api-gateway-${ENV}, an ALB will be provisioned."
echo "  Get its DNS:    kubectl get ingress -n petclinic-${ENV}"
echo "  Grafana port-forward: kubectl port-forward svc/grafana 3000:80 -n monitoring"
