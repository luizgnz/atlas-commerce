# Create the private managed Redis replication group for Atlas development.
module "elasticache_redis" {
  source = "../../../modules/aws/elasticache-redis"

  project     = var.project
  environment = var.environment

  # Place Redis inside the existing private subnets.
  private_subnet_ids = module.network.private_subnet_ids

  # Attach the dedicated Redis firewall.
  cache_security_group_id = module.security_groups.redis_security_group_id

  # Permit Redis traffic only from the EKS cluster security group.
  allowed_security_group_id = module.eks.cluster_primary_security_group_id

  # Redis replication group configuration.
  replication_group_id = var.redis_replication_group_id
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  port                 = var.redis_port

  # Development topology: one primary, no replica or Multi-AZ yet.
  num_cache_clusters         = var.redis_num_cache_clusters
  automatic_failover_enabled = var.redis_automatic_failover_enabled
  multi_az_enabled           = var.redis_multi_az_enabled

  # Optional AUTH token, supplied outside Git.
  auth_token = var.redis_auth_token

  parameter_group_name         = var.redis_parameter_group_name
  snapshot_retention_limit     = var.redis_snapshot_retention_limit
  preferred_maintenance_window = var.redis_preferred_maintenance_window
  preferred_snapshot_window    = var.redis_preferred_snapshot_window
  apply_immediately            = var.redis_apply_immediately

  additional_tags = var.additional_tags
}