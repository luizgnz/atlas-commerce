# Define the AWS region where development resources will be created.
variable "aws_region" {
  description = "AWS region where Atlas development resources will be created."
  type        = string
  default     = "eu-central-1"
}

# Define the project name used for names and tags.
variable "project" {
  description = "Project name used for resource names and tags."
  type        = string
  default     = "atlas-commerce"
}

# Define the environment name used for names and tags.
variable "environment" {
  description = "Environment name."
  type        = string
  default     = "alpha"
}

# Define the CIDR range assigned to the development VPC.
variable "vpc_cidr" {
  description = "CIDR block assigned to the development VPC."
  type        = string
}

# Define how many Availability Zones the network module will use.
variable "availability_zone_count" {
  description = "Number of Availability Zones used by the development network."
  type        = number
  default     = 2
}

# Define one CIDR block for each public subnet.
variable "public_subnet_cidrs" {
  description = "CIDR blocks assigned to public subnets."
  type        = list(string)
}

# Define one CIDR block for each private subnet.
variable "private_subnet_cidrs" {
  description = "CIDR blocks assigned to private subnets."
  type        = list(string)
}

# Control whether private subnets receive outbound internet access through NAT.
# Required when true: the EKS node group runs in private subnets and needs
# outbound access to pull kubelet/CNI images and register with the cluster.
# Disabling this without another egress path (e.g. VPC endpoints) leaves the
# node group unable to complete creation.
variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway for private subnet outbound internet access."
  type        = bool
  default     = true
}

# Allow environment-specific tags without modifying module code.
variable "additional_tags" {
  description = "Additional tags applied to Atlas development resources."
  type        = map(string)
  default     = {}
}


# Define which IPv4 ranges may reach the public Application Load Balancer.
variable "alb_ingress_cidrs" {
  description = "IPv4 CIDR blocks allowed to reach the public ALB on ports 80 and 443."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}


