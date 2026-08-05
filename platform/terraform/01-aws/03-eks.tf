# Flattened from modules/aws/eks (cluster.tf, node-groups.tf, iam.tf,
# locals.tf, irsa.tf, velero.tf, addons.tf, ebs-csi.tf,
# aws-load-balancer-controller.tf, external-secrets.tf, versions.tf).
#
# All module toggles that live/aws/alpha always passed as fixed literals
# (enable_irsa = true, enable_velero_irsa = true, cluster_endpoint_private/
# public_access = true, node_group_name = "default", velero_namespace =
# "velero", etc.) are now local values instead of variables — they were never
# exposed as tfvars in alpha.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

# Auto-detect the operator's current public IP for the EKS endpoint
# allowlist, used only when eks_cluster_endpoint_public_access_cidrs is left
# at its default empty list. This makes terraform plan/apply depend on
# checkip.amazonaws.com being reachable; set the variable explicitly to
# avoid that dependency (e.g. in CI, or behind a firewall).
data "http" "operator_public_ip" {
  count = length(var.eks_cluster_endpoint_public_access_cidrs) == 0 ? 1 : 0

  url                = "https://checkip.amazonaws.com"
  request_timeout_ms = 10000
}

locals {
  eks_common_tags = merge(
    local.common_tags,
    {
      Component = "eks"
    }
  )

  # Fixed toggles that live/aws/alpha always passed as literals to the old
  # eks module (never overridden through tfvars).
  eks_enable_irsa        = true
  eks_enable_velero_irsa = true

  eks_node_group_name             = "default"
  eks_node_ami_type               = "AL2023_x86_64_STANDARD"
  eks_velero_namespace            = "velero"
  eks_velero_service_account_name = "velero"

  # Use the explicit override when set; otherwise fall back to the
  # auto-detected operator IP as a /32 CIDR.
  eks_cluster_endpoint_public_access_cidrs = length(var.eks_cluster_endpoint_public_access_cidrs) > 0 ? (
    var.eks_cluster_endpoint_public_access_cidrs
    ) : [
    "${trimspace(data.http.operator_public_ip[0].response_body)}/32"
  ]

  # Build the issuer host and path used in IAM trust-policy conditions.
  eks_oidc_issuer_hostpath = replace(
    aws_eks_cluster.main.identity[0].oidc[0].issuer,
    "https://",
    ""
  )

  velero_service_account_subject = "system:serviceaccount:${local.eks_velero_namespace}:${local.eks_velero_service_account_name}"

  # Pin the namespace and ServiceAccount that Helm will create later.
  external_secrets_namespace            = "external-secrets"
  external_secrets_service_account_name = "external-secrets"

  # Restrict ESO to Atlas secrets for this environment only.
  external_secrets_secret_arn_pattern = "arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project}/${var.environment}/*"
}

# -----------------------------------------------------------------------------
# Cluster
# -----------------------------------------------------------------------------

resource "aws_eks_cluster" "main" {
  name = var.eks_cluster_name

  role_arn = aws_iam_role.cluster.arn

  version = var.eks_kubernetes_version

  # Terraform manages VPC CNI, CoreDNS, and kube-proxy as EKS add-ons.
  bootstrap_self_managed_addons = false

  enabled_cluster_log_types = []

  vpc_config {
    subnet_ids = [for s in aws_subnet.private : s.id]

    security_group_ids = null

    # Keep internal EKS communication inside the VPC.
    endpoint_private_access = true

    # Allow local kubectl access, restricted to the allowed CIDR ranges.
    endpoint_public_access = true

    public_access_cidrs = local.eks_cluster_endpoint_public_access_cidrs
  }

  tags = merge(
    local.eks_common_tags,
    {
      Name = var.eks_cluster_name
      Role = "eks-cluster"
    }
  )

  # Ensure the cluster IAM permissions are attached before EKS creates the control plane.
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy
  ]

  lifecycle {
    # Never allow a public API endpoint without explicit CIDR restrictions.
    precondition {
      condition     = length(local.eks_cluster_endpoint_public_access_cidrs) > 0
      error_message = "Public EKS API access requires at least one allowed CIDR."
    }
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  upgrade_policy {
    support_type = "STANDARD"
  }
}

# -----------------------------------------------------------------------------
# Node group
# -----------------------------------------------------------------------------

