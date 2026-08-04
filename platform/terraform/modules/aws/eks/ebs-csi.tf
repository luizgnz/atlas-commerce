# Build the IRSA trust policy for the EBS CSI controller service account.
data "aws_iam_policy_document" "ebs_csi_assume_role" {
  # Create this policy only when IRSA is enabled.
  count = var.enable_irsa ? 1 : 0

  statement {
    # Allow the Kubernetes service account to obtain temporary AWS credentials.
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      # Trust the EKS OIDC provider created by this module.
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }

    condition {
      # Require the AWS STS audience.
      test     = "StringEquals"
      variable = "${local.oidc_issuer_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      # Restrict this role to the EBS CSI controller only.
      test     = "StringEquals"
      variable = "${local.oidc_issuer_hostpath}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

# Create a dedicated IAM role for the Amazon EBS CSI controller.
resource "aws_iam_role" "ebs_csi" {
  # Create the role only when IRSA is enabled.
  count = var.enable_irsa ? 1 : 0

  # Use a stable and readable role name.
  name = "${local.name_prefix}-ebs-csi-role"

  # Attach the trust policy restricted to the controller service account.
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role[0].json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ebs-csi-role"
      Role = "ebs-csi"
    }
  )
}

# Grant the CSI controller permission to manage tagged EBS volumes and snapshots.
resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  # Create this attachment only when IRSA is enabled.
  count = var.enable_irsa ? 1 : 0

  # Attach the policy to the dedicated CSI role.
  role = aws_iam_role.ebs_csi[0].name

  # Use AWS's tag-scoped managed policy for the EBS CSI driver.
  policy_arn = data.aws_iam_policy.ebs_csi_driver_policy.arn
}