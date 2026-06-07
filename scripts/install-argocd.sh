#!/usr/bin/env bash
# Install ArgoCD into the EKS cluster and bootstrap petclinic Application CRDs.
# Usage: ./scripts/install-argocd.sh [domain] [acm-cert-arn]
# Domain and cert are optional — omit to skip ALB ingress (use port-forward instead).
set -euo pipefail

DOMAIN="${1:-}"
CERT_ARN="${2:-}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Installing ArgoCD v2.11.3"
kubectl apply -f "${REPO_ROOT}/k8s/argocd/install/namespace.yaml"
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.11.3/manifests/install.yaml

echo "==> Waiting for ArgoCD deployments to be ready"
kubectl rollout status deployment/argocd-server                   -n argocd --timeout=180s
kubectl rollout status deployment/argocd-repo-server              -n argocd --timeout=180s
# application-controller is a StatefulSet in ArgoCD v2.11
kubectl wait pod -l app.kubernetes.io/name=argocd-application-controller \
  -n argocd --for=condition=Ready --timeout=180s

echo "==> Patching ArgoCD ConfigMap"
kubectl apply -f "${REPO_ROOT}/k8s/argocd/install/argocd-cm-patch.yaml"

# ── ALB Ingress (optional — requires real domain + ACM cert) ─────────────────
if [ -n "$DOMAIN" ] && [ -n "$CERT_ARN" ]; then
  echo "==> Applying ArgoCD Ingress (domain=${DOMAIN})"
  sed "s/REPLACE_WITH_DOMAIN/${DOMAIN}/g; s|REPLACE_WITH_ACM_CERT_ARN|${CERT_ARN}|g" \
    "${REPO_ROOT}/k8s/argocd/install/argocd-server-ingress.yaml" \
    | kubectl apply -f -
else
  echo "==> Skipping ALB ingress (no domain/cert provided)"
  echo "    Access ArgoCD via port-forward:"
  echo "      kubectl port-forward svc/argocd-server 8080:443 -n argocd"
  echo "    Then open: https://localhost:8080"
fi

echo "==> Applying AppProjects"
kubectl apply -f "${REPO_ROOT}/k8s/argocd/applications/dev/appproject.yaml"
kubectl apply -f "${REPO_ROOT}/k8s/argocd/applications/prod/appproject.yaml"

echo "==> Applying namespaces"
kubectl apply -f "${REPO_ROOT}/k8s/base/namespaces.yaml"

echo "==> Applying dev Application CRDs (auto-sync)"
kubectl apply -f "${REPO_ROOT}/k8s/argocd/applications/dev/"

echo "==> Applying prod Application CRDs (manual sync)"
kubectl apply -f "${REPO_ROOT}/k8s/argocd/applications/prod/"

echo ""
echo "==> ArgoCD initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "(secret not yet available)"
echo ""

echo "==> ArgoCD installation complete"
echo "  Applications: kubectl get applications -n argocd"
if [ -n "$DOMAIN" ]; then
  echo "  UI:           https://argocd.${DOMAIN}"
fi
echo "  Port-forward: kubectl port-forward svc/argocd-server 8080:443 -n argocd"
echo ""
echo "  Run install-addons.sh next:"
echo "    ./scripts/install-addons.sh dev"
