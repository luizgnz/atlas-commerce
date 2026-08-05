#!/usr/bin/env bash
# Plan and apply the alpha product stack in 01-aws.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV="${1:-alpha}"

BACKEND_FILE="${ROOT}/envs/${ENV}.backend.hcl"
VAR_FILE="${ROOT}/envs/${ENV}.tfvars"

if [ ! -f "${BACKEND_FILE}" ]; then
  echo "Missing ${BACKEND_FILE}" >&2
  echo "Generate it from bootstrap first:" >&2
  echo "  cd ../bootstrap && ./scripts/generate-backend-hcl.sh ${ENV}" >&2
  exit 1
fi

if [ ! -f "${VAR_FILE}" ]; then
  echo "Missing ${VAR_FILE}" >&2
  exit 1
fi

cd "${ROOT}"
terraform init -backend-config="envs/${ENV}.backend.hcl"
terraform plan -var-file="envs/${ENV}.tfvars" -out=tfplan
terraform apply tfplan
echo "Applied ${ENV}."
