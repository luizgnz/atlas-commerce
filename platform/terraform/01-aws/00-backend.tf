# Declare that this root module stores its Terraform state in S3.
terraform {
  # Keep environment-specific backend values in a *.backend.hcl file passed
  # via -backend-config at `terraform init` time (see envs/alpha.backend.hcl.example).
  backend "s3" {}
}
