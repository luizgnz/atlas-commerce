# Expose the VPC ID created by the network module.
output "vpc_id" {
  value = module.network.vpc_id
}

# Expose the public subnet IDs for future ALB or NAT resources.
output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

# Expose the private subnet IDs for future EKS nodes and data services.
output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

# Expose the Availability Zones selected for this environment.
output "availability_zones" {
  value = module.network.availability_zones
}

# Expose the NAT Gateway ID when NAT is enabled.
output "nat_gateway_id" {
  value = module.network.nat_gateway_id
}

# Expose the future ALB security group ID.
output "alb_security_group_id" {
  value = module.security_groups.alb_security_group_id
}

# Expose the future EKS nodes security group ID.
output "eks_nodes_security_group_id" {
  value = module.security_groups.eks_nodes_security_group_id
}

# Expose the PostgreSQL security group ID.
output "rds_security_group_id" {
  value = module.security_groups.rds_security_group_id
}

# Expose the Redis security group ID.
output "redis_security_group_id" {
  value = module.security_groups.redis_security_group_id
}

output "platform_secret_arn" {
  description = "ARN of the Atlas development platform secret."
  value       = module.secrets_manager.secret_arns["platform"]
}

output "platform_secret_name" {
  description = "Name of the Atlas development platform secret."
  value       = module.secrets_manager.secret_names["platform"]
}

output "rds_postgresql_address" {
  description = "Private DNS hostname of the Atlas development PostgreSQL RDS instance."
  value       = module.rds_postgresql.address
}

output "rds_postgresql_port" {
  description = "PostgreSQL listener port."
  value       = module.rds_postgresql.port
}

output "rds_postgresql_master_secret_arn" {
  description = "ARN of the RDS-managed master credentials secret."
  value       = module.rds_postgresql.master_user_secret_arn
}

output "redis_primary_endpoint" {
  description = "Primary endpoint hostname for Atlas managed Redis."
  value       = module.elasticache_redis.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Reader endpoint hostname for future Redis replicas."
  value       = module.elasticache_redis.reader_endpoint_address
}

output "redis_port" {
  description = "Redis listener port."
  value       = module.elasticache_redis.port
}

# Expose repository URLs for GitHub Actions and Helm values.
output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

# Expose repository ARNs for future IAM policies.
output "ecr_repository_arns" {
  value = module.ecr.repository_arns
}

output "github_actions_ecr_push_role_arn" {
  value = module.github_actions_iam.github_actions_ecr_push_role_arn
}

output "github_actions_ecr_push_role_name" {
  value = module.github_actions_iam.github_actions_ecr_push_role_name
}

output "github_actions_eks_deploy_role_arn" {
  description = "ARN of the IAM role GitHub Actions assumes for helm deploy to EKS. Set as repo variable AWS_EKS_DEPLOY_ROLE_ARN."
  value       = module.github_actions_iam.github_actions_eks_deploy_role_arn
}

output "github_actions_eks_deploy_role_name" {
  value = module.github_actions_iam.github_actions_eks_deploy_role_name
}

output "eks_cluster_name" {
  description = "EKS cluster name. Set as repo variable EKS_CLUSTER_NAME."
  value       = module.eks.cluster_name
}