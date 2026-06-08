locals {
  name = "${var.project}-${var.environment}"
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}

# ── VPC ───────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${local.name}-vpc" })
}

# ── Internet Gateway ──────────────────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${local.name}-igw" })
}

# ── Public subnets (one per AZ) ───────────────────────────────────────────────
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name                                  = "${local.name}-public-${count.index + 1}"
      "kubernetes.io/cluster/${local.name}" = "shared"
      "kubernetes.io/role/elb"              = "1"
    },
  )
}

# ── Route table: all traffic via IGW ─────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${local.name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Security Groups (shells — no inline rules to avoid cycles) ────────────────
# Rules are defined below as separate aws_security_group_rule resources so that
# cross-referencing SGs (ALB ↔ node, cluster ↔ node) does not create a cycle.

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "ALB: HTTP/HTTPS from internet"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${local.name}-alb-sg" })

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "eks_cluster" {
  name        = "${local.name}-eks-cluster-sg"
  description = "EKS cluster control plane"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${local.name}-eks-cluster-sg" })

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "eks_node" {
  name        = "${local.name}-eks-node-sg"
  description = "EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${local.name}-eks-node-sg" })

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "RDS MySQL: ingress from EKS nodes only"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${local.name}-rds-sg" })

  lifecycle { create_before_destroy = true }
}

# ── ALB rules ─────────────────────────────────────────────────────────────────

resource "aws_security_group_rule" "alb_ingress_http" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  description       = "HTTP from internet"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_ingress_https" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  description       = "HTTPS from internet"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_egress_nodeport" {
  security_group_id        = aws_security_group.alb.id
  type                     = "egress"
  description              = "NodePort range to EKS nodes"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_node.id
}

resource "aws_security_group_rule" "alb_egress_healthcheck" {
  security_group_id        = aws_security_group.alb.id
  type                     = "egress"
  description              = "Health checks to EKS nodes"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_node.id
}

# ── EKS cluster rules ─────────────────────────────────────────────────────────

resource "aws_security_group_rule" "cluster_ingress_from_nodes" {
  security_group_id        = aws_security_group.eks_cluster.id
  type                     = "ingress"
  description              = "API server from nodes"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_node.id
}

resource "aws_security_group_rule" "cluster_egress_all" {
  security_group_id = aws_security_group.eks_cluster.id
  type              = "egress"
  description       = "All outbound"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# ── EKS node rules ────────────────────────────────────────────────────────────

resource "aws_security_group_rule" "node_ingress_from_cluster" {
  security_group_id        = aws_security_group.eks_node.id
  type                     = "ingress"
  description              = "All from cluster control plane"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "node_ingress_self" {
  security_group_id = aws_security_group.eks_node.id
  type              = "ingress"
  description       = "Inter-node communication"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
}

resource "aws_security_group_rule" "node_ingress_kubelet" {
  security_group_id        = aws_security_group.eks_node.id
  type                     = "ingress"
  description              = "Kubelet API from cluster"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "node_ingress_nodeport_from_alb" {
  security_group_id        = aws_security_group.eks_node.id
  type                     = "ingress"
  description              = "NodePort services from ALB"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "node_ingress_pods_from_alb" {
  security_group_id        = aws_security_group.eks_node.id
  type                     = "ingress"
  description              = "Pod ports from ALB (IP target group mode)"
  from_port                = 8080
  to_port                  = 9090
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_egress_pods" {
  security_group_id        = aws_security_group.alb.id
  type                     = "egress"
  description              = "Pod ports to EKS nodes (IP target group mode)"
  from_port                = 8080
  to_port                  = 9090
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_node.id
}

resource "aws_security_group_rule" "node_egress_all" {
  security_group_id = aws_security_group.eks_node.id
  type              = "egress"
  description       = "All outbound"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# ── RDS rules ─────────────────────────────────────────────────────────────────

resource "aws_security_group_rule" "rds_ingress_mysql_node" {
  security_group_id        = aws_security_group.rds.id
  type                     = "ingress"
  description              = "MySQL from EKS node SG"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_node.id
}

resource "aws_security_group_rule" "rds_egress_all" {
  security_group_id = aws_security_group.rds.id
  type              = "egress"
  description       = "All outbound"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}


