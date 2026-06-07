#!/usr/bin/env bash
# Run AFTER terraform apply for a given environment.
# Sets GitHub secrets from terraform outputs and patches helm-values RDS placeholders.
# Usage: ./scripts/post-apply.sh [env]          (default: dev)
set -euo pipefail

ENV="${1:-dev}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform/environments/${ENV}"
APP_REPO="FrankAsanteVanLaarhoven/spring-petclinic-microservices"
PLATFORM_REPO="FrankAsanteVanLaarhoven/pet-clinic"

echo "==> post-apply for environment: ${ENV}"
echo ""

# ── Read terraform outputs ────────────────────────────────────────────────────
echo "==> Reading terraform outputs from ${TF_DIR}"
GITHUB_ACTIONS_ROLE_ARN=$(terraform -chdir="$TF_DIR" output -raw github_actions_role_arn 2>/dev/null || echo "")
RDS_ENDPOINT=$(terraform -chdir="$TF_DIR" output -raw rds_endpoint 2>/dev/null || echo "")

if [ -z "$GITHUB_ACTIONS_ROLE_ARN" ] && [ "${ENV}" = "dev" ]; then
  echo "ERROR: github_actions_role_arn not found in terraform output."
  echo "       Run 'terraform apply' in ${TF_DIR} first."
  exit 1
fi

# ── Set GitHub secrets in app repo fork ───────────────────────────────────────
if [ -n "$GITHUB_ACTIONS_ROLE_ARN" ]; then
  echo "==> Setting AWS_ROLE_ARN secret in ${APP_REPO}"
  gh secret set AWS_ROLE_ARN --body "$GITHUB_ACTIONS_ROLE_ARN" --repo "$APP_REPO"
  echo "  AWS_ROLE_ARN = ${GITHUB_ACTIONS_ROLE_ARN}"
fi

# PLATFORM_REPO_TOKEN — needs a fine-grained PAT with contents:write on pet-clinic.
# Create one at: https://github.com/settings/tokens?type=beta
# Select repository: pet-clinic → Repository permissions → Contents: Read and Write
if [ -z "${PLATFORM_REPO_TOKEN:-}" ]; then
  echo ""
  echo "  ACTION REQUIRED: Set PLATFORM_REPO_TOKEN in the app repo manually."
  echo "  1. Go to https://github.com/settings/tokens?type=beta"
  echo "  2. New fine-grained token → select repo: pet-clinic → Contents: Read/Write"
  echo "  3. Run: gh secret set PLATFORM_REPO_TOKEN --body '<token>' --repo ${APP_REPO}"
  echo ""
else
  echo "==> Setting PLATFORM_REPO_TOKEN secret in ${APP_REPO}"
  gh secret set PLATFORM_REPO_TOKEN --body "$PLATFORM_REPO_TOKEN" --repo "$APP_REPO"
fi

# ── Patch RDS endpoint in helm-values ────────────────────────────────────────
if [ -z "$RDS_ENDPOINT" ]; then
  echo "WARNING: rds_endpoint not found in terraform output — skipping helm-values patch."
else
  echo ""
  echo "==> Patching helm-values RDS endpoint (${ENV})"

  if [ "${ENV}" = "dev" ]; then
    PLACEHOLDER="PLACEHOLDER_RDS_ENDPOINT"
    FILES=(
      "${REPO_ROOT}/helm-values/customers-service.yaml"
      "${REPO_ROOT}/helm-values/visits-service.yaml"
      "${REPO_ROOT}/helm-values/vets-service.yaml"
    )
  else
    PLACEHOLDER="PLACEHOLDER_RDS_PROD_ENDPOINT"
    FILES=(
      "${REPO_ROOT}/helm-values/customers-service-prod.yaml"
      "${REPO_ROOT}/helm-values/visits-service-prod.yaml"
      "${REPO_ROOT}/helm-values/vets-service-prod.yaml"
    )
  fi

  for f in "${FILES[@]}"; do
    if grep -q "$PLACEHOLDER" "$f" 2>/dev/null; then
      sed -i "s|${PLACEHOLDER}|${RDS_ENDPOINT}|g" "$f"
      echo "  patched $(basename "$f") → ${RDS_ENDPOINT}"
    else
      echo "  $(basename "$f") — placeholder already replaced or not present"
    fi
  done

  # Commit + push if anything changed
  cd "$REPO_ROOT"
  if ! git diff --quiet helm-values/; then
    git add helm-values/
    git commit -m "chore(${ENV}): set RDS endpoint from terraform output"
    git push myfork main
    echo "  Committed and pushed helm-values RDS endpoint."
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "==> post-apply complete for ${ENV}"
echo "  AWS_ROLE_ARN set:     ${GITHUB_ACTIONS_ROLE_ARN:-not set (dev only)}"
echo "  RDS endpoint:         ${RDS_ENDPOINT:-not found}"
echo ""
echo "  Next steps:"
if [ "${ENV}" = "dev" ]; then
  echo "  1. Set PLATFORM_REPO_TOKEN (see above if not set)"
  echo "  2. Run: ./scripts/install-argocd.sh"
  echo "  3. Run: ./scripts/install-addons.sh dev"
  echo "  4. Push to app repo to trigger dev CI/CD"
else
  echo "  1. Run: ./scripts/install-argocd.sh prod"
  echo "  2. Run: ./scripts/install-addons.sh prod"
  echo "  3. Push tag v*.*.* to app repo to trigger prod CI/CD"
fi