resource "aws_eks_node_group" "default" {
  cluster_name = aws_eks_cluster.main.name

  node_group_name = local.eks_node_group_name

  node_role_arn = aws_iam_role.node.arn

  subnet_ids = [for s in aws_subnet.private : s.id]

  ami_type = local.eks_node_ami_type

  capacity_type = var.eks_node_capacity_type

  instance_types = var.eks_node_instance_types

  disk_size = var.eks_node_disk_size_gib

  scaling_config {
    min_size     = var.eks_node_min_size
    desired_size = var.eks_node_desired_size
    max_size     = var.eks_node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(
    local.eks_common_tags,
    {
      Name = "${local.name_prefix}-${local.eks_node_group_name}-nodes"
      Role = "eks-node-group"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_ecr_pull_policy,
    aws_eks_addon.vpc_cni
  ]

  lifecycle {
    precondition {
      condition = (
        var.eks_node_min_size <= var.eks_node_desired_size &&
        var.eks_node_desired_size <= var.eks_node_max_size
      )

      error_message = "eks_node_min_size must be <= eks_node_desired_size, which must be <= eks_node_max_size."
    }
  }
}

# -----------------------------------------------------------------------------
# Cluster / node IAM roles
# -----------------------------------------------------------------------------

data "aws_iam_policy" "eks_cluster_policy" {
  name = "AmazonEKSClusterPolicy"
}

data "aws_iam_policy" "eks_worker_node_policy" {
  name = "AmazonEKSWorkerNodePolicy"
}

data "aws_iam_policy" "ec2_container_registry_pull_only" {
  name = "AmazonEC2ContainerRegistryPullOnly"
}

data "aws_iam_policy" "eks_cni_policy" {
  name = "AmazonEKS_CNI_Policy"
}

data "aws_iam_policy" "ebs_csi_driver_policy" {
  name = "AmazonEBSCSIDriverPolicyV2"
}

resource "aws_iam_role" "cluster" {
  name = "${local.name_prefix}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.eks_common_tags,
    {
      Name = "${local.name_prefix}-eks-cluster-role"
      Role = "eks-cluster"
    }
  )
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role = aws_iam_role.cluster.name

  policy_arn = data.aws_iam_policy.eks_cluster_policy.arn
}

resource "aws_iam_role" "node" {
  name = "${local.name_prefix}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.eks_common_tags,
    {
      Name = "${local.name_prefix}-eks-node-role"
      Role = "eks-node"
    }
  )
}

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  role = aws_iam_role.node.name

  policy_arn = data.aws_iam_policy.eks_worker_node_policy.arn
}

resource "aws_iam_role_policy_attachment" "node_ecr_pull_policy" {
  role = aws_iam_role.node.name

  policy_arn = data.aws_iam_policy.ec2_container_registry_pull_only.arn
}

# Keep CNI permissions on nodes only when IRSA is explicitly disabled.
resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  count = local.eks_enable_irsa ? 0 : 1

  role = aws_iam_role.node.name

  policy_arn = data.aws_iam_policy.eks_cni_policy.arn
}

# -----------------------------------------------------------------------------
# IRSA (OIDC provider + dedicated VPC CNI role)
# -----------------------------------------------------------------------------

data "tls_certificate" "eks_oidc" {
  count = local.eks_enable_irsa ? 1 : 0

  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  count = local.eks_enable_irsa ? 1 : 0

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    data.tls_certificate.eks_oidc[0].certificates[0].sha1_fingerprint
  ]

  url = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(
    local.eks_common_tags,
    {
      Name = "${local.name_prefix}-eks-oidc"
      Role = "eks-oidc-provider"
    }
  )
}

data "aws_iam_policy_document" "vpc_cni_assume_role" {
  count = local.eks_enable_irsa ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer_hostpath}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }
  }
}

resource "aws_iam_role" "vpc_cni" {
  count = local.eks_enable_irsa ? 1 : 0

  name = "${local.name_prefix}-vpc-cni-role"

  assume_role_policy = data.aws_iam_policy_document.vpc_cni_assume_role[0].json

  tags = merge(
    local.eks_common_tags,
    {
      Name = "${local.name_prefix}-vpc-cni-role"
      Role = "vpc-cni"
    }
  )
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy" {
  count = local.eks_enable_irsa ? 1 : 0

  role = aws_iam_role.vpc_cni[0].name

  policy_arn = data.aws_iam_policy.eks_cni_policy.arn
}

# -----------------------------------------------------------------------------
# Velero IRSA role
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "velero_assume_role" {
  count = local.eks_enable_velero_irsa ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.eks[0].arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer_hostpath}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer_hostpath}:sub"

      values = [
        local.velero_service_account_subject
      ]
    }
  }
}

resource "aws_iam_role" "velero" {
  count = local.eks_enable_velero_irsa ? 1 : 0

  name = "${local.name_prefix}-velero-irsa-role"

  assume_role_policy = data.aws_iam_policy_document.velero_assume_role[0].json

  tags = merge(
    local.eks_common_tags,
    {
      Name = "${local.name_prefix}-velero-irsa-role"
    }
  )
}

data "aws_iam_policy_document" "velero" {
  count = local.eks_enable_velero_irsa ? 1 : 0

  statement {
    sid    = "AllowEbsSnapshotOperations"
    effect = "Allow"

    actions = [
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:CreateSnapshot",
      "ec2:DeleteSnapshot"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    sid    = "AllowVeleroBackupObjectAccess"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]

    resources = [
      "${aws_s3_bucket.velero.arn}/*"
    ]
  }

  statement {
    sid    = "AllowVeleroBackupBucketAccess"
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.velero.arn
    ]
  }
}

