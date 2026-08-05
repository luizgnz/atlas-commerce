#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")" && pwd)/../../platform/terraform/01-aws/scripts/seed-platform-secret.sh" "$@"
