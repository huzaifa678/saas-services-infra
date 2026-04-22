apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: external-secrets
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  project: default
  source:
    repoURL: https://charts.external-secrets.io
    chart: external-secrets
    targetRevision: 0.9.11
    helm:
      releaseName: external-secrets
      parameters:
        - name: installCRDs
          value: "true"
        - name: serviceAccount.create
          value: "true"
        - name: serviceAccount.name
          value: external-secrets
        - name: serviceAccount.annotations.eks\.amazonaws\.com/role-arn
          value: "${external_secrets_irsa_role_arn}"
  destination:
    server: https://kubernetes.default.svc
    namespace: external-secrets
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
