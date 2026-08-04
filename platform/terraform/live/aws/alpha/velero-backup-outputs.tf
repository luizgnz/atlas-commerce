output "velero_backup_bucket_name" {
  description = "S3 bucket used by Velero for development backups."
  value       = module.velero_backup.bucket_name
}

output "velero_backup_bucket_arn" {
  description = "S3 bucket ARN used by Velero for development backups."
  value       = module.velero_backup.bucket_arn
}