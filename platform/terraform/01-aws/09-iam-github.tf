# Flattened from modules/aws/iam (github-actions.tf, locals.tf, variables.tf,
# outputs.tf).
#
# Deprecated module variables that were never referenced by any resource
# (github_organization, github_repository, github_branch,
# additional_github_repositories) were dropped rather than carried forward.
# create_eks_deploy_role was always passed as the literal `true` from
# live/aws/alpha, so it is a local here instead of a variable.

locals {
  iam_common_tags = merge(
    local.common_tags,
    {
      Component = "iam"
    }
  )

  # Always true in live/aws/alpha ("Always created in alpha. Do not gate on
  # role ARN != null — that output is often (known after apply) and breaks
  # count.").
  iam_create_eks_deploy_role = true

  # Not previously exposed as variables — these were module defaults.
  iam_role_name            = "atlas-commerce-github-actions-ecr-push-role"
  iam_eks_deploy_role_name = "atlas-commerce-github-actions-eks-deploy-role"

  # GitHub OIDC `sub` prefixes per allowed repository.
  # Legacy:     repo:OWNER/REPO
  # Immutable:  repo:OWNER@OWNER_ID/REPO@REPO_ID
  # See: https://github.blog/changelog/2026-04-23-immutable-subject-claims-for-github-actions-oidc-tokens/
  iam_github_repo_sub_prefixes = flatten([
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
  iam_github_subject_patterns = flatten([
    for prefix in local.iam_github_repo_sub_prefixes : [
      "${prefix}:ref:refs/heads/*",
      "${prefix}:environment:${var.environment}",
    ]
  ])
}

# Build the trust policy that limits role assumption to this repository's branches.
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      # Trust the GitHub Actions OIDC provider created by bootstrap/gh-actions-oidc.
      # AWS allows only one OIDC provider per issuer URL per account, so this
      # reuses it instead of creating a new one.
      type = "Federated"

      identifiers = [
        var.github_oidc_provider_arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      # Allow branch refs (ECR push) and environment:<env> (deploy / Terraform-style).
      # Not pull_request subjects. See local.iam_github_subject_patterns.
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.iam_github_subject_patterns
    }
  }
}

# Create the IAM role assumed by GitHub Actions through OIDC.
resource "aws_iam_role" "github_actions_ecr_push" {
  name = local.iam_role_name

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  # Limit temporary workflow sessions to one hour.
  max_session_duration = 3600

  tags = merge(
    local.iam_common_tags,
    {
      Name = local.iam_role_name
      Role = "github-actions-ecr-push"
    }
  )
}

# Build the least-privilege permissions policy for publishing images to ECR.
data "aws_iam_policy_document" "github_actions_ecr_push" {
  statement {
    sid = "EcrAuthorizationToken"

    effect = "Allow"

    # ECR authentication tokens cannot be scoped to individual repositories.
    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    sid = "PushImagesToAtlasRepositories"

    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage"
    ]

    # Restrict image pushes to the ECR repositories created in 06-ecr.tf.
    resources = [for r in aws_ecr_repository.this : r.arn]
  }
}

resource "aws_iam_role_policy" "github_actions_ecr_push" {
  name = "${local.name_prefix}-github-actions-ecr-push"

  role = aws_iam_role.github_actions_ecr_push.id

  policy = data.aws_iam_policy_document.github_actions_ecr_push.json
}

# -----------------------------------------------------------------------------
# EKS deploy role (helm upgrade / kubectl from GitHub Actions)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "github_actions_eks_deploy" {
  count = local.iam_create_eks_deploy_role ? 1 : 0

  name                 = local.iam_eks_deploy_role_name
  assume_role_policy   = data.aws_iam_policy_document.github_actions_assume_role.json
  max_session_duration = 3600

  tags = merge(
    local.iam_common_tags,
    {
      Name = local.iam_eks_deploy_role_name
      Role = "github-actions-eks-deploy"
    }
  )
}

data "aws_iam_policy_document" "github_actions_eks_deploy" {
  count = local.iam_create_eks_deploy_role ? 1 : 0

  statement {
    sid    = "EksDescribeForKubeconfig"
    effect = "Allow"

    actions = [
      "eks:DescribeCluster",
    ]

    resources = [aws_eks_cluster.main.arn]
  }
}

resource "aws_iam_role_policy" "github_actions_eks_deploy" {
  count = local.iam_create_eks_deploy_role ? 1 : 0

  name   = "${local.name_prefix}-github-actions-eks-deploy"
  role   = aws_iam_role.github_actions_eks_deploy[0].id
  policy = data.aws_iam_policy_document.github_actions_eks_deploy[0].json
}
