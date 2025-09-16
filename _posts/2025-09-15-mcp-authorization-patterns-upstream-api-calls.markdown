---
layout: post
title: MCP Authorization Patterns for Upstream API Calls
modified:
categories: 
comments: true
tags: [ai, rest, agents, agentic, capabilities, llm, architecture, mcp, tools, openapi, swagger, oas]
image:
  feature:
date: 2025-09-15T16:07:53-07:00
---

The [Model Context Protocol](https://modelcontextprotocol.io/docs/getting-started/intro) (MCP) is moving fast from experimental to enterprise-ready. I am working with a number of customers / prospects / community members who want to go beyond locally deployed [stdio transport](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports#stdio) MCP servers to multi-tenant remote HTTP "MCP services". 

Doing so raises a number of questions especially for enterprise adoption:

* How do we authenticate the communication between MCP client and MCP server? On behalf of the user?
* How do we determine what tools/resources/prompts a specific user is allowed to see / call
* How are we safely maintaining session state and tying to the right user?
* Should we even be doing MCP servers as stateful? Or should we treat them more like REST APIs?

Each of these deserves its own deep dive, but the question we keep hearing right now is:

<blockquote>
"How do we call upstream APIs on behalf of a user from our multi-tenant MCP servers when the call crosses trust domain boundaries?"
</blockquote>

That is, an MCP server must call an upstream API like GitHub, Google, Slack, or Atlassian on behalf of the user. Those APIs sit in their own trust domains, with their own identity providers and auth mechanisms (OAuth, API keys, etc). If the upstream API is in the same enterprise trust domain as the MCP server, it's more straightforward. But when the trust domains are different, we need a pattern for securely approving, crossing, and auditing calls across the trust domain boundaries.

A “real-life” example: I travel a lot for work and stay in a lot of hotels. I use my ID or passport to get through most of the system ie, airports, car rentals, restaurants. But when I check into a hotel, I can’t just use my ID to open the room door. I have to exchange it at the front desk for a hotel keycard. That keycard is time-bound and limited ie, it only works at that specific hotel, for my room, and only while I’m checked in.

![](/images/mcp-auth-patterns/problem-statement.png)

In this blog we look at five patterns for enabling this kind of communication. We will look at the pros and cons of each, and we will hopefully land on a pattern that can be implemented today. 

If you're interested in content like this, follow ([@christianposta](https://x.com/christianposta) or connect [/in/ceposta](https://linkedin.com/in/ceposta)) for more.


## Can MCP Authorization Help

The MCP Authorization spec was introduced back in March 2025 to help solve the challenge of authorizing the communication between an MCP client and an MCP server. I've [pointed out then](https://blog.christianposta.com/the-updated-mcp-oauth-spec-is-a-mess/) (when it was released) and [more recently](https://blog.christianposta.com/enterprise-challenges-with-mcp-adoption/) (when it was updated) the challenges of implementing this spec in an enterprise environment. Nevertheless, this part of the spec [is evolving](https://github.com/modelcontextprotocol/modelcontextprotocol/issues/1415) and continuing to improve. This part of the spec, however, addresses auth between the MCP client and MCP server. It does not specify much in the way of upstream MCP server calls. 

![](/images/mcp-auth-patterns/mcp-auth-question.png)








## Pattern 1: Service Account access to Upstream API

The first pattern we'll look at gives the MCP server total access to the upstream API. This can be done with a service account or some variant of an "admin" credential. 

![](/images/mcp-auth-patterns/day1.png)

#### It works like this:

* A user logs into an MCP client with an internal enterprise mechanism (SSO/MFA).
* The MCP client calls the MCP server to call a tool
* The MCP server needs to call an upstream API / SaaS / external service as a result of the tool call
* The internal user identity is not recognized by the upstream identity provider
* The MCP server holds an all-access service account that can impersonate any user and make upstream calls on their behalf

I've seen this pattern in the wild and is not desirable. It appears on first glance like it could work since it may already be used internally (within trust domain), can be done right now (ie, doesn't need to wait for spec updates), and doesn't expose any sensitive credentials to the MCP client or end user. 

However there are a number of downsides. <br>
❌ MCP server becomes a high-value target for this admin credential <br>
❌ Violates "lease privileged" access per user <br>
❌ Highly blast radius for confused deputy errors <br>
❌ Circumvents RBAC at the upstream API (admin can do anything) <br>
❌ Auditing and attribution becomes messy <br>


Although this pattern may seem like a quick win (ie, "we'll figure out security later") it should be avoided. In fact, it should be treated as an "anti-pattern".








## Pattern 2: Upstream API Credential Passthrough

Another tempting pattern looks like this: What if the client / user somehow acquires the upstream API credentials ahead of time? For example, they login to Google, or GitHub's API and acquire a short-lived (or long-lived token -- even worse) credential representing the user. Then, they configure the MCP client (ie, Claude Code, Cursor, etc) with the user's credential. 

![](/images/mcp-auth-patterns/day2.png)

#### Here’s how it works:

* User acquires credentials (tokens/keys/passwords) for an upstream API
* User gives these credentials to the MCP client
* MCP client calls the MCP server with those user credentials
* MCP server passes them along to the upstream API
* Upstream API thinks it’s talking to the user, applies proper RBAC

So this pattern eliminates the big drawback of the previous pattern. There is no service account / admin access to the upstream API which can perform any action. So we undo some of the drawbacks of that pattern. However, we create new downsides:

Here are some of the downsides:<br>
❌ Unclear security boundaries: who was the token issued to? are they authorized to make these calls? if handed off, is the recipient allowed to make calls? Can the upstream API trust that there has not been a compromise? <br>
❌ In some cases, the MCP clients/agents are public/third-party and should not be trusted with sensitive upstream API tokens <br>
❌ An AI agent could potentially pass this token to a different MCP server than is intended <br>
❌ MCP server gets tricked into doing something with a co-opted/stolen token or co-opting an in-progress session with passed through token (confused deputy) <br>
❌ Auditing and attribution becomes messy. Where did these calls come from?<br>

Not surprisingly the MCP server spec's ["Security Best Practices" doc](https://modelcontextprotocol.io/specification/2025-06-18/basic/security_best_practices#token-passthrough) explicitly calls this an anti-pattern:

<blockquote>
“Token passthrough” is an anti-pattern where an MCP server accepts tokens from an MCP client without validating that the tokens were properly issued to the MCP server and “passing them through” to the upstream API.
</blockquote>

We should avoid this pattern. 







## Pattern 3: Leveraging SSO Federation for Upstream APIs / services

When enterprise applications talk to external services, the ideal starting point is federated SSO: an established trust agreement between the enterprise and the upstream API. Without that, upstream API calls probably shouldn’t be allowed at all. But even with SSO in place, does it fully solve the problem of upstream access? Unfortunately, not quite. Let’s dig deeper.

![](/images/mcp-auth-patterns/day3.png)

#### Here’s how it works:

* User is logged in with their internal IdP / SSO
* MCP client leverages SSO, login to MCP server
* MCP server passes user's SSO Identity to upstream API
* External service/upstream can validate SSO / user identity; apply policy

At first, this looks like a promising path: just pass the user’s identity along and adjust for the correct audience. Unfortunately most upstream APIs won’t accept it. Services like Google, GitHub, and Slack are built around OAuth tied to their IdP, and they require **OAuth access tokens**. Knowing who the user is isn’t enough on its own.

Here are some of the downsides:<br>
❌ Likely won't work out of the box <br>
❌ External services require OAuth for their APIs, SSO just gives you identity not authorization delegation <br>
❌ No central policy governing what apps are allowed to call upstream APIs <br>

That being said there *may* be individual providers that have something that could work today. Basically, what we need is a federated, trusted way to exchange a user's SSO credential for a correctly scoped/mapped upstream OAuth access token. For example, if your upstream API is a Google API, you can federate your internal IdP with [Google's Workforce federation capability](https://cloud.google.com/iam/docs/workforce-identity-federation). In this workload federation, you can specify mapping rules that define how a user's internal roles/groups/claims can be mapped to specific scopes in Google OAuth. Then you can use Google's STS to [obtain access tokens](https://cloud.google.com/iam/docs/workforce-obtaining-short-lived-credentials) from your mapped IdP token. 

Unfortunately this is very provider dependent and would not work with other providers. 

### Cross Domain Identity Token Exchange

As we saw in the previous example, there are providers that enable a secure token exchange to issue scoped access tokens once federation is in place (i.e. Google Workforce Federation). What we would like it some standards in place so more identity providers can make this available. To do this, we need two things: 

1. A way to exchange a SSO user identity for an intermediate identity assertion that can be understood in another provider (cross-domain)
2. A way to exchange this intermediate identity assertion to a provider specific access token


There are two draft specifications in flight right now to address these needs:

* [OAuth Identity and Authorization Chaining Across Domains](https://www.ietf.org/archive/id/draft-ietf-oauth-identity-chaining-06.html#name-token-exchange)
* [Identity Assertion Authorization Grant](https://www.ietf.org/archive/id/draft-ietf-oauth-identity-assertion-authz-grant-00.html#name-token-exchange)

When combined, these specifications formalize the following interaction for MCP servers:


![](/images/mcp-auth-patterns/identity-jag.png)

#### The TL;DR of how this works

* User is logged into enterprise SSO
* MCP client calls MCP server with user's identity
* MCP server calls internal IdP to exchange user identity for JWT Identity Assertion Grant (`id-jag`) to call external service
* Internal IdP decides whether user is allowed to communicate externally; if so, issues `id-jag` token
* MCP server calls external IdP to exchange this `id-jag` token for an access token scoped to user in external IdP
* External IdP trusts `id-jag` token (by way of a-priori federation), evaluates claims, issues a scoped access token
* MCP server uses access token to call upstream API


You can read more in Aaron Parecki's blog [Enterprise-Ready MCP](https://aaronparecki.com/2025/05/12/27/enterprise-ready-mcp). I believe this is the right long-term solution to this problem. The question is, when will this become a standard and when will it be implemented across various IdPs? And what can we do now?






## Pattern 4: Protocol Support for URL Elicitation

If we ignore policy checks and whether or not a user is allowed to make an external call, the crux of the problem is really how do we securely get the user's upstream access token to the MCP server. The MCP server community is looking to address this part of the problem directly in the protocol itself. It's basically how can the MCP server prompt the user that more information is requested. 

Remember, the MCP protocol allows for the MCP server to initiate a request to the MCP client. There is already an ["elicitation" feature of the MCP protocol](https://modelcontextprotocol.io/specification/2025-06-18/client/elicitation) which allows the MCP server to do this. However, the MCP spec says this feature (as is) should not be used to transmit sensitive credentials:

<blockquote>
Servers MUST NOT request sensitive information through elicitation
</blockquote>

The main reason for this suggestion is the MCP client may not be trusted to handle the user's sensitive upstream. A [recently approved proposal called](https://github.com/modelcontextprotocol/modelcontextprotocol/issues/1036) "url elicitations" should appear in the next revision of the MCP specification. 


![](/images/mcp-auth-patterns/day4.png)


#### Here’s how it works:

* MCP client calls MCP server (ie, tool call) with their internal SSO token
* MCP server tool call requires external API call protected by external IdP
* MCP server initiates a URL elicitation; client directs user to URL specified by MCP server
* User completes required auth process (OAuth, API key, consent, etc)
* Callback (ie, OAuth) goes directly to the MCP server with credential
* MCP server has credentials to call upstream API

Here's a demo of this in action:

<iframe width="560" height="315" src="https://www.youtube.com/embed/ArIftrVsStY?si=sfrblj69a7dDV8c8" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

This is a good approach, within the protocol, to facilitate this secure credential acquisition. 

However, there are some downsides:<br>
❌ Not part of the MCP spec (Yet! Hopefully coming soon)<br>
❌ Heavily depends on user experience: how do you notify the user?<br>
❌ All agents/MCP servers in a chain will need to support this<br>


There are some real questions you need to think about if going to implement this URL elicitation approach.

The first is, are you calling external APIs outside of your organization? and is this an approved action? And if it is, for which users? And how is this enforced? 

The second important question is: once the MCP server acquires these credentials, how are you managing the lifecycle of this session? Does the external provider give user-level access to manage revocation? If this is an API key/JWT, does it expire? Is the MCP server eligible to do request refresh of the credential?

The last is how do you manage this user experience? Do these elicitations get tracked somewhere? Do you get one for every tool call? What's the right balance between appropriate credential acquisition and bombarding users with notifications/elicitations? And can the agents properly handle this async workflow?







## Pattern 5: Offload Out-of-Band Elicitation to Secure Infrastructure

One of the big questions we need to sort out is "if we do url elicitations, how do we securely manage the lifecycle of these upstream credentials"? That is, a lot of access tokens will be issued/procured by the MCP server on behalf of lots of users:

* Do we trust the MCP servers (external vendor, self-hosted) to not misuse these credentials?
* Even if the MCP server is developed by internal developers, this is easy to get wrong, do we trust this code?
* Do we trust all of the various permutations of MCP servers (internal, developed by different teams, external/vendor self-hosted)? 
* Lastly, how do we revoke credentials/sessions for any of the MCP servers actively using user credentials? 

What if we could extract some of the sensitive parts of the elicitation into secure, trusted infrastructure? We can handle the user authorization out of band of the MCP server, safely store credentials for users across any MCP server, and then transparently inject them into any upstream API requests? This way, neither the MCP client nor the MCP server need to handle sensitive credential material. 


![](/images/mcp-auth-patterns/day5.png)


#### Here’s how it works:

* MCP client calls MCP server (ie, tool call) with their internal SSO token
* MCP server tool call requires upstream API call protected by external IdP
* *Agentgateway* applies policy to internal SSO. 
* Either the *agentgateway* exchanges the token ahead of time (`id-jag`, provider-specific, etc) or the *agentgateway* handles MCP url elicitations from the server (not the MCP client)
* MCP elicitation proceeds through a dedicated MCP Authorization Portal (notify user, handle callbacks, etc)
* No credentials are returned to MCP server, and *agentgateway* injects credentials when MCP server communicates upstream

![](/images/mcp-auth-patterns/agw-token-exchange.png)

There are a number of advantages to offloading elicitations to secure infrastructure:
<br>
✅ Can implement internal policy about what users can leverage external services<br>
✅ Keeps sensitive upstream credentials away from the MCP client (and MCP server if desired)<br>
✅ Options to simplify MCP server implementation for handling this<br>
✅ Can seamlessly adopt current/upcoming token exchange specs<br>

Here are some of the downsides:<br>
❌ May need to work ahead of the current MCP spec to make it flow nicely <br>
❌ Need to manage sensitive components (agentgateway, MCP auth portal, etc) 


Here's a demo of this in action:

<iframe width="560" height="315" src="https://www.youtube.com/embed/hHnxk-G72W4?si=m8s7XBxIkPLzqPTB" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>


## Upstream Authorization Patterns

AI agents in production should [force us to do auth right](https://blog.christianposta.com/ai-agents-are-not-like-microservices-or-monoliths/). When it comes to MCP authorization, it’s tempting to grab the first thing that works (like we did in the past): pass through a token, hardcode a service account, etc. Those patterns may get you started, but they won’t stand up to enterprise needs like auditability, fine-grained scoping, or secure delegation.

That’s why leveraging secure infrastructure is so powerful. It gives you a place to enforce enterprise policy, manage risk, and keep humans and agents aligned. More importantly, it sets you up for the long run: today you can support secure, enterprise-ready authorization, and tomorrow you’re positioned to layer in federated token exchange as IdP providers make that more seamless.

