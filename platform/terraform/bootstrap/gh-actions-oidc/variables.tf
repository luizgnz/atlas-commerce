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
  description = <<-EOT
    GitHub repositories allowed to assume these roles. `name` is "owner/repo".
    `owner_id` and `repo_id` are the immutable GitHub numeric IDs used in the
    OIDC `sub` claim for repos created/opted-in after GitHub's immutable
    subject claim rollout (e.g. repo:owner@OWNER_ID/repo@REPO_ID:...).
    Both legacy and immutable `sub` patterns are trusted when IDs are set.
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
    Terraform live environments that get their own apply IAM roles.
    Keys are used in role names and must match the GitHub Environment name
    on the apply job (reusable-terraform.yml sets environment: <key>).

    allowed_sub is the OIDC subject suffix after "repo:OWNER/REPO:" (matched
    with StringLike). Jobs that use a GitHub Environment mint
    "environment:<name>" — NOT "ref:refs/heads/..." — so apply trust must
    use environment:<key>. Plan jobs have no environment and still use
    "repo:...:*" on the shared plan role.

    require_deploy_approval (default true) attaches the IAM deny-until-tagged
    gate (deploy-approved). Set false for disposable envs (alpha) while the
    stack is being brought up so apply can run without approve-deploy.sh.
  EOT
  type = map(object({
    allowed_sub               = string
    require_deploy_approval   = optional(bool, true)
  }))
  default = {
    bootstrap = { allowed_sub = "environment:bootstrap" }
    # alpha is currently the only live environment — no separate "shared"
    # environment. Approval gate off until the stack is functional; re-enable
    # require_deploy_approval later. Keep GitHub Environment reviewers empty
    # for alpha as well (Settings → Environments → alpha).
    alpha = {
      allowed_sub             = "environment:alpha"
      require_deploy_approval = false
    }
  }
}

variable "deploy_approval_tag_key" {
  description = "IAM tag key used as the human approval gate on apply roles. Only a human operator with IAM tagging rights sets this tag; GitHub Actions cannot set it on itself."
  type        = string
  default     = "deploy-approved"
}

variable "terraform_state_bucket" {
  description = "S3 bucket holding Terraform remote state. The plan role needs write access only for native S3 lockfiles (*.tflock); state objects stay read-only via ReadOnlyAccess."
  type        = string
  default     = "atlas-commerce-shared-tfstate-553337000139-eu-central-1"
}
