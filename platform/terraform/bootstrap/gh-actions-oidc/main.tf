data "aws_caller_identity" "current" {}

# GitHub's OIDC issuer. One provider per AWS account, shared by every role
# below and by any future workflow in this repo.
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
# Plan role: one role, read-only, assumable from any ref (PRs and branches)
# in this repo. Runs `terraform plan` in CI without ever needing approval —
# it cannot create, modify, or delete anything.
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
  name               = "${local.name_prefix}-terraform-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
}

resource "aws_iam_role_policy_attachment" "plan_read_only" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# terraform plan with use_lockfile=true must PutObject/DeleteObject the
# `.tflock` companion object. ReadOnlyAccess covers state reads but not
# lock writes, so grant the narrowest write scope that still lets plan run.
data "aws_iam_policy_document" "plan_state_lock" {
  statement {
    sid    = "ListTerraformStateBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::${var.terraform_state_bucket}",
    ]
  }

  statement {
    sid    = "ReadTerraformStateObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "arn:aws:s3:::${var.terraform_state_bucket}/*",
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
      "arn:aws:s3:::${var.terraform_state_bucket}/*.tflock",
    ]
  }
}

resource "aws_iam_role_policy" "plan_state_lock" {
  name   = "terraform-state-lock"
  role   = aws_iam_role.plan.name
  policy = data.aws_iam_policy_document.plan_state_lock.json
}

# ---------------------------------------------------------------------------
# Apply roles: one per Terraform live environment. Trust matches the GitHub
# Environment OIDC subject (`environment:<name>`), because the apply job sets
# `environment:` and GitHub mints that claim instead of `ref:refs/heads/...`.
# Every write action is still denied unless a human tags the role
# `deploy-approved = true` first — see scripts/approve-deploy.sh.
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

  name               = "${local.name_prefix}-terraform-apply-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.apply_trust[each.key].json

  # The deploy-approval tag starts absent — untagged means denied. A human
  # operator adds it via scripts/approve-deploy.sh right before approving
  # the apply job, and scripts/revoke-deploy.sh removes it right after.
}

resource "aws_iam_role_policy_attachment" "apply_admin" {
  for_each = var.environments

  role       = aws_iam_role.apply[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy" "apply_requires_human_approval" {
  for_each = var.environments

  name   = "requires-human-approval"
  role   = aws_iam_role.apply[each.key].name
  policy = data.aws_iam_policy_document.deploy_approval_gate.json
}

# Deny every action except sts:GetCallerIdentity unless the role itself
# currently carries the operator-controlled approval tag. IAM NotAction
# cannot use a wildcard service vendor (e.g. "*:Get*" is invalid — the
# vendor segment before ":" must be a literal), so this denies everything
# rather than trying to enumerate/exempt read-only verbs. In practice this
# is fine: the apply job applies a plan produced earlier by the read-only
# plan role, it does not re-run `terraform plan` under this role.
#
# Two statements, not one, on purpose: IAM ANDs conditions within a single
# statement, so a single "tag missing OR tag wrong" check needs the deny
# split across two statements (tag absent; tag present but not "true"),
# which IAM then ORs together as separate policy statements.
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
