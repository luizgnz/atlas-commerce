locals {
  name_prefix = "gh-actions-${var.project}"

  common_tags = {
    Project   = var.project
    ManagedBy = "terraform"
    Component = "gh-actions-oidc"
  }

  # GitHub OIDC `sub` patterns for each allowed repository.
  # Legacy:     repo:OWNER/REPO:...
  # Immutable:  repo:OWNER@OWNER_ID/REPO@REPO_ID:...
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
}
