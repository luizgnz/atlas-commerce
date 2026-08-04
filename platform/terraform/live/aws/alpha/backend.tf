# Declare that this root module stores its Terraform state in S3.
terraform {
  # Keep environment-specific backend values in backend.hcl.
  backend "s3" {}
}