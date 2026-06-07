#!/usr/bin/env bash
# Install ArgoCD into the EKS cluster and bootstrap petclinic Application CRDs.
# Usage: ./scripts/install-argocd.sh <domain> <acm-cert-arn>
set -euo pipefail

DOMAIN="${1:?Usage: $0 <domain> <acm-cert-arn>}"
CERT_ARN="${2:?Usage: $0 <domain> <acm-cert-arn>}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Installing ArgoCD v2.11.3"
kubectl apply -f "${REPO_ROOT}/k8s/argocd/install/namespace.yaml"
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.11.3/manifests/install.yaml

echo "==> Waiting for ArgoCD deployments to be ready"
kubectl rollout status deployment/argocd-server                      -n argocd --timeout=120s
kubectl rollout status statefulset/argocd-application-controller     -n argocd --timeout=120s

echo "==> Patching ArgoCD ConfigMap"
kubectl apply -f "${REPO_ROOT}/k8s/argocd/install/argocd-cm-patch.yaml"

echo "==> Applying ArgoCD Ingress (domain=${DOMAIN})"
sed "s/REPLACE_WITH_DOMAIN/${DOMAIN}/g; s|REPLACE_WITH_ACM_CERT_ARN|${CERT_ARN}|g" \
  "${REPO_ROOT}/k8s/argocd/install/argocd-server-ingress.yaml" \
  | kubectl apply -f -

echo "==> Applying AppProjects"
kubectl apply -f "${REPO_ROOT}/k8s/argocd/applications/dev/appproject.yaml"
kubectl apply -f "${REPO_ROOT}/k8s/argocd/applications/prod/appproject.yaml"

echo "==> Applying dev Application CRDs (auto-sync)"
kubectl apply -f "${REPO_ROOT}/k8s/argocd/applications/dev/"

echo "==> Applying prod Application CRDs (manual sync)"
kubectl apply -f "${REPO_ROOT}/k8s/argocd/applications/prod/"

echo ""
echo "==> ArgoCD initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""
echo "==> ArgoCD UI: https://argocd.${DOMAIN}"
