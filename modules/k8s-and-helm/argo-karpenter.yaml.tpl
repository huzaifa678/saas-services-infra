apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: karpenter
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  project: default
  source:
    repoURL: oci://public.ecr.aws/karpenter
    chart: karpenter
    targetRevision: 1.4.0
    helm:
      releaseName: karpenter
      parameters:
        - name: settings.clusterName
          value: "${cluster_name}"
        - name: settings.interruptionQueue
          value: "${karpenter_interruption_queue_name}"
        - name: controller.resources.requests.cpu
          value: "250m"
        - name: controller.resources.requests.memory
          value: "256Mi"
        - name: controller.resources.limits.cpu
          value: "1"
        - name: controller.resources.limits.memory
          value: "1Gi"
        - name: replicas
          value: "2"
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
