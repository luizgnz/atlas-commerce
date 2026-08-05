# Shared locals used across every domain file in this flattened root module.
# Domain-specific locals (per-resource Component tags, etc.) live in their
# corresponding numbered file instead of here — see 01-network.tf onward.
locals {
  # Build a consistent resource name prefix, for example atlas-commerce-alpha.
  name_prefix = "${var.project}-${var.environment}"

  # Define tags automatically applied to every Atlas resource.
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Component   = "platform"
    },
    var.additional_tags
  )
}
