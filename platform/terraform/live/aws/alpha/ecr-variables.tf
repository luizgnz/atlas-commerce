variable "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider created by bootstrap/gh-actions-oidc (output oidc_provider_arn). AWS allows only one OIDC provider per issuer URL per account, so this is passed in rather than created here."
  type        = string
}

variable "repository_prefix" {
  description = "Namespace placed before each ECR repository name."
  type        = string
  default     = "atlas-commerce"
}

variable "repository_names" {
  description = "Names of the ECR repositories to create."
  type        = set(string)
}

variable "scan_on_push" {
  type    = bool
  default = true
}

variable "image_tag_mutability" {
  type    = string
  default = "IMMUTABLE"

  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be IMMUTABLE or MUTABLE."
  }
}

variable "max_tagged_images" {
  type    = number
  default = 20
}

variable "untagged_image_expiration_days" {
  type    = number
  default = 7
}
