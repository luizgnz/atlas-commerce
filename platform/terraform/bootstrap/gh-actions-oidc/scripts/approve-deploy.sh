#!/usr/bin/env bash
# Tag the apply role for <env> with deploy-approved=true, opening the human
# approval gate described in ../README.md. Requires AWS credentials with
# iam:TagRole on the role (your own admin session, not the GitHub role).
#
# This does NOT auto-expire. Run revoke-deploy.sh yourself once the run has
# applied — or, if you forget, the tag stays set and the gate stays open for
# that environment until someone revokes it.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <env>   (e.g. alpha, bootstrap)" >&2
  exit 1
fi

env="$1"
role_name="gh-actions-atlas-commerce-terraform-apply-${env}"

aws iam tag-role \
  --role-name "${role_name}" \
  --tags Key=deploy-approved,Value=true

echo "Approved: ${role_name} can now run write actions."
echo "Remember to run ./revoke-deploy.sh ${env} once the deploy finishes."
