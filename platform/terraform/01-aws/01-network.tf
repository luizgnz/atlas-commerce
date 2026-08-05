# Flattened from modules/aws/network (vpc.tf, subnets.tf, nat.tf, routes.tf,
# data.tf, locals.tf, variables.tf, outputs.tf).

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  # Availability Zones selected for the public/private subnets below.
  network_availability_zones = slice(
    data.aws_availability_zones.available.names,
    0,
    var.availability_zone_count
  )

  # Tags shared by every network resource in this file.
  network_common_tags = merge(
    local.common_tags,
    {
      Component = "network"
    }
  )
}

# Create the Atlas VPC.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr # Assign the private IP address range provided by the calling environment.
  enable_dns_support   = true         # Enable AWS internal DNS resolution inside the VPC.
  enable_dns_hostnames = true         # Allow AWS resources to receive DNS hostnames when applicable.

  tags = merge(
    local.network_common_tags,
    {
      Name = "${local.name_prefix}-vpc"
    }
  )
}

# Create an Internet Gateway and attach it to the VPC.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.network_common_tags,
    {
      Name = "${local.name_prefix}-igw"
    }
  )
}

# Create one public subnet in each selected Availability Zone.
resource "aws_subnet" "public" {
  count = var.availability_zone_count

  vpc_id = aws_vpc.main.id

  cidr_block = var.public_subnet_cidrs[count.index]

  availability_zone = local.network_availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = merge(
    local.network_common_tags,
    {
      # Example: atlas-commerce-alpha-public-1.
      Name = "${local.name_prefix}-public-${count.index + 1}"

      Tier = "public"

      "kubernetes.io/role/elb" = "1"
    }
  )
}

# Create one private subnet in each selected Availability Zone.
resource "aws_subnet" "private" {
  count = var.availability_zone_count

  vpc_id = aws_vpc.main.id

  cidr_block = var.private_subnet_cidrs[count.index]

  availability_zone = local.network_availability_zones[count.index]

  map_public_ip_on_launch = false

  tags = merge(
    local.network_common_tags,
    {
      # Example: atlas-commerce-alpha-private-1.
      Name = "${local.name_prefix}-private-${count.index + 1}"

      Tier = "private"

      "kubernetes.io/role/elb" = "1"
    }
  )
}

# Reserve one static public IP address for the NAT Gateway.
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  domain = "vpc"

  tags = merge(
    local.network_common_tags,
    {
      Name = "${local.name_prefix}-nat-eip"
    }
  )
}

# Create one NAT Gateway in the first public subnet.
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id

  subnet_id = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.main]

  tags = merge(
    local.network_common_tags,
    {
      Name = "${local.name_prefix}-nat"
    }
  )
}

# Add an outbound internet route to every private route table.
resource "aws_route" "private_nat_gateway" {
  count = var.enable_nat_gateway ? var.availability_zone_count : 0

  route_table_id = aws_route_table.private[count.index].id

  destination_cidr_block = "0.0.0.0/0"

  nat_gateway_id = aws_nat_gateway.main[0].id
}

# Create one route table shared by all public subnets.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    local.network_common_tags,
    {
      Name = "${local.name_prefix}-public-rt"
      Tier = "public"
    }
  )
}

# Associate every public subnet with the public route table.
resource "aws_route_table_association" "public" {
  count = var.availability_zone_count

  subnet_id = aws_subnet.public[count.index].id

  route_table_id = aws_route_table.public.id
}

# Create one private route table per Availability Zone.
resource "aws_route_table" "private" {
  count = var.availability_zone_count

  vpc_id = aws_vpc.main.id

  # No internet route here — aws_route.private_nat_gateway above adds it
  # only when NAT Gateway is enabled.

  tags = merge(
    local.network_common_tags,
    {
      Name = "${local.name_prefix}-private-${count.index + 1}-rt"
      Tier = "private"
    }
  )
}

# Associate every private subnet with its matching private route table.
resource "aws_route_table_association" "private" {
  count = var.availability_zone_count

  subnet_id = aws_subnet.private[count.index].id

  route_table_id = aws_route_table.private[count.index].id
}
