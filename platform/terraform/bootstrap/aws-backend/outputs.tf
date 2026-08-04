output "terraform_state_bucket_name" {
  description = "S3 bucket used for Terraform remote state."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_state_bucket_arn" {
  description = "ARN of the S3 bucket used for Terraform remote state."
  value       = aws_s3_bucket.terraform_state.arn
}

output "aws_region" {
  description = "AWS region where the backend resources were created."
  value       = var.aws_region
}

output "backend_config_template" {
  description = <<-EOT
    Backend config body for any live/aws/<env>/backend.hcl. The bucket/region
    values are read from this state, not retyped by hand, to avoid pointing
    a new environment at the wrong AWS account's state bucket.

    Generate a real backend.hcl without manual transcription, e.g. for alpha:
      terraform output -raw backend_config_template \
        | sed 's#<ENV>#alpha#' > ../../live/aws/alpha/backend.hcl
  EOT
  value       = <<EOT
bucket       = "${aws_s3_bucket.terraform_state.bucket}"
key          = "atlas-commerce/<ENV>/terraform.tfstate"
region       = "${var.aws_region}"
encrypt      = true
use_lockfile = true
EOT
}