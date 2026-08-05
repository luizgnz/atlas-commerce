variable "project" {
  description = "Project name used for naming AWS resources."
  type        = string
  default     = "atlas-commerce"
}

variable "environment" {
  description = "Logical name for the state-backend bucket naming (typically shared)."
  type        = string
  default     = "shared"
}

variable "aws_region" {
  description = "AWS region for API calls and for the state bucket."
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

variable "github_repositories" {
  description = <<-EOT
    GitHub repositories allowed to assume these roles. `name` is "owner/repo".
    `owner_id` and `repo_id` are the immutable GitHub numeric IDs used in the
    OIDC `sub` claim for repos created/opted-in after GitHub's immutable
    subject claim rollout.
  EOT
  type = list(object({
    name     = string
    owner_id = optional(string)
    repo_id  = optional(string)
  }))
  default = [
    {
      name     = "Nitros64/atlas-commerce"
      owner_id = "50177640"
      repo_id  = "1230706878"
    },
    {
      name     = "luizgnz/atlas-commerce"
      owner_id = "101154230"
      repo_id  = "1323178047"
    },
  ]
}

variable "environments" {
  description = <<-EOT
    Environments that get their own apply IAM roles. Keys must match the
    GitHub Environment name on the apply job.

    require_deploy_approval (default true) attaches the IAM deny-until-tagged
    gate (deploy-approved). Set false for disposable envs (alpha) while the
    stack is being brought up.
  EOT
  type = map(object({
    allowed_sub             = string
    require_deploy_approval = optional(bool, true)
  }))
  default = {
    bootstrap = { allowed_sub = "environment:bootstrap" }
    alpha = {
      allowed_sub             = "environment:alpha"
      require_deploy_approval = false
    }
  }
}

variable "deploy_approval_tag_key" {
  description = "IAM tag key used as the human approval gate on apply roles."
  type        = string
  default     = "deploy-approved"
}
