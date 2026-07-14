apiVersion: v1
kind: Secret
metadata:
  name: in-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    env: ${env}
stringData:
  name: in-cluster
  server: https://kubernetes.default.svc
  config: |
    {"tlsClientConfig":{"insecure":false}}
---
# App-of-ApplicationSets: the single entrypoint that installs every ApplicationSet
# (infra, platform, istio, microservices, api-gateway). Env-independent — the
# `env` dimension comes from the labelled cluster secret above, not from Git path.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: appsets
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-2"
spec:
  project: default
  source:
    repoURL: https://github.com/huzaifa678/SAAS-Continious-Delivery.git
    targetRevision: main
    path: appsets
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - ApplyOutOfSyncOnly=true
