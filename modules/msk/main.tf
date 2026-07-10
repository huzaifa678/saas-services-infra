terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
  }
}

locals {
  # A three-broker cluster sustains RF=3 with min.insync.replicas=2, which is the
  # smallest configuration that survives one broker loss without losing writes.
  replication_factor = min(var.number_of_broker_nodes, 3)
  min_insync         = local.replication_factor >= 3 ? 2 : 1
}

resource "aws_msk_cluster" "this" {
  cluster_name           = var.cluster_name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes
  enhanced_monitoring    = var.enhanced_monitoring

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = var.subnet_ids
    security_groups = [var.msk_sg_id]

    storage_info {
      ebs_storage_info {
        volume_size = var.broker_volume_size
      }
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.this.arn
    revision = aws_msk_configuration.this.latest_revision
  }

  # `unauthenticated = true` was previously hardcoded here, with no SASL mechanism
  # configured at all: any principal that could reach a broker port could read and
  # write every topic.
  client_authentication {
    unauthenticated = var.unauthenticated_access

    sasl {
      iam   = var.sasl_iam_enabled
      scram = var.sasl_scram_enabled
    }
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = var.kms_key_arn

    encryption_in_transit {
      client_broker = var.client_broker_encryption
      in_cluster    = var.in_cluster_encryption
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk.name
      }
    }
  }

  tags = merge(var.tags, { Name = var.cluster_name })

  lifecycle {
    precondition {
      condition     = var.unauthenticated_access == false
      error_message = "INVARIANT: MSK unauthenticated access must never be enabled."
    }

    precondition {
      condition     = var.sasl_iam_enabled || var.sasl_scram_enabled
      error_message = "INVARIANT: MSK must enable at least one SASL mechanism (IAM or SCRAM)."
    }

    precondition {
      condition     = var.client_broker_encryption == "TLS"
      error_message = "INVARIANT: MSK client-broker encryption must be TLS; PLAINTEXT and TLS_PLAINTEXT are forbidden."
    }

    precondition {
      condition     = var.number_of_broker_nodes >= length(var.subnet_ids)
      error_message = "number_of_broker_nodes must be >= the number of client subnets, and a multiple of it."
    }
  }
}

resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/${var.cluster_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_msk_configuration" "this" {
  name           = "${var.cluster_name}-config"
  kafka_versions = [var.kafka_version]

  server_properties = <<-PROPS
    auto.create.topics.enable=${var.auto_create_topics}
    default.replication.factor=${local.replication_factor}
    min.insync.replicas=${local.min_insync}
    num.partitions=${var.num_partitions}
    log.retention.hours=${var.log_retention_hours}
  PROPS

  lifecycle {
    create_before_destroy = true
  }
}
