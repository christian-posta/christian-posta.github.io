---
layout: post
title: Inbound Auth for Agentcore With Agentgateway
modified:
categories: 
comments: true
tags: []
image:
  feature:
date: 2026-03-03T18:48:35-07:00
---

The best thing about being on the frontline of large enterprises adopting AI agents and MCP tools at scale is we get to see real, practical challenges. [AWS Agentcore](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/what-is-bedrock-agentcore.html) is a popular platform for deploying custom-built AI agents, but one question crops up frequently: **how do callers authenticate to my agent, and how does the agent know _who_ is calling?** Getting both right ie, strong caller authentication _and_ rich user/agent identity is essential for [compliance, audit trails, and least-privilege access control](https://blog.christianposta.com/do-we-even-need-agent-identity/).

At [Solo.io](https://solo.io), we help customers answer this question every day. This post walks through the challenge and presents three concrete patterns that combine [Agentgateway](https://agentgateway.dev) with AgentCore to give you both IAM-level authentication and full user/agent identity context.


## Understanding AgentCore's Inbound Auth Modes

AgentCore Runtime supports two [inbound authentication](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/runtime-oauth.html) modes:

1. **AWS IAM (SigV4)** — the default. Callers sign requests with AWS credentials. No additional configuration is required.
2. **JWT (OIDC)** — callers present a bearer token from a trusted OIDC provider (Cognito, Azure Entra ID, Keycloak, Auth0, Okta, etc.). You configure a discovery URL, allowed audiences, and optionally allowed client IDs.

A given agent runtime is configured with **one** of these modes. This creates an inherent tension:

- **JWT mode** gives you user identity (the token carries `sub`, `iss`, claims, roles) but the built-in claim checking is basic (issuer, audience, client ID, support for some custom claims). There is no way to enforce sophisticated ABAC/ReBAC/authorization policies, and there is no built-in way to represent an _agent acting on behalf of a user_ (agent + user identity in one token).
- **IAM mode** gives you strong, AWS-native caller authentication but the runtime doesn't see a JWT at all. User context can only be passed via the `X-Amzn-Bedrock-AgentCore-Runtime-User-Id` header, which is an opaque string. The runtime doesn't validate this value cryptographically; it trusts whoever the SigV4-authenticated caller is to set it correctly.

But what if you want strong agent identity, user identity, policy enforcement, _and_ AWS IAM authentication when calling your agents? Neither mode alone gives you all of these.

## Using an Agentgateway to front AgentCore

[Agentgateway](https://agentgateway.dev) can sit in front of AgentCore Runtime. Clients/Agents can call it via HTTP, MCP, or A2A and agentgateway can enforce sophistcated authorization policies written in CEL. If needed, agentgatewy can call out to OpenPolicyAgent, OpenFGA, or any other policy engine (AWS Verified Permissions). This alone is a big step up from what you get out of the box with Agentcore. But how can we combine user/agent identity?

Agentgateway Enterprise allows you to perform a token exchange to create an "on behalf of" flow. It can take a user's token, combine with an agent identity (ie, authenticated with mTLS, a client-credential token, or other) and exchange it for a token that looks similar to this:


```json
{
  "act": {
    "sub": "spiffe://acme.com/ns/default/sa/agent-sa",
    "iss": "https://kubernetes.default.svc.cluster.local"
  },
  "exp": 1769450288,
  "iat": 1769363888,
  "iss": "enterprise-agentgateway.enterprise-agentgateway.svc.cluster.local:7777",
  "nbf": 1769363888,
  "scope": "openid profile email",
  "sub": "e3349fa1-02c5-4d80-b497-4e7963b20148"
}
```

Note, in this token we express the user's identity `sub` and the agent actor `act` and we can pass through any additional claims from the user (ie, entitlement, roles, groups, etc). If agents call other agents, we can chain together the `act` claims. You can see a full cryptographically verifiable flow in the token and apply policy based on that. For example, a user "Christian" may have access to GitHub, but an agent "Claude" acting on behalf of "Christian" may only be able to do read-only actions on GitHub. 

At this point we have options for how we want to call Agentcore. We could pass this JWT through to Agentcore, or we could call it with Sigv4 and have an additional layer of protection: only Agentgateway can call the agents directly. Everything else has to go through Agentgateway. 

> **Why not AWS API Gateway?** AWS API Gateway can validate JWTs (via Lambda or Cognito authorizers), but it cannot natively combine "validate JWT at the edge, then call an AgentCore Runtime backend with SigV4 and inject verified user-id headers." 


## Pattern 1: OBO Token Exchange

**The idea:** Agentgateway performs a token exchange (RFC 8693) combining the user's JWT and the agent's identity (e.g. a Kubernetes service account token, SPIFFE, OAuth client credentials, etc) into a single On-Behalf-Of (OBO) token. The AgentCore agent's inbound auth is configured in JWT mode and verifies this OBO token, including both user and agent claims.

**Flow:**

![](/images/agentcore/flow1.png)

1. The user authenticates with their IdP and sends a JWT to Agentgateway.
2. Agentgateway takes the user's JWT and the agent's own identity token (e.g. a Kubernetes service account token) and sends both to the Gateway's token exchange endpoint (STS).
3. The STS evaluates policy (e.g. does the user's token contain a `may_act` claim authorizing this agent?) and issues an OBO token. This token carries the user's `sub` as the subject and the agent's identity in the `act` claim.
4. Agentgateway forwards the OBO token to AgentCore as a Bearer token. The runtime's JWT inbound auth validates issuer, audience, and claims — including the `act` claim for the agent.

**When to use:** You need a single token that cryptographically represents the agent-user relationship. Downstream services and the agent itself can verify both identities from one token. Best for environments where you want end-to-end verifiable delegation.

---

## Pattern 2: JWT Pass-Through with SigV4

**The idea:** Agentgateway authenticates to AgentCore with SigV4 (IAM), but passes the user's original JWT (or an OBO-exchanged JWT) as a custom header. The agent code is responsible for decoding and verifying the JWT.

**Flow:**

![](/images/agentcore/flow2.png)

Secure agentgateway to agentcore with IAM/sigv4; flow through OBO token

1. The user sends a JWT to Agentgateway. Agentgateway may exchange the user/agent identity for an OBO (on-behalf-of) token.
2. Agentgateway validates the JWT, then calls AgentCore using SigV4 (IAM). The JWT is forwarded as a custom header (e.g. `X-User-Authorization`), which must be allowlisted on the agent runtime via `--request-header-allowlist`.
3. IAM policy is enforced; only the Agentgateway can call the agent in AgentCore
4. The agent code receives the JWT in the header and is responsible for decoding, verifying the signature, and checking claims.

**When to use:** You want IAM authentication to the runtime but still need the full JWT available inside the agent for fine-grained authorization decisions. The agent must have JWT verification logic (libraries, JWKS caching, etc.).

---

## Pattern 3: Claims as Headers

**The idea:** Agentgateway validates the JWT at the edge and extracts verified claims (e.g. `sub`, roles). It then calls AgentCore with SigV4 and injects those claims as headers. The agent never sees or verifies a JWT — it receives pre-validated identity attributes.

**Flow:**

![](/images/agentcore/flow3.png)

1. The user sends a JWT to Agentgateway. Agentgateway may exchange the user/agent identity for an OBO (on-behalf-of) token.
2. Agentgateway validates the JWT, then calls AgentCore using SigV4 (IAM). 
3. IAM policy is enforced; only the Agentgateway can call the agent in AgentCore. Agentgateway sets headers from verified JWT claims:
   - `X-Amzn-Bedrock-AgentCore-Runtime-User-Id` — the user's `sub` claim
   - `X-Amzn-Bedrock-AgentCore-Runtime-Custom-Agent-Id` — agent id
   - `X-Amzn-Bedrock-AgentCore-Runtime-Custom-XXXX` — additional claims as needed
4. The agent reads user identity directly from these headers.

**Security note:** The `X-Amzn-Bedrock-AgentCore-Runtime-User-Id` header is treated as an opaque value by the runtime — it does not verify the header cryptographically. The security boundary is that **only a trusted SigV4-authenticated principal** (in this case, Agentgateway) should be allowed to set this header. The IAM policy for `InvokeAgentRuntimeForUser` must be scoped to the Gateway's role only.

**When to use:** You want the simplest agent-side integration — no JWT libraries, no signature verification. The agent trusts the Gateway to have validated the user. Best for lightweight agents or when the agent framework doesn't support JWT verification natively.

---

## When to Use Which Pattern

| | Pattern 1: OBO Token | Pattern 2: JWT Pass-Through | Pattern 3: Claims as Headers |
|---|---|---|---|
| **AgentCore inbound auth** | JWT | IAM (SigV4) | IAM (SigV4) |
| **Agent sees** | OBO JWT with user `sub` + agent `act` | Original/exchanged JWT as header | Pre-validated user-id / claims as headers |
| **Agent verifies JWT?** | No (runtime does it) | Yes (agent code), after gateway does  | No (Gateway did it) |
| **Agent+user in one token?** | Yes | Depends (if OBO exchange used) | No |
| **Agent-side complexity** | Low | High (JWT verification logic) | Lowest |
| **Best for** |Simple policy check, need agent+user | Fine-grained in-agent authz | Simple agents; no JWT libraries needed |

---

Here's an example of what Agentgateway config could look like for calling Agentcore with Sigv4. OBO / Token exchange in the enterprise solution adds a few more steps. I am putting together an end-to-end demo/video showing all of this working, please follow along for the next post! [in/ceposta](https://linkedin.com/in/ceposta).

```yaml
binds:
- port: 3000
  listeners:
  - routes:
    - matches:
      - path:
          pathPrefix: /supply-chain-agent
      policies:
        jwtAuth:
          mode: strict
          issuer: https://ceposta-solo.auth0.com/
          audiences: [https://api.supply-chain-ui.local]
          jwks:
            url: https://ceposta-solo.auth0.com/.well-known/jwks.json
      backends:
      - agentCore:
          agentRuntimeArn: "arn:aws:bedrock-agentcore:us-west-2:606469916935:runtime/a2a_sca_iam-4rLvS1BRqq"
        policies:
          transformations:
            request:
              set:
                X-Amzn-Bedrock-AgentCore-Runtime-User-Id: jwt.sub
                X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: jwt.sub
```

The `jwtAuth` policy validates the token (issuer, JWKS signature, audience). The `transformations` block extracts `jwt.sub` and sets it on both the standard `X-Amzn-Bedrock-AgentCore-Runtime-User-Id` header and a custom header. The agent runtime must allowlist these headers via `--request-header-allowlist`.

---

AgentCore needs more sophisticated authentication, authorization, and policy enforcement than its current IAM and JWT modes provide with the drawbacks described above. AgentGateway can fill that role by validating JWTs at the edge, calling Agentcore with SigV4, and injecting verified user and agent context so you get both strong caller auth and proper identity-aware policy.

Stay tuned for a more complete step-by-step guide for doing this! [Reach out](https://linkedin.com/in/ceposta) if interested in this solution. 

