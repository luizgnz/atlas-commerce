variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider to trust. AWS allows only one OIDC provider per issuer URL per account, so this must reference the provider created by bootstrap/gh-actions-oidc rather than creating a new one."
  type        = string
}

variable "github_repositories" {
  description = <<-EOT
    GitHub repositories allowed to assume these roles. `name` is "owner/repo".
    `owner_id` and `repo_id` are the immutable GitHub numeric IDs used in the
    OIDC `sub` claim (repo:owner@OWNER_ID/repo@REPO_ID:...). Both legacy and
    immutable `sub` patterns are trusted when IDs are set.
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

variable "github_organization" {
  description = "Deprecated. Use github_repositories. Kept for callers that still pass it."
  type        = string
  default     = "Nitros64"
}

variable "github_repository" {
  description = "Deprecated. Use github_repositories. Kept for callers that still pass it."
  type        = string
  default     = "atlas-commerce"
}

variable "github_branch" {
  description = "Deprecated. Roles trust refs/heads/* and environment:<env> (see locals.github_subject_patterns)."
  type        = string
  default     = "master"
}

variable "additional_github_repositories" {
  description = "Deprecated. Use github_repositories. Ignored when github_repositories default/list is used."
  type        = list(string)
  default     = []
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs that GitHub Actions can push images to."
  type        = list(string)
}

variable "role_name" {
  description = "IAM role name assumed by GitHub Actions through OIDC."
  type        = string
  default     = "atlas-commerce-github-actions-ecr-push-role"
}

variable "eks_cluster_arn" {
  description = "EKS cluster ARN the deploy role may DescribeCluster. When null, the EKS deploy role is not created."
  type        = string
  default     = null
}

variable "eks_deploy_role_name" {
  description = "IAM role name assumed by GitHub Actions to run helm/kubectl against EKS."
  type        = string
  default     = "atlas-commerce-github-actions-eks-deploy-role"
}

variable "additional_tags" {
  type    = map(string)
  default = {}
}
