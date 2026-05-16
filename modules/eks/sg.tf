# ─── Node ↔ Control Plane rules ──────────────────────────────────────────────
# These must live in the EKS module because they reference the cluster-managed SG,
# which only exists after aws_eks_cluster is created.

resource "aws_security_group_rule" "allow_node_to_control_plane" {
  description              = "Allow nodes to communicate with control plane API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  source_security_group_id = var.eks_nodes_sg_id
  depends_on               = [aws_eks_cluster.eks_cluster]
}

resource "aws_security_group_rule" "allow_control_plane_to_nodes" {
  description              = "Allow control plane to communicate with nodes"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = var.eks_nodes_sg_id
  source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  depends_on               = [aws_eks_cluster.eks_cluster]
}

resource "aws_security_group_rule" "allow_node_to_core_dns_tcp" {
  description              = "Allow nodes to reach CoreDNS via TCP"
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  source_security_group_id = var.eks_nodes_sg_id
  depends_on               = [aws_eks_cluster.eks_cluster]
}

resource "aws_security_group_rule" "allow_node_to_core_dns_udp" {
  description              = "Allow nodes to reach CoreDNS via UDP"
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  source_security_group_id = var.eks_nodes_sg_id
  depends_on               = [aws_eks_cluster.eks_cluster]
}
