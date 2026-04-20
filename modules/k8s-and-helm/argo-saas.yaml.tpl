apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: saas-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/huzaifa678/SAAS-Continious-Delivery.git
    targetRevision: main
    path: eks-chart
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: saas
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
