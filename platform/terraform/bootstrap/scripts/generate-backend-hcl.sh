#!/usr/bin/env bash
# Generate 01-aws/envs/<env>.backend.hcl from this bootstrap root's outputs.
# Never hand-edit the generated file — it always reflects the current account's
# state bucket name.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <env>   (e.g. alpha)" >&2
  exit 1
fi

env="$1"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bootstrap_dir="$(cd "${script_dir}/.." && pwd)"
target_file="${bootstrap_dir}/../01-aws/envs/${env}.backend.hcl"
target_dir="$(dirname "${target_file}")"

if [ ! -d "${target_dir}" ]; then
  echo "error: ${target_dir} does not exist" >&2
  exit 1
fi

cd "${bootstrap_dir}"
terraform output -raw backend_config_template \
  | sed "s#<ENV>#${env}#" \
  > "${target_file}"

echo "Wrote ${target_file}"
