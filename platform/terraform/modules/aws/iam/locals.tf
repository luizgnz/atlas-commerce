locals {
  name_prefix = "${var.project}-${var.environment}"

  # Upstream + fork (same repos as bootstrap/gh-actions-oidc).
  github_repo_names = distinct(concat(
    ["${var.github_organization}/${var.github_repository}"],
    var.additional_github_repositories
  ))

  # ECR push (reusable-service-ci on a branch) mints ref:refs/heads/<branch>.
  # Deploy job binds GitHub Environment `alpha` and mints environment:alpha
  # (same claim shape as Terraform apply). Trust both forms; exclude PRs.
  github_subject_patterns = flatten([
    for repo in local.github_repo_names : [
      "repo:${repo}:ref:refs/heads/*",
      "repo:${repo}:environment:${var.environment}",
    ]
  ])

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
