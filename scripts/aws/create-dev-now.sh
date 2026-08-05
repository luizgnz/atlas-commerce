#!/usr/bin/env bash
# Deprecated name: use platform/terraform/01-aws/scripts/create-alpha.sh
exec "$(cd "$(dirname "$0")" && pwd)/../../platform/terraform/01-aws/scripts/create-alpha.sh" "${@:-alpha}"
