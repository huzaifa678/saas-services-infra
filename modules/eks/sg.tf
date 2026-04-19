resource "aws_security_group" "eks_nodes" {
  name        = "${var.cluster_name}-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow HTTPS egress to AWS services and internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow HTTP egress for package downloads"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow DNS UDP egress"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow DNS TCP egress"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow node-to-node communication within VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${var.cluster_name}-nodes-sg" }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.cluster_name}-rds-sg"
  description = "Security group for RDS PostgreSQL instances"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.cluster_name}-rds-sg" }
}

resource "aws_security_group" "redis_sg" {
  name        = "${var.cluster_name}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.cluster_name}-redis-sg" }
}

resource "aws_security_group" "msk_sg" {
  name        = "${var.cluster_name}-msk-sg"
  description = "Security group for MSK Kafka brokers"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.cluster_name}-msk-sg" }
}

resource "aws_security_group" "opensearch_sg" {
  name        = "${var.cluster_name}-opensearch-sg"
  description = "Security group for OpenSearch domain"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.cluster_name}-opensearch-sg" }
}

# ─── Node ↔ Control Plane ────────────────────────────────────────────────────
resource "aws_security_group_rule" "allow_node_to_control_plane" {
  description              = "Allow nodes to communicate with control plane API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.eks_nodes.id
  depends_on               = [aws_eks_cluster.eks_cluster]
}

resource "aws_security_group_rule" "allow_control_plane_to_nodes" {
  description              = "Allow control plane to communicate with nodes"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  depends_on               = [aws_eks_cluster.eks_cluster]
}

# ─── DNS ─────────────────────────────────────────────────────────────────────
resource "aws_security_group_rule" "allow_node_to_core_dns_tcp" {
  description              = "Allow nodes to reach CoreDNS via TCP"
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.eks_nodes.id
  depends_on               = [aws_eks_cluster.eks_cluster]
}

resource "aws_security_group_rule" "allow_node_to_core_dns_udp" {
  description              = "Allow nodes to reach CoreDNS via UDP"
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.eks_nodes.id
  depends_on               = [aws_eks_cluster.eks_cluster]
}

resource "aws_security_group_rule" "node_to_node_dns_tcp" {
  description              = "Allow node-to-node DNS resolution via TCP"
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
}

resource "aws_security_group_rule" "node_to_node_dns_udp" {
  description              = "Allow node-to-node DNS resolution via UDP"
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
}

# ─── EKS → RDS (PostgreSQL) ──────────────────────────────────────────────────
resource "aws_security_group_rule" "eks_to_rds" {
  description              = "Allow EKS nodes to connect to RDS PostgreSQL"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.rds_sg.id
}

# ─── EKS → Redis ─────────────────────────────────────────────────────────────
resource "aws_security_group_rule" "eks_to_redis" {
  description              = "Allow EKS nodes to connect to ElastiCache Redis"
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.redis_sg.id
}

# ─── EKS → MSK (Kafka) ───────────────────────────────────────────────────────
resource "aws_security_group_rule" "eks_to_msk" {
  description              = "Allow EKS nodes to connect to MSK Kafka brokers"
  type                     = "ingress"
  from_port                = 9092
  to_port                  = 9096
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.msk_sg.id
}

# ─── EKS → OpenSearch ────────────────────────────────────────────────────────
resource "aws_security_group_rule" "eks_to_opensearch" {
  description              = "Allow EKS nodes to connect to OpenSearch"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.opensearch_sg.id
}

# Zero VPN config (prod only)
resource "aws_security_group" "ssm_endpoints_sg" {
  count       = var.enable_ssm_access ? 1 : 0
  name        = "${var.cluster_name}-ssm-endpoints-sg"
  description = "Allow HTTPS from EKS nodes to SSM/SSMMessages/EC2Messages VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from EKS nodes"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-ssm-endpoints-sg" }
}
