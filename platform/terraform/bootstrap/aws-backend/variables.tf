variable "project" {
  description = "Project name used for naming AWS resources."
  type        = string
  default     = "atlas-commerce"
}

variable "environment" {
  description = "Environment name. For backend bootstrap we use shared."
  type        = string
  default     = "shared"
}

variable "aws_region" { #The default AWS region will be Frankfurt. But we could change it without touching main.tf.
  description = "AWS region where the Terraform backend resources will be created."
  type        = string
  default     = "eu-central-1"
}

variable "state_bucket_name" {
  description = "Optional custom S3 bucket name for Terraform state. Must be globally unique."
  type        = string
  default     = null
}

variable "force_destroy_state_bucket" {
  description = "Allows destroying the state bucket even if it contains objects. Keep false for safety."
  type        = bool
  default     = false
}