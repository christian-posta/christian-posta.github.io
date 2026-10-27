---

title: "Credential Brokering Patterns for AI Agents Part 3: Protecting the Token Vault with OpenBAO"
date: 2026-10-26T09:00:00-07:00
categories: [AI Agents, Identity]
hidden: true
sitemap: false
tags: [agentgateway, mcp, vault, openbao, credential-broker, enterprise]
description: Parts 2 and 2.5 built broker-gated envelope encryption for agentgateway's token store on AWS KMS. Lots of orgs can't or won't put that key in a hyperscaler, so here are two ways to run Mode 3 on Vault/OpenBao, side by side, what each one costs you, and how I'd pick between them.
---



![CB4A Flow](/images/cb4a/cb4a-part2.gif)


In [part 1](/credential-brokering-patterns-for-ai-agent-egress/) I looked at the [Credential Broker 4 Agents (CB4A)](https://datatracker.ietf.org/doc/html/draft-hartman-credential-broker-4-agents-00) draft and argued that the agent should never hold a credential at all, and that a proxy (in our case [agentgateway](https://agentgateway.dev)) should exchange the user's (and potentially agent's) identity for the upstream token on the live request. That means the proxy's token store holds every user's GitHub token, Slack token, etc, so in [part 2](/credential-brokering-patterns-for-ai-agent-egress-part2/) I asked how much of the store an attacker can read **when the process holding the token store is fully compromised**.

Mode 1 (KEK in a Kubernetes Secret) gives up everything, offline, forever. Mode 2 (KEK in AWS KMS) gives up everything while the attacker is live. Mode 3 (broker-gated KMS grants) gives up only what a separate broker will authorize, right now, for this user, on this row, which makes it the only one that *prevents* mass decrypt instead of just detecting it, and [part 2.5](/credential-brokering-mode-3-at-scale/) added a variant (after [Stephane Nangue](https://www.linkedin.com/in/stephane-nangue-480a2557/) pointed out that grants don't scale) where the broker does the unwrap itself. But all of it rests on AWS KMS, and a lot of the organizations that care most about credential concentration can't, or won't, put the key that guards every user's credentials in a hyperscaler's hands.

So why Vault/[OpenBao](https://openbao.org/)? Some of it is "sovereignty" and "hold your own key" buzzwords, but a few concrete reasons keep coming up.

- **Where you run.** On-prem, air-gapped, or a sovereign/regional cloud where AWS KMS isn't an option.
- **Multi-cloud.** One key service, one policy model, and one audit trail across AWS/Azure/GCP/on-prem.
- **What you already run.** A Vault/OpenBao cluster with a team, a policy review process, and an audit pipeline, which a new token store should plug into.
- **Custody.** You hold the KEK, you can read the source, and the authorization config lives in git.

I'll use OpenBao (the community fork after HashiCorp [moved Vault to the BSL](https://www.hashicorp.com/en/blog/hashicorp-adopts-business-source-license) in 2023), but almost all of it applies to Vault too.

There are two reasonable ways to do Mode 3 on OpenBao with agentgateway, either let the gateway log in to OpenBao as the user, or keep the broker from part 2 and point it at OpenBao (I'm calling that Mode 3b). I don't think either one wins outright. The vault login is simpler, but the decrypt token it hands out is scoped to the user, so a live request for one of alice's credentials opens all of them. The broker scopes it to the one row the request is for, and you pay for that with another component on the request path and per-row policy state in OpenBao.

## Who holds what, quickly

Every mode in this series comes down to who holds the key and what has to say yes before a decrypt happens. Envelope encryption is the foundation. A per-row DEK encrypts the token payload and the KEK only wraps and unwraps DEKs, so the KEK can live somewhere the controller can't reach. Mode 3 then takes the "yes" away from the controller, so reading one credential needs the ciphertext from the controller and a short-lived decrypt grant from the broker (a KMS grant scoped to that one row).


| Role                                | Holds                                                | Never holds                 |
| ----------------------------------- | ---------------------------------------------------- | --------------------------- |
| **ciphertext holder** (controller)  | the encrypted rows                                   | any decrypt path of its own |
| **user verifier + minter** (broker) | mint authority, IdP JWKS, policy, the owner-HMAC key | ciphertext, DB, DEKs        |
| **key custodian** (KMS / OpenBao)   | the KEK                                              | application data            |


The key custodian is whatever holds the KEK and does the unwrap, KMS in part 2 and OpenBao Transit here. The two designs in this post differ on who plays the "user verifier + minter role", ie, who checks the user's subject token and then issues the short-lived permission to decrypt (which I'll call the decrypt token).

In **Design 1 (vault login)** there's no broker, and OpenBao plays both the user verifier + minter role and the key custodian role. On each live request the gateway calls OpenBao's `auth/jwt/login` with the user's subject token, OpenBao verifies it against the IdP and returns the decrypt token, and the gateway passes it to the controller. Since the gateway is the only thing allowed to call that login, a decrypt token only exists while a real request is in flight.

In **Design 2 (Mode 3b, broker)** the broker from part 2 keeps the user verifier + minter role, so it checks the subject token and asks OpenBao for the decrypt token, and OpenBao only plays key custodian.

Both designs keep the ciphertext in the application database. Moving the rows into a KV mount the controller can read is a standing read on the whole store, which is the same trap as standing `kms:Decrypt` in Mode 2.

## Design 1: let the gateway log in as the user

This design starts from the fact that the broker only exists because KMS can't authenticate the end user (it only ever sees the controller's IAM role), but OpenBao's JWT auth method *can*. So let OpenBao verify the user directly, and the broker's authorize step becomes a built-in, audited, fail-closed auth mount with no custom code. [Mesut Özdil](https://github.com/moezdil) sent me this design as a [working demo](https://github.com/moezdil/openbao-credential-broker-demo) shortly after part 2, and a lot of it holds up (in a few places, e.g. token TTL, rewrap, and fail-closed audit, it's better than what we built on KMS).

On a live request the gateway logs in to OpenBao with the user's subject token, and OpenBao verifies it against the IdP JWKS and returns a short-lived OpenBao token whose policy is templated to that user's Transit key. That token carries no key material, just permission to call Transit. Each user has their own Transit key (created with `derived=true`), and each row's `context` derives a different subkey from it, so a wrapped DEK only unwraps with its own row's context. The gateway hands it to the controller, which sends the row's wrapped DEK and `context` to `transit/decrypt`, gets back the plaintext DEK, and decrypts the upstream token locally, so OpenBao never sees the credential itself.

![Design 1: the gateway logs in to OpenBao as the user](/images/cb4a/part3-design1.png)

So who gets to call `auth/jwt/login`? That's the first thing to get right. Vault auth assumes a human is present, and in agent egress the user may well be asleep while a machine replays their token, so the identity is real but nothing in the token says a request is actually happening. The controller has to hold the subject token (it's the [RFC 8693](https://www.rfc-editor.org/rfc/rfc8693) token-exchange input), so if it can reach the login path, a compromised controller can do this.

```
t=0      alice makes a real MCP call. The compromised controller keeps her subject JWT.
t=+40m   no traffic anywhere. Controller calls auth/jwt/login with the stored JWT.
         OpenBao: signature ok, exp ok, aud ok. Here is your token.
         Controller decrypts using ciphertext and context from its own database.
         Repeat for every JWT it harvested this hour.
```

Every check passed exactly the way it's supposed to, and liveness went from a 30-second single-use proof to about an hour of replay. `token_bound_cidrs` doesn't help, since it pins where the token is *used*. What does help is letting only the gateway call `auth/jwt/login` (over mTLS, every other caller denied), so the only OpenBao tokens the controller ever sees are the ones the gateway hands it during a live request.

With the login path locked down, this is a good design. There's no broker to run or compromise, nothing writes OpenBao policy at runtime, and every authorization rule is OpenBao config your Vault team can review in git.

So what does the login actually return? A token scoped to the user, since the subject token says who and nothing in it says which of that user's credentials the request is for. The per-row subkeys don't help here, because the `context` isn't a secret (it sits in the controller's database next to the wrapped DEK). The controller can send any of alice's rows with that row's own matching context, and the policy, which only names her key, lets it through.

Part 2 promised to protect "this user's other credentials," and this design gives that up on every live request. Can you push the row into the login? Not really, since the gateway doesn't know the `elicitation_id` and `bound_claims` only matches static values in the JWT. A subject token per upstream (e.g. with an [RFC 8707](https://www.rfc-editor.org/rfc/rfc8707) resource indicator) would get you to the resource, but most IdPs don't issue them, and it still stops short of the row.

Design 1 also loses the per-request checks the broker did in part 2, ie, CEL rules over which resource, audience, and action a request is for (or how fast a user is pulling credentials), honeytoken rows that alert when someone asks for a decoy, and a log of *why* a decrypt was denied. `auth/jwt/login` only checks static claims in the JWT, so it never sees any of that request context ([Sentinel](https://developer.hashicorp.com/vault/docs/enterprise/sentinel) could, but it's Vault Enterprise only). If you want those checks, you build them into the gateway before it calls the login, and the gateway is the most exposed component we have, so a compromised gateway takes the checks down with it.

**A vault login gets you liveness if only the gateway can reach it, but the token it gets back opens every credential that user has.** How much that matters depends on how many upstreams your users connect and how valuable the ones a request *wasn't* for are.

## Design 2: keep the broker and point it at OpenBao (Mode 3b)

Mode 3b keeps the broker from part 2 and leaves OpenBao as only the key custodian. Before it mints anything the broker verifies the user's subject token (signed by the IdP) and the gateway's freshness proof (SVID-signed, single-use `jti`, about a 30-second `exp`, bound to the resource and a hash of the subject). Then it checks that the row the controller named is for the resource in the proof, computes `owner` from the subject, runs CEL, and mints a decrypt token for exactly that row.

Compared to Design 1, that's two changes, and they're independent of each other even though they're easy to conflate.

1. **OpenBao trusts nothing external.** There's no JWT auth mount at all, so harvested subject tokens are worthless at OpenBao, and the only way to get a decrypt token is `[auth/token/create/<role>](https://openbao.org/api-docs/auth/token/)`, which only the broker can call.
2. **Capabilities are per-row.** A named policy pins that row's `context`, and since only the controller knows the `elicitation_id`, whatever mints it has to be something the controller calls.

The broker is also the natural place to add the agent's identity (e.g. its [SPIFFE](https://spiffe.io/) SVID) to CEL. Have the broker verify the agent's JWT-SVID itself though, since an agent ID the gateway copies into its own proof is just the gateway's word.

### How do you scope a decrypt to one row?

This part surprised me. A KMS grant is a permission object you create per request, carrying whatever constraints you pass to `CreateGrant`, and nothing has to be registered ahead of time. An OpenBao ACL is static `(path, parameters, capabilities)` config, and the only dynamic part is which policy *names* get attached to a token. So per-row scoping on OpenBao needs per-row *state*, and Mode 3b pairs a human-authored token role (in git, the analog of the IAM condition block) with a per-row policy the broker writes just before minting.

```hcl
# per-row policy, name: decrypt-row-4711
path "transit/decrypt/user-9f2c8a..." {           # Transit key: one per user, derived=true
  capabilities       = ["update"]
  allowed_parameters = { "context" = ["<b64 row context>"], "ciphertext" = [] }
  denied_parameters  = ["batch_input"]
}
```

```bash
bao write auth/token/roles/decrypt \
  allowed_policies_glob="decrypt-row-*" orphan=true renewable=false \
  token_type=batch token_bound_cidrs=<controller pod CIDR>
```

Mode 3's two independent checks still hold. The ciphertext is bound to the row at wrap time (`derived=true` plus a per-row `context` HKDF-derives a different subkey, where KMS uses `EncryptionContext` as AAD), and the caller is bound to the row at mint time (`allowed_parameters` pins the `context`, where KMS uses `EncryptionContextSubset`). Send some other ciphertext with this row's context and derivation fails, send another row's ciphertext with its own context and the ACL rejects it. Per-user keys on top of that mean a bypassed parameter ACL still can't reach past one user.

So what happens to that policy after the token dies? Nothing, it sits there, but a leftover one is inert, since it does nothing until the broker mints a token that names it (a forgotten KMS grant, on the other hand, *is* the authority). The broker writes one policy per row (a repeat request for the same row reuses it), not one per request. So the broker deletes `decrypt-row-<id>` when the controller tells it an elicitation was revoked or deleted. OpenBao 2.3 added a `ttl` [on policies](https://openbao.org/api-docs/system/policies/) that could do this lazily, but that means a policy write per mint instead of per row.

### The Mode 3b flow

![Design 2 (Mode 3b): the broker gets a decrypt token for one row](/images/cb4a/part3-mode3b.png)

Compared to Mode 3 in part 2, the only thing that changed is what does the decrypt (KMS became OpenBao Transit). The `proof.resource == row.resource` check in the Broker box is one I glossed over in part 2, and without it a compromised controller could hand the broker alice's Slack row during her live GitHub request. Also note that OpenBao is on the synchronous path in both designs (every decrypt calls `transit/decrypt`), and Mode 3b puts the broker on that path too.

## The two side by side

Both designs stop a compromised controller from mass-decrypting the store, and in both a decrypt only happens during a live request through the gateway. The difference is scope and cost. In Design 1 a decrypt token opens every credential the user has, request-context policy (CEL, honeytokens, a decision log) lives in the gateway or nowhere, and the whole thing is OpenBao config with no broker to run. In Mode 3b a decrypt token opens one row and that policy lives in a broker the gateway doesn't control, and you pay for it with another component on the request path and a per-row policy lifecycle in OpenBao.

## The Main Point

The port works, and it works two ways. OpenBao can be the key custodian with the same three roles and the same two independent checks, so if you're on-prem or on a sovereign cloud because you're worried about credential concentration, you can get the same prevent-not-detect property against a compromised token store.

Which design comes down to how far you want one live request to reach. If per-row scoping matters for your users, run the broker, point it at OpenBao, and install no JWT auth mount. If it doesn't, start with the vault login and lock the login path down. Either way, ship the audit log somewhere none of your components can reach.

If you're on AWS, though, Mode 3 on KMS (with the broker-unwrap variant from [part 2.5](/credential-brokering-mode-3-at-scale/)) is still what I'd recommend to a customer. You get the HSM custody boundary and CloudTrail for free, so I wouldn't move off AWS to get either OpenBao design.

Thanks to [Mesut Özdil](https://github.com/moezdil) for the [demo](https://github.com/moezdil/openbao-credential-broker-demo). Arguing with it in detail is what produced most of this post, and the vault-login design is his. If you're working through credential isolation for agent egress on Vault/OpenBao in your own stack, or you think I've weighed the two designs wrong, [connect on LinkedIn](https://linkedin.com/in/ceposta) and tell me!!