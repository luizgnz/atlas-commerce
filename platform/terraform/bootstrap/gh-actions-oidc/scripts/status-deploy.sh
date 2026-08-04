#!/usr/bin/env bash
# Show which apply roles currently carry the deploy-approved tag, i.e. which
# environments have their human approval gate open right now.
set -euo pipefail

for role in $(aws iam list-roles \
  --query "Roles[?starts_with(RoleName, 'gh-actions-atlas-commerce-terraform-apply-')].RoleName" \
  --output text); do
  env="${role#gh-actions-atlas-commerce-terraform-apply-}"
  approved=$(aws iam list-role-tags \
    --role-name "${role}" \
    --query "Tags[?Key=='deploy-approved'].Value | [0]" \
    --output text)

  if [ "${approved}" = "true" ]; then
    echo "${env}: OPEN (deploy-approved=true)"
  else
    echo "${env}: closed"
  fi
done
