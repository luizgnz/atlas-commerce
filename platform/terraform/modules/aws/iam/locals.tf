locals {
  name_prefix = "${var.project}-${var.environment}"

  # Any branch on this repo may assume the GitHub Actions roles (alpha is a
  # disposable environment; selective deploy runs via workflow_dispatch from
  # the chosen ref). Pull requests are excluded — only refs/heads/*.
  github_subject_pattern = "repo:${var.github_organization}/${var.github_repository}:ref:refs/heads/*"

  create_eks_deploy_role = var.eks_cluster_arn != null

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Component   = "iam"
    },
    var.additional_tags
  )
}
