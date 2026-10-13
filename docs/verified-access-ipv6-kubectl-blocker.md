# AVA Connectivity Client ⟷ private EKS API — the IPv6 blocker

A field report of why `kubectl` against the **private** `saas-eks-test` API **could not
be made to work through the AWS Verified Access (AVA) Connectivity Client** from an
operator laptop — even after the client authenticated and showed "connected" — and what
to use instead.

This is the companion troubleshooting note to [verified-access-auth0.md](verified-access-auth0.md).
That doc covers standing AVA up; this one covers the access path failing from a specific
network, and the root cause is **client-side networking, not the Terraform**.

> **TL;DR** The AVA Connectivity Client requires IPv6 to connect. The operator's ISP
> (PTCL) has no native IPv6, so IPv6 was provided via a **6in4 tunnel**. The client then
> authenticated fine — but AVA handed it an **IPv6-only inner tunnel**, while the EKS API
> (and the split-DNS resolver it needs) are **IPv4-only** inside `10.0.0.0/16`. There is
> no NAT64 to bridge them, so no packet can reach the API. Nothing in the repo is
> misconfigured; the AVA `cidr`/TCP endpoint is correct. Use the **SSM port-forward via an
> EKS node** path below until a **native dual-stack IPv6** uplink is available.

---

## Symptom

The client tray showed a successful connection (`AuthComplete`, no crash), but:

```
E … memcache.go:265] couldn't get current server API group list:
  Get "https://<id>.gr7.us-east-1.eks.amazonaws.com/api?timeout=32s":
  dial tcp: lookup <id>.gr7.us-east-1.eks.amazonaws.com: i/o timeout
```

Note it is a **DNS `lookup … i/o timeout`**, not a TCP connect failure — kubectl never
reached the connect step.

---

## What was tried on the network side (and worked)

Getting the client to *connect at all* required real work, all of which succeeded:

1. **IPv6 presence.** AVA hard-requires IPv6; PTCL offers none. A **6in4 tunnel**
   (`gif0`, protocol-41) via a NetAssist broker gave the machine a global IPv6 address.
2. **Router DMZ** to the Mac so inbound protocol-41 reaches it.
3. **NetAssist client-endpoint fix.** PTCL rotates the public IPv4; the broker was
   pinned to a stale one, so replies were black-holed. Updating the broker's
   **Client IPv4** to the current WAN IP restored the tunnel (`tcpdump proto 41` then
   showed inbound packets). The AVA client authenticated after this.
4. Crucially, the IPv6 **default route** is left **off** `gif0` — the global address
   alone satisfies AVA, and keeping IPv4 as the default route avoids the slow-tunnel /
   MTU black-hole that took normal internet down.

So "connected" was genuinely achieved. It still did not yield `kubectl`.

---

## Root cause: connected ≠ routed, and the inner is IPv6-only

Diagnostics on the live tunnel (`utun4` is the AVA data-plane interface):

| Check | Result | Meaning |
|---|---|---|
| `ifconfig utun4` | only `inet6 2600:1f18:4bed:fb80::…`, **no `inet`** | tunnel inner is **IPv6-only** |
| `route -n get 10.0.4.186` | `interface: en0`, `gateway: 192.168.100.1` | API-bound packets go to the **home router**, not the tunnel |
| `netstat -rn -f inet \| grep 10.0` | *(nothing)* | **no `10.0.0.0/16` route** was installed |
| `ps … ava-openvpn` | `--route-nopull` | AVA's NetworkManager plugin owns routes; it **skipped** the v4 route |
| `sudo route add -net 10.0.0.0/16 -interface utun4` | `Network is unreachable` | macOS refuses a v4 route on an interface with **no v4 address** |
| `scutil --dns` | resolver #8/#9: `*.eks.amazonaws.com → 10.0.0.2` | AVA split-DNS points EKS lookups at the **VPC `.2` resolver** (IPv4) |
| `dig AAAA <api-fqdn>` | empty | the EKS API endpoint has **no IPv6 address** |
| `getaddrinfo(AF_INET6)` | only `::ffff:10.0.4.186` | v4-mapped, **not** a NAT64 synthesis — there is no NAT64 |
| `aws eks describe-cluster` | `ipFamily: ipv4`, `publicAccess: false` | cluster + API are **IPv4-only**, private |

Putting it together:

```
kubectl ──▶ resolve  <api-fqdn>  ──(split-DNS)──▶ 10.0.0.2   ← IPv4, in-VPC
                                                     │
                                        needs the tunnel … but
                                        utun4 is IPv6-only, no v4 route
                                                     │
                                                     ✗ i/o timeout  (this is the error)
```

Both the **DNS server** (`10.0.0.2`) and the **API ENIs** (`10.0.4.186`, `10.0.3.69`)
are IPv4 addresses reachable only through the tunnel, and the tunnel cannot carry IPv4.
Same single cause for both the DNS timeout and the (would-be) data timeout.

---

## Why the obvious fixes don't work

- **Add the IPv4 route by hand** → `Network is unreachable`: `utun4` has no IPv4 address
  to route from. AVA's own plugin hit the same wall, which is why the route is missing.
- **Assign `utun4` a fake IPv4 and force the route** → packets would leave, but AVA
  never assigned this session an IPv4 inner identity, so the server has **no reverse
  route** for replies — they are dropped.
- **Reconnect the client** → renegotiates (the inner address changed `::7002 → ::3002`)
  but comes back **IPv6-only every time**. Deterministic, not a transient.
- **Point AVA at the dual-stack IP space of nodes/pods** (make the *target* IPv6) → does
  **not** help `kubectl`: kubectl talks to the **control-plane API endpoint**, not to
  nodes/pods, and EKS does **not** expose an IPv6 control-plane endpoint even on
  `ipFamily: ipv6` clusters (that only changes pod/service networking). `ipFamily` is
  immutable, so this also means recreating the whole cluster — for a change that still
  wouldn't give the API an IPv6 address.
- **"Use TCP-level access instead"** → the endpoint is *already* TCP-level
  (`cidr_options { protocol = "tcp" }`). Every non-HTTP AVA mode (`cidr` or
  `network-interface` + TCP) goes through the **same Connectivity Client and the same
  IPv6-only inner**. The only client-free mode is the HTTP/browser endpoint, which can't
  carry the kube-apiserver (it terminates TLS — breaking client-cert/token auth and the
  SPDY/WebSocket upgrades that `exec`/`port-forward`/`watch` use).

### Why it came up IPv6-only

The machine's **only** path to the AVA endpoint is the 6in4 IPv6 tunnel (IPv6 exists
*because of* it; remove it and AVA refuses to connect). AVA negotiated an IPv6-only inner
to match that IPv6-only underlay. A clean **native dual-stack** connection is expected to
yield a **dual-stack inner** (including the IPv4 address that's missing), which is what
would actually let the tunnel carry traffic to the IPv4 API. The exotic 6in4 path
(one-family presence, MTU clamping) is what collapses the inner to v6-only.

---

## Terraform verdict: nothing to change

The AVA stack in [`modules/verified-access`](../modules/verified-access) is correct for
`kubectl`:

- `aws_verifiedaccess_endpoint` is `endpoint_type = "cidr"`, `cidr = 10.0.0.0/16`,
  `protocol = "tcp"`, port 443 — the right shape for raw-TCP kube-API access.
- SG egress to the EKS API CIDR + the `eks_api_from_ava` ingress on the cluster SG are
  both present.
- The private-only + AVA posture is deliberate: `modules/guardrails` sets
  `eks_endpoint_public_access = false` for test/prod and *requires* AVA to be on when it
  is (so there's always a human path).

No edit to the AVA module or `layers/30-edge` changes the outcome — the blocker is 100%
the client-side IPv6 underlay quality.

---

## Interim access that works today: SSM port-forward via an EKS node

Reach the private API by forwarding through a cluster node (which trivially reaches the
API) over SSM. This needs **no** AVA, tunnel, or DNS.

Prerequisites observed in this account:
- EKS nodes run the **standard** EKS AL2023 AMI → the **SSM agent is already installed**.
  They only lack the IAM permission.
- The **runner** (`saas-test-gha-runner`) runs `al2023-**minimal**`, which ships
  **without** the SSM agent, so it is **not** a usable SSM target without installing the
  agent first (and you can't SSM in to install it). Use a node, not the runner.
- `session-manager-plugin` and `kubectl` are installed locally.

```bash
# 1. Give the node-group role SSM (out-of-band; see "durable fix" below).
aws iam attach-role-policy \
  --role-name <eks-node-group-role> \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# 2. Wait ~1-2 min, confirm a node registers.
aws ssm describe-instance-information --region us-east-1 \
  --query 'InstanceInformationList[].{id:InstanceId,ping:PingStatus}' --output table

# 3. Terminal A — forward the private API to localhost:6443 through a node.
aws ssm start-session --region us-east-1 --target <node-instance-id> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["<api-fqdn>"],"portNumber":["443"],"localPortNumber":["6443"]}'

# 4. Terminal B — a kubeconfig whose server is https://localhost:6443 and whose
#    tls-server-name is the real API FQDN (so the cert still validates), with the
#    normal `aws eks get-token` auth. Then:
KUBECONFIG=~/.kube/saas-eks-test-ssm.yaml kubectl get ns
```

The node resolves `<api-fqdn>` to the private ENI IP itself, so the forward target can be
the FQDN. If `kubectl` returns a **403** (not a timeout), the tunnel is fine but your IAM
principal isn't mapped in the cluster — add an EKS **access entry** for it.

---

## Durable resolutions (pick one)

1. **Native dual-stack IPv6 uplink** — the faithful fix. With real IPv6 (not a 6in4
   broker), the AVA client should negotiate a dual-stack inner and `kubectl`-over-AVA
   works as designed. Depends on the ISP.
2. **Restricted-public test endpoint** — flip the test tier to
   `eks_endpoint_public_access = true` locked to the operator IP (as **dev** already
   does), relaxing the guardrail that limits public access to dev. kubectl then works
   over plain IPv4, no tunnel/AVA/SSM. Prod stays private. Reversible. A posture change.
3. **Keep SSM as the operator path** — make the node-group SSM permission durable in
   `modules/eks` (add `AmazonSSMManagedInstanceCore` to the node role) instead of the
   out-of-band attach above, and optionally install `amazon-ssm-agent` in the runner
   userdata so the runner is SSM-reachable too.
