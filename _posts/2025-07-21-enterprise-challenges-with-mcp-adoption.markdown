---
layout: post
title: Enterprise Challenges With MCP Adoption
modified:
categories: 
comments: true
tags: [ai, rest, agents, agentic, capabilities, llm, architecture, mcp, tools, openapi, swagger, oas]
image:
  feature:
date: 2025-07-21T16:36:42-07:00
---

We know building MCP servers are where everyone's mind is when it comes to AI agents. That is, if you're going to build useful AI agents, they will need access to enterprise data, tools, and context. Enterprise companies are scrambling to figure out what this means. Does this mean they build MCP servers instead of APIs? Which vendors' MCP servers do they use? How do they secure these flows? How do they govern _any_ of this? 

I wrote a while back about how the MCP Authorization spec [was a mess for enterprises](https://blog.christianposta.com/the-updated-mcp-oauth-spec-is-a-mess/). With recent changes to the [MCP spec around authorization](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization), it's now generally heading in the right direction, but what are the real challenges an enterprise will face as they build out MCP servers? I'll boil it down to three issues I see:

* how to onboard/registering/discover MCP services?
* how much of the MCP authorization spec to adopt?
* how will they manage upstream API/service permissions, consent?

## MCP Servers vs MCP Services

I think the first point to make is that people are cranking out new MCP servers left and right. But who's going to [blindly take these and run them](https://www.knostic.ai/blog/mapping-mcp-servers-study) in an enterprise? Probably more than you would think. A majority of these "MCP servers" are hacked together plugins for desktop use cases. These are great when you don't care about (or don't think about) security, tenancy, and attack vectors. Enterprises should be thinking about building "MCP services" which are remotely-accessible, multi-tenant, highly governed/versioned and tightly secured context services. Doing this, however, is [easier said than done](https://thenewstack.io/remote-mcp-servers-inevitable-not-easy/). 

From an onboarding and registration standpoint, enterprises will need a catalog of approved MCP services and a workflow for getting services into this registry. [I've written about this in the past](https://blog.christianposta.com/prevent-mcp-tool-poisoning-attacks-with-a-registration-workflow/). A big part of this registration and onboarding is to provide the first line of defense to filter for [MCP tool poisoning](https://blog.christianposta.com/understanding-mcp-and-a2a-attack-vectors-for-ai-agents/). Once you have registration, you'll need discovery. Something like [Agent Naming Service](https://blog.christianposta.com/dynamic-agent-discovery-with-a2a-and-ans/) can help here.  

But let's say you get this sorted out, now you need to enable agents and AI applications to call these MCP services. What are some of the challenges here?

## Do you adopt all of the MCP Authorization spec?

A lot of what I had identified in the past has been sorted out by treating an MCP server as a "resource server" instead of an authorization server (AS, RS). However, the new spec now highly recommends using newer parts of OAuth that not many authorization servers (AS) implement and enterprises may not be comfortable with. For those trying to implement as close to the spec as possible, you get back into the [same scenarios](https://den.dev/blog/mcp-confused-deputy-api-management/) for which I wrote the [MCP spec is a mess](https://blog.christianposta.com/the-updated-mcp-oauth-spec-is-a-mess/).  For example, this is what the spec requires and highly recommends:

#### MCP Authorization Required (MUST) 
* OAuth 2.1 / PKCE support (public OAuth clients)
* RFC 8414 - OAuth 2.0 Authorization Server Metadata
* RFC 9728 - OAuth 2.0 Protected Resource Metadata

#### MCP Authorization Suggested (SHOULD)
* RFC 7591 - OAuth 2.0 Dynamic Client Registration Protocol
* RFC 8707 - Resource Indicators for OAuth 2.0

The "MUST" requirements are fairly straight forward and most providers support these. Implementing RFC 9728 is straight forward (for the most part, we will see later...) Where things get interesting is in the "SHOULD" section. If you don't implement these, you get into scenarios. 


Here's what I've been able to determine is supported by popular OAuth/Identity Provider options:

### RFC Requirements Summary:
- **PKCE**: Proof Key for Code Exchange (OAuth 2.1 requirement)
- **RFC 8414**: OAuth 2.0 Authorization Server Metadata
- **RFC 7591**: OAuth 2.0 Dynamic Client Registration Protocol
- **RFC 8707**: Resource Indicators for OAuth 2.0

| Identity Provider | PKCE | RFC 8414 | RFC 7591 | RFC 8707 |
|-------------------|------|----------|----------|----------|
| **Okta** | Yes | Yes | Yes | No |
| **Auth0** | Yes | Yes | Kinda | No |
| **Keycloak** | Yes | Yes | Yes | No |
| **Ping Federate** | Yes | Yes | Yes | Yes |
| **ForgeRock** | Yes | Yes | Yes | Kinda |
| **Google OAuth** | Yes | No | No | No |
| **Microsoft Entra** | Yes | Yes | No | No |

Let's dig into some of this in detail. 

#### Dynamic Client Registration (DCR)

Enterprise environments (that I know) have authorization servers that don't support DCR (ie, Microsoft), or they specifically don't enable it/allow it. Actually, I'll clarify. The MCP authorization spec expects "anonymous DCR" which means any client without identifying itself in any way can register as a valid OAuth client to any MCP server. Enterprises frown on anonymous client registration because it opens up challenges around monitoring, auditing, and revocation. It could potentially open up to accidental (or purposeful) denial of service attacks. 

Some enterprises I've seen enable limited DCR with pre-issued registration tokens. The MCP spec tries to enable a nice "plug and play" experience, but if you don't fully embrace the full anonymous DCR, [you're on your own](https://github.com/modelcontextprotocol/modelcontextprotocol/issues/695). 

So where does leave enterprises? OAuth clients will likely need to be registered and audited as they are today. But this may cause [issues with existing AI agents that expect DCR](https://github.com/anthropics/claude-code/issues/2527). Or maybe organizations end up using a single OAuth client for all MCP clients that use a particular MCP server? This may seem a reasonable compromise, but it leaves challenges around monitoring (which may be alleviated through other mechanisms, like Agent identity?). 

Another alternative is they have the MCP server/service implement client registration and revert partially to the previous spec [which has the MCP server become an Authorization Server](https://den.dev/blog/mcp-confused-deputy-api-management/). I don't think this is very well ironed out yet. 


#### Resource Indicators

If an org choses some flavor of supporting Dynamic Client Registration, then you'll want to make sure your IdP supports [RFC 8707 Resource Indicators](https://www.rfc-editor.org/rfc/rfc8707.html). This becomes critical when issuing tokens and delegating user authorizations for calls that require further upstream calls. It's crucial to not [blindly passthrough user access tokens](https://modelcontextprotocol.io/specification/draft/basic/security_best_practices#token-passthrough) to upstream services because of the large potential of misuse. What will that MCP server (or AI agent) do with the permissions? 

Tokens should be downscoped, and permitted audiences should be adjusted as tokens flow through an agentic architecture. We may have [gotten away with not doing this properly with microservices](https://blog.christianposta.com/ai-agents-are-not-like-microservices-or-monoliths/), but the risk of AI agents and [AI models significantly misbehaving](https://www.anthropic.com/research/agentic-misalignment) [with a user's credentials](https://www.spirl.com/blog/ais-security-problem-isnt-ai----its-everything-around-it) is real and unavoidable. 

What that means is that OAuth clients must (in my words) request access tokens with the appropriate `aud` claim. That's where RFC 8707 comes into the picture. However, that's also where it leaves the picture: since most IdPs don't implement it today :-/ Some providers have workarounds or proprietary mechanisms to do this, but as of this writing most don't implement the spec. 


#### Scoping

The last topic is around scoping and preventing privilege escalation or overly broad scoping. The MCP spec requires to implement [RFC 9728 - OAuth 2.0 Protected Resource Metadata](https://datatracker.ietf.org/doc/html/rfc9728). What that means is, the MCP server must publish metadata related to automatically discovering authorization information, including where the client must go to register and obtain access tokens. For example, here's what that metadata could look like (from my series on [securing MCP servers by implementing the Authorization spec](https://blog.christianposta.com/understanding-mcp-authorization-step-by-step/)):

```json
{
  "resource": "http://localhost:9000",
  "authorization_servers": ["http://localhost:8080/realms/mcp-realm"],
  "scopes_supported": [
    "echo-mcp-server-audience",
    "mcp:read",
    "mcp:tools",
    "mcp:prompts"
  ],
  "bearer_methods_supported": ["header"],
  "resource_documentation": "http://localhost:9000/docs",
  "mcp_protocol_version": "2025-06-18",
  "resource_type": "mcp-server"
}
```

Note that this metadata publishes "scopes_supported" which are the scopes required to call an MCP server's tools. But, if you're building MCP services, you may have tools that require certain scopes that are not available to all clients. So what are we supposed to do with this document? Request all scopes? When we request access tokens? 

That's what some of the early DCR clients are doing. This may work fine if the authorization server (AS) is smart enough to only give out scopes in the access token that it knows the user has access to. But how will the MCP server know what a particular user is allowed to have? Are the opportunities for privilege escalation for users that end up with scopes but don't have the right entitlements in the enterprise system? Will the access token include additional metadata to indicate roles that an MCP server can use to verify? Although this is not much different for microservices, it's an after thought in most of the enterprises I've spoken with. 

So at this point in time, the question remains: 

> How much of the MCP Authorization spec will an enterprise implement?

## How to manage upstream API/service permissions, consent?

If there’s one part of the MCP flow that’s still murky for enterprise teams, it’s this one.

Let’s say you’ve built an MCP service that exposes a useful set of tools to AI agents—great. But what happens when those tools themselves need to call upstream APIs or services on behalf of the user? For example, fetching user profile data from an internal HR system, querying a customer record from Salesforce, or invoking a billing API. At this point, your MCP service isn’t just a "resource", it becomes an API client too. And it needs credentials to call those upstream services. But how should it get them? Most enterprise identity teams don’t want MCP clients or servers passing around raw access tokens or API keys issued to the user. There are too many risks. 

Enterprises need a secure and governed way for MCP services to obtain delegated authorization for upstream calls without compromising user credentials or security boundaries. And it needs to support not only OAuth, but API keys, terms-and-conditions, acknowledgements, etc. But today, there’s no well-defined standard pattern for this.

One proposal now [under discussion in the MCP community](https://github.com/modelcontextprotocol/modelcontextprotocol/pull/887) is a concept called Secure Elicitations. This pattern allows an MCP server to initiate an out-of-band authorization flow directly with the user, typically via a secure browser-based prompt, without routing sensitive tokens through the MCP client. It gives enterprises a chance to handle consent, login, and token issuance securely and transparently.

While this is just one proposed approach (and still under community review), it’s worth keeping an eye on. This kind of pattern may become essential for enabling real enterprise use cases where MCP services act as a proxy for upstream tools and APIs, but without creating new security liabilities.

## Wrapping Up

MCP Services are the right path forward to enterprises building on the MCP protocol, but even with recent revisions to the MCP protocol, there are some things still left to be ironed out. If you're building MCP services and AI agents, I'd really love to [connect](https://linkedin.com/in/ceposta) and chat more. 


