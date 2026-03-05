# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "digitalis_hardened" {
  most_recent = true
  owners      = ["aws-marketplace", "679593333241", "436673215683"]

  filter {
    name   = "name"
    values = ["digitalis-hardened*"]
  }
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.digitalis_hardened.id

  availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, min(3, length(data.aws_availability_zones.available.names)))

  # Use the number of AZs that matches the subnet CIDRs
  num_azs = min(length(local.availability_zones), length(var.public_subnet_cidrs))

  # VPC and subnet IDs
  vpc_id = var.create_vpc ? aws_vpc.cluster[0].id : var.vpc_id

  public_subnet_ids = var.create_vpc ? aws_subnet.public[*].id : var.existing_subnet_ids

  # Static IP allocation within subnets (similar to Hetzner approach)
  # Servers get IPs .10, .11, .12, etc.
  # Agents get IPs .100, .101, .102, etc.
  server_private_ips = [
    for i in range(var.server_count) : cidrhost(var.public_subnet_cidrs[i % local.num_azs], 10 + floor(i / local.num_azs))
  ]

  agent_private_ips = [
    for i in range(var.agent_count) : cidrhost(var.public_subnet_cidrs[i % local.num_azs], 100 + floor(i / local.num_azs))
  ]

  # Primary server IP (first server)
  primary_server_private_ip = var.server_count > 0 ? local.server_private_ips[0] : ""

  # Common tags
  common_tags = merge(
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      "k3s-cluster"                               = var.cluster_name
      "ManagedBy"                                 = "terraform"
    },
    var.extra_tags
  )
}

# -----------------------------------------------------------------------------
# K3s Cluster Token
# -----------------------------------------------------------------------------

resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

resource "aws_vpc" "cluster" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-vpc"
  })
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "cluster" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.cluster[0].id

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-igw"
  })
}

# -----------------------------------------------------------------------------
# Public Subnets
# -----------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = var.create_vpc ? local.num_azs : 0

  vpc_id                  = aws_vpc.cluster[0].id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = var.associate_public_ip

  tags = merge(local.common_tags, {
    Name                                        = "${var.cluster_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

# -----------------------------------------------------------------------------
# Route Table for Public Subnets
# -----------------------------------------------------------------------------

resource "aws_route_table" "public" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.cluster[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cluster[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = var.create_vpc ? local.num_azs : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-sg"
  description = "Security group for k3s cluster ${var.cluster_name}"
  vpc_id      = local.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# SSH access
resource "aws_security_group_rule" "ssh" {
  count = length(var.ssh_allowed_cidrs) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_allowed_cidrs
  security_group_id = aws_security_group.cluster.id
  description       = "SSH access"
}

# k3s API access
resource "aws_security_group_rule" "k3s_api" {
  count = length(var.k3s_api_allowed_cidrs) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = var.k3s_api_allowed_cidrs
  security_group_id = aws_security_group.cluster.id
  description       = "k3s API access"
}

# NodePort services
resource "aws_security_group_rule" "nodeport" {
  count = length(var.nodeport_allowed_cidrs) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = var.nodeport_allowed_cidrs
  security_group_id = aws_security_group.cluster.id
  description       = "NodePort services"
}

# Inter-node communication (all traffic within VPC CIDR)
resource "aws_security_group_rule" "inter_node" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.cluster.id
  description       = "Inter-node communication"
}

# Allow all egress traffic
resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
  description       = "Allow all egress"
}

# Extra security group rules
resource "aws_security_group_rule" "extra" {
  count = length(var.extra_security_group_rules)

  type              = var.extra_security_group_rules[count.index].type
  from_port         = var.extra_security_group_rules[count.index].from_port
  to_port           = var.extra_security_group_rules[count.index].to_port
  protocol          = var.extra_security_group_rules[count.index].protocol
  cidr_blocks       = var.extra_security_group_rules[count.index].cidr_blocks
  security_group_id = aws_security_group.cluster.id
  description       = var.extra_security_group_rules[count.index].description
}

# -----------------------------------------------------------------------------
# IAM Role for EC2 Instances
# -----------------------------------------------------------------------------

resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "node" {
  name = "${var.cluster_name}-node-policy"
  role = aws_iam_role.node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeRegions",
          "ec2:DescribeVolumes",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ec2:DescribeVpcs",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/k3s-cluster" = var.cluster_name
          }
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.cluster_name}-node-profile"
  role = aws_iam_role.node.name

  tags = local.common_tags
}
