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

variable "github_organization" {
  description = "GitHub organization or user that owns the repository."
  type        = string
  default     = "Nitros64"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the AWS role."
  type        = string
  default     = "atlas-commerce"
}

variable "github_branch" {
  description = "Deprecated. Roles trust any branch via StringLike refs/heads/* (see locals.github_subject_pattern)."
  type        = string
  default     = "master"
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