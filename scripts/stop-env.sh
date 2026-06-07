#!/usr/bin/env bash
set -euo pipefail

#
# stop-env.sh — Pause your AWS environment to save costs
#
# Stops RDS and scales EKS node group to 0 nodes.
# EKS control plane stays running ($0.10/hr = $2.40/day) but compute and DB stop.
# For zero cost: use weekly-destroy.yml or terraform destroy.
#
# Usage:
#   ./scripts/stop-env.sh dev
#   ./scripts/stop-env.sh prod
#

REGION="${AWS_DEFAULT_REGION:-eu-central-1}"

usage() {
  echo "Usage: $0 <environment>"
  echo "  environment: dev | prod"
  echo ""
  echo "Examples:"
  echo "  $0 dev      # Stop dev environment"
  echo "  $0 prod     # Stop prod environment"
  exit 1
}

if [[ $# -ne 1 ]]; then
  usage
fi

ENV="$1"
if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
  echo "Error: environment must be 'dev' or 'prod'"
  usage
fi

CLUSTER_NAME="petclinic-${ENV}"
NODEGROUP_NAME="petclinic-${ENV}-nodes"
RDS_INSTANCE_ID="petclinic-${ENV}-mysql"

echo "============================================"
echo "  Stopping environment: ${ENV}"
echo "  Region: ${REGION}"
echo "============================================"
echo ""

# --- Stop RDS Instance ---
echo "[1/2] Stopping RDS instance: ${RDS_INSTANCE_ID}"

RDS_STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier "${RDS_INSTANCE_ID}" \
  --region "${REGION}" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text 2>/dev/null || echo "not-found")

case "${RDS_STATUS}" in
  available)
    aws rds stop-db-instance \
      --db-instance-identifier "${RDS_INSTANCE_ID}" \
      --region "${REGION}" > /dev/null
    echo "  -> RDS stop initiated. It will stop within a few minutes."
    echo "  -> Note: AWS auto-restarts stopped RDS instances after 7 days."
    ;;
  stopped)
    echo "  -> RDS is already stopped. No action needed."
    ;;
  stopping)
    echo "  -> RDS is already stopping. Please wait."
    ;;
  not-found)
    echo "  -> RDS instance not found. Skipping."
    ;;
  *)
    echo "  -> RDS is in '${RDS_STATUS}' state. Cannot stop now."
    ;;
esac

echo ""

# --- Scale EKS Node Group to 0 ---
echo "[2/2] Scaling EKS node group to 0: ${NODEGROUP_NAME}"

NODEGROUP_EXISTS=$(aws eks describe-nodegroup \
  --cluster-name "${CLUSTER_NAME}" \
  --nodegroup-name "${NODEGROUP_NAME}" \
  --region "${REGION}" \
  --query 'nodegroup.status' \
  --output text 2>/dev/null || echo "not-found")

if [[ "${NODEGROUP_EXISTS}" == "not-found" ]]; then
  echo "  -> Node group not found. Skipping."
else
  CURRENT_DESIRED=$(aws eks describe-nodegroup \
    --cluster-name "${CLUSTER_NAME}" \
    --nodegroup-name "${NODEGROUP_NAME}" \
    --region "${REGION}" \
    --query 'nodegroup.scalingConfig.desiredSize' \
    --output text)

  if [[ "${CURRENT_DESIRED}" == "0" ]]; then
    echo "  -> Node group already at 0 nodes. No action needed."
  else
    aws eks update-nodegroup-config \
      --cluster-name "${CLUSTER_NAME}" \
      --nodegroup-name "${NODEGROUP_NAME}" \
      --scaling-config minSize=0,maxSize=3,desiredSize=0 \
      --region "${REGION}" > /dev/null
    echo "  -> Scaled to 0. Nodes will terminate within a few minutes."
  fi
fi

echo ""
echo "============================================"
echo "  Environment ${ENV} is stopping."
echo ""
echo "  Still running (you pay for):"
echo "    - EKS control plane (\$0.10/hr = \$2.40/day)"
echo ""
echo "  Stopped (free):"
echo "    - EC2 nodes (t4g.small — Graviton free trial)"
echo "    - RDS db.t4g.micro (free tier when stopped)"
echo ""
echo "  To eliminate ALL costs: weekly-destroy.yml or terraform destroy"
echo ""
echo "  To fully destroy: terraform destroy"
echo "  To restart:       ./scripts/start-env.sh ${ENV}"
echo "============================================"
