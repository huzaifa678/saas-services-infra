# VPC CNI NetworkPolicy enforcement stalls all GitOps (ArgoCD) sync

A field report of why, on a freshly bootstrapped `saas-eks-test`, **every ArgoCD
Application sat at `SYNC: Unknown`** and nothing (Karpenter, cert-manager,
external-dns, the Gateway API CRDs, microservices) ever deployed — and the full
chain of misdirections before the real cause (the **AWS VPC CNI network-policy
agent dropping cross-node ClusterIP traffic**) was found.

Companion to [verified-access-ipv6-kubectl-blocker.md](verified-access-ipv6-kubectl-blocker.md).
Everything here was diagnosed over an SSM port-forward to the private API (see that
doc for the kubeconfig).

> **TL;DR (definitive root cause).** **Cilium is the cluster CNI, and it came up in
> its default `cluster-pool` IPAM + `vxlan` tunnel mode, but the worker-node security
> group only allowed port 53 node-to-node — so every cross-node pod packet (VXLAN,
> UDP 8472) was silently dropped.** Same-node pods worked; anything cross-node
> (ArgoCD controller → repo-server/redis, cross-node CoreDNS, service mesh) timed
> out, which stalled all GitOps sync → every app `Unknown`. The fix is to allow
> Cilium's datapath between nodes (**UDP 8472 VXLAN + TCP 4240 health**) in the node
> SG — now in [`modules/node-security-group`](../modules/node-security-group/main.tf).
>
> **Mode mismatch to resolve too:** the CD repo
> ([`gitops/infra/cilium/values.yaml`](https://github.com/huzaifa678/SAAS-Continious-Delivery))
> *intends* `cni.chainingMode=aws-cni` + `routingMode=native` (Cilium **chained on
> VPC CNI** — VPC CNI gives pods real ENI IPs, Cilium does policy/Hubble/kube-proxy
> replacement, **no VXLAN**). The live cluster is running Cilium's **defaults**
> instead, because the `cilium` ArgoCD app was itself stuck `Unknown` (the stall), so
> the intended values never applied. In the intended native/chaining mode VXLAN is
> unused and cross-node rides VPC routing — but the SG rule is harmless there and
> unblocks the chicken-and-egg either way.
>
> The sections below (NetworkPolicy, CoreDNS upstream throttling) were **real
> contributing layers and earlier dead-ends** in the investigation — kept for the
> debugging trail — but the cross-node VXLAN drop is the thing that gates everything.

---

## Symptom

```
$ kubectl get applications -n argocd -o custom-columns=NAME:...,SYNC:.status.sync.status
cert-manager-staging     Unknown
external-dns-staging     Unknown
karpenter-staging        Unknown
... (all 33 apps)         Unknown
```

Per-app condition:

```
ComparisonError: Failed to load target state: failed to generate manifest for
source 1 of 1: rpc error: code = Unavailable desc = dns: A record lookup error:
lookup argocd-repo-server on 172.20.0.10:53: dial udp 172.20.0.10:53: i/o timeout
```

The error **flapped** between two forms:
- `lookup argocd-repo-server on 172.20.0.10:53: i/o timeout` (can't reach **CoreDNS**)
- `dial tcp 172.20.186.115:8081: i/o timeout` (resolved, can't reach **repo-server**)

Both are **ClusterIP reachability failures from the application-controller pod.**
The controller is on one node, repo-server on another, and the kube-dns ClusterIP
load-balances across CoreDNS pods on *both* nodes — the flapping is the tell that
**cross-node pod traffic is being dropped.**

Downstream, cert-manager and external-dns CrashLooped with:
- cert-manager: `the Gateway API CRDs do not seem to be present` (it has `enableGatewayAPI: true`)
- external-dns: sources `gateway-httproute` / `gateway-grpcroute` require the same CRDs

Those CRDs ship in an ArgoCD app that never synced — so this was a *consequence* of
the stall, not its own problem.

---

## Definitive root cause: Cilium VXLAN dropped by the node security group

The pod IPs were the tell. redis is `argocd-redis … 10.0.2.2` on node `ip-10-0-3-204`
(`10.0.3.x`) — but that node's ENIs are all in `10.0.3.x` and **none of them owns
`10.0.2.2`**. So `10.0.2.2` is **not a VPC-CNI secondary IP** — it's a **Cilium**
endpoint:

```
$ kubectl get cm cilium-config -n kube-system -o jsonpath=...
ipam=cluster-pool  routing-mode=tunnel  tunnel-protocol=vxlan  cluster-pool-cidr=10.0.0.0/8
$ cilium endpoint list    # on node 3-204
267   …  redis.TCP.6379  …  10.0.2.2   ready        # redis IS a Cilium endpoint
```

So **Cilium is the CNI**, assigning pod IPs from its own pool and routing them
**node-to-node over a VXLAN tunnel (UDP 8472)**. And the node SGs do **not** allow it:

```
# both node SGs, rules for 8472/6081:
sg-0f70f21… (saas-eks-test-nodes-sg):  []
sg-02e790… (eks-managed node SG):      []
```

A cross-node TCP probe confirmed it — a pod on node `…6-25` could not reach redis's
pod IP `10.0.2.2` on node `…3-204` (8/8 fail), while same-node worked. The node SG
only permitted **port 53** node-to-node (see the DNS-only ingress rules in
[`modules/node-security-group`](../modules/node-security-group/main.tf)), so VXLAN —
and therefore all cross-node pod traffic — was dropped. DNS "half-worked" only
because CoreDNS has a pod on each node and same-node queries didn't need the tunnel.

Everything else in this doc (NetworkPolicy, CoreDNS upstream throttling) was a
symptom or an amplifier of this: cross-node drops → ArgoCD retry loops → DNS query
storm → CoreDNS upstream throttling → the `ndots`/SRV noise. Fixing those helped the
*same-node* paths but could never fix cross-node while VXLAN was blocked.

### Fix

Immediate (allow Cilium's node-to-node datapath):
```bash
aws ec2 authorize-security-group-ingress --region us-east-1 \
  --group-id <node-sg> --protocol udp --port 8472 --source-group <node-sg>
aws ec2 authorize-security-group-ingress --region us-east-1 \
  --group-id <node-sg> --protocol tcp --port 4240 --source-group <node-sg>   # cilium-health
```

Durable (done): `modules/node-security-group` now adds self-ingress for **UDP 8472**
(VXLAN) and **TCP 4240** (cilium-health).

### The mode mismatch (resolve separately)

The CD repo intends Cilium **chained on VPC CNI**, not replacing it:

```yaml
# gitops/infra/cilium/values.yaml
kubeProxyReplacement: true
cni: { chainingMode: aws-cni }
routingMode: native
```

In that mode VPC CNI assigns pods real ENI IPs, Cilium handles policy / Hubble /
kube-proxy replacement, and there is **no VXLAN** (cross-node = VPC routing). The
live cluster is on Cilium's defaults instead because the `cilium` ArgoCD app was
stuck `Unknown` (this very stall), so `aws-cni`/native never applied — a
chicken-and-egg. The VXLAN SG rule breaks the deadlock: with it, cross-node works →
ArgoCD syncs → it can then apply the intended chaining/native Cilium (which no longer
needs VXLAN, though the rule stays harmless). Note the current `cluster-pool-cidr`
`10.0.0.0/8` also **overlaps the VPC `10.0.0.0/16`**, another reason to converge on
the intended `aws-cni` chaining mode rather than stay on Cilium-owned IPAM.

---

## Root cause (investigation layer 1 — NetworkPolicy)

> This was a real but secondary drop found early; it is **not** what gated the
> cluster (that is the Cilium VXLAN block above). Kept for the trail.

VPC CNI network-policy enforcement was **on**:

```
$ kubectl get ds aws-node -n kube-system -o jsonpath='{...containers[*].name}'
aws-node
aws-eks-nodeagent                       # <- the network-policy enforcement agent
$ kubectl set env ds/aws-node -n kube-system --list | grep NETWORK_POLICY
NETWORK_POLICY_ENFORCING_MODE=standard
```

The `aws-eks-nodeagent` drops the controller's cross-node ClusterIP traffic. ArgoCD
ships per-component NetworkPolicies (one of which restricts ingress to repo-server),
but the agent mishandles them — and, critically, it also broke traffic the policies
**don't even govern** (the controller's egress to CoreDNS in kube-system), so the
enforcement agent itself — not the policy content — is the fault.

### The decisive diagnostic (libc works, the Go resolver doesn't)

With enforcement *disabled* and a fresh busybox pod pinned to the controller's node:

```
[DNS clusterIP 172.20.0.10:53]   rc=0
[repo-server clusterIP :8081]    rc=0
nslookup argocd-repo-server...   -> 172.20.186.115     # works
```

And from **inside the controller pod itself**:

```
$ getent hosts argocd-repo-server.argocd.svc.cluster.local
172.20.186.115                                           # libc resolves fine
```

Yet the ArgoCD process (Go, static binary → pure-Go resolver, connected UDP) timed
out on the same query **100% of the time**. libc dodges the residual eBPF path; Go's
connected-UDP socket hits it. That isolates it to **residual nodeagent eBPF on the
nodes**, not CoreDNS, kube-proxy, security groups, or the service.

---

## Investigation layer 2 — CoreDNS → upstream VPC DNS throttling (amplifier)

> This is a real problem and the cache fix below is worth keeping, but it is an
> **amplifier/symptom** of the cross-node VXLAN block (the retry storms drove the
> upstream query flood), not the gating cause. Kept for the trail.

Disabling enforcement **and recycling both nodes** did **not** fix it — apps stayed
`Unknown` with the ArgoCD controller (now on a fresh node, Cilium confirmed passive,
VPC-CNI nodeagent disabled) still timing out. The error had also **moved and spread**:

```
git_ms=36588                                   # repo-server call now SUCCEEDS but takes 36s (DNS retries)
error: dial tcp: lookup argocd-redis: i/o timeout    # now REDIS lookup fails too
getent hosts argocd-repo-server -> exit code 2       # even libc resolution now fails, intermittently
```

That is **intermittent DNS for everything**, not a single blocked flow — so the cause
is CoreDNS itself. CoreDNS's own logs were conclusive:

```
[ERROR] plugin/errors: 2 github.com. A:            read udp 10.0.2.66:49347->10.0.0.2:53: i/o timeout
[ERROR] plugin/errors: 2 github.com.ec2.internal. A: read udp ...->10.0.0.2:53: i/o timeout
[ERROR] plugin/errors: 2 _grpclb._tcp.argocd-repo-server. SRV: read udp ...->10.0.0.2:53: i/o timeout
```

**CoreDNS cannot reliably reach the upstream VPC DNS resolver `10.0.0.2:53`** (the
VPC "+2" Route53 Resolver). Why it saturates:

- `ndots:5` (the pod default) means every short name is first tried with each search
  domain — including `…​.ec2.internal` (from the VPC DHCP option set) — so one lookup
  becomes several upstream queries.
- gRPC adds `_grpclb._tcp.<svc>` **SRV** lookups on top.
- **Both CoreDNS replicas were scheduled on the same node** (`ip-10-0-3-204`), so this
  whole amplified flood egresses a **single ENI** and hits the **VPC Route53 Resolver
  limit of 1024 packets/sec per ENI** → `i/o timeout`.

Consequences that read as unrelated bugs:
- repo-server "failed to get repo objects" = it couldn't resolve **github.com** to clone.
- controller "lookup argocd-repo-server / argocd-redis i/o timeout" = search-permutation
  queries to upstream were throttled.
- 30s+ latencies = libc/Go retry loops over the 5s DNS timeout.
- The cluster "half worked" (some lookups succeeded) because it was **throttled, not
  blocked** — which is exactly why it looked like flaky networking for so long.

### Fix

Immediate (spread the upstream load off one ENI):
```bash
kubectl -n kube-system scale deploy coredns --replicas=4   # lands across nodes (soft anti-affinity)
```

Durable:
1. **NodeLocal DNSCache** — per-node DNS cache; collapses the upstream query flood and
   also sidesteps the ClusterIP conntrack race. The canonical EKS fix for this.
2. **Reduce `ndots`** on chatty workloads (ArgoCD especially) via pod `dnsConfig`
   `options: [{name: ndots, value: "2"}]` — kills the `.ec2.internal` / search fan-out.
3. **Spread CoreDNS durably** in the `coredns` EKS addon config (`modules/eks`):
   higher `replicaCount` + topology-spread so both replicas never co-locate. The addon
   is `resolve_conflicts = OVERWRITE`, so a bare `kubectl scale` is reverted on the next
   10-platform apply — the replica count / spread must live in the addon config.

> Lesson: the whole NetworkPolicy/Cilium/node-recycle chase below was treating a
> *symptom*. When "DNS works via `getent` but a process times out" and the error
> **spreads to multiple services and flaps**, look at **CoreDNS → upstream** (its logs)
> early, not at NetworkPolicy. The VPC-CNI enforcement fix is still correct and kept,
> but it was never going to resolve this on its own.

---

## What was ruled out (and why each looked plausible)

| Suspected | Why it looked right | Why it wasn't |
|---|---|---|
| ArgoCD DNS to repo-server | first error was a DNS timeout | CoreDNS/CNI/nodes all healthy; it flapped to a TCP error too |
| ArgoCD's own NetworkPolicies | repo-server ingress policy under enforcement | deleting all argocd netpols didn't fix it; controller→CoreDNS isn't governed by them |
| Sync-wave ordering (CRDs before cert-manager) | cert-manager crashed on missing Gateway CRDs | real, but downstream — nothing synced at all |
| Stale `AWS_DEPLOY_ROLE_ARN` | there *was* a 401 earlier (separate issue, see below) | fixed separately; this stall is post-auth |
| Agent version too old | old default was CNI v1.22.4 / agent v1.4.0 | upgrading to v1.23.2 / agent v1.4.3 (newest for 1.32) still dropped traffic |
| Disabling enforcement via env | `ENABLE_NETWORK_POLICY=false` + aws-node roll | env stops *new* enforcement; does **not** unload eBPF already attached → needs a node restart |
| Residual nodeagent eBPF / node recycle | fresh node = clean datapath | recycled both nodes; controller on a fresh node still timed out → not eBPF residue |
| Cilium (second CNI layer) | `cilium`/`cilium-envoy` DS running, no CNI chaining | `cilium endpoint list` shows none of the argocd/coredns pods; `cilium monitor` saw 0 drops → passive, not in their datapath |

---

## Resolution

> The **primary cure is the CoreDNS/upstream fix** in "The actual root cause" above
> (spread CoreDNS, NodeLocal DNSCache, lower `ndots`). The NetworkPolicy steps below
> are still correct and kept — they removed a genuine secondary drop and are the right
> resting state — but on their own they do not resolve the stall.

1. **Disable NetworkPolicy enforcement** on the VPC CNI (durable), in
   [`modules/eks/main.tf`](../modules/eks/main.tf) `cluster_addons.vpc-cni`:
   ```hcl
   addon_version = "v1.23.2-eksbuild.3"            # keep the CNI current
   configuration_values = jsonencode({ enableNetworkPolicy = "false" })
   ```
   Immediate equivalent on the live cluster:
   `kubectl set env ds/aws-node -n kube-system ENABLE_NETWORK_POLICY=false`.

2. **Recycle the nodes** so the already-attached nodeagent eBPF is gone (the env
   change alone does not remove it):
   ```bash
   aws autoscaling start-instance-refresh \
     --auto-scaling-group-name <node-group-asg> --region us-east-1 \
     --preferences '{"MinHealthyPercentage":50,"InstanceWarmup":120}'
   ```

3. **Stop ArgoCD shipping its own NetworkPolicies** (hygiene; harmless with
   enforcement off) — [`modules/k8s-and-helm/argocd.tf`](../modules/k8s-and-helm/argocd.tf)
   `helm_release.argocd` values: `global.networkPolicy.create = false`.

After fresh nodes: controller reaches repo-server → apps leave `Unknown` → the
Gateway API CRDs app syncs → cert-manager and external-dns self-heal.

> If network segmentation is wanted later, enforce it with a CNI that does it
> reliably (the repo already carries a `cilium` app) rather than the VPC CNI agent.
> VPC CNI enforcement + Cilium policy would be redundant anyway.

---

## Adjacent issues hit during the same bring-up (distinct fixes)

These surfaced while chasing the above and are documented so they aren't re-confused
with it:

- **50-addons 401 `the server has asked for the client to provide credentials`** —
  the GitHub Actions deploy secret `AWS_DEPLOY_ROLE_ARN` pointed at a stale role
  (`github-actions-terraform`) not in the cluster access entries. Fixed by pointing
  it at `saas-test-gha-tf-apply` (which 45-rbac maps to `saas:ci-deployers`).
- **50-addons 403 `iam:PassRole` on the OTel collector role** and **10-platform 403
  `iam:GetRole`/`iam:GetPolicy`** — `tf-apply` has `PowerUserAccess`, which excludes
  all `iam:*`. The platform layers create/manage IAM (EKS cluster/node roles, every
  IRSA role, Karpenter instance profile), so `tf-apply` was given `IAMFullAccess`
  in [`modules/gha-oidc/main.tf`](../modules/gha-oidc/main.tf).
- **ADOT addon `version not supported`** — the version was hardcoded; now resolved
  from the cluster's k8s version via `data.aws_eks_addon_version` in
  [`modules/otel/main.tf`](../modules/otel/main.tf).
- **S3 state locks slow to clear** — the backend uses S3 native locking
  (`use_lockfile = true`), so a stale lock is just an object; delete it directly
  (`aws s3 rm s3://<state-bucket>/<env>/<layer>/terraform.tfstate.tflock`) instead of
  the slow `terragrunt force-unlock` (which re-inits providers first).
