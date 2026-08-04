data "aws_caller_identity" "velero_backup" {}

data "aws_region" "velero_backup" {}

module "velero_backup" {
  source = "../../../modules/aws/velero-backup"

  project     = "atlas-commerce"
  environment = "alpha"

  bucket_name = "atlas-commerce-alpha-velero-${data.aws_caller_identity.velero_backup.account_id}-${data.aws_region.velero_backup.name}"
}