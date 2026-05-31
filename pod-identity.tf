locals {
  pod_identity_associations = {
    cert_manager = {
      namespace = "cert-manager"
      sa_name   = "cert-manager"
      role_arn  = module.iam.cert_manager_irsa_role_arn
    }
    external_dns = {
      namespace = "external-dns"
      sa_name   = "external-dns"
      role_arn  = module.iam.external_dns_irsa_role_arn
    }
    external_secrets = {
      namespace = "external-secrets"
      sa_name   = "external-secrets"
      role_arn  = module.iam.external_secrets_irsa_role_arn
    }
    aws_lb_controller = {
      namespace = "kube-system"
      sa_name   = "aws-load-balancer-controller"
      role_arn  = module.iam.aws_lb_controller_irsa_role_arn
    }
    karpenter = {
      namespace = "kube-system"
      sa_name   = "karpenter"
      role_arn  = module.iam.karpenter_irsa_role_arn
    }
    ebs_csi_controller = {
      namespace = "kube-system"
      sa_name   = "ebs-csi-controller-sa"
      role_arn  = module.iam.ebs_csi_role_arn
    }
  }
}

resource "aws_eks_pod_identity_association" "this" {
  for_each = local.pod_identity_associations

  cluster_name    = module.eks.eks_cluster_name
  namespace       = each.value.namespace
  service_account = each.value.sa_name
  role_arn        = each.value.role_arn
}
