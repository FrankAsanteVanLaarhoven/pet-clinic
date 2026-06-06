#!/usr/bin/env bash
# bootstrap-state.sh — provision S3 state bucket + DynamoDB lock table
#
# Run ONCE before `terraform init`. Safe to re-run (idempotent).
#
# Usage:
#   bash scripts/bootstrap-state.sh
#   bash scripts/bootstrap-state.sh --region eu-west-1

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
REGION="eu-central-1"

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --region) REGION="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Derive account ID and bucket name ─────────────────────────────────────────
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="petclinic-terraform-state-${ACCOUNT_ID}"
TABLE="petclinic-terraform-locks"

echo "Bootstrap Terraform remote state"
echo "  Region    : ${REGION}"
echo "  Account   : ${ACCOUNT_ID}"
echo "  S3 Bucket : ${BUCKET}"
echo "  DynamoDB  : ${TABLE}"
echo

# ── S3 bucket ─────────────────────────────────────────────────────────────────
if aws s3api head-bucket --bucket "${BUCKET}" --region "${REGION}" 2>/dev/null; then
  echo "✓ S3 bucket already exists: ${BUCKET}"
else
  echo "Creating S3 bucket: ${BUCKET}"

  if [[ "${REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket \
      --bucket "${BUCKET}" \
      --region "${REGION}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET}" \
      --region "${REGION}" \
      --create-bucket-configuration LocationConstraint="${REGION}"
  fi

  echo "✓ Bucket created"
fi

# Versioning
aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled
echo "✓ Versioning enabled"

# Encryption (SSE-S3 / AES256)
aws s3api put-bucket-encryption \
  --bucket "${BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'
echo "✓ Encryption enabled (AES256)"

# Block all public access (4 settings)
aws s3api put-public-access-block \
  --bucket "${BUCKET}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
echo "✓ Public access blocked"

# ── DynamoDB table ────────────────────────────────────────────────────────────
if aws dynamodb describe-table --table-name "${TABLE}" --region "${REGION}" 2>/dev/null | grep -q TableStatus; then
  echo "✓ DynamoDB table already exists: ${TABLE}"
else
  echo "Creating DynamoDB table: ${TABLE}"
  aws dynamodb create-table \
    --table-name "${TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"

  aws dynamodb wait table-exists --table-name "${TABLE}" --region "${REGION}"
  echo "✓ DynamoDB table created"
fi

# ── Update backend.tf files with real account ID ─────────────────────────────
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for env in dev prod; do
  BACKEND="${REPO_ROOT}/terraform/environments/${env}/backend.tf"
  if [[ -f "${BACKEND}" ]]; then
    sed -i "s/petclinic-terraform-state-ACCOUNT_ID/petclinic-terraform-state-${ACCOUNT_ID}/g" "${BACKEND}"
    echo "✓ Updated backend.tf for ${env} (bucket: petclinic-terraform-state-${ACCOUNT_ID})"
  fi
done

echo
echo "Bootstrap complete."
echo
echo "Next steps:"
echo "  cd terraform/environments/dev"
echo "  terraform init"
echo "  terraform validate"
