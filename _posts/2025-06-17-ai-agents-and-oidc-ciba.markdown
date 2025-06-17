---
layout: post
title: Bridging Agent Autonomy and Human Oversight with OIDC CIBA
modified:
categories: 
comments: true
tags: [ai, rest, agents, agentic, capabilities, llm, architecture, mcp, tools, openapi, swagger, oas]
image:
  feature:
date: 2025-06-17T08:56:51-04:00
---


In earlier posts exploring AI agent and agent identity, [Do We Even Need Agent Identity?](https://blog.christianposta.com/do-we-even-need-agent-identity/) and [Agent Identity: Impersonation or Delegation?](https://blog.christianposta.com/agent-identity-impersonation-or-delegation/), I dug into the identity tradeoffs surrounding AI agents in the enterprise. The TL;DR: AI agents acting as first-class, autonomous participants in secure systems can’t just borrow human identities. They need their own.

That stance immediately raises a critical question: how do we let agents operate independently, while still enforcing human oversight for sensitive or risky actions?

In the world of platform engineering, where systems are increasingly automated and policy-driven, we still need engineers in the loop—just at more strategic points. The trick is balancing autonomy with safety. "Human in the Loop" is a known concept in AI agent workflows, but we need to tie authentication and authorization into this. 

Enter OpenID Connect’s [Client-Initiated Backchannel Authentication](https://openid.net/specs/openid-client-initiated-backchannel-authentication-core-1_0.html) (CIBA), an underused but incredibly relevant protocol for letting AI agents ask permission the right way.

## Autonomous Agents Will Need Human Approval Loops

Let’s say you’ve built a platform that uses AI agents to handle infrastructure operations: monitoring for degraded service health, rotating secrets, triggering failovers, scaling out workloads, or approving CI/CD pipelines. That agent might be operating 24/7 without direct human involvement.

But what happens when one of those decisions crosses a threshold of risk or ambiguity?

Here are real examples from modern SRE and platform workflows:

* An AI agent observes elevated tail latencies and wants to roll back a recent platform config (e.g., Istio load balancing policy) change.
* A CI/CD agent is ready to promote a canary rollout to full production after its metrics look good—but the metrics are still noisy and need human intervention.
* A platform reliability agent proposes draining a node due to disk pressure, but the node is hosting a latency-sensitive control plane.
* A GitOps agent wants to auto-merge a PR created by another agent that modifies traffic splitting rules in your API gateway.

In each case, the system is autonomous until it needs a human. The action is time-sensitive, often safety-critical, and tied to platform state that only an engineer with context can verify.

Traditional identity and access flows weren’t designed for this kind of collaboration between humans and agents.

## CIBA Decouples Identity and Interaction

CIBA is designed for asynchronous, decoupled authentication/authorization. It was originally created to support scenarios like approving a bank transaction on your phone while interacting with a smart TV or ATM.

But the same model applies beautifully to agentic systems: an AI agent needs approval from a human, even though the two aren’t sharing a device or screen.

In a CIBA flow, the agent initiates a request to the identity provider. The identity system then reaches out—out-of-band—to the human responsible for approving or denying the action. Once approved, the identity system issues a token to the agent that’s scoped only to the specific operation.

![](/images/ciba/simple-flow.png)

This is obviously different from typical OAuth flows where the user is initiating the flow (through some action on the client). 

Looking a little closer, here's what the Agent sends to the IdP:

```json
Authorization: Basic base64(client_id:client_secret)
Content-Type: application/x-www-form-urlencoded

client_id=agent-release-bot
scope=openid offline_access
login_hint=alice@company.com
binding_message=Approve rollout for foo-v2 to prod
requested_expiry=600
```

The Agent then polls (or other connectivity depending on IdP) for the approval from the Human (the IdP sends back a auth_req_id that the Agent uses to poll, for example). Eventually, if successfully approved, the Agent would get a response like this:

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR...",
  "refresh_token": "a-refresh-token-if-issued",
  "id_token": "eyJhbGciOiJSUzI1NiIsInR...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

With the following access token:

```json
{
  "iss": "https://idp.example.com",
  "sub": "alice@company.com",
  "aud": "agent-release-bot",
  "exp": 1718650000,
  "iat": 1718646400,
  "auth_time": 1718646370,
  "acr": "ciba",
  "amr": ["ciba", "otp", "user_approval"],
  "action": "promote-rollout",
  "target": "foo-v2",
  "environment": "prod",
  "approved_by": "alice@company.com"
}
```

Note the specific claims for particular actions and environments. 


## SRE Agents, with Human Approval

Imagine your AI release manager (maybe powered by Argo Rollouts or something more sophisticated) has evaluated a release and wants to fully promote it. Historically, that might mean:

1. The agent impersonates a human (with some predefined keys or passwords) and acts directly.
2. Or it halts and waits for a Slack approval (but still has security authority to complete once the human approves).
3. Or worse, the engineer has to log in and click a button in a UI no one remembers how to use.

Instead, with CIBA:

* The agent sends a signed request to the IdP with metadata: “I want to promote rollout `foo-v2` in `prod` because success rate = 99.8%.”
* The IdP notifies the engineer responsible for `foo`, say Alice.
* Alice gets a push notification on her phone or workstation with full context: success rates, error budgets, SLO burn rate, etc.
* She approves or modifies the action (“proceed, but increase wait interval”).
* The agent _receives a scoped access token_ and promotes the release.

Note the agent receives a **scoped access token** to complete that one step. This token should be short lived and expire on its own. 

![](/images/ciba/agent-deploy.png)

This pattern gives you all the benefits of agent autonomy with none of the downsides of identity overreach. It’s like pairing “GitOps” with “Guardrails-as-Code,” all under the posture of "zero trust" and "zero standing privilege".  The guardrails are enforced via secure identity protocols and enable auditable decision making. The agent keeps its own identity, human approval is cryptographically verifiable, and the resulting action is traceable to both parties: “Agent `argo-release-bot` performed action X, approved by `alice@company.com` at 09:22 UTC.”

For teams under regulatory pressure or running critical production infrastructure, this is critical. You also avoid the trap of persistent impersonation. The token the agent receives is short-lived, single-purpose, and bounded to the human-approved context.

A number of identity providers support CIBA. For example, [Auth0](https://auth0.com/docs/get-started/authentication-and-authorization-flow/client-initiated-backchannel-authentication-flow/user-authentication-with-ciba) and [Keycloak](https://www.keycloak.org/securing-apps/oidc-layers#_client_initiated_backchannel_authentication_grant) both support these flows. 


This post is a continuation of my thoughts around Agent Identity and Security. More to come. If you're working on secure, AI-native platform automation and want to talk identity models, I’d love to connect: ([@christianposta](https://x.com/christianposta) or [/in/ceposta](https://linkedin.com/in/ceposta)).