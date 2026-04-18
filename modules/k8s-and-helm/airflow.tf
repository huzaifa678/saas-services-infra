resource "helm_release" "airflow" {
  name             = "airflow"
  namespace        = "airflow"
  repository       = "https://airflow-helm.github.io/charts"
  chart            = "airflow"
  create_namespace = true
  timeout          = 600
  wait             = true

  set = [
    { name = "airflow.executor",                        value = "CeleryExecutor" },
    { name = "dags.persistence.enabled",                value = "true" },
    { name = "dags.persistence.size",                   value = "2Gi" },
    { name = "logs.persistence.enabled",                value = "true" },
    { name = "logs.persistence.size",                   value = "1Gi" },
    { name = "scheduler.logCleanup.enabled",            value = "false" },
    { name = "workers.logCleanup.enabled",              value = "false" },
    { name = "workers.replicas",                        value = "1" },
    { name = "ingress.enabled",                         value = "true" },
    { name = "ingress.className",                       value = "nginx" },
    { name = "ingress.web.hosts[0].host",               value = "airflow.local" },
    { name = "ingress.web.hosts[0].paths[0].path",      value = "/" },
    { name = "ingress.web.hosts[0].paths[0].pathType",  value = "Prefix" }
  ]

  values = [file("${path.module}/values.yaml")]

  depends_on = [
    var.eks_node_group,
    kubectl_manifest.gateway_api_crds
  ]
}
