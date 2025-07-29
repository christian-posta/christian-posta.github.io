---
layout: post
title: Configuring A2A OAuth User Delegation
modified:
categories: 
comments: true
tags: [ai, rest, agents, agentic, capabilities, llm, architecture, mcp, tools, openapi, swagger, oas]
image:
  feature:
date: 2025-07-28T11:47:19-07:00
---

In this blog post, we'll walk through an [OAuth 2.0 token exchange](https://oauth.net/2/token-exchange/) and delegation to an [A2A Agent](https://a2aproject.github.io/A2A/latest/). We will focus on configuring the [A2A Agent Card](https://a2aproject.github.io/A2A/latest/specification/#5-agent-discovery-the-agent-card), implementing the agent in Python, and validating the [OAuth credentials](https://a2aproject.github.io/A2A/latest/specification/#43-clientuser-identity-authentication-process). At the end of this walk through, we'll have an A2A enabled agent that has a user's delegated/downscoped intended for specific skills of the agent. This token can be further exchanged to operate as the user including calling out to MCP tools. Source code for this demo [is on my GitHub](https://github.com/christian-posta/oauth-agent-flows/tree/main/agent_calculator). Digging into MCP Authorization is the next blog. Let's dig in.

> This is part of a much larger showcase of MCP / Agent2Agent identity, delegation, and authorization I'm working on. Please follow ([@christianposta](https://x.com/christianposta) or [/in/ceposta](https://linkedin.com/in/ceposta)) along if interested.

---

## Setting up the A2A Agent

