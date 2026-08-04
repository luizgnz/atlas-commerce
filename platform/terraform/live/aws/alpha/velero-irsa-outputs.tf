output "velero_role_arn" {
  description = "IAM role ARN used by Velero in the development EKS cluster."
  value       = module.eks.velero_role_arn
}