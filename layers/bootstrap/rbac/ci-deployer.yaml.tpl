apiVersion: v1
kind: Namespace
metadata:
  name: argocd
---
# Cluster-scoped powers the GitOps bootstrap genuinely needs — namespaces, CRDs,
# and ClusterRoles/Bindings with bind+escalate so it can install ArgoCD's roles.
# Everything else stays namespaced. This is deliberately NOT cluster-admin.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ci-deployer
rules:
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["create", "get", "list", "watch", "update", "patch", "delete"]
  - apiGroups: ["apiextensions.k8s.io"]
    resources: ["customresourcedefinitions"]
    verbs: ["create", "get", "list", "watch", "update", "patch", "delete"]
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["clusterroles", "clusterrolebindings"]
    verbs: ["create", "get", "list", "watch", "update", "patch", "delete", "bind", "escalate"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ci-deployer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ci-deployer
subjects:
  - kind: Group
    name: ${deployer_group} # maps to the tf-apply role via its EKS access entry
    apiGroup: rbac.authorization.k8s.io
---
# Full control inside the argocd namespace only.
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ci-deployer
  namespace: argocd
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ci-deployer
  namespace: argocd
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ci-deployer
subjects:
  - kind: Group
    name: ${deployer_group}
    apiGroup: rbac.authorization.k8s.io
