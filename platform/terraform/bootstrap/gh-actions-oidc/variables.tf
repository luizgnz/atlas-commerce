variable "project" {
  description = "Project name used for naming AWS resources."
  type        = string
  default     = "atlas-commerce"
}

variable "aws_region" {
  description = "AWS region where the IAM/OIDC resources will be created. IAM is global, but the provider still needs a region for API calls."
  type        = string
  default     = "eu-central-1"
}

variable "github_repositories" {
  description = "GitHub repositories allowed to assume these roles, each in \"owner/repo\" form. Includes the upstream repo and any fork CI runs from."
  type        = list(string)
  default     = ["Nitros64/atlas-commerce", "luizgnz/atlas-commerce"]
}

variable "environments" {
  description = <<-EOT
    Terraform live environments that get their own plan/apply IAM roles.
    Keys are used in role names; values control which git refs may assume
    the apply role for that environment. allowed_ref is matched with
    StringLike, so "ref:refs/heads/*" allows any branch.
  EOT
  type = map(object({
    allowed_ref = string
  }))
  default = {
    bootstrap = { allowed_ref = "ref:refs/heads/master" }
    # alpha is currently the only live environment — no separate "shared"
    # environment. It's a disposable test environment: any branch may apply
    # to it, not just master, so it can be exercised without merging first.
    alpha = { allowed_ref = "ref:refs/heads/*" }
  }
}

variable "deploy_approval_tag_key" {
  description = "IAM tag key used as the human approval gate on apply roles. Only a human operator with IAM tagging rights sets this tag; GitHub Actions cannot set it on itself."
  type        = string
  default     = "deploy-approved"
}
