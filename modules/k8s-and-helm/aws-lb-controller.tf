resource "kubernetes_service_account_v1" "aws_lb_controller" {
  provider = kubernetes.eks
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.aws_lb_controller_irsa_role_arn
    }
  }
}

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  timeout    = 300
  wait       = true

  set = [
    { name = "clusterName", value = var.cluster_name },
    { name = "region", value = var.region },
    { name = "vpcId", value = var.vpc_id },
    { name = "serviceAccount.create", value = "false" },
    { name = "serviceAccount.name", value = "aws-load-balancer-controller" }
  ]

  depends_on = [
    kubernetes_service_account_v1.aws_lb_controller,
    helm_release.argocd
  ]
}
