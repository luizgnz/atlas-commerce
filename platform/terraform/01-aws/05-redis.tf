# Flattened from modules/aws/elasticache-redis (redis.tf, network.tf,
# locals.tf, variables.tf, outputs.tf).

locals {
  redis_common_tags = merge(
    local.common_tags,
    {
      Component = "elasticache-redis"
    }
  )
}

# Create the private subnet group where ElastiCache can place Redis nodes.
resource "aws_elasticache_subnet_group" "main" {
  name = "${local.name_prefix}-redis"

  subnet_ids = [for s in aws_subnet.private : s.id]

  tags = merge(
    local.redis_common_tags,
    {
      Name = "${local.name_prefix}-redis"
      Role = "elasticache-subnet-group"
    }
  )

  lifecycle {
    precondition {
      # Keep two subnets available for future replicas or Multi-AZ.
      condition     = length(aws_subnet.private) >= 2
      error_message = "ElastiCache Redis requires at least two private subnets for this Atlas design."
    }
  }
}

# Allow Redis access only from the EKS cluster security group.
resource "aws_vpc_security_group_ingress_rule" "redis_from_eks" {
  security_group_id = aws_security_group.redis.id

  ip_protocol = "tcp"
  from_port   = var.redis_port
  to_port     = var.redis_port

  # Allow connections only from EKS-managed workloads.
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id

  description = "Allow Redis access from Atlas EKS managed nodes."
}

# Create a cluster-mode-disabled Redis OSS replication group for Atlas.
resource "aws_elasticache_replication_group" "main" {
  replication_group_id = var.redis_replication_group_id

  description = "Atlas Commerce managed Redis cache."

  # Terraform uses "redis" as the Redis OSS engine identifier.
  engine         = "redis"
  engine_version = var.redis_engine_version

  node_type = var.redis_node_type

  port = var.redis_port

  # One primary node in dev; future environments can add replicas.
  num_cache_clusters = var.redis_num_cache_clusters

  automatic_failover_enabled = var.redis_automatic_failover_enabled
  multi_az_enabled           = var.redis_multi_az_enabled

  subnet_group_name = aws_elasticache_subnet_group.main.name

  security_group_ids = [
    aws_security_group.redis.id
  ]

  # Encrypt cached data at rest with the ElastiCache managed key.
  at_rest_encryption_enabled = true

  # Require TLS between Atlas workloads and Redis.
  transit_encryption_enabled = true
  transit_encryption_mode    = "required"

  # Optional Redis AUTH token. Never place its value in Git or terraform.tfvars.
  auth_token = var.redis_auth_token

  parameter_group_name = var.redis_parameter_group_name

  snapshot_retention_limit = var.redis_snapshot_retention_limit

  maintenance_window = var.redis_preferred_maintenance_window
  snapshot_window    = var.redis_preferred_snapshot_window

  apply_immediately = var.redis_apply_immediately

  auto_minor_version_upgrade = true

  tags = merge(
    local.redis_common_tags,
    {
      Name = var.redis_replication_group_id
      Role = "redis"
    }
  )

  lifecycle {
    precondition {
      # Redis failover needs a primary plus at least one replica.
      condition = (
        !var.redis_automatic_failover_enabled ||
        var.redis_num_cache_clusters >= 2
      )

      error_message = "redis_automatic_failover_enabled requires at least two cache nodes."
    }

    precondition {
      # Multi-AZ only makes sense with automatic failover and replicas.
      condition = (
        !var.redis_multi_az_enabled ||
        (
          var.redis_automatic_failover_enabled &&
          var.redis_num_cache_clusters >= 2
        )
      )

      error_message = "redis_multi_az_enabled requires automatic failover and at least two cache nodes."
    }

    precondition {
      # AWS requires TLS when using Redis AUTH.
      condition = (
        var.redis_auth_token == null ||
        true # transit_encryption_enabled is always true above
      )

      error_message = "redis_auth_token requires transit encryption to be enabled."
    }
  }
}
