data "aws_caller_identity" "current" {}

locals {
  # State bucket naming: atlas-commerce-shared-tfstate-<account>-<region>
  state_name_prefix = "${var.project}-${var.environment}"
  state_bucket_name = coalesce(
    var.state_bucket_name,
    "${local.state_name_prefix}-tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  )

  # GitHub Actions IAM role prefix: gh-actions-atlas-commerce-...
  oidc_name_prefix = "gh-actions-${var.project}"

  common_tags = {
    Project   = var.project
    ManagedBy = "terraform"
    Component = "bootstrap"
  }

  # GitHub OIDC `sub` patterns for each allowed repository.
  # Legacy:     repo:OWNER/REPO:...
  # Immutable:  repo:OWNER@OWNER_ID/REPO@REPO_ID:...
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
}
