# Flattened from modules/aws/security-groups (security-groups.tf, rules.tf,
# locals.tf, variables.tf, outputs.tf).
#
# Rules: Internet -> ALB, ALB -> EKS, EKS -> RDS, EKS -> Redis. The EKS -> RDS
# and EKS -> Redis ingress rules live in 04-rds.tf / 05-redis.tf next to the
# resources they protect (same as the original rds-postgresql /
# elasticache-redis modules).

locals {
  sg_common_tags = merge(
    local.common_tags,
    {
      Component = "security-groups"
    }
  )
}

# Create the public-facing security group for the Application Load Balancer.
resource "aws_security_group" "alb" {
  name = "${local.name_prefix}-alb-sg"

  description = "Controls inbound traffic to the Atlas Application Load Balancer."

  vpc_id = aws_vpc.main.id

  tags = merge(
    local.sg_common_tags,
    {
      Name = "${local.name_prefix}-alb-sg"
      Role = "alb"
    }
  )
}

# Create the security group assigned to EKS worker nodes and workloads.
resource "aws_security_group" "eks_nodes" {
  name = "${local.name_prefix}-eks-nodes-sg"

  description = "Controls traffic for Atlas EKS worker nodes and workloads."

  vpc_id = aws_vpc.main.id

  tags = merge(
    local.sg_common_tags,
    {
      Name = "${local.name_prefix}-eks-nodes-sg"
      Role = "eks-nodes"
    }
  )
}

# Create the security group that protects PostgreSQL databases.
resource "aws_security_group" "rds" {
  name = "${local.name_prefix}-rds-sg"

  description = "Controls access to Atlas PostgreSQL databases."

  vpc_id = aws_vpc.main.id

  tags = merge(
    local.sg_common_tags,
    {
      Name = "${local.name_prefix}-rds-sg"
      Role = "rds"
    }
  )
}

# Create the security group that protects Redis clusters.
resource "aws_security_group" "redis" {
  name = "${local.name_prefix}-redis-sg"

  description = "Controls access to Atlas Redis clusters."

  vpc_id = aws_vpc.main.id

  tags = merge(
    local.sg_common_tags,
    {
      Name = "${local.name_prefix}-redis-sg"
      Role = "redis"
    }
  )
}

# Allow HTTP traffic from approved IPv4 CIDR ranges to the public ALB.
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = toset(var.alb_ingress_cidrs)

  security_group_id = aws_security_group.alb.id

  cidr_ipv4 = each.value

  from_port = 80
  to_port   = 80

  ip_protocol = "tcp"

  description = "Allow HTTP traffic to the Atlas public ALB."
}

# Allow HTTPS traffic from approved IPv4 CIDR ranges to the public ALB.
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  for_each = toset(var.alb_ingress_cidrs)

  security_group_id = aws_security_group.alb.id

  cidr_ipv4 = each.value

  from_port = 443
  to_port   = 443

  ip_protocol = "tcp"

  description = "Allow HTTPS traffic to the Atlas public ALB."
}
