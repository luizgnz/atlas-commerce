# Build the trust policy that limits role assumption to this repository's branches.
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    # Allow GitHub OIDC tokens to request temporary AWS credentials.
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      # Trust the GitHub Actions OIDC provider created by bootstrap/gh-actions-oidc.
      # AWS allows only one OIDC provider per issuer URL per account, so this
      # module reuses it instead of creating its own.
      type = "Federated"

      identifiers = [
        var.github_oidc_provider_arn
      ]
    }

    condition {
      # Require the audience expected by AWS STS.
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      # Allow any branch of Nitros64/atlas-commerce (not pull_request subjects).
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.github_subject_pattern]
    }
  }
}

# Create the IAM role assumed by GitHub Actions through OIDC.
resource "aws_iam_role" "github_actions_ecr_push" {
  # Use the configured role name.
  name = var.role_name

  # Attach the GitHub OIDC trust policy.
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  # Limit temporary workflow sessions to one hour.
  max_session_duration = 3600

  tags = merge(
    local.common_tags,
    {
      Name = var.role_name
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

    # Allow only the API calls required to upload image layers and manifests.
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage"
    ]

    # Restrict image pushes to the ECR repositories passed by live/aws/alpha.
    resources = var.ecr_repository_arns
  }
}

# Attach the ECR push policy to the GitHub Actions role.
resource "aws_iam_role_policy" "github_actions_ecr_push" {
  # Use a readable inline policy name.
  name = "${local.name_prefix}-github-actions-ecr-push"

  # Attach the policy to the OIDC-assumed role.
  role = aws_iam_role.github_actions_ecr_push.id

  # Use the least-privilege ECR policy built above.
  policy = data.aws_iam_policy_document.github_actions_ecr_push.json
}

# -----------------------------------------------------------------------------
# EKS deploy role (helm upgrade / kubectl from GitHub Actions)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "github_actions_eks_deploy" {
  count = local.create_eks_deploy_role ? 1 : 0

  name                 = var.eks_deploy_role_name
  assume_role_policy   = data.aws_iam_policy_document.github_actions_assume_role.json
  max_session_duration = 3600

  tags = merge(
    local.common_tags,
    {
      Name = var.eks_deploy_role_name
      Role = "github-actions-eks-deploy"
    }
  )
}

data "aws_iam_policy_document" "github_actions_eks_deploy" {
  count = local.create_eks_deploy_role ? 1 : 0

  statement {
    sid    = "EksDescribeForKubeconfig"
    effect = "Allow"

    actions = [
      "eks:DescribeCluster",
    ]

    resources = [var.eks_cluster_arn]
  }
}

resource "aws_iam_role_policy" "github_actions_eks_deploy" {
  count = local.create_eks_deploy_role ? 1 : 0

  name   = "${local.name_prefix}-github-actions-eks-deploy"
  role   = aws_iam_role.github_actions_eks_deploy[0].id
  policy = data.aws_iam_policy_document.github_actions_eks_deploy[0].json
}