resource "aws_iam_policy" "velero" {
  count = local.eks_enable_velero_irsa ? 1 : 0

  name        = "${local.name_prefix}-velero-policy"
  description = "Allows Velero to store backups in S3 and manage EBS snapshots."

  policy = data.aws_iam_policy_document.velero[0].json

  tags = merge(
    local.eks_common_tags,
    {
      Name = "${local.name_prefix}-velero-policy"
    }
  )
}

resource "aws_iam_role_policy_attachment" "velero" {
  count = local.eks_enable_velero_irsa ? 1 : 0

  role       = aws_iam_role.velero[0].name
  policy_arn = aws_iam_policy.velero[0].arn
}

# -----------------------------------------------------------------------------
# EKS add-ons
# -----------------------------------------------------------------------------

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name

  addon_name = "vpc-cni"

  resolve_conflicts_on_create = "OVERWRITE"

  resolve_conflicts_on_update = "PRESERVE"

  service_account_role_arn = local.eks_enable_irsa ? aws_iam_role.vpc_cni[0].arn : null

  depends_on = [
    aws_iam_role_policy_attachment.vpc_cni_policy
  ]
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name

  addon_name = "coredns"

  resolve_conflicts_on_create = "OVERWRITE"

  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_node_group.default
  ]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name

  addon_name = "kube-proxy"

  resolve_conflicts_on_create = "OVERWRITE"

  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_node_group.default
  ]
}

resource "aws_eks_addon" "ebs_csi" {
  count = local.eks_enable_irsa ? 1 : 0

  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  service_account_role_arn = aws_iam_role.ebs_csi[0].arn

  depends_on = [
    aws_eks_node_group.default,
    aws_iam_role_policy_attachment.ebs_csi_policy,
  ]
}

# -----------------------------------------------------------------------------
# EBS CSI IRSA role
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  count = local.eks_enable_irsa ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer_hostpath}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  count = local.eks_enable_irsa ? 1 : 0

  name = "${local.name_prefix}-ebs-csi-role"

  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role[0].json

  tags = merge(
    local.eks_common_tags,
    {
      Name = "${local.name_prefix}-ebs-csi-role"
      Role = "ebs-csi"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  count = local.eks_enable_irsa ? 1 : 0

  role = aws_iam_role.ebs_csi[0].name

  policy_arn = data.aws_iam_policy.ebs_csi_driver_policy.arn
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller IRSA role
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  count = local.eks_enable_irsa ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer_hostpath}:sub"
      values = [
        "system:serviceaccount:kube-system:aws-load-balancer-controller"
      ]
    }
  }
}

# Store the official IAM policy pinned to controller version 3.4.0.
resource "aws_iam_policy" "aws_load_balancer_controller" {
  count = local.eks_enable_irsa ? 1 : 0

  name = "${local.name_prefix}-aws-load-balancer-controller"

  description = "IAM permissions for AWS Load Balancer Controller v3.4.0."

  # Read the reviewed policy committed alongside this root module.
  policy = file(
    "${path.module}/policies/aws-load-balancer-controller-v3.4.0.json"
  )

  tags = merge(
    local.eks_common_tags,
    {
      Name = "${local.name_prefix}-aws-load-balancer-controller"
      Role = "aws-load-balancer-controller-policy"
    }
  )
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  count = local.eks_enable_irsa ? 1 : 0

  name = "${local.name_prefix}-aws-load-balancer-controller-role"

  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role[0].json

  tags = merge(
    local.eks_common_tags,
    {
      Name = "${local.name_prefix}-aws-load-balancer-controller-role"
      Role = "aws-load-balancer-controller"
    }
  )
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  count = local.eks_enable_irsa ? 1 : 0

  role = aws_iam_role.aws_load_balancer_controller[0].name

  policy_arn = aws_iam_policy.aws_load_balancer_controller[0].arn
}

# -----------------------------------------------------------------------------
# External Secrets Operator IRSA role
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "external_secrets_assume_role" {
  count = local.eks_enable_irsa ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer_hostpath}:sub"
      values = [
        "system:serviceaccount:${local.external_secrets_namespace}:${local.external_secrets_service_account_name}"
      ]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  count = local.eks_enable_irsa ? 1 : 0

  name = "${local.name_prefix}-external-secrets-role"

  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume_role[0].json

  tags = merge(
    local.eks_common_tags,
    {
      Name = "${local.name_prefix}-external-secrets-role"
      Role = "external-secrets"
    }
  )
}

# Allow ESO to read only Atlas secrets belonging to this environment.
data "aws_iam_policy_document" "external_secrets_read" {
  count = local.eks_enable_irsa ? 1 : 0

  statement {
    sid    = "ReadAtlasEnvironmentSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]

    resources = [
      local.external_secrets_secret_arn_pattern,
      "arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:rds!db-*"
    ]
  }
}

resource "aws_iam_role_policy" "external_secrets_read" {
  count = local.eks_enable_irsa ? 1 : 0

  name = "${local.name_prefix}-external-secrets-read"

  role   = aws_iam_role.external_secrets[0].id
  policy = data.aws_iam_policy_document.external_secrets_read[0].json
}
