# Flattened from modules/aws/velero-backup (s3.tf, locals.tf, variables.tf,
# outputs.tf) plus the live/aws/alpha wiring (velero-backup.tf).
#
# Resource collision avoidance: the module's `aws_s3_bucket.main` is renamed
# to `aws_s3_bucket.velero` (and its sibling S3 sub-resources renamed to
# match) so a future S3 bucket added elsewhere in this flat root module never
# collides with it.

data "aws_caller_identity" "velero_backup" {}

data "aws_region" "velero_backup" {}

locals {
  velero_common_tags = merge(
    local.common_tags,
    {
      Component = "velero-backup"
    }
  )

  # live/aws/alpha built this name from literal "atlas-commerce"/"alpha"
  # strings rather than var.project/var.environment — kept identical here.
  velero_bucket_name = "atlas-commerce-alpha-velero-${data.aws_caller_identity.velero_backup.account_id}-${data.aws_region.velero_backup.name}"

  # Not previously exposed as a variable — module default was 30 days.
  velero_noncurrent_version_expiration_days = 30
}

resource "aws_s3_bucket" "velero" {
  bucket = local.velero_bucket_name

  # Prevent accidental deletion of backup data.
  force_destroy = false

  tags = merge(
    local.velero_common_tags,
    {
      Name = "${local.name_prefix}-velero-backups"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "velero" {
  bucket = aws_s3_bucket.velero.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "velero" {
  bucket = aws_s3_bucket.velero.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "velero" {
  bucket = aws_s3_bucket.velero.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero" {
  bucket = aws_s3_bucket.velero.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "velero" {
  bucket = aws_s3_bucket.velero.id

  depends_on = [
    aws_s3_bucket_versioning.velero
  ]

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = local.velero_noncurrent_version_expiration_days
    }
  }
}
