run "dev_posture" {
  command = plan

  variables {
    environment                 = "dev"
    allowed_public_access_cidrs = ["203.0.113.0/24"]
  }

  assert {
    condition     = output.security.rds_multi_az == false
    error_message = "dev should not pay for Multi-AZ."
  }

  assert {
    condition     = output.security.vpc_single_nat_gateway == true
    error_message = "dev should use a single NAT gateway to control cost."
  }

  assert {
    condition     = output.security.eks_endpoint_public_access == true
    error_message = "dev is the only environment permitted a public EKS endpoint."
  }

  assert {
    condition     = output.security.verified_access_enabled == false
    error_message = "dev reaches the public endpoint directly; Verified Access is not provisioned."
  }

  assert {
    condition     = output.security.rds_storage_encrypted && output.security.rds_publicly_accessible == false
    error_message = "dev must still encrypt RDS and keep it private."
  }

  assert {
    condition     = output.security.msk_client_broker_encryption == "TLS"
    error_message = "dev MSK must still enforce TLS in transit."
  }

  assert {
    condition     = output.security.ecr_immutable_tags && output.security.ecr_scan_on_push
    error_message = "ECR immutability and scan-on-push are not negotiable, even in dev."
  }

  assert {
    condition     = output.name_prefix == "saas-dev"
    error_message = "name_prefix must be <project>-<env>."
  }

  assert {
    condition     = output.is_production == false
    error_message = "dev is not production."
  }
}

run "test_posture" {
  command = plan

  variables {
    environment = "test"
  }

  assert {
    condition     = output.security.eks_endpoint_public_access == false
    error_message = "test EKS API must be private-only."
  }

  assert {
    condition     = output.security.verified_access_enabled
    error_message = "test has a private-only endpoint, so Verified Access must front it."
  }

  assert {
    condition     = output.security.vpc_single_nat_gateway == false
    error_message = "test requires one NAT gateway per AZ."
  }

  assert {
    condition     = output.security.rds_deletion_protection && output.security.rds_multi_az
    error_message = "test RDS must be protected and Multi-AZ."
  }

  assert {
    condition     = output.security.opensearch_zone_awareness
    error_message = "test OpenSearch must be zone-aware."
  }

  assert {
    condition     = output.sizing.opensearch_instance_count >= 2
    error_message = "zone awareness requires >= 2 OpenSearch nodes."
  }
}

run "prod_posture" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = output.security.rds_backup_retention_days >= 30
    error_message = "prod RDS backup retention must be >= 30 days."
  }

  assert {
    condition     = output.security.msk_sasl_scram_enabled
    error_message = "prod MSK must enable SASL/SCRAM."
  }

  assert {
    condition     = output.sizing.msk_broker_count >= 3
    error_message = "prod MSK needs >= 3 brokers for RF=3 / min.insync.replicas=2."
  }

  assert {
    condition     = output.sizing.eks_node_min_size >= 3
    error_message = "prod needs >= 3 schedulable nodes."
  }

  assert {
    condition     = output.security.verified_access_log_trust_context
    error_message = "prod AVA logs must include trust context for forensics."
  }

  assert {
    condition     = output.common_tags.DataClass == "confidential"
    error_message = "prod data is confidential."
  }

  assert {
    condition     = output.is_production
    error_message = "prod is production."
  }
}

# Sizing overrides are cost/capacity only. A caller may shrink a prod node group
# within the invariant floor, but may not cross it -- see prod_min_size_floor.
run "sizing_override_is_honoured" {
  command = plan

  variables {
    environment = "prod"
    sizing = {
      eks_node_desired_size = 9
      rds_instance_class    = "db.m7g.2xlarge"
    }
  }

  assert {
    condition     = output.sizing.eks_node_desired_size == 9
    error_message = "caller-supplied sizing override was ignored."
  }

  assert {
    condition     = output.sizing.rds_instance_class == "db.m7g.2xlarge"
    error_message = "caller-supplied rds_instance_class override was ignored."
  }

  assert {
    condition     = output.sizing.eks_node_max_size == 20
    error_message = "un-overridden sizing keys must fall back to the environment default."
  }
}

# --- Capacity tiers ---------------------------------------------------------

