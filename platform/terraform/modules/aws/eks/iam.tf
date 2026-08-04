# Look up AWS-managed policy ARNs by name instead of hardcoding them, since
# the exact ARN path (e.g. service-role/ vs. root) varies between policies
# and is easy to get wrong.
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

# Create the IAM role assumed by the EKS control plane.
resource "aws_iam_role" "cluster" {
  # Use a stable and readable role name.
  name = "${local.name_prefix}-eks-cluster-role"

  # Allow only the EKS service to assume this role.
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
    local.common_tags,
    {
      Name = "${local.name_prefix}-eks-cluster-role"
      Role = "eks-cluster"
    }
  )
}

# Attach the AWS-managed permissions required by the EKS control plane.
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  # Attach the policy to the EKS control-plane role.
  role = aws_iam_role.cluster.name

  # Use AWS managed permissions for standard EKS clusters.
  policy_arn = data.aws_iam_policy.eks_cluster_policy.arn
}

# Create the IAM role assumed by EC2 instances in the managed node group.
resource "aws_iam_role" "node" {
  # Use a stable and readable role name.
  name = "${local.name_prefix}-eks-node-role"

  # Allow only EC2 instances to assume this role.
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
    local.common_tags,
    {
      Name = "${local.name_prefix}-eks-node-role"
      Role = "eks-node"
    }
  )
}

# Allow worker nodes to connect and register with the EKS cluster.
resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  # Attach the policy to the managed node role.
  role = aws_iam_role.node.name

  # Use the AWS-managed worker-node policy.
  policy_arn = data.aws_iam_policy.eks_worker_node_policy.arn
}

# Allow worker nodes to pull private container images from Amazon ECR.
resource "aws_iam_role_policy_attachment" "node_ecr_pull_policy" {
  # Attach the policy to the managed node role.
  role = aws_iam_role.node.name

  # Grant only the ECR image-pull permissions required by the nodes.
  policy_arn = data.aws_iam_policy.ec2_container_registry_pull_only.arn
}

# Keep CNI permissions on nodes only when IRSA is explicitly disabled.
resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  # Do not attach this broad policy when the dedicated IRSA role exists.
  count = var.enable_irsa ? 0 : 1

  role = aws_iam_role.node.name

  policy_arn = data.aws_iam_policy.eks_cni_policy.arn
}