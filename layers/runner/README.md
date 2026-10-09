# runner layer

The self-hosted GitHub Actions runner in its **own isolated VPC**, peered to the
application VPC so it can reach the **private** EKS API. Split out from `bootstrap` so
the CI identity (ECR + OIDC roles) has zero infra dependency and the runner's network
lifecycle is independent of `00-network`.

## What it stands up

| Component | Module | Purpose |
|---|---|---|
| Isolated runner VPC | `modules/runner-vpc` | Minimal VPC: 1 public + 1 private subnet, IGW, single NAT. CIDR `10.100.0.0/16` (must not overlap the app VPC's `10.0.0.0/16`). |
| Self-hosted runner | `modules/gha-runner` | AL2023 EC2 (ASG of 1, self-healing) in the private subnet. Thin instance profile: SSM + read PAT + pull the toolchain image, **no deploy rights**. |
| Peering to the app VPC | `modules/runner-peering` | VPC peering + routes both ways + a 443 ingress on the cluster SG + association of the EKS private hosted zone with the runner VPC (so the API FQDN resolves). |
| Dedicated CMK | this layer | Encrypts the runner's PAT secret and root volume. |

## Dependencies

- **`bootstrap`** → `ecr_repository_arn`, `toolchain_repository_url` (the image to pull).
- **`00-network`** → `vpc_id`, `vpc_cidr`, `private_route_table_ids` (the peer + return routes).
- **`10-platform`** → `cluster_security_group_id`, `cluster_endpoint` (443 ingress + private DNS).

## Reachability model

Humans reach the private API via AWS Verified Access; **CI reaches it via this peered
runner VPC**. The peering module wires all three requirements — the connection,
bidirectional routes, and the EKS private-hosted-zone association — plus the cluster-SG
443 ingress. If EKS named its private hosted zone differently from the API endpoint
FQDN, set `eks_private_zone_name`; to manage that DNS out-of-band, set
`associate_eks_private_zone = false`.

```bash
make apply ENV=<env> LAYER=runner

# then seed the PAT and cycle the ASG so the instance registers:
cd live/<env>/runner
aws secretsmanager put-secret-value \
  --secret-id "$(terragrunt output -raw runner_pat_secret_arn)" \
  --secret-string "<github-pat>"
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "$(terragrunt output -raw runner_asg_name)"
```