run "default_tier_preserves_prod_scale" {
  command = plan

  variables {
    environment = "prod"
    # capacity_tier deliberately unset -> must reproduce the original prod size.
  }

  assert {
    condition     = output.sizing.rds_instance_class == "db.m7g.large" && output.sizing.eks_node_desired_size == 6 && output.sizing.opensearch_instance_count == 3
    error_message = "unset capacity_tier must fall back to the `scale` tier for prod (original values)."
  }
}

run "default_tier_preserves_test_growth" {
  command = plan

  variables {
    environment = "test"
  }

  assert {
    condition     = output.sizing.rds_instance_class == "db.t4g.medium" && output.sizing.eks_node_desired_size == 3
    error_message = "unset capacity_tier must fall back to the `growth` tier for test (original values)."
  }
}

run "launch_tier_is_prod_legal" {
  command = plan

  variables {
    environment   = "prod"
    capacity_tier = "launch"
  }

  assert {
    condition     = output.sizing.rds_allocated_storage == 150 && output.sizing.eks_node_desired_size == 4
    error_message = "prod on the launch tier should use the cost-optimised storage and 4 desired nodes."
  }

  assert {
    condition     = output.sizing.msk_broker_count >= 3 && output.sizing.eks_node_min_size >= 3 && output.sizing.opensearch_instance_count >= 2
    error_message = "the launch tier must stay prod-legal (>= 3 brokers, >= 3 nodes, >= 2 OpenSearch nodes)."
  }
}

run "launch_lite_tier_for_test" {
  command = plan

  variables {
    environment   = "test"
    capacity_tier = "launch_lite"
  }

  assert {
    condition     = output.sizing.msk_broker_count == 2 && output.sizing.eks_node_desired_size == 2
    error_message = "launch_lite is the leaner non-prod footprint: 2 brokers, 2 nodes."
  }

  assert {
    condition     = output.sizing.rds_instance_class == "db.t4g.medium" && output.sizing.opensearch_instance_count == 2
    error_message = "launch_lite should use the burstable RDS class and keep OpenSearch >= 2 for zone awareness."
  }
}

run "prod_rejects_launch_lite" {
  command = plan

  variables {
    environment   = "prod"
    capacity_tier = "launch_lite"
  }

  # launch_lite has 2 brokers / 2 nodes, so the prod capacity invariants must
  # reject it -- the tier ladder cannot smuggle an unsafe size into prod.
  expect_failures = [terraform_data.guardrail_invariants]
}

run "per_key_override_beats_tier" {
  command = plan

  variables {
    environment   = "prod"
    capacity_tier = "launch"
    sizing = {
      eks_node_desired_size = 5
    }
  }

  assert {
    condition     = output.sizing.eks_node_desired_size == 5
    error_message = "an explicit sizing key must win over the selected tier."
  }

  assert {
    condition     = output.sizing.rds_allocated_storage == 150
    error_message = "unset keys must still come from the launch tier."
  }
}

run "rejects_unknown_capacity_tier" {
  command = plan

  variables {
    environment   = "test"
    capacity_tier = "huge"
  }

  expect_failures = [var.capacity_tier]
}

# --- Negative cases: the invariants must actually fire ----------------------

run "dev_requires_public_cidr_allowlist" {
  command = plan

  variables {
    environment                 = "dev"
    allowed_public_access_cidrs = []
  }

  # An empty list passes variable validation; it is the guardrail precondition
  # that rejects it, because dev is the environment with a public endpoint.
  expect_failures = [terraform_data.guardrail_invariants]
}

run "world_open_cidr_is_rejected" {
  command = plan

  variables {
    environment                 = "dev"
    allowed_public_access_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.allowed_public_access_cidrs]
}

run "invalid_environment_is_rejected" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}

run "prod_sizing_floor_cannot_be_crossed" {
  command = plan

  variables {
    environment = "prod"
    sizing = {
      eks_node_min_size     = 1
      eks_node_desired_size = 1
    }
  }

  expect_failures = [terraform_data.guardrail_invariants]
}

run "node_sizing_must_be_ordered" {
  command = plan

  variables {
    environment = "test"
    sizing = {
      eks_node_min_size     = 5
      eks_node_desired_size = 2
    }
  }

  expect_failures = [terraform_data.guardrail_invariants]
}
