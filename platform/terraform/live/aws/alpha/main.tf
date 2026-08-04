# Create the Atlas development network by calling the reusable network module.
module "network" {
  # Reference the local reusable network module.
  source = "../../../modules/aws/network"

  # Pass project and environment values used for names and tags.
  project     = var.project
  environment = var.environment

  # Pass the VPC address range for development.
  vpc_cidr = var.vpc_cidr

  # Define how many Availability Zones the network should use.
  availability_zone_count = var.availability_zone_count

  # Pass the CIDR ranges for public subnets.
  public_subnet_cidrs = var.public_subnet_cidrs

  # Pass the CIDR ranges for private subnets.
  private_subnet_cidrs = var.private_subnet_cidrs

  # Keep NAT disabled by default to avoid hourly AWS costs in development.
  enable_nat_gateway = var.enable_nat_gateway

  # Pass any environment-specific tags to the network resources.
  additional_tags = var.additional_tags
}

# Create the baseline security groups inside the development VPC.
module "security_groups" {
  # Reference the local reusable security groups module.
  source = "../../../modules/aws/security-groups"

  # Create all security groups inside the VPC returned by the network module.
  vpc_id = module.network.vpc_id

  # Pass project and environment values used for names and tags.
  project     = var.project
  environment = var.environment

  # Allow approved IPv4 ranges to reach the future public ALB.
  alb_ingress_cidrs = var.alb_ingress_cidrs

  # Reuse development-specific tags.
  additional_tags = var.additional_tags
}

