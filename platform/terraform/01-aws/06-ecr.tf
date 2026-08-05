# Flattened from modules/aws/ecr (repositories.tf, lifecycle.tf, locals.tf,
# variables.tf, outputs.tf).

locals {
  ecr_common_tags = merge(
    local.common_tags,
    {
      Component = "ecr"
    }
  )
}

# Create one private ECR repository for each Atlas service.
resource "aws_ecr_repository" "this" {
  for_each = var.repository_names

  # Example: atlas-commerce/auth-service.
  name = "${var.repository_prefix}/${each.value}"

  # Prevent a tag such as sha-abc123 from being overwritten.
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  # Allow terraform destroy when the repo still has images (alpha / CI tags).
  force_delete = true

  tags = merge(
    local.ecr_common_tags,
    {
      Name    = "${var.repository_prefix}/${each.value}"
      Service = each.value
    }
  )
}

# Clean old images automatically to avoid unnecessary ECR storage costs.
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after the configured number of days"

        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_expiration_days
        }

        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the configured number of SHA-tagged images"

        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = var.max_tagged_images
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}
