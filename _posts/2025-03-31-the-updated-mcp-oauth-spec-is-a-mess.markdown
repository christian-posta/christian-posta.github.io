---
layout: post
title: The MCP Authorization Spec Is... a Mess for Enterprise
modified:
categories: 
comments: true
tags: [ai, mcp, security, authorization, enterprise, llm, tools, agentic, agents, oauth]
image:
  feature:
date: 2025-03-31T14:40:01+01:00
---

The [Model Context Protocol](https://spec.modelcontextprotocol.io/specification/2024-11-05/) has created quite the buzz in the AI ecosystem at the moment, but as enterprise organizations look to adopt it, they are confronted with a hard truth: it lacks important security functionality. Up until now, as people experiment with Agentic AI and tool support, they've mostly adopted the [MCP stdio transport](https://spec.modelcontextprotocol.io/specification/2024-11-05/basic/transports/#stdio), which means you end up with a 1:1 deployment of MCP server and MCP client. What organizations need is a way to deploy MCP servers remotely and leverage authorization to give resource owner's access to their data safely. 

To address this, the MCP specification recently introduced [MCP Authorization -- based on OAuth 2.1](https://spec.modelcontextprotocol.io/specification/2025-03-26/basic/authorization/). While this update aims to solve the security gap, it also introduces significant friction for enterprises. The new requirements place a heavy burden on MCP server implementors—one that may not integrate smoothly with existing security infrastructure, even when OAuth is already in place.




## The problem with the new MCP Authorization specification

The main problem the new MCP Authorization specification is that it couples two main OAuth concepts. It treats the MCP server as both [a _resource server_ AND an _authorization server_](https://www.oauth.com/oauth2-servers/definitions/). This has fundamental implications for MCP server developers and for runtime operations including:

* stateless vs stateful servers
* going against enterprise best practices
* additional complexity for mcp server developers
* varying security implementations which leads runtime and scale challenges

There is an [active discussion](https://github.com/modelcontextprotocol/specification/issues/205) around these challenges, and a [proposal to change the spec](https://github.com/modelcontextprotocol/specification/issues/195) to alleviate some of these concerns. In this blog I will go into some of the details and what we can do today to secure MCP servers. 




## The MCP Authorization Specification

The new [MCP Authorization](https://spec.modelcontextprotocol.io/specification/2025-03-26/basic/authorization/) from the [2025-03-26 revision of MCP](https://spec.modelcontextprotocol.io/specification/2025-03-26/) calls out the following requirements for MCP servers to implement Authorization with OAuth 2.1:

* MCP auth implementations MUST implement OAuth 2.1 (which [makes PKCE mandatory](https://oauth.net/2/pkce/))
* MCP auth SHOULD support [Dynamic Client Registration](https://oauth.net/2/dynamic-client-registration/)
* MCP servers SHOULD implement [Authorization Server Metadata](https://oauth.net/2/authorization-server-metadata/) 
* If MCP servers leverage a third-party authorization server, the MCP server MUST maintain a mapping of third-party tokens to MCP issued tokens





## Digging into the Details

Before we get into the MCP OAuth details, we should do a quick refresher on OAuth 2.x, especially how enterprises have adopted it. Enterprises prefer to keep the backend resources (APIs) stateless and horizontally scalable. When they leverage OAuth flows for authorization delegation, they do so through an Identity Provider (Auth0, Keycloak, Okta, etc). 

![](/images/mcp-oauth/oauth-flow.png)

The authentication and authorization delegation happens for the client and user ("resource owner") directly with the authorization server / Identity Provider (IdP). They eventually negotiate an access token that gets sent to the backend resources (APIs, applications, etc). The application then checks the validity of the access token, and then relies on its claims to determine authorizations. 

This separation of authorization server and resource keeps the resources free from complex security code, and centralizes security into best of breed tools. 





### Authorization endpoint discovery

The MCP OAuth specification blurs the distinction between a "resource server" and an "authorization server." In the [2.3 Server Metadata Discovery](https://spec.modelcontextprotocol.io/specification/2025-03-26/basic/authorization/#23-server-metadata-discovery) section, it states that an MCP server SHOULD support the [OAuth 2.0 Authorization Server Metadata](https://datatracker.ietf.org/doc/html/rfc8414) protocol. If it does not, it must expose the default endpoints:  

- `URL_BASE/authorize`  
- `URL_BASE/token`  
- `URL_BASE/register`  

![](/images/mcp-oauth/combined.png)

The Authorization Server Metadata protocol allows clients to discover OAuth endpoints dynamically. If an MCP server follows this protocol, its metadata would be accessible at:  

```
URL_BASE/.well-known/oauth-authorization-server
```  

For example:  

```json
{
  "issuer": "http://localhost:3000",
  "authorization_endpoint": "http://localhost:3000/authorize",
  "token_endpoint": "http://localhost:3000/token",
  "registration_endpoint": "http://localhost:3000/register",
  "scopes_supported": ["repo", "user", "read:org"],
  "response_types_supported": ["code"],
  "grant_types_supported": ["authorization_code"],
  "token_endpoint_auth_methods_supported": ["none"],
  "code_challenge_methods_supported": ["S256"]
}
```  

The issue? These "well-known" endpoints are traditionally hosted by the **authorization server**—typically an enterprise Identity Provider — not by individual resource servers. This design choice means every MCP server must expose its own metadata discovery URL, or potentially separate `/authorize`, `/token`, and `/register` endpoints. That creates unnecessary fragmentation, complicating client implementations and deviating from OAuth best practices.  

```
https://server1.mcp.com/.well-known/oauth-authorization-server
https://server2.mcp.com/.well-known/oauth-authorization-server
https://server3.mcp.com/.well-known/oauth-authorization-server
```




### Who implements the 'authorize' endpoints?

The spec specifies that if the Authorization Server Metadata protocol is not implement, then the MCP server should implement the default `/authorize`, `/token`, and `/register` endpoints. But how does it do that? Does it implement its own bespoke code for doing this? Does it issue it's own authorization codes and access tokens? 

Based on the diagrams from the spec ...

![](/images/mcp-oauth/mcp-flow.png)


…it certainly seems to suggest that MCP servers are responsible for managing their own authorization flow. But this raises a major issue. If an MCP server is expected to implement `/authorize` and `/token` itself, essentially acting as an OAuth provider, then it also takes on the responsibility of **issuing and managing tokens.** This is **extremely difficult to get right**, which is precisely why most organizations rely on dedicated Identity Providers (IdPs) for this task.  


In fact, [one of the reference implementations](https://blog.cloudflare.com/remote-model-context-protocol-servers-mcp/#why-do-mcp-servers-issue-their-own-tokens) does exactly that: issues its own tokens. From the blog on **"Why do MCP servers issue their own tokens"**:

> On the surface, this indirection might sound more complicated. Why does it work this way?
> By issuing its own token, MCP Servers can restrict access and enforce more granular controls than the upstream provider. If a token you issue to an MCP client is compromised, the attacker only gets the limited permissions you've explicitly granted through your MCP tools, not the full access of the original token.

This token handling and authorization-server responsibility makes the MCP server stateful (expected to manage tokens, etc) which makes it very difficult to scale and puts onerous requirements on the implementation to have safe backends (databases/caches, etc). What makes this worse, is any third-party MCP server you deploy would each be their own authorization server. This would be a non-starter in an enterprise organization.




### What if we just delegate to a provider?

What if, instead of hosting its own authorization endpoints, an MCP server simply advertised the locations of the `/authorize`, `/register`, and `/token` endpoints of an external IdP or OAuth server through its Authorization Server Metadata?  

For example, the MCP server’s metadata endpoint (`URL_BASE/.well-known/oauth-authorization-server`) could return:  

```json
{
  "issuer": "https://your-idp.com",
  "authorization_endpoint": "https://your-idp.com/authorize",
  "token_endpoint": "https://your-idp.com/token",
  "registration_endpoint": "https://your-idp.com/register",
  "scopes_supported": ["repo", "user", "read:org"],
  "response_types_supported": ["code"],
  "grant_types_supported": ["authorization_code"],
  "token_endpoint_auth_methods_supported": ["none"],
  "code_challenge_methods_supported": ["S256"]
}
```  

This setup aligns more closely with how enterprises typically operate, but it introduces **new complexities** under the MCP Authorization spec. Specifically, this approach falls under the [2.9 Third-Party Authorization](https://spec.modelcontextprotocol.io/specification/2025-03-26/basic/authorization/#29-third-party-authorization-flow) flow.  

The challenge? The spec outlines several requirements for handling third-party tokens:  

- **Mapping:** The MCP server must securely associate third-party tokens with its own issued tokens.  
- **Validation:** It must verify the third-party token’s status before honoring an MCP token.  
- **Lifecycle Management:** The MCP server is responsible for tracking token validity and enforcing lifecycle policies.  
- **Renewal:** It needs to handle token expiration and refresh processes appropriately.  

This means the MCP server isn’t just deferring authentication to an IdP—it’s also taking on significant token management responsibilities. As noted in [this comment from issue #205](https://github.com/modelcontextprotocol/specification/issues/205#issuecomment-2762850164), these requirements introduce real-world complexity that may not align with how OAuth is typically implemented.  



> 2.9.2 - This is complex. Just setting this up looks daunting, let alone doing so securely (...and I've worked on a popular OAuth library before).

> 2.9.2.6 - Requires that the MCP server is now stateful, and has access to all secure tokens (Now this component is heavily involved in every security audit)

> 2.9.3.1 - This requires a secure DB, which is an additional piece of infrastructure with high security demands.

> 2.9.3.2 - If the MCP client or underlying resource is performing token validation, this step may not be required and wasteful of resources (latency of extra round trips)

> 2.9.4.4 - Token chaining security means handling propagation delays on revocation and timing attacks, and who knows what else.





## So what can we do?

To properly integrate OAuth with MCP servers, we should align with enterprise best practices by separating the authorization server from the resource servers. While this may require deviating from the current MCP specification, it offers the best chance for enterprises to maintain security while keeping MCP servers stateless.  

In this approach, an enterprise would:  

- **Use its existing IdP systems** as the **authorization server**, supporting OAuth flows like authorization code or client credentials (or others).  
- **Have MCP servers act solely as resource servers**, verifying tokens issued by the IdP.  
- **Leverage an API gateway** (optional) to handle token validation, then use **machine-to-machine identities** (e.g., **SPIFFE/mTLS**) to securely transmit the validated token to the MCP server.  
- **Enforce RBAC within the MCP server**, based on the verified token.  

![](/images/mcp-oauth/enterprise-mcp.png)


One key question in the ongoing MCP Authorization discussion is: **How does an MCP server communicate to the MCP client which authorization server to use?** [In issue #205](https://github.com/modelcontextprotocol/specification/issues/205), a proposed solution is to return a `WWW-Authenticate` header when an unauthorized request is made, directing clients to the appropriate authorization server:  

```bash
HTTP/1.1 401 Unauthorized  
WWW-Authenticate: Bearer realm="example",  
                  error="invalid_token",  
                  error_description="The access token expired",  
                  authorization_uri="https://auth.example.com/oauth/authorize",  
                  discovery_uri="https://auth.example.com/.well-known/oauth-authorization-server",  
                  token_type="Bearer"
```  

We’re actively working with the community to **revise the MCP specification** to better address these enterprise security challenges. If this impacts your organization, we encourage you to [join the conversation](https://github.com/modelcontextprotocol/specification/issues/205) and help shape the future of MCP Authorization.  

