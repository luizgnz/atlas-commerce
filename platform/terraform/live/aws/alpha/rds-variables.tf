variable "rds_identifier" {
  description = "Stable identifier for the development PostgreSQL RDS instance."
  type        = string
  default     = "atlas-commerce-alpha-postgresql"
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version selected for RDS."
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