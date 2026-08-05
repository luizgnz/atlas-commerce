# -----------------------------------------------------------------------------
# Root / shared variables (from live/aws/alpha/variables.tf)
# -----------------------------------------------------------------------------

# Define the AWS region where Atlas resources will be created.
variable "aws_region" {
  description = "AWS region where Atlas development resources will be created."
  type        = string
  default     = "eu-central-1"
}

# Define the project name used for names and tags.
variable "project" {
  description = "Project name used for resource names and tags."
  type        = string
  default     = "atlas-commerce"
}

# Define the environment name used for names and tags.
variable "environment" {
  description = "Environment name."
  type        = string
  default     = "alpha"
}

# Allow environment-specific tags without modifying resource code.
variable "additional_tags" {
  description = "Additional tags applied to Atlas development resources."
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Network variables (from modules/aws/network + live/aws/alpha/variables.tf)
# -----------------------------------------------------------------------------

# Define the CIDR range assigned to the development VPC.
variable "vpc_cidr" {
  description = "CIDR block assigned to the development VPC."
  type        = string
}

# Define how many Availability Zones the network will use.
variable "availability_zone_count" {
  description = "Number of Availability Zones used by the development network."
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 3
    error_message = "availability_zone_count must be between 2 and 3."
  }
}

# Define one CIDR block for each public subnet.
variable "public_subnet_cidrs" {
  description = "CIDR blocks assigned to public subnets."
  type        = list(string)
}

# Define one CIDR block for each private subnet.
variable "private_subnet_cidrs" {
  description = "CIDR blocks assigned to private subnets."
  type        = list(string)
}

# Control whether private subnets receive outbound internet access through NAT.
# Required when true: the EKS node group runs in private subnets and needs
# outbound access to pull kubelet/CNI images and register with the cluster.
# Disabling this without another egress path (e.g. VPC endpoints) leaves the
# node group unable to complete creation.
variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway for private subnet outbound internet access."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Security group variables (from modules/aws/security-groups)
# -----------------------------------------------------------------------------

# Define which IPv4 ranges may reach the public Application Load Balancer.
variable "alb_ingress_cidrs" {
  description = "IPv4 CIDR blocks allowed to reach the public ALB on ports 80 and 443."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# -----------------------------------------------------------------------------
# EKS variables (from modules/aws/eks + live/aws/alpha/eks-variables.tf)
# -----------------------------------------------------------------------------

variable "eks_cluster_name" {
  type    = string
  default = "atlas-commerce-alpha"
}

variable "eks_kubernetes_version" {
  type = string
}

variable "eks_cluster_endpoint_public_access_cidrs" {
  description = <<-EOT
    CIDRs allowed to reach the public EKS API endpoint. Leave empty (the
    default) to auto-detect the operator's current public IP via
    checkip.amazonaws.com at plan/apply time — see the eks_* locals in
    03-eks.tf. Set explicitly to pin a fixed CIDR (e.g. an office IP or VPN
    range) instead of relying on auto-detection.
  EOT
  type        = list(string)
  default     = []
}

variable "eks_node_instance_types" {
  type = list(string)
}

variable "eks_node_capacity_type" {
  type    = string
  default = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.eks_node_capacity_type)
    error_message = "eks_node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "eks_node_min_size" {
  type    = number
  default = 2
}

variable "eks_node_desired_size" {
  type    = number
  default = 2
}

variable "eks_node_max_size" {
  type    = number
  default = 3
}

variable "eks_node_disk_size_gib" {
  type    = number
  default = 20
}

# -----------------------------------------------------------------------------
# RDS PostgreSQL variables (from modules/aws/rds-postgresql + live rds-variables.tf)
# -----------------------------------------------------------------------------

variable "rds_identifier" {
  description = "Stable identifier for the development PostgreSQL RDS instance."
  type        = string
  default     = "atlas-commerce-alpha-postgresql"
}

variable "rds_engine_version" {
  description = "Exact PostgreSQL engine version supported in the selected AWS Region."
  type        = string
}

variable "rds_instance_class" {
  description = "RDS instance class for development."
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_allocated_storage_gib" {
  description = "Initial gp3 storage allocated to RDS in GiB."
  type        = number
  default     = 20
}

variable "rds_master_username" {
  description = "RDS master username. AWS manages its password in Secrets Manager."
  type        = string
  default     = "atlas_admin"
}

variable "rds_backup_retention_period_days" {
  description = "Number of days to retain automated RDS backups."
  type        = number
  default     = 7

  validation {
    condition     = var.rds_backup_retention_period_days >= 0 && var.rds_backup_retention_period_days <= 35
    error_message = "rds_backup_retention_period_days must be between 0 and 35."
  }
}

