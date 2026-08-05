#!/usr/bin/env bash
# Remove the deploy-approved tag from the apply role for <env>, closing the
# human approval gate again. Safe to run at any time, including when the
# tag is already absent.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <env>   (e.g. alpha, bootstrap)" >&2
  exit 1
fi

env="$1"
role_name="gh-actions-atlas-commerce-terraform-apply-${env}"

aws iam untag-role \
  --role-name "${role_name}" \
  --tag-keys deploy-approved

echo "Revoked: ${role_name} is denied all write actions again."
