#!/usr/bin/env bash
# Generate backend.hcl for a live/aws/<env> or bootstrap/<module> directory
# from this module's Terraform state, instead of hand-typing the state
# bucket name. See README.md.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <env>        (e.g. dev, staging, prod, shared)" >&2
  echo "       $0 <bootstrap/module>  (e.g. bootstrap/gh-actions-oidc)" >&2
  exit 1
fi

target="$1"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${target}" == bootstrap/* ]]; then
  key="${target}"
  target_dir="${script_dir}/../${target#bootstrap/}"
else
  key="${target}"
  target_dir="${script_dir}/../../live/aws/${target}"
fi

if [ ! -d "${target_dir}" ]; then
  echo "error: ${target_dir} does not exist — is '${target}' valid?" >&2
  exit 1
fi

cd "${script_dir}"
terraform output -raw backend_config_template \
  | sed "s#<ENV>#${key}#" \
  > "${target_dir}/backend.hcl"

echo "Wrote ${target_dir}/backend.hcl"
