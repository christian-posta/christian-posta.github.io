---
layout: post
title: Understanding MCP Authorization, Step by Step, Part Three
modified:
categories: 
comments: true
tags: [ai, rest, agents, agentic, capabilities, llm, architecture, mcp, tools, openapi, swagger, oas]
image:
  feature:
date: 2025-07-05T10:20:10-04:00
---

This is the final post in a three-part series on [MCP Authorization](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization) following the June 2025 revisions. In the first two posts, we built an [MCP server with the HTTP transport](https://blog.christianposta.com/understanding-mcp-authorization-step-by-step/) and implemented the right OAuth [token handling and verification](https://blog.christianposta.com/understanding-mcp-authorization-step-by-step-part-two/). Up until now, we used a local identity provider (IdP) and in this post, we'll make the right updates to use a production IdP. For this post, we'll use the [Keycloak project](https://www.keycloak.org), but the same can be done with any other OAuth capable IdP. 


---

Generally, in this series of blog posts (three parts + [source code](https://github.com/christian-posta/mcp-auth-step-by-step)), we'll walk "step-by-step" through the latest MCP Authorization spec and implement it. I have made all of the [source code for each of the steps available on GitHub](https://github.com/christian-posta/mcp-auth-step-by-step).

* Part 1: [Implement a spec compliant remote MCP server with HTTP Transport](https://blog.christianposta.com/understanding-mcp-authorization-step-by-step/)
* Part 2: [Layer in Authorization specification with OAuth 2.1](https://blog.christianposta.com/understanding-mcp-authorization-step-by-step-part-two/)
* Part 3: (This) Bring in a production Identity Provider (Keycloak)

Follow ([@christianposta](https://x.com/christianposta) or [/in/ceposta](https://linkedin.com/in/ceposta)) for the next parts. 

---

## Recap

Let's recap where we left off from the previous post. We implemented the following using a local IdP (ie, local keys):

* JWT validation including checking issuer, audience, expiration, etc
* Respond with WWW-Authenticate, pointing to OAuth protected resource
* Implement the OAuth protected resource endpoint `/.well-known/oauth-protected-resource`
* Enforce scopes on the MCP capabilities

There were 8 previous steps that we took to get to this point. In these last two steps, step 9 and 10, we'll update the MCP server code to use [Keycloak](https://www.keycloak.org).

## Step 9: Setting up Keycloak 

Follow along with the source code [for this step](https://github.com/christian-posta/mcp-auth-step-by-step/blob/main/src/mcp_http/step9.py). 

In our environment, we are going to set up the Keycloak server with the following settings:

* an `mcp-realm` realm
* a single, public, OAuth client: `mcp-test-client`
* a few scopes: `mcp:read`, `mcp:tools`, `mcp:prompts`
* a scope-mapper to control the correct audience for the MCP server: `echo-mcp-server`
* three test users: `mcp-admin`, `mcp-user`, `mcp-readonly`

You can see the full [config.json](https://github.com/christian-posta/mcp-auth-step-by-step/blob/main/keycloak/config.json) file to see the exact details. 

If you run the following, Keycloak will be started as a Docker container with the correct settings mentioned above:

```bash
❯ uv run step9
```

You can verify Keycloak was set up correctly and can get the right tokens with the following script:

```bash
❯ ./test_step9.sh

ℹ️  Key fields:
ℹ️    Issuer: http://localhost:8080/realms/mcp-realm
ℹ️    Audience: echo-mcp-server
ℹ️    Subject: b6046365-9438-4975-8957-e6b50352a2b9
ℹ️    Username: mcp-readonly
ℹ️    Scope: openid email mcp:read echo-mcp-server-audience profile
✅ Token audience verification passed: echo-mcp-server
ℹ️  Token scopes: openid email mcp:read echo-mcp-server-audience profile
✅ Token acquisition and validation passed for mcp-readonly
✅ === Step 9 Keycloak verification and token testing completed successfully! ===
ℹ️  Keycloak URL: http://localhost:8080
ℹ️  Keycloak Realm: mcp-realm
ℹ️  Client ID: mcp-test-client
ℹ️  Test users: mcp-admin, mcp-user, mcp-readonly
ℹ️  All tokens have correct audience: echo-mcp-server
ℹ️  Ready for Step 10: MCP Server with Keycloak Integration
```

Of particular note is the JWT access token that Keycloak returns:

Payload:

```json
{
  "exp": 1751490842,
  "iat": 1751487242,
  "jti": "onrtro:6dc1938a-0810-48d1-b904-a3cc25bb428b",
  "iss": "http://localhost:8080/realms/mcp-realm",
  "aud": "echo-mcp-server",
  "sub": "b6046365-9438-4975-8957-e6b50352a2b9",
  "typ": "Bearer",
  "azp": "mcp-test-client",
  "sid": "5a3a1ea3-de69-425a-b1ae-2b5676ef74a0",
  "acr": "1",
  "scope": "openid email mcp:read echo-mcp-server-audience profile",
  "email_verified": true,
  "name": "MCP ReadOnly",
  "preferred_username": "mcp-readonly",
  "given_name": "MCP",
  "family_name": "ReadOnly",
  "email": "readonly@mcp.example.com"
}
```

Note that the `aud` claim is set to the `echo-mcp-server` which will the intended audience. Keycloak (at the time of this writing) does not support [RFC 8707 Resource Indicators for OAuth](https://www.rfc-editor.org/rfc/rfc8707.html) so we rely on the scope mapping defined in Keycloak. 

At this point, we have a Keycloak IdP configured to support our MCP client and MCP server. Let's update out implementation in the next step:



## Step 10: Updating MCP Server to use Keycloak for Authorization

Follow along with the source code [for this step](https://github.com/christian-posta/mcp-auth-step-by-step/blob/main/src/mcp_http/step10.py). 

To update our MCP Server from Step 8 to use Keycloak, we need to specify our environment to use Keycloak in its configuration:


```python
KEYCLOAK_URL = "http://localhost:8080"
KEYCLOAK_REALM = "mcp-realm"
JWT_ISSUER = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}"
JWT_AUDIENCE = ["echo-mcp-server"] 
```

We need to update our code for which public key to use to point to Keycloak's JWKS. From there we can grab the public key:

```python
async def fetch_keycloak_jwks(self) -> Dict[str, Any]:
    
    jwks_url = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/certs"
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(jwks_url)
            response.raise_for_status()
            jwks_data = response.json()
                            
            return jwks_data
```

Now that we are using the Keycloak JWKS and public key, we can get rid of that endpoint from our implementation (including the `oauth-authorization-server` metadata). Delete these functions:

```python
@self.app.get("/.well-known/oauth-authorization-server")
async def authorization_server_metadata():


@self.app.get("/.well-known/jwks.json")
async def jwks_endpoint():

```

We will need to update our verification function to verify the right Issuer and Audience. Note, we are expecting the right `aud` claim to be `echo-mcp-server` so any clients retrieving a token must take this into account, or the JWT will be invalid for this MCP server. We could even try to verify the `azp` claim if we want even tighter control over which MCP clients can call this MCP server. 

```python
async def verify_token(
    self,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
) -> Dict[str, Any]:
        ...
        ...
        ...
        payload = jwt.decode(
            token,
            public_key_pem,
            algorithms=["RS256"],
            audience=JWT_AUDIENCE,
            issuer=JWT_ISSUER,
            options={"verify_signature": True, "verify_exp": True, "verify_iat": False}
        )
    
    scopes = payload['scopes']
    
    # Add scopes to payload for consistency
    payload['scopes'] = scopes
    
    username = payload.get('preferred_username', payload.get('sub', 'unknown'))
    
    return payload
```

The last piece of the puzzle is to update our `oauth-protected-resource` metadata document to point the `authorization_servers` list to Keycloak:

```python
@self.app.get("/.well-known/oauth-protected-resource")
async def protected_resource_metadata():
    """OAuth 2.0 Protected Resource Metadata (RFC 9728)."""
    return {
        "resource": MCP_SERVER_URL,
        "authorization_servers": [f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/.well-known/oauth-authorization-server"],
        "scopes_supported": ["mcp:read", "mcp:tools", "mcp:prompts"],
        "bearer_methods_supported": ["header"],
        "resource_documentation": f"{MCP_SERVER_URL}/docs",
        "mcp_protocol_version": "2025-06-18",
        "resource_type": "mcp-server"
    }
```

And that's it! Now we have a fully functional and MCP-spec compliant Authorization implementation on our MCP server. We can test with the following script:

```bash
❯ ./test_step10.sh

✅ === Step 10 Keycloak integration test completed successfully! ===
ℹ️   Keycloak URL: http://localhost:8080
ℹ️   Keycloak Realm: mcp-realm
ℹ️   MCP Server URL: http://localhost:9000
ℹ️   Test users: mcp-admin, mcp-user, mcp-readonly
ℹ️   Stopping MCP server (PID: 6813)...
```


## Final Touches

At this point, you’ve got a working, standards-compliant MCP server that delegates auth responsibilities to a real-world OAuth 2.1 Identity Provider (in this case, Keycloak). You’re:

* Validating tokens with the right `aud` and `iss`
* Pulling JWKS dynamically
* Enforcing scopes and aligning them with real users and roles
* Advertising the protected resource and auth server metadata

A few optional finishing touches you might consider:

* Add support for refresh tokens — helpful for longer-lived sessions or interactive use.
* Use Dynamic Client Registration - simplifies MCP client registration to the IdP
* Log JWT validation failures clearly — aids in debugging and securing your service.
* Externalize config values — right now they’re in code; consider env vars or a config service.
* Automate end-to-end tests — especially when validating token flows and failure modes.

## Where to go from here?

This wraps up the “step-by-step” foundation of building an MCP-compliant server using MCP Authorization. But there’s still more to explore, especially as the spec evolves and adoption increases:

**Dynamic Client Registration**
Allowing clients to register with the Authorization Server dynamically (e.g., via [RFC 7591](https://datatracker.ietf.org/doc/html/rfc7591)) would make onboarding agents smoother in multi-tenant or dynamic environments.

**Resource Indicators (RFC 8707)**
Right now, we're faking the `aud` claim via scope mapping in Keycloak. When Keycloak supports [RFC 8707](https://www.rfc-editor.org/rfc/rfc8707.html), it’ll allow cleaner and more secure token issuance per resource, making multi-tenant deployments more manageable.


**Human-in-the-loop & Delegation Flows**
As AI agents adopt MCP, expect richer delegation scenarios. Specs like [OIDC CIBA](https://blog.christianposta.com/ai-agents-and-oidc-ciba/) and structured authorization layers will be essential.


That’s it for this series. If this was helpful, or you’re building on top of MCP for AI or app interoperability, I’d love to hear from you — [@christianposta](https://x.com/christianposta) or [/in/ceposta](https://linkedin.com/in/ceposta).

And stay tuned: up next, we'll look at A2A authentication and authorization!
