#!/usr/bin/env bash
# Destroy the alpha product stack in 01-aws.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV="${1:-alpha}"

BACKEND_FILE="${ROOT}/envs/${ENV}.backend.hcl"
VAR_FILE="${ROOT}/envs/${ENV}.tfvars"

if [ ! -f "${BACKEND_FILE}" ]; then
  echo "Missing ${BACKEND_FILE}" >&2
  exit 1
fi

cd "${ROOT}"
terraform init -backend-config="envs/${ENV}.backend.hcl"
terraform apply -input=false -auto-approve \
  -var-file="envs/${ENV}.tfvars" \
  -target=aws_ecr_repository.this
terraform destroy -input=false -auto-approve -var-file="envs/${ENV}.tfvars"
echo "Destroyed ${ENV}."
