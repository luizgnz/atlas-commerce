# Create the private PostgreSQL RDS instance for Atlas development.
module "rds_postgresql" {
  source = "../../../modules/aws/rds-postgresql"

  project     = var.project
  environment = var.environment

  # Place RDS across the existing private subnets.
  private_subnet_ids = module.network.private_subnet_ids

  # Attach the database firewall created by the security-groups module.
  database_security_group_id = module.security_groups.rds_security_group_id

  # Allow PostgreSQL only from the EKS cluster security group.
  allowed_security_group_id = module.eks.cluster_primary_security_group_id

  # RDS instance configuration.
  identifier                   = var.rds_identifier
  engine_version               = var.rds_engine_version
  instance_class               = var.rds_instance_class
  allocated_storage_gib        = var.rds_allocated_storage_gib
  master_username              = var.rds_master_username
  backup_retention_period_days = var.rds_backup_retention_period_days
  multi_az                     = var.rds_multi_az
  deletion_protection          = var.rds_deletion_protection
  skip_final_snapshot          = var.rds_skip_final_snapshot

  additional_tags = var.additional_tags
}