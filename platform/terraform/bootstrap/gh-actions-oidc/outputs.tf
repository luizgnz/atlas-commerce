output "plan_role_arn" {
  description = "IAM role ARN GitHub Actions assumes to run `terraform plan` (read-only, any ref)."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arns" {
  description = "IAM role ARN per environment GitHub Actions assumes to run `terraform apply`. Denied until a human tags the role — see scripts/approve-deploy.sh."
  value       = { for env, role in aws_iam_role.apply : env => role.arn }
}

output "oidc_provider_arn" {
  description = "GitHub OIDC provider ARN registered in this AWS account."
  value       = aws_iam_openid_connect_provider.github.arn
}