For this example, we are using [FastAPI](https://fastapi.tiangolo.com) and the [FastAPI support in A2A's](https://github.com/a2aproject/a2a-python/blob/main/src/a2a/server/apps/jsonrpc/fastapi_app.py) python SDK.

```python
# Create A2A FastAPI app and integrate with existing app
a2a_app = A2AFastAPIApplication(
    agent_card=agent_card,
    http_handler=request_handler
)
```

Here we see a basic request_hanlder for the HTTP side of things ([see source code](https://github.com/christian-posta/oauth-agent-flows/tree/main/agent_calculator)) and we pass in an `agent_card`. Let's dig into what that is. 

### What is the AgentCard?

The AgentCard is how the agent advertises its capabilities, identity, and requirements to the outside world. Think of it as a self-describing contract. It includes metadata like the agent’s name, version, capabilities, and expected input/output modes—but more importantly, it describes the security expectations.

For clients to call this agent securely, they need to know **what kind of token to send** and **what scopes it must contain**. The AgentCard defines that precisely, so downstream tools like delegation frameworks and identity brokers can dynamically determine what kind of delegation or token exchange is needed.

---

### Configuring Security in the AgentCard

Here’s what that looks like in code:

```python
# Create agent card with authentication requirements
agent_card = AgentCard(
    ...
    securitySchemes={
        "Bearer": SecurityScheme(
            root=HTTPAuthSecurityScheme(
                type="http",
                scheme="bearer",
                bearerFormat="JWT",
                description="OAuth 2.0 JWT token with 'tax:calculate' scope required"
            )
        )
    },
    security=[
        {
            "Bearer": ["tax:calculate"]
        }
    ],
    ...
)
```


The `securitySchemes` section defines *how* the client can authenticate. In this case, the agent expects an HTTP Bearer token in JWT format. You could imagine this being issued by a system like Keycloak, Auth0, or a custom OIDC broker.

Then the `security` field outlines *what* that token must authorize. In our case, the agent requires a scope of `tax:calculate`. This gives us a nice clean contract: the agent declares what it needs, and the identity broker ensures the delegated token includes only that.

This mechanism also makes it possible to generate **agent-specific tokens** that follow the principle of least privilege—crucial in agentic systems where you don't want an agent with excessive access rights.

---

### Adding Middleware to Enforce Authentication

With FastAPI, one way to add JWT bearer token checking is through [Middleware](https://fastapi.tiangolo.com/tutorial/middleware/). We can add rules to exclude auth checking for the AgentCard and properly handle scenarios when the correct Bearer token is not present. If a token is found, then we need to validate it.

```python
@app.middleware("http")
async def auth_middleware(request, call_next):
    # Skip auth for docs & favicon
    if request.path in ["/docs", "/openapi.json", "/favicon.ico"]:
        return await call_next(request)

    # Handle A2A endpoints
    if request.path.startswith("/a2a"):
        if request.path == "/a2a/.well-known/agent.json":
            return await call_next(request)

        auth_header = request.headers.get("Authorization")
        if not auth_header:
            return Response(status_code=401, content="Missing Authorization header")

        if not auth_header.startswith("Bearer "):
            return Response(status_code=401, content="Invalid Authorization format")

        token = auth_header[7:]  # Strip "Bearer "
        decoded = await verify_token(token)
        request.state.user_token = decoded

    return await call_next(request)
```

This middleware intercepts every HTTP request and applies authentication logic to the A2A endpoints.

* **Bypasses Auth for Safe Routes**: The first check allows unauthenticated access to /docs, /openapi.json, and /favicon.ico. These are common public endpoints that don’t need protection.
* **Handles A2A Paths**: We only enforce authentication for requests targeting /a2a/*, which is the context path for A2A agent interactions.
* **AgentCard is Public**: The agent’s discovery endpoint (/a2a/.well-known/agent.json) is intentionally left unauthenticated—this allows clients to fetch the AgentCard before obtaining or exchanging a token.
* **Bearer Token Required**: All other A2A requests must include a valid Authorization header. If it's missing or incorrectly formatted, the middleware returns a 401 Unauthorized.
* **Token Validation**: If a properly formatted token is found, the middleware verifies it (via verify_token) and attaches the decoded result to `request.state.user_token`. This makes the user’s identity and scopes available downstream to the route handler.

This pattern ensures your agent safely accepts only scoped, valid JWTs—paving the way for delegated, auditable agent behavior.

---

## But What Kind of OAuth Token Should This Be?

When sending OAuth access tokens to Agents, [we need to be very careful](https://blog.christianposta.com/agent-identity-impersonation-or-delegation/). When a user logs in and authorizes a set of permissions to an OAuth client and then proceeds to instruct agents to work on behalf of the user, you will want to limit and be selective of what permissions go to which agents, based on skills.

Why? Because agents that act *on behalf of a user* can invoke tools, perform actions, and chain calls to other agents or services *as the user*. If you hand upstream agents a token with broad scopes, that’s a recipe for [agentic misalignment](https://www.anthropic.com/research/agentic-misalignment).

Instead, we follow a delegation flow using [OAuth 2.0 Token Exchange](https://tools.ietf.org/html/rfc8693). You take a user’s broad-scope access token and exchange it for a **narrow, fine-grained, downscoped** token for a specific agent (audience) and use case.


```bash
calculator_exchange_response = await client.post(
    f"{KEYCLOAK_URL}/realms/{REALM_NAME}/protocol/openid-connect/token",
    data={
        "grant_type": "urn:ietf:params:oauth:grant-type:token-exchange",
        "client_id": AGENT_TAX_OPTIMIZER_CLIENT_ID,
        "client_secret": agent_tax_optimizer_secret,
        "subject_token": tax_optimizer_token,
        "subject_token_type": "urn:ietf:params:oauth:token-type:access_token",
        "requested_token_type": "urn:ietf:params:oauth:token-type:access_token",
        "audience": AGENT_CALCULATOR_CLIENT_ID,
        "scope": "tax:calculate"
    },
    headers={"Content-Type": "application/x-www-form-urlencoded"}
)
```

For example, here’s what a downscoped token might look like:

```json
{
  "sub": "user-id",
  "aud": "agent-calculator",
  "scope": "tax:calculate",
  "preferred_username": "testuser",
  ...
}
```

This token is only valid for a specific agent (`aud = agent-calculator`) and only includes the `tax:calculate` permission. If the agent tries to do anything else on behalf of the user, ie, call another API, escalate access, etc it shouldn't work. 

This is how we align **security posture** with **agent capability**. By narrowing the delegation at the token level, we can safely compose powerful agentic workflows without introducing risk.

---

## Putting It All Together

Once the agent receives this token, it can proceed to call MCP servers or APIs using the delegated authority. If it needs to further act on behalf of the user, it can perform another token exchange or pass that identity downstream, [within the bounds of the original delegation](https://blog.christianposta.com/agent-identity-impersonation-or-delegation/).

This opens the door to safe, auditable **chained agent execution**, critical for enterprise use cases where human oversight, traceability, and tight auth boundaries are essential.

See the [full demo here](https://github.com/christian-posta/oauth-agent-flows/blob/main/agent_calculator/test_a2a_auth.py).  
