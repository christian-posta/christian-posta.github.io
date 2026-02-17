---
layout: post
title: Deep Dive AAuth (Agent Auth) - Identity and Access Management for AI Agents
modified:
categories: 
comments: true
tags: []
image:
  feature:
date: 2026-02-16T18:25:53-07:00
---

OAuth has evolved a lot since 2012 with many "lessons learned". [AAuth (Agent Auth)](https://github.com/dickhardt/agent-auth) is an attempt to bring those lessons together for AI agents. [AAuth](https://github.com/dickhardt/agent-auth) is an exploratory spec from Dick Hardt (Author/Co-Author of OAuth 2.0, 2.1)

What started as [OAuth 2.0](https://datatracker.ietf.org/doc/html/rfc6749) has grown into dozens of supporting RFCs, drafts, and practical implementations: [PKCE](https://datatracker.ietf.org/doc/html/rfc7636), [DPoP](https://datatracker.ietf.org/doc/html/rfc9449), [Token Exchange](https://datatracker.ietf.org/doc/html/rfc8693), [Rich Authorization Requests (RAR)](https://datatracker.ietf.org/doc/html/rfc9396), [JAR](https://datatracker.ietf.org/doc/html/rfc9101), [JARM](https://openid.net/specs/oauth-v2-jarm-05.html), [OAuth 2.0 mTLS](https://datatracker.ietf.org/doc/html/rfc8705), [Pushed Authorization Requests (PAR)](https://datatracker.ietf.org/doc/html/rfc9126), and more. Each one addresses a real gap. Each one moves the ecosystem forward. But taken together, they also show something else: the original model wasn’t built for the systems we’re building today.

We are building autonomous agents which make decisions on their own, calling other agents, APIs and MCP servers. We have multi-hop user delegation. We have AI systems making decisions on behalf of users. We have MCP tool invocation where identity, delegation, and proof-of-possession matter. We’ve bolted improvements onto OAuth to handle these realities, but the patterns are scattered across specs, profiles, and drafts.

AAuth (Agent Auth) brings together authentication, authorization, a number of OAuth RFCs and combines with message signing and discovery to provide the foundation of agent identity and access management. 

![AAuth Full Demo](https://raw.githubusercontent.com/christian-posta/aauth-full-demo/main/docs/images/demo2.png)

### With AAuth, we can:

* get rid of bearer tokens
* make agent identity cryptographically verifiable
* provide a progressive scale for auth: starting with pseudonymous, advancing to stable identity, and then authorization/user/obo etc
* dynamically discover permissions to request
* bind permission requests to agents cryptographically
* support rich authorizations
* support agent identity delegation / distributed deployments
* tie in with existing identity standards (SPIFFE/WISME, etc) where it makes sense


<div style="background-color: #e7f3ff; border-left: 4px solid #308cbc; border-right: 1px solid #b8daff; border-top: 1px solid #b8daff; border-bottom: 1px solid #b8daff; padding: 1em 1.5em; margin: 1.5em 0; border-radius: 0 5px 5px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.06); font-size: 1.05em; line-height: 1.6;">
<strong>📖 AAuth Flows:</strong> Digging into all the flows with concrete examples: <a href="https://blog.christianposta.com/aauth-full-demo/" style="color: #0066aa; text-decoration: underline; font-weight: 600;">AAuth Flows</a>
</div>

AAuth is not a replacement for OAuth. It’s not a new standard (at the moment). It’s an exploration of what authentication and authorization could look like if we started from the perspective of agent-to-agent communication, cryptographic identity, proof-of-possession by default, and unified authn/authz semantics.

In AAuth, agents are first-class identities, require signed HTTP messages, unify identity and authorization into one protocol, and make delegation explicit and verifiable. Instead of bearer tokens waiting to be exfiltrated, every request is signed. Instead of tokens representing either a user or an application, AAuth tokens can represent both simultaneously. Instead of bolting token exchange onto the side, delegation chains become visible and enforceable.

How does it all work? I [encourage you to read the draft exploratory spec](https://github.com/dickhardt/agent-auth). And then take a look at how it works in a real(istic) environment (next section). 

## Full Working Prototype

<div style="background-color: #e7f3ff; border-left: 4px solid #308cbc; border-right: 1px solid #b8daff; border-top: 1px solid #b8daff; border-bottom: 1px solid #b8daff; padding: 1em 1.5em; margin: 1.5em 0; border-radius: 0 5px 5px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.06); font-size: 1.05em; line-height: 1.6;">
<strong>📖 Full working demo:</strong> I’ve put together a <a href="https://blog.christianposta.com/aauth-full-demo/" style="color: #0066aa; text-decoration: underline; font-weight: 600;">full working demo</a> with videos that walks through the entire flow with <a href="https://www.keycloak.org/" style="color: #0066aa; text-decoration: underline; font-weight: 600;">Keycloak</a>, Agentgateway, A2A, and MCP.
</div>

![AAuth Demo Flow](/images/demo-flow.png)


It [starts with agent identity](https://blog.christianposta.com/aauth-full-demo/agent-identity-jwks.html) established via JWKS and HTTP message signing. A backend signs requests, downstream agents verify identity via discovery, and an agentgateway enforces signature policies. Then it moves into [autonomous authorization](https://blog.christianposta.com/aauth-full-demo/agent-authorization-autonomous.html), where a resource challenges with a resource token, the caller exchanges it at [Keycloak](https://www.keycloak.org/), and retries with a bound authorization token. Then it [adds user-delegated](https://blog.christianposta.com/aauth-full-demo/agent-authorization-on-behalf-of.html) authorization, where user consent is required and the resulting token carries both the user’s identity and the agent’s identity. Finally, it shows how [Agentgateway](https://agentgateway.dev) can act as [a policy enforcement point](https://blog.christianposta.com/aauth-full-demo/apply-policy-agentgateway.html), applying CEL-based policies to AAuth claims, validating delegation chains, and enforcing scopes and audiences centrally.


If you’re building AI agents, MCP-style systems, or any form of agent-to-agent infrastructure, you should care about three things: who is calling, on whose behalf, and can they prove it cryptographically. OAuth continues to evolve, and that’s a good thing. AAuth is an attempt from Dick Hardt to synthesize where we are, simplify the model, and push forward patterns that matter for agentic and AI-native systems. I am going to be following the evolution of this very closely. 

