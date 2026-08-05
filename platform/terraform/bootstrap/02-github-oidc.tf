# GitHub Actions OIDC provider + plan/apply IAM roles.
# Apply roles may optionally require a human deploy-approved tag
# (see scripts/approve-deploy.sh).

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    data.tls_certificate.github.certificates[0].sha1_fingerprint,
  ]
}

# ---------------------------------------------------------------------------
# Plan role: read-only, assumable from any ref in allowed repos.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for prefix in local.github_repo_sub_prefixes : "${prefix}:*"]
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "${local.oidc_name_prefix}-terraform-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
}

resource "aws_iam_role_policy_attachment" "plan_read_only" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# terraform plan with use_lockfile=true must write `.tflock` objects.
data "aws_iam_policy_document" "plan_state_lock" {
  statement {
    sid    = "ListTerraformStateBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.terraform_state.arn,
    ]
  }

  statement {
    sid    = "ReadTerraformStateObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "${aws_s3_bucket.terraform_state.arn}/*",
    ]
  }

  statement {
    sid    = "WriteTerraformStateLockfiles"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "${aws_s3_bucket.terraform_state.arn}/*.tflock",
    ]
  }
}

resource "aws_iam_role_policy" "plan_state_lock" {
  name   = "terraform-state-lock"
  role   = aws_iam_role.plan.name
  policy = data.aws_iam_policy_document.plan_state_lock.json
}

# ---------------------------------------------------------------------------
# Apply roles: one per environment (GitHub Environment OIDC subject).
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "apply_trust" {
  for_each = var.environments

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for prefix in local.github_repo_sub_prefixes : "${prefix}:${each.value.allowed_sub}"]
    }
  }
}

resource "aws_iam_role" "apply" {
  for_each = var.environments

  name               = "${local.oidc_name_prefix}-terraform-apply-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.apply_trust[each.key].json
}

resource "aws_iam_role_policy_attachment" "apply_admin" {
  for_each = var.environments

  role       = aws_iam_role.apply[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy" "apply_requires_human_approval" {
  for_each = {
    for name, cfg in var.environments : name => cfg
    if try(cfg.require_deploy_approval, true)
  }

  name   = "requires-human-approval"
  role   = aws_iam_role.apply[each.key].name
  policy = data.aws_iam_policy_document.deploy_approval_gate.json
}

data "aws_iam_policy_document" "deploy_approval_gate" {
  statement {
    sid    = "DenyAllWhenApprovalTagMissing"
    effect = "Deny"

    not_actions = [
      "sts:GetCallerIdentity",
    ]

    resources = ["*"]

    condition {
      test     = "Null"
      variable = "aws:PrincipalTag/${var.deploy_approval_tag_key}"
      values   = ["true"]
    }
  }

  statement {
    sid    = "DenyAllWhenApprovalTagNotTrue"
    effect = "Deny"

    not_actions = [
      "sts:GetCallerIdentity",
    ]

    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalTag/${var.deploy_approval_tag_key}"
      values   = ["true"]
    }
  }
}
