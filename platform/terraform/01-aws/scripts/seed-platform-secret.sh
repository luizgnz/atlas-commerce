#!/usr/bin/env bash
# Seed the platform Secrets Manager secret from 01-aws Terraform outputs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REGION="${AWS_REGION:-eu-central-1}"

PLATFORM_SECRET_NAME="$(terraform -chdir="${ROOT}" output -raw platform_secret_name)"

JWT_SECRET="$(openssl rand -base64 48)"
REDIS_PASSWORD="$(openssl rand -base64 32)"
POSTGRES_PASSWORD="$(openssl rand -base64 32)"

SECRET_STRING=$(cat <<EOF
{
  "SECURITY_JWT_SECRET": "$JWT_SECRET",
  "REDIS_PASSWORD": "$REDIS_PASSWORD",
  "POSTGRES_PASSWORD": "$POSTGRES_PASSWORD"
}
EOF
)

aws secretsmanager put-secret-value \
  --region "$REGION" \
  --secret-id "$PLATFORM_SECRET_NAME" \
  --secret-string "$SECRET_STRING"

unset JWT_SECRET REDIS_PASSWORD POSTGRES_PASSWORD SECRET_STRING

echo "Seeded platform secret: $PLATFORM_SECRET_NAME"
