# Runbook: migrate Cilium from cluster-pool/VXLAN → aws-cni chaining + native

**Why:** the live cluster is running Cilium in its **default** mode
(`ipam=cluster-pool`, `routingMode=tunnel`/VXLAN, pool `10.0.0.0/8` which **overlaps
the VPC `10.0.0.0/16`**, `kubeProxyReplacement=false`). That mode's cross-node
datapath (VXLAN/UDP 8472) does not work here and gated all GitOps sync — see
[eks-vpc-cni-networkpolicy-argocd-stall.md](eks-vpc-cni-networkpolicy-argocd-stall.md).

**Target (what the CD repo intends — `gitops/infra/cilium/values.yaml`):**

```yaml
kubeProxyReplacement: true
cni:
  chainingMode: aws-cni      # VPC CNI is primary + assigns IPs; Cilium chains on top
  exclusive: false
routingMode: native          # no VXLAN; cross-node = plain VPC routing
enableIPv4Masquerade: false  # VPC CNI handles masquerade
hubble: { enabled: true, relay: {enabled: true}, ui: {enabled: true} }
operator: { replicas: 2 }
# staging also: k8sServicePort: 443
```

In this mode pods get **real VPC-CNI ENI IPs**, cross-node is VPC routing (already
allowed by the EKS node SG's `1025-65535` self rule), there is **no VXLAN**, and the
`10.0.0.0/8` overlap is gone. That is the "Cilium + VPC CNI coexist" design.

> **This is disruptive.** Switching Cilium's IPAM/routing mode is **not** a clean
> in-place change: every pod keeps its old (cluster-pool) IP until recreated, and the
> node CNI conflist has to be rewritten. Plan a maintenance window and expect
> cluster-wide pod networking churn. The clean way is to **recreate the nodes** after
> applying the new config.

---

## Preconditions

- `kubectl` to the private API (SSM port-forward kubeconfig — see the stall doc).
- `helm` locally, and the Cilium chart (CD repo `gitops/infra/cilium`, upstream
  `cilium/cilium` **1.20.2**).
- VPC CNI (`aws-node`) is installed and healthy — it becomes the **primary** CNI /
  IPAM provider in chaining mode:
  ```bash
  kubectl -n kube-system get ds aws-node   # must be READY on every node
  ```
- The node SG already allows the Cilium ports (committed in
  `modules/node-security-group`): harmless in native mode, required only if you stay
  on VXLAN. Native mode also needs node-to-node on the pod ports — `sg-02e790…`
  already permits TCP `1025-65535` self; if pods use ports below 1025 cross-node,
  widen that rule.
- `kubeProxyReplacement: true` needs Cilium to reach the API server directly. Set
  `k8sServiceHost` to the **EKS API endpoint host** and `k8sServicePort: 443`.
  **Caveat:** kube-proxy replacement has **known limitations in aws-cni chaining
  mode**. If Cilium agents crashloop or Services misbehave after the switch, set
  `kubeProxyReplacement: false` (keep the normal `kube-proxy` DaemonSet) and
  re-evaluate — getting pods onto VPC IPs is the priority; kpr can come later.

---

## Migration

ArgoCD renders these manifests directly (no tracked helm release), and it is
currently **stalled**, so drive the switch with **helm directly** to break the
chicken-and-egg, then hand control back to ArgoCD.

### 1. Stop ArgoCD fighting the change (it's stalled anyway)

```bash
export KUBECONFIG=~/.kube/saas-eks-test-ssm.yaml
kubectl -n argocd patch application cilium-staging --type merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'   # disable auto-sync for the cilium app
```

### 2. Apply the intended Cilium config via helm

```bash
helm repo add cilium https://helm.cilium.io/ && helm repo update
API=$(aws eks describe-cluster --name saas-eks-test --region us-east-1 \
  --query 'cluster.endpoint' --output text | sed 's#https://##')

helm upgrade --install cilium cilium/cilium --version 1.20.2 -n kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="$API" --set k8sServicePort=443 \
  --set cni.chainingMode=aws-cni --set cni.exclusive=false \
  --set routingMode=native \
  --set enableIPv4Masquerade=false \
  --set operator.replicas=2 \
  --set hubble.enabled=true --set hubble.relay.enabled=true --set hubble.ui.enabled=true
```

This rewrites the CNI conflist to **chained** (`aws-cni` → `cilium`) and drops
cluster-pool/VXLAN. Existing pods keep their old IPs until step 4.

### 3. Roll Cilium + VPC CNI

```bash
kubectl -n kube-system rollout restart ds/aws-node ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=180s
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status | \
  grep -iE "Routing|KubeProxy|IPAM"   # expect Routing: Native, no Tunnel
```

### 4. Recreate the nodes (clean CNI chain + VPC pod IPs)

Fresh nodes install the chained CNI from boot and schedule pods with **VPC-CNI IPs**
— the reliable way to leave cluster-pool behind:

```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name <node-group-asg> --region us-east-1 \
  --preferences '{"MinHealthyPercentage":50,"InstanceWarmup":180}'
```

(Find the ASG: `aws eks describe-nodegroup --cluster-name saas-eks-test \
--nodegroup-name <ng> --query 'nodegroup.resources.autoScalingGroups[0].name'`.)

### 5. Verify

```bash
# pod IPs now come from node ENI subnets (VPC CNI), not a Cilium 10.0.0.0/8 pool:
kubectl get pods -A -o wide | awk '{print $7, $8}' | head
# cross-node reachability (no VXLAN):
kubectl run x --image=public.ecr.aws/docker/library/busybox:1.36 --restart=Never --rm -it \
  --overrides='{"spec":{"nodeName":"<node-A>"}}' -- \
  sh -c 'nc -w3 -z <redis-podIP-on-node-B> 6379 && echo OK || echo FAIL'
# apps leave Unknown:
kubectl get applications -n argocd -o custom-columns=SYNC:.status.sync.status --no-headers | sort | uniq -c
# no VXLAN interface / native routing:
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status | grep Routing
```

Expected: pod IPs in the node subnets, cross-node `OK`, `Routing: Network: Native`,
apps `Synced`/`OutOfSync` (not `Unknown`).

### 6. Hand control back to ArgoCD

Re-enable auto-sync; the `cilium-staging` app now matches the live state:

```bash
kubectl -n argocd patch application cilium-staging --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
```

Make sure the CD repo's `gitops/infra/cilium/values*.yaml` carries the **same**
values you helm-set here (chainingMode/routingMode/kpr + `k8sServiceHost` if kpr
stays on), so ArgoCD converges instead of reverting.

---

## Rollback

If the cluster is worse after the switch (e.g. kpr-in-chaining breakage):

```bash
helm upgrade cilium cilium/cilium --version 1.20.2 -n kube-system \
  --set kubeProxyReplacement=false --reuse-values   # drop kpr first; least invasive
```

If still bad, reinstall the previous (default) Cilium and recreate nodes. Keep the
node-SG VXLAN rule in place during rollback — it's required by the default mode.

---

## Open items to decide before running

1. **`kubeProxyReplacement` in aws-cni chaining** — officially limited. Confirm it's
   actually required (the CD repo sets it `true`); if not, run with it `false` and the
   stock `kube-proxy` for stability.
2. **CIDR hygiene** — once on VPC IPs, the `cluster-pool-cidr 10.0.0.0/8` is gone;
   remove any leftover Cilium cluster-pool config so it can't reassert.
3. **Do it via a clean re-provision instead?** Given how churned this test cluster is,
   building a fresh cluster with all committed fixes (node-SG VXLAN rule is moot in
   native mode, CoreDNS cache, enforcement off, tf-apply IAM, ADOT version,
   gateway-api-crds app, and Cilium pinned to aws-cni chaining from the start) may be
   faster and lower-risk than migrating this one in place.
