# Create the Atlas ECR repositories. There is no separate "shared" Terraform
# environment — alpha is currently the only live environment, so container
# images live here too.
module "ecr" {
  source = "../../../modules/aws/ecr"

  project     = var.project
  environment = var.environment

  repository_prefix = var.repository_prefix
  repository_names  = var.repository_names

  scan_on_push                   = var.scan_on_push
  image_tag_mutability           = var.image_tag_mutability
  max_tagged_images              = var.max_tagged_images
  untagged_image_expiration_days = var.untagged_image_expiration_days

  additional_tags = var.additional_tags
}

# Create the GitHub Actions roles used to push images to ECR and deploy to EKS.
# Reuses the OIDC provider created by bootstrap/gh-actions-oidc.
module "github_actions_iam" {
  source = "../../../modules/aws/iam"

  project     = var.project
  environment = var.environment

  github_oidc_provider_arn = var.github_oidc_provider_arn
  ecr_repository_arns      = values(module.ecr.repository_arns)
  eks_cluster_arn          = module.eks.cluster_arn

  additional_tags = var.additional_tags
}