variable "rds_multi_az" {
  description = "Whether RDS uses a standby instance in another Availability Zone."
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "Whether accidental deletion of the RDS instance is blocked."
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Whether Terraform skips the final snapshot when destroying alpha RDS."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# ElastiCache Redis variables (from modules/aws/elasticache-redis + live redis-variables.tf)
# -----------------------------------------------------------------------------

variable "redis_replication_group_id" {
  description = "Stable identifier for the development ElastiCache Redis replication group."
  type        = string
  default     = "atlas-commerce-alpha-redis"
}

variable "redis_engine_version" {
  description = "Redis OSS engine version selected for ElastiCache in eu-central-1."
  type        = string
}

variable "redis_node_type" {
  description = "ElastiCache node type for the development Redis replication group."
  type        = string
  default     = "cache.t4g.micro"
}

variable "redis_port" {
  description = "Redis listener port."
  type        = number
  default     = 6379

  validation {
    condition     = var.redis_port > 0 && var.redis_port <= 65535
    error_message = "redis_port must be between 1 and 65535."
  }
}

variable "redis_num_cache_clusters" {
  description = "Total Redis nodes, including the primary node."
  type        = number
  default     = 1

  validation {
    condition     = var.redis_num_cache_clusters >= 1 && var.redis_num_cache_clusters <= 6
    error_message = "redis_num_cache_clusters must be between 1 and 6."
  }
}

variable "redis_automatic_failover_enabled" {
  description = "Enable Redis automatic failover."
  type        = bool
  default     = false
}

variable "redis_multi_az_enabled" {
  description = "Enable Redis Multi-AZ placement."
  type        = bool
  default     = false
}

variable "redis_auth_token" {
  description = "Redis AUTH token. Supply later through TF_VAR_redis_auth_token, never through Git."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "redis_parameter_group_name" {
  description = "Optional ElastiCache parameter group."
  type        = string
  default     = null
  nullable    = true
}

variable "redis_snapshot_retention_limit" {
  description = "Days to retain automatic Redis snapshots."
  type        = number
  default     = 7

  validation {
    condition     = var.redis_snapshot_retention_limit >= 0 && var.redis_snapshot_retention_limit <= 35
    error_message = "redis_snapshot_retention_limit must be between 0 and 35."
  }
}

variable "redis_preferred_maintenance_window" {
  description = "Optional UTC maintenance window."
  type        = string
  default     = null
  nullable    = true
}

variable "redis_preferred_snapshot_window" {
  description = "Optional UTC snapshot window."
  type        = string
  default     = null
  nullable    = true
}

variable "redis_apply_immediately" {
  description = "Apply Redis changes immediately in development."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# ECR variables (from modules/aws/ecr + live ecr-variables.tf)
# -----------------------------------------------------------------------------

variable "repository_prefix" {
  description = "Namespace placed before each ECR repository name."
  type        = string
  default     = "atlas-commerce"
}

variable "repository_names" {
  description = "Names of the ECR repositories to create."
  type        = set(string)
}

variable "scan_on_push" {
  type    = bool
  default = true
}

variable "image_tag_mutability" {
  type    = string
  default = "IMMUTABLE"

  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be IMMUTABLE or MUTABLE."
  }
}

variable "max_tagged_images" {
  type    = number
  default = 20
}

variable "untagged_image_expiration_days" {
  type    = number
  default = 7
}

# -----------------------------------------------------------------------------
# GitHub Actions IAM variables (from modules/aws/iam + live ecr-variables.tf)
# -----------------------------------------------------------------------------

variable "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider created by bootstrap/gh-actions-oidc (output oidc_provider_arn). AWS allows only one OIDC provider per issuer URL per account, so this is passed in rather than created here."
  type        = string
}

variable "github_repositories" {
  description = <<-EOT
    GitHub repositories allowed to assume the GitHub Actions IAM roles. `name`
    is "owner/repo". `owner_id` and `repo_id` are the immutable GitHub numeric
    IDs used in the OIDC `sub` claim (repo:owner@OWNER_ID/repo@REPO_ID:...).
    Both legacy and immutable `sub` patterns are trusted when IDs are set.
  EOT
  type = list(object({
    name     = string
    owner_id = optional(string)
    repo_id  = optional(string)
  }))
  default = [
    {
      name     = "Nitros64/atlas-commerce"
      owner_id = "50177640"
      repo_id  = "1230706878"
    },
    {
      name     = "luizgnz/atlas-commerce"
      owner_id = "101154230"
      repo_id  = "1323178047"
    },
  ]
}
