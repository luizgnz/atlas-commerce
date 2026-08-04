locals {
  name_prefix = "${var.project}-${var.environment}"

  state_bucket_name = coalesce( #for custom bucket name, otherwise use default naming convention
    var.state_bucket_name,
    "${local.name_prefix}-tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  )

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "terraform-backend"
  }
}