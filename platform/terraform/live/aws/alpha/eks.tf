# Define the future Atlas EKS platform.
module "eks" {
  source = "../../../modules/aws/eks"

  project     = var.project
  environment = var.environment

  cluster_name       = var.eks_cluster_name
  kubernetes_version = var.eks_kubernetes_version

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  # Keep internal EKS communication inside the VPC.
  cluster_endpoint_private_access = true

  # Allow local kubectl access, restricted to your public IP only.
  cluster_endpoint_public_access = true

  cluster_endpoint_public_access_cidrs = local.eks_cluster_endpoint_public_access_cidrs

  # Keep CloudWatch control-plane logs disabled for now to avoid extra cost.
  enabled_cluster_log_types = []

  enable_irsa = true

  node_group_name     = "default"
  node_instance_types = var.eks_node_instance_types
  node_capacity_type  = var.eks_node_capacity_type

  node_min_size      = var.eks_node_min_size
  node_desired_size  = var.eks_node_desired_size
  node_max_size      = var.eks_node_max_size
  node_disk_size_gib = var.eks_node_disk_size_gib

  additional_tags = var.additional_tags

  enable_velero_irsa       = true
  velero_backup_bucket_arn = module.velero_backup.bucket_arn
}