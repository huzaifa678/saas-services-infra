terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
  }
}

# Resolve the IAM role behind whoever is running Terraform. With
# enable_cluster_creator_admin_permissions turned OFF, this role gets cluster
# admin through an explicit access entry instead of the bootstrap shortcut, so
# the cluster is never left without an administrator.
data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

locals {
  admin_principal_arns = toset(concat(
    var.include_caller_as_cluster_admin ? [data.aws_iam_session_context.current.issuer_arn] : [],
    var.cluster_admin_principal_arns,
  ))

  # AWS-managed cluster-scoped admin policy, attached via an access entry.
  cluster_admin_policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_entries = {
    for arn in local.admin_principal_arns : arn => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn = local.cluster_admin_policy_arn
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets

  # Endpoint posture is driven by the platform layer / guardrails. Private access
  # is always on; public access (dev only) is CIDR-scoped, never wide open.
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = var.enable_public_access
  cluster_endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Envelope-encrypt secrets with the shared CMK from 00-network (the module does
  # not create its own key).
  create_kms_key = false
  cluster_encryption_config = {
    provider_key_arn = var.kms_key_arn
    resources        = ["secrets"]
  }

  # OIDC provider for IRSA / pod identity consumers in later layers.
  enable_irsa = true

  # ── Access: the API way, no creator-admin shortcut ─────────────────────────
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = false
  access_entries                           = local.access_entries

  cluster_addons = {
    coredns = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-proxy = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    vpc-cni = {
      before_compute              = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    eks-pod-identity-agent = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      service_account_role_arn    = var.ebs_csi_role_arn
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [var.node_instance_type]

      min_size     = var.min_size
      max_size     = var.max_size
      desired_size = var.desired_size

      # The module creates the node<->control-plane security group and its rules.
      # We additionally attach the external node SG (from modules/node-security-
      # group) so the data-tier SGs, which allow that SG as their only ingress
      # source, keep working.
      vpc_security_group_ids = [var.eks_nodes_sg_id]

      # IMDSv2 required (blocks SSRF credential theft). Guardrails mandates this.
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }
    }
  }

  tags = merge(var.tags, { cluster = var.cluster_name })
}
