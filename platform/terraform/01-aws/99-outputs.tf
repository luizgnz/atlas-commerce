# Merged from live/aws/alpha/outputs.tf, velero-backup-outputs.tf, and
# velero-irsa-outputs.tf, with every module.X.y reference replaced by a
# direct resource reference into the resources defined in 01-network.tf
# through 10-eks-github-access.tf.

# Expose the VPC ID.
output "vpc_id" {
  value = aws_vpc.main.id
}

# Expose the public subnet IDs for future ALB or NAT resources.
output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

# Expose the private subnet IDs for EKS nodes and data services.
output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

# Expose the Availability Zones selected for this environment.
output "availability_zones" {
  value = local.network_availability_zones
}

# Expose the NAT Gateway ID when NAT is enabled.
output "nat_gateway_id" {
  value = try(aws_nat_gateway.main[0].id, null)
}

# Expose the ALB security group ID.
output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

# Expose the EKS nodes security group ID.
output "eks_nodes_security_group_id" {
  value = aws_security_group.eks_nodes.id
}

# Expose the PostgreSQL security group ID.
output "rds_security_group_id" {
  value = aws_security_group.rds.id
}

# Expose the Redis security group ID.
output "redis_security_group_id" {
  value = aws_security_group.redis.id
}

output "platform_secret_arn" {
  description = "ARN of the Atlas development platform secret."
  value       = aws_secretsmanager_secret.this["platform"].arn
}

output "platform_secret_name" {
  description = "Name of the Atlas development platform secret."
  value       = aws_secretsmanager_secret.this["platform"].name
}

output "rds_postgresql_address" {
  description = "Private DNS hostname of the Atlas development PostgreSQL RDS instance."
  value       = aws_db_instance.main.address
}

output "rds_postgresql_port" {
  description = "PostgreSQL listener port."
  value       = aws_db_instance.main.port
}

output "rds_postgresql_master_secret_arn" {
  description = "ARN of the RDS-managed master credentials secret."
  value       = try(aws_db_instance.main.master_user_secret[0].secret_arn, null)
}

output "redis_primary_endpoint" {
  description = "Primary endpoint hostname for Atlas managed Redis."
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Reader endpoint hostname for future Redis replicas."
  value       = try(aws_elasticache_replication_group.main.reader_endpoint_address, null)
}

output "redis_port" {
  description = "Redis listener port."
  value       = aws_elasticache_replication_group.main.port
}

# Expose repository URLs for GitHub Actions and Helm values.
output "ecr_repository_urls" {
  value = {
    for service, repository in aws_ecr_repository.this :
    service => repository.repository_url
  }
}

# Expose repository ARNs for future IAM policies.
output "ecr_repository_arns" {
  value = {
    for service, repository in aws_ecr_repository.this :
    service => repository.arn
  }
}

output "github_actions_ecr_push_role_arn" {
  value = aws_iam_role.github_actions_ecr_push.arn
}

output "github_actions_ecr_push_role_name" {
  value = aws_iam_role.github_actions_ecr_push.name
}

output "github_actions_eks_deploy_role_arn" {
  description = "ARN of the IAM role GitHub Actions assumes for helm deploy to EKS. Set as repo variable AWS_EKS_DEPLOY_ROLE_ARN."
  value       = try(aws_iam_role.github_actions_eks_deploy[0].arn, null)
}

output "github_actions_eks_deploy_role_name" {
  value = try(aws_iam_role.github_actions_eks_deploy[0].name, null)
}

output "eks_cluster_name" {
  description = "EKS cluster name. Set as repo variable EKS_CLUSTER_NAME."
  value       = aws_eks_cluster.main.name
}

output "velero_backup_bucket_name" {
  description = "S3 bucket used by Velero for development backups."
  value       = aws_s3_bucket.velero.bucket
}

output "velero_backup_bucket_arn" {
  description = "S3 bucket ARN used by Velero for development backups."
  value       = aws_s3_bucket.velero.arn
}

output "velero_role_arn" {
  description = "IAM role ARN used by Velero in the development EKS cluster."
  value       = try(aws_iam_role.velero[0].arn, null)
}
