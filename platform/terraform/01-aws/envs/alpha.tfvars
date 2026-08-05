# Deploy Atlas alpha resources in Frankfurt.
aws_region = "eu-central-1"

# Identify this Terraform environment.
project     = "atlas-commerce"
environment = "alpha"

# Reserve a dedicated private network range for the alpha VPC.
vpc_cidr = "10.20.0.0/16"

# Spread the network across two Availability Zones.
availability_zone_count = 2

# Public subnets: intended later for ALB, NAT Gateway, and public-facing components.
public_subnet_cidrs = [
  "10.20.0.0/24",
  "10.20.1.0/24"
]

# Private subnets: intended later for EKS nodes, pods, databases, and internal services.
private_subnet_cidrs = [
  "10.20.16.0/20",
  "10.20.32.0/20"
]

# Enabled: EKS node group nodes live in private subnets and need outbound
# internet access to pull kubelet/CNI images and register with the cluster.
# Costs ~$0.045/hour (~$32/month) plus data processing.
enable_nat_gateway = true

# Add environment-specific resource tags.
additional_tags = {
  Purpose = "development"
}

# EKS cluster configuration.
eks_kubernetes_version = "1.35"

# Pin for local/CI consistency. Leave unset only when you want the eks_*
# locals in 03-eks.tf to auto-detect your public IP via
# checkip.amazonaws.com (has a 10s timeout).
eks_cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

eks_node_instance_types = ["t3.medium"]

# RDS PostgreSQL configuration.
rds_engine_version = "17.10"

# ElastiCache Redis configuration.
redis_engine_version = "7.1"

# GitHub Actions OIDC provider created by ../../bootstrap/gh-actions-oidc
# (output oidc_provider_arn). Reused here for the ECR push role.
github_oidc_provider_arn = "arn:aws:iam::553337000139:oidc-provider/token.actions.githubusercontent.com"

# ECR repositories for Atlas Commerce container images.
repository_prefix = "atlas-commerce"

repository_names = [
  "api-gateway",
  "auth-service",
  "catalog-service",
  "cart-service",
  "pricing-service",
  "coupon-service",
  "order-service",
  "inventory-service",
  "payment-service",
  "shipping-service",
  "notification-service",
  "audit-service"
]

scan_on_push                   = true
image_tag_mutability           = "IMMUTABLE"
max_tagged_images              = 20
untagged_image_expiration_days = 7
