apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keycloak-helm
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: keycloak
    targetRevision: "*"
    helm:
      releaseName: keycloak
      parameters:
        - name: auth.adminUser
          value: admin
        # keycloak_db_endpoint is the RDS endpoint "host:5432"; externalDatabase.host
        # must be the hostname ONLY (the port is set separately below), else keycloak
        # tries to resolve "host:5432" as a hostname (UnknownHostException).
        - name: externalDatabase.host
          value: "${split(":", keycloak_db_endpoint)[0]}"
        - name: externalDatabase.port
          value: "5432"
        - name: externalDatabase.database
          value: keycloak_db
        - name: externalDatabase.user
          value: keycloak_user
        # Bitnami deprecated its public Docker Hub catalog (Aug 2025): docker.io/
        # bitnami/keycloak:<tag> now 404s (ImagePullBackOff). Pull from the frozen
        # bitnamilegacy archive instead, which still has the historical tags.
        # NOTE: bitnamilegacy is unmaintained (no new CVE patches) — this is a
        # stopgap; the maintained path is the keycloakx addon (gitops/infra/keycloak).
        - name: image.repository
          value: bitnamilegacy/keycloak
        - name: postgresql.enabled
          value: "false"
  destination:
    server: https://kubernetes.default.svc
    namespace: keycloak
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
