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
}

variable "redis_num_cache_clusters" {
  description = "Total Redis nodes, including the primary node."
  type        = number
  default     = 1
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

variable "redis_snapshot_retention_limit" {
  description = "Days to retain automatic Redis snapshots."
  type        = number
  default     = 7
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