---
title: "Connecting SaaS MCP Servers to Enterprise With Agentgateway"
date: 2026-02-23T09:18:22-07:00
categories: [AI Agents]
tags: [agentgateway, agents, enterprise, gateway, mcp]
---

Enterprise adoption of MCP [still has problems](https://www.solo.io/blog/enterprise-challenges-with-mcp-adoption). How do you govern its usage? Especially when developers are willy-nilly installing `stdio` MCP servers on their machines. >> BTW << we should be restricting any usage of `stdio` MCP servers. If a stdio MCP server requires API keys or credentials because it makes network calls, [it should be a remote MCP server](https://blog.christianposta.com/mcp-should-be-remote/) behind an [AI/MCP gateway](https://agentgateway.dev) and [governance layer](https://agentgateway.dev/blog/2026-02-21-kill-switch/). 

<div class="callout">
<p>But what about SaaS providers offering public remote MCP servers?</p>
</div>

Public SaaS providers are offering their [own hosted remote MCP](https://docs.databricks.com/aws/en/generative-ai/mcp/) servers. And this introduces problems: using them (even through an MCP gateway) [bypasses corporate identity, security, and observability controls](https://blog.christianposta.com/mcp-should-be-remote/). Enterprises need to consume SaaS MCP servers while still enforcing their own identity, network, and policy boundaries. That means bringing external MCP endpoints inside the trust domain in a controlled way.

In [MCP Authorization Patterns for Upstream API Calls](https://blog.christianposta.com/mcp-authorization-patterns-upstream-api-calls/), I showed how self-built remote MCP servers can safely call SaaS APIs ([GitHub](https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp/extend-copilot-chat-with-mcp), [Atlassian](https://support.atlassian.com/atlassian-rovo-mcp-server/docs/getting-started-with-the-atlassian-remote-mcp-server/), [Databricks](https://docs.databricks.com/aws/en/generative-ai/mcp/), etc.) when those calls cross trust-domain boundaries. For example: when the enterprise uses Okta, but the SaaS (ie, GitHub) has their own Oauth IdP.  But it didn't cover the case where the SaaS hosted the MCP server.

In this post we look at how **Agentgateway** can solve connecting SaaS MCP servers with their own IdPs to the enterprise so that agents can use them without bypassing corporate identity, policy, or audit requirements.

## The Core Problem

A natural first instinct is to use federated SSO to connect your enterprise users to SaaS MCP servers. This wont work, at least not on its own. SSO gives you user identity. What you need is user authorization: OAuth access tokens scoped to specific SaaS APIs on behalf of a specific user. To be more clear: SSO gives you a SAML/OIDC token. What you need is a properly scoped OAuth token **for the SaaS IdP**. 

![](/images/cross-domain-mcp-1.png)

Some providers like Google and Databricks offer ways to map/exchange SSO identity to access tokens for OAuth tokens, but it's not uniform and most other providers don't support it at all.

What you need is a layer that bridges enterprise SSO to the SaaS IdPs which enforces policy at both connect time and at runtime. That's what [Agentgateway Enterprise](https://www.solo.io/products/agentgateway-enterprise) does here.

![](/images/cross-domain-mcp-2.png)

## SaaS MCP Server Scenarios

There are three SaaS MCP scenarios that often come up in my work with customers. They want to solve for:

1. User sitting with agent, connecting directly to SaaS MCP server; e.g., Agentic IDE
2. User sitting with complex agent, may call other agents which need SaaS MCP tool access; e.g., custom agents built for SRE activities
3. Autonomous agent, no user involved - may need to consent and impersonate the user at some point; e.g., monitoring/analytics, policy enforcement, etc

If we break this down, we can classify the scenarios as consenting access "synchronously" vs "asynchronously". 

For example, with scenario 1, if the user is sitting with the agent (agentic IDE), the user can configure the SaaS MCP server and be prompted synchronously to connect and authenticate/authorize. In both scenarios 2 and 3, the agent may be multiple hops away from the user. If an agent needs to connect and use a SaaS MCP server on behalf of the user at some point in a multi-hop agentic communication, it must coordinate asynchronously/out-of-band with the user to get auth/consent. 

![](/images/cross-domain-mcp-3.png)



## Authorization Through Policy and Token Exchange

At first glance, you might think simply routing MCP traffic through a gateway would solve the problem. But the naive approach of pointing your MCP client at a SaaS MCP server (even through a gateway) doesn't work.

When the MCP client connects to the SaaS MCP server, the server responds with a `401 Unauthorized` and redirects the user to authenticate with the SaaS provider's IdP (e.g., GitHub's OAuth, Databricks' login). The user is prompted to log in with their SaaS credentials directly. This completely bypasses enterprise SSO, policy enforcement, and audit controls. The enterprise has no visibility into which users are accessing what, no way to enforce scopes or permissions, and no audit trail of the authorization flow.

With Agentgateway Enterprise, we can intercept the authorization flow, enforces enterprise SSO first, apply policy, then broker the token exchange to the SaaS IdP on behalf of the user all while maintaining policy and audit controls throughout. 

The administrator configures the SaaS MCP servers in the Agentgateway and exposes them as MCP endpoints. Users connect to the gateway, which orchestrates the OAuth flow: first enterprise SSO (e.g., Microsoft Entra), then the SaaS IdPs. If we are exposing a composite MCP server on the gateway (ie, multiple backend MCP servers) the flow would include consent to all of the backend MCP servers. In the admin configuration you can pre-consent certain scopes or restrict which scopes are requested on behalf of the user.

![](/images/cross-domain-mcp-4.png)

People will ask: *how do you prevent users from going directly to the SaaS MCP and bypassing the gateway?* This isn't an MCP-specific problem. It's the same as forcing any SaaS traffic through a controlled path. Common strategies include: **network egress and forward proxy** so that MCP client traffic to known SaaS MCP endpoints is routed through (or only allowed via) the gateway; **tenant restrictions** (e.g., [Microsoft Entra tenant restrictions](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/tenant-restrictions)) so only approved tenants and apps are used; and **internal catalog and device policy** so that the only MCP server URLs you distribute (e.g., via MDM or internal docs) point at the gateway, not at the vendor's direct URL.

#### Demo Video

For a step-by-step walkthrough of securing MCP with Microsoft Entra and Agentgateway, see [Enterprise MCP SSO with Microsoft Entra and Agentgateway](https://www.solo.io/blog/enterprise-mcp-sso-with-microsoft-entra-and-agentgateway). 

You can see a demo of this sync flow in the video below.

<div style="text-align: center; margin: 2em 0;">
  <iframe width="560" height="315" src="https://www.youtube.com/embed/p0Q8xRSdHTo" 
          title="Agentgateway: Securing SaaS MCP Servers with Enterprise SSO" 
          frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
          allowfullscreen>
  </iframe>
  <p style="margin-top: 0.5em; font-size: 1.1em;">
    <a href="https://youtu.be/p0Q8xRSdHTo" target="_blank">Watch this walkthrough of securing SaaS MCP servers with Agentgateway Enterprise on YouTube</a>
  </p>
</div>


But what if you're not sitting with the AI agent? 

## Async auth to SaaS MCP Servers with elicitation

What if the user isn't sitting with the agent? Maybe it's an autonomous agent that sometimes needs a user to review or consent, or the agent calls other agents and the chain eventually needs access to a SaaS MCP. In those cases you need **elicitation**. [MCP url/secure elicitation](https://modelcontextprotocol.io/specification/2025-11-25/client/elicitation#url-mode-elicitation-requests) is part of the protocol, but many SaaS MCP servers don't support it yet. Agentgateway Enterprise can still support secure elicitation at the gateway.

![](/images/cross-domain-mcp-5.png)

As in the previous section, the admin configures the SaaS IdPs. When an MCP client tries to call a SaaS MCP server that requires auth, the gateway can orchestrate elicitation: it returns an error to the MCP client with a URL. The MCP client can then prompt the agent to obtain information from the user (e.g., via the [A2A protocol](https://a2a-protocol.org) for input-required state) and/or notify the user through some async channel (Slack, Teams, email, desktop alert, etc.). The Agentgateway UI shows that the gateway needs access to a given resource to proceed. The user completes auth; the agent can retry and continue.

#### Demo Video

<div style="text-align: center; margin: 2em 0;">
  <iframe width="560" height="315" src="https://www.youtube.com/embed/_DxOmM6biQ4" 
          title="Agentgateway Elicitation Flow Example" 
          frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
          allowfullscreen>
  </iframe>
  <p style="margin-top: 0.5em; font-size: 1.1em;">
    <a href="https://youtu.be/_DxOmM6biQ4" target="_blank">Watch this demo of Agentgateway Enterprise async/elicitation flow on YouTube</a>
  </p>
</div>



## A word on XAA (Cross App Access)

The cross-identity and token-exchange standards we touched on in the [upstream API patterns post](https://blog.christianposta.com/mcp-authorization-patterns-upstream-api-calls/) for exchanging SSO identity for intermediate assertions and then for provider-specific access tokens are being worked on in the IETF and elsewhere. [Cross App Access (XAA)](https://xaa.dev) is a related effort and testing platform for that space: secure, user-scoped access across app and trust boundaries. The problem is that most SaaS IdPs don't support this yet (even if [some open source IdPs like Keycloak is exploring](https://www.keycloak.org/nightly/securing-apps/jwt-authorization-grant)). Until the public SaaS IdPs support ID-JAG/XAA, there's not much to use here. 

## Conclusion

[Agentgateway Enterprise](https://www.solo.io/products/agentgateway-enterprise) can support several patterns for SaaS IdP, API, and MCP auth:

* Building your own MCP servers that call SaaS APIs (as in the [upstream patterns post](https://blog.christianposta.com/mcp-authorization-patterns-upstream-api-calls/))
* Using SaaS MCP servers directly from an agent, with enterprise SSO and scope policy at the gateway
* Agent-to-agent chains that eventually need SaaS MCP access
* Autonomous agents that later prompt the user for consent via elicitation

Take a look at [Agentgateway](https://agentgateway.dev) (OSS) and [Agentgateway Enterprise](https://www.solo.io/products/agentgateway-enterprise) for more. 

