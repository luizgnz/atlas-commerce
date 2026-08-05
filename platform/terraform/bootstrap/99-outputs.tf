output "terraform_state_bucket_name" {
  description = "S3 bucket used for Terraform remote state."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_state_bucket_arn" {
  description = "ARN of the S3 bucket used for Terraform remote state."
  value       = aws_s3_bucket.terraform_state.arn
}

output "aws_region" {
  description = "AWS region where bootstrap resources were created."
  value       = var.aws_region
}

output "backend_config_template" {
  description = <<-EOT
    Backend config body for 01-aws/envs/<env>.backend.hcl.
    Generate without hand-typing the bucket name:

      ./scripts/generate-backend-hcl.sh alpha
  EOT
  value       = <<EOT
bucket       = "${aws_s3_bucket.terraform_state.bucket}"
key          = "atlas-commerce/<ENV>/terraform.tfstate"
region       = "${var.aws_region}"
encrypt      = true
use_lockfile = true
EOT
}

output "plan_role_arn" {
  description = "IAM role ARN GitHub Actions assumes to run terraform plan."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arns" {
  description = "IAM role ARN per environment for terraform apply."
  value       = { for env, role in aws_iam_role.apply : env => role.arn }
}

output "oidc_provider_arn" {
  description = "GitHub OIDC provider ARN in this AWS account."
  value       = aws_iam_openid_connect_provider.github.arn
}
