%{ for ns in provisioned_namespaces ~}
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${ns}
%{ endfor ~}
---
# Cluster-scoped powers the GitOps bootstrap genuinely needs when it installs the
# platform charts directly (Argo CD, AWS Load Balancer Controller, NGINX Gateway
# Fabric) — namespaces, CRDs, ClusterRoles/Bindings with bind+escalate (to install
# the controllers' own cluster roles), admission webhooks (the LB controller
# registers them) and IngressClasses (the LB controller creates `alb`). Everything
# else is namespaced, below. This is deliberately NOT cluster-admin: it cannot
# read or write workloads/secrets in arbitrary namespaces.
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
  - apiGroups: ["admissionregistration.k8s.io"]
    resources: ["validatingwebhookconfigurations", "mutatingwebhookconfigurations"]
    verbs: ["create", "get", "list", "watch", "update", "patch", "delete"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingressclasses"]
    verbs: ["create", "get", "list", "watch", "update", "patch", "delete"]
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
%{ for ns in admin_namespaces ~}
---
# Full control inside ${ns} only — the deployer installs/updates a platform chart
# here (helm needs to manage whatever the chart defines). Namespaced, so it confers
# nothing outside these explicitly enumerated install-target namespaces.
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ci-deployer
  namespace: ${ns}
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ci-deployer
  namespace: ${ns}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ci-deployer
subjects:
  - kind: Group
    name: ${deployer_group}
    apiGroup: rbac.authorization.k8s.io
%{ endfor ~}
