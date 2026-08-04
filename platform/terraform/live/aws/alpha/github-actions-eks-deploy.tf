# Grant the GitHub Actions EKS deploy role Kubernetes API access via EKS access
# entries (API_AND_CONFIG_MAP authentication mode on the cluster).
# Always created in alpha (create_eks_deploy_role = true). Do not gate on
# role ARN != null — that output is often (known after apply) and breaks count.

resource "aws_eks_access_entry" "github_actions_deploy" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.github_actions_iam.github_actions_eks_deploy_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions_deploy" {
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
