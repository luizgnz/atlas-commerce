locals {
  name_prefix = "${var.project}-${var.environment}"

  # GitHub OIDC `sub` prefixes per allowed repository.
  # Legacy:     repo:OWNER/REPO
  # Immutable:  repo:OWNER@OWNER_ID/REPO@REPO_ID
  # See: https://github.blog/changelog/2026-04-23-immutable-subject-claims-for-github-actions-oidc-tokens/
  github_repo_sub_prefixes = flatten([
    for r in var.github_repositories : concat(
      ["repo:${r.name}"],
      (
        try(r.owner_id, null) != null && try(r.repo_id, null) != null
        ? ["repo:${split("/", r.name)[0]}@${r.owner_id}/${split("/", r.name)[1]}@${r.repo_id}"]
        : []
      )
    )
  ])

  # ECR push mints ref:refs/heads/<branch>.
  # Deploy (and similar) bind GitHub Environment and mint environment:<env>.
  # Trust both; exclude pull_request subjects.
  github_subject_patterns = flatten([
    for prefix in local.github_repo_sub_prefixes : [
      "${prefix}:ref:refs/heads/*",
      "${prefix}:environment:${var.environment}",
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
