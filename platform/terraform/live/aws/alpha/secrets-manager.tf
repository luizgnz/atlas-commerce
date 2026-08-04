# Create AWS Secrets Manager containers for Atlas development runtime secrets.
module "secrets_manager" {
  source = "../../../modules/aws/secrets-manager"

  project     = var.project
  environment = var.environment

  # One JSON secret keeps development cost and setup complexity low.
  secret_names = [
    "platform"
  ]

  additional_tags         = var.additional_tags
  recovery_window_in_days = 0
}