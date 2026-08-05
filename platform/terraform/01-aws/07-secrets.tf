# Flattened from modules/aws/secrets-manager (secrets.tf, locals.tf,
# variables.tf, outputs.tf).
#
# live/aws/alpha passed a fixed secret_names list (["platform"]) and
# recovery_window_in_days = 0 as literals rather than variables, so they stay
# as locals here instead of becoming new tfvars.

locals {
  secrets_common_tags = merge(
    local.common_tags,
    {
      Component = "secrets-manager"
    }
  )

  # One JSON secret keeps development cost and setup complexity low.
  secret_names                    = toset(["platform"])
  secrets_recovery_window_in_days = 0
}

# Create secret containers only.
# Secret values are intentionally populated outside Terraform.
resource "aws_secretsmanager_secret" "this" {
  for_each = local.secret_names

  # Example: atlas-commerce/alpha/platform
  name = "${var.project}/${var.environment}/${each.value}"

  description = "Runtime secret container for ${var.project} ${var.environment}: ${each.value}."

  # Keep a recovery period in case a secret is deleted accidentally.
  recovery_window_in_days = local.secrets_recovery_window_in_days

  tags = merge(
    local.secrets_common_tags,
    {
      Name   = "${local.name_prefix}-${replace(each.value, "/", "-")}"
      Secret = each.value
    }
  )
}
