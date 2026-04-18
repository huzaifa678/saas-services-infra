resource "aws_security_group" "eks_nodes" {
  name        = "${var.cluster_name}-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-nodes-sg" }
}

resource "aws_security_group" "rds_sg" {
  name   = "${var.cluster_name}-rds-sg"
  vpc_id = var.vpc_id
  tags   = { Name = "${var.cluster_name}-rds-sg" }
}

resource "aws_security_group" "redis_sg" {
  name   = "${var.cluster_name}-redis-sg"
  vpc_id = var.vpc_id
  tags   = { Name = "${var.cluster_name}-redis-sg" }
}

resource "aws_security_group" "msk_sg" {
  name   = "${var.cluster_name}-msk-sg"
  vpc_id = var.vpc_id
  tags   = { Name = "${var.cluster_name}-msk-sg" }
}

resource "aws_security_group" "opensearch_sg" {
  name   = "${var.cluster_name}-opensearch-sg"
  vpc_id = var.vpc_id
  tags   = { Name = "${var.cluster_name}-opensearch-sg" }
}

# ─── Node ↔ Control Plane ────────────────────────────────────────────────────
resource "aws_security_group_rule" "allow_node_to_control_plane" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.eks_nodes.id
  depends_on               = [aws_eks_cluster.eks_cluster]
}

resource "aws_security_group_rule" "allow_control_plane_to_nodes" {
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
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.eks_nodes.id
  depends_on               = [aws_eks_cluster.eks_cluster]
}

resource "aws_security_group_rule" "allow_node_to_core_dns_udp" {
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.eks_nodes.id
  depends_on               = [aws_eks_cluster.eks_cluster]
}

resource "aws_security_group_rule" "node_to_node_dns_tcp" {
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
}

resource "aws_security_group_rule" "node_to_node_dns_udp" {
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
}

# ─── EKS → RDS (PostgreSQL) ──────────────────────────────────────────────────
resource "aws_security_group_rule" "eks_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.rds_sg.id
}

# ─── EKS → Redis ─────────────────────────────────────────────────────────────
resource "aws_security_group_rule" "eks_to_redis" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.redis_sg.id
}

# ─── EKS → MSK (Kafka) ───────────────────────────────────────────────────────
resource "aws_security_group_rule" "eks_to_msk" {
  type                     = "ingress"
  from_port                = 9092
  to_port                  = 9096
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.msk_sg.id
}

# ─── EKS → OpenSearch ────────────────────────────────────────────────────────
resource "aws_security_group_rule" "eks_to_opensearch" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.opensearch_sg.id
}
