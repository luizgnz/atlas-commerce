# From live/aws/alpha/github-actions-eks-deploy.tf.
#
# Grant the GitHub Actions EKS deploy role Kubernetes API access via EKS
# access entries (API_AND_CONFIG_MAP authentication mode on the cluster).
# Always created in alpha (local.iam_create_eks_deploy_role = true). Do not
# gate on the role ARN != null — that output is often (known after apply)
# and breaks count.

resource "aws_eks_access_entry" "github_actions_deploy" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.github_actions_eks_deploy[0].arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions_deploy" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.github_actions_eks_deploy[0].arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [
    aws_eks_access_entry.github_actions_deploy
  ]
}
