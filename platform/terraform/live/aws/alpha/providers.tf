# Configure the AWS provider used by this development environment.
provider "aws" {
  # Deploy Atlas development resources in the selected AWS region.
  region = var.aws_region

  # Apply common tags automatically to supported AWS resources.
  default_tags {
    tags = local.common_tags
  }
}