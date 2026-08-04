# Create one private ECR repository for each Atlas service.
resource "aws_ecr_repository" "this" {
  for_each = var.repository_names

  # Example: atlas-commerce/auth-service.
  name = "${var.repository_prefix}/${each.value}"

  # Prevent a tag such as sha-abc123 from being overwritten.
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    # Scan pushed images for known vulnerabilities.
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    # Use AWS-managed encryption at rest.
    encryption_type = "AES256"
  }

  # Allow terraform destroy when the repo still has images (alpha / CI tags).
  force_delete = true

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.repository_prefix}/${each.value}"
      Service = each.value
    }
  )
}