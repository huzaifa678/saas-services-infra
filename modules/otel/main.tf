terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

# ── ADOT EKS Add-on ──────────────────────────────────────────────────────────
resource "aws_eks_addon" "adot" {
  cluster_name             = var.cluster_name
  addon_name               = "adot"
  addon_version            = "v0.102.1-eksbuild.1"
  service_account_role_arn = var.otel_collector_irsa_role_arn
  resolve_conflicts_on_create = "OVERWRITE"
}

resource "kubectl_manifest" "otel_collector_grafana" {
  count = var.observability == "grafana" ? 1 : 0
  
  depends_on = [aws_eks_addon.adot]

  yaml_body = yamlencode({
    apiVersion = "opentelemetry.io/v1alpha1"
    kind       = "OpenTelemetryCollector"
    metadata = {
      name      = "adot-grafana"
      namespace = var.namespace
    }
    spec = {
      serviceAccount = "otel-collector"
      mode           = "deployment"
      image          = "public.ecr.aws/aws-observability/aws-otel-collector:v0.43.1"

      podAnnotations = {
        "eks.amazonaws.com/role-arn" = var.otel_collector_irsa_role_arn
      }

      config = yamlencode({
        extensions = {
          sigv4auth = {
            region  = var.region
            service = "aps"
          }
        }

        receivers = {
          otlp = {
            protocols = {
              grpc = { endpoint = "0.0.0.0:4317" }
              http = { endpoint = "0.0.0.0:4318" }
            }
          }
        }

        processors = {
          batch = {}
          resource = {
            attributes = [{
              key            = "service.name"
              from_attribute = "service.name"
              action         = "insert"
            }]
          }
        }

        exporters = {
          awsxray = { region = var.region }

          prometheusremotewrite = {
            endpoint = "${var.prometheus_endpoint}api/v1/remote_write"
            auth     = { authenticator = "sigv4auth" }
          }

          awscloudwatchlogs = {
            region          = var.region
            log_group_name  = "/saas/otel/logs"
            log_stream_name = "otel-stream"
          }
        }

        service = {
          extensions = ["sigv4auth"]
          pipelines = {
            traces = {
              receivers  = ["otlp"]
              processors = ["resource", "batch"]
              exporters  = ["awsxray"]
            }
            metrics = {
              receivers  = ["otlp"]
              processors = ["resource", "batch"]
              exporters  = ["prometheusremotewrite"]
            }
            logs = {
              receivers  = ["otlp"]
              processors = ["resource", "batch"]
              exporters  = ["awscloudwatchlogs"]
            }
          }
        }
      })
    }
  })
}

resource "kubectl_manifest" "otel_collector_elk" {
  count = var.observability == "elk" ? 1 : 0

  depends_on = [aws_eks_addon.adot]

  yaml_body = yamlencode({
    apiVersion = "opentelemetry.io/v1alpha1"
    kind       = "OpenTelemetryCollector"
    metadata = {
      name      = "adot-elk"
      namespace = var.namespace
    }
    spec = {
      mode  = "deployment"
      image = "public.ecr.aws/aws-observability/aws-otel-collector:v0.43.1"

      podAnnotations = {
        "://amazonaws.com" = var.otel_collector_irsa_role_arn
      }

      config = yamlencode({
        extensions = {
          sigv4auth = {
            region  = var.region
            service = "aps"
          }
          sigv4_os = {
            region  = var.region
            service = "es"
          }
        }

        receivers = {
          otlp = {
            protocols = {
              grpc = { endpoint = "0.0.0.0:4317" }
              http = { endpoint = "0.0.0.0:4318" }
            }
          }
        }

        processors = {
          batch = {}
          resource = {
            attributes = [
              { key = "service.name", from_attribute = "service.name", action = "insert" },
              { key = "cloud.provider", value = "aws", action = "insert" }
            ]
          }
          "transform/logs" = {
            log_statements = [{
              context = "log"
              statements = [
                "set(attributes[\"message\"], body)",
                "set(attributes[\"log.level\"], severity_text)",
                "set(attributes[\"service.name\"], resource.attributes[\"service.name\"])",
              ]
            }]
          }
        }

        exporters = {
          awsxray = { region = var.region }

          prometheusremotewrite = {
            endpoint = "${var.prometheus_endpoint}api/v1/remote_write"
            auth     = { authenticator = "sigv4auth" }
          }

          opensearch = {
            endpoint = "https://${var.opensearch_endpoint}"
            auth     = { authenticator = "sigv4_os" }
            logs_index   = "otel-logs-%%{+yyyy.MM.dd}"
            traces_index = "otel-traces-%%{+yyyy.MM.dd}"
          }
        }

        service = {
          extensions = ["sigv4auth", "sigv4_os"]
          pipelines = {
            traces = {
              receivers  = ["otlp"]
              processors = ["resource", "batch"]
              exporters  = ["awsxray", "opensearch"] # Multi-export traces
            }
            metrics = {
              receivers  = ["otlp"]
              processors = ["resource", "batch"]
              exporters  = ["prometheusremotewrite"]
            }
            logs = {
              receivers  = ["otlp"]
              processors = ["transform/logs", "batch"]
              exporters  = ["opensearch"]
            }
          }
        }
      })
    }
  })
}
