apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infra-${env}
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  project: default
  source:
    repoURL: https://github.com/huzaifa678/SAAS-Continious-Delivery.git
    targetRevision: main
    path: infra/overlays/${env}
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: apps-${env}
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  project: default
  source:
    repoURL: https://github.com/huzaifa678/SAAS-Continious-Delivery.git
    targetRevision: main
    path: apps
    directory:
      include: "${env}.yaml"
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
