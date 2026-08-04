# Grant the GitHub Actions EKS deploy role Kubernetes API access via EKS access
# entries (API_AND_CONFIG_MAP authentication mode on the cluster).

resource "aws_eks_access_entry" "github_actions_deploy" {
  count = module.github_actions_iam.github_actions_eks_deploy_role_arn != null ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.github_actions_iam.github_actions_eks_deploy_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions_deploy" {
  count = module.github_actions_iam.github_actions_eks_deploy_role_arn != null ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.github_actions_iam.github_actions_eks_deploy_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [
    aws_eks_access_entry.github_actions_deploy
  ]
}
