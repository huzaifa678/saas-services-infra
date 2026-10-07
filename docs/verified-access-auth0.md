# AWS Verified Access ⟷ Auth0 OIDC — setup runbook

How the private EKS API is fronted by **AWS Verified Access (AVA)** with **Auth0**
as the OIDC trust provider, and the exact steps to stand it up in an environment.

Applies to **test** and **prod** (the private-endpoint environments). **dev** has a
public, CIDR-allow-listed endpoint and no AVA plane, so none of this applies there.

---

## How it fits together

In test/prod the EKS API server has **no public endpoint**
(`eks_endpoint_public_access = false` in the guardrails security matrix). AVA is the
public front door:

```
kubectl / browser
      │  HTTPS 443 (open to 0.0.0.0/0)
      ▼
AWS Verified Access endpoint (cidr endpoint)
      │  1. redirect to Auth0 to authenticate (OIDC)
      │  2. receive claims: email, email_verified, groups
      │  3. evaluate the Cedar policy on the AVA group
      ▼  (only if the policy permits)
private EKS API ENIs (443)
```

Pieces, all created by [`modules/verified-access`](../modules/verified-access):

- **`aws_verifiedaccess_instance`** — the access plane.
- **`aws_verifiedaccess_trust_provider` (oidc)** — points at your Auth0 tenant.
- **`aws_verifiedaccess_group`** — carries the **Cedar policy**.
- **`aws_verifiedaccess_endpoint` (cidr)** — forwards :443 to the EKS API CIDR.

The layer that wires it is [`layers/30-edge`](../layers/30-edge); it is only built
when `verified_access_enabled` is true (`local.ava_enabled`).

### Where each value comes from

| Value | Source | Notes |
|---|---|---|
| OIDC **issuer** | `ava.oidc_issuer` in `live/<env>/env.hcl` | Auth0 tenant domain, **no trailing slash** |
| OIDC **client_id** | Secrets Manager `saas/<env>/auth0` | JSON `{client_id, client_secret}`, seeded out-of-band |
| OIDC **client_secret** | Secrets Manager `saas/<env>/auth0` | never in VCS or CI |
| **custom subdomain** | `ava.custom_subdomain` in `live/<env>/env.hcl` | a domain you control; NS-delegated after apply |
| **Cedar policy** | `ava_policy_document` in `live/<env>/30-edge/terragrunt.hcl` | must not be `when { true }` |
| **callback URL** | module output `oidc_redirect_uri` | known only after the first apply |

The OIDC **endpoints are derived from the issuer** by the module
([`main.tf`](../modules/verified-access/main.tf)):

- authorize → `{issuer}/authorize`
- token → `{issuer}/oauth/token`
- userinfo → `{issuer}/userinfo`
- scope → `openid profile email`

### The Cedar policy

test and prod both ship:

```cedar
permit(principal, action, resource)
when {
  context.oidc.email_verified == true &&
  context.oidc.groups.contains("platform-admins")
};
```

Authentication alone is **not** enough — the caller's token must carry a top-level
`groups` claim containing `platform-admins`.

---

## Runbook

### Phase 1 — Auth0 (first pass, UI)

1. Create a **Regular Web Application** in the Auth0 dashboard.
2. From its **Settings**, copy the **Domain**, **Client ID**, and **Client Secret**.
3. Add a **Login Action** (Flows → Login) that injects a **top-level `groups` claim**
   into both the **ID token** and **userinfo**. It must be named exactly `groups`
   (not a namespaced URL claim), or `context.oidc.groups` in Cedar won't see it, e.g.:

   ```js
   exports.onExecutePostLogin = async (event, api) => {
     const groups = event.authorization?.roles ?? [];
     api.idToken.setCustomClaim("groups", groups);
     api.accessToken.setCustomClaim("groups", groups);
   };
   ```

4. Create a **role/group `platform-admins`** and assign your operators to it.
5. Leave **Allowed Callback URLs** empty for now — you set it in Phase 3, once the
   AVA endpoint domain exists.

### Phase 2 — AWS / Terraform

6. Seed the Auth0 client credentials into Secrets Manager (per env). Example for prod:

   ```bash
   aws secretsmanager create-secret \
     --name saas/prod/auth0 \
     --secret-string '{"client_id":"<CLIENT_ID>","client_secret":"<CLIENT_SECRET>"}'
   ```

   (Use `put-secret-value` if the secret already exists.)

7. In `live/prod/env.hcl` set the real Auth0 values under `ava`:

   ```hcl
   ava = {
     oidc_issuer      = "https://<your-tenant>.<region>.auth0.com" # no trailing slash
     custom_subdomain = "eks-prod.<your-domain>"                   # a domain you control
   }
   ```

8. Apply just the edge layer:

   ```bash
   cd live/prod/30-edge && terragrunt apply
   ```

9. Capture the outputs you need next:

   ```bash
   terragrunt output oidc_redirect_uri   # -> Auth0 Allowed Callback URLs
   terragrunt output endpoint_domain     # -> kubectl server address
   terragrunt output name_servers        # -> NS delegation targets
   ```

### Phase 3 — Auth0 (second pass) + DNS

10. In the Auth0 app, add the `oidc_redirect_uri` value
    (`https://<endpoint_domain>/oauth2/idpresponse`) to **Allowed Callback URLs**.
11. Delegate the `custom_subdomain` to the AVA `name_servers` with **NS records** in
    your DNS. Until this resolves, `kubectl` hangs — see
    [`outputs.tf`](../modules/verified-access/outputs.tf).

### Phase 4 — verify

12. Point your kubeconfig's server at `endpoint_domain` and exercise it:

    ```bash
    kubectl get ns
    ```

    Complete the Auth0 login in the browser flow, then confirm a user **not** in
    `platform-admins` is denied (Cedar authorization), while an admin succeeds.

---

## Gotchas

- **The `groups` claim is the #1 failure.** Auth0 does not emit `groups` unless your
  Action adds it. If it's missing, auth "works" but Cedar denies everyone.
- **Issuer trailing slash.** Auth0's token `iss` is `https://<tenant>/` *with* a
  trailing slash, but the module appends `/authorize` directly to `oidc_issuer`, so a
  trailing slash yields `//authorize`. Keep `oidc_issuer` **without** a trailing slash.
  If AVA then rejects tokens on an `iss` mismatch, set `oidc_issuer` **with** the slash
  and pin the three endpoints explicitly via the module's `oidc_endpoint_overrides`.
- **Chicken-and-egg callback.** The Auth0 app (client_id/secret) must exist *before*
  the Terraform apply, but the callback URL can only be set *after* the apply reveals
  `endpoint_domain`. That's why Phase 1 and Phase 3 are split.
- **Credentials never in VCS/CI.** `client_id` and `client_secret` live only in
  Secrets Manager `saas/<env>/auth0`; the layer reads them at apply time. Only
  `oidc_issuer` and `custom_subdomain` are in `env.hcl`.
