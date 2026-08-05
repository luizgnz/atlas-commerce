# Flattened from modules/aws/rds-postgresql (rds.tf, network.tf, locals.tf,
# variables.tf, outputs.tf).

locals {
  rds_common_tags = merge(
    local.common_tags,
    {
      Component = "rds-postgresql"
    }
  )
}

# Create the private subnet group where RDS can place its network interfaces.
resource "aws_db_subnet_group" "main" {
  name = "${local.name_prefix}-postgresql"

  # RDS requires subnets spanning at least two Availability Zones.
  subnet_ids = [for s in aws_subnet.private : s.id]

  tags = merge(
    local.rds_common_tags,
    {
      Name = "${local.name_prefix}-postgresql"
      Role = "rds-db-subnet-group"
    }
  )

  lifecycle {
    precondition {
      # Fail early if there are not enough private subnets.
      condition     = length(aws_subnet.private) >= 2
      error_message = "RDS requires at least two private subnets in different Availability Zones."
    }
  }
}

# Allow PostgreSQL traffic only from EKS worker nodes through the cluster SG.
resource "aws_vpc_security_group_ingress_rule" "postgresql_from_eks" {
  security_group_id = aws_security_group.rds.id

  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432

  # Allow connections only from the EKS cluster primary security group.
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id

  description = "Allow PostgreSQL access from Atlas EKS managed nodes."
}

# Create the private PostgreSQL RDS instance for Atlas development.
resource "aws_db_instance" "main" {
  identifier = var.rds_identifier

  engine         = "postgres"
  engine_version = var.rds_engine_version

  instance_class = var.rds_instance_class

  allocated_storage = var.rds_allocated_storage_gib
  storage_type      = "gp3"
  storage_encrypted = true

  # No default database — Atlas databases are created later by the database
  # bootstrap process.
  db_name = null

  username                    = var.rds_master_username
  manage_master_user_password = true

  publicly_accessible = false

  db_subnet_group_name = aws_db_subnet_group.main.name

  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]

  multi_az                = var.rds_multi_az
  backup_retention_period = var.rds_backup_retention_period_days
  copy_tags_to_snapshot   = true

  deletion_protection       = var.rds_deletion_protection
  skip_final_snapshot       = var.rds_skip_final_snapshot
  final_snapshot_identifier = var.rds_skip_final_snapshot ? null : "${var.rds_identifier}-final"

  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false

  tags = merge(
    local.rds_common_tags,
    {
      Name = var.rds_identifier
      Role = "postgresql"
    }
  )
}
