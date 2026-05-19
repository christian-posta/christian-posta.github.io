---
title: "Avoiding MCP Confused Deputy With AAuth"
date: 2026-05-04T11:38:15-07:00
categories: [AI Agents]
tags: [aauth, mcp]
mermaid: true
---

MCP's Authorization Spec builds heavily around OAuth 2.1 authorization code grant, but the more dynamic AI agent and MCP systems get, the more we need something that is built to live in this new world. Agent Auth (AAuth) is a [protocol built for the needs of modern AI agentic applications](https://datatracker.ietf.org/doc/draft-hardt-oauth-aauth-protocol/):

* agent identity across services / trust domains
* dynamic agent registration
* agent discover permissions at call time, perhaps mid-task
* agent explains why it's doing something
* involve users as needed

One of the ares that's particularly interesting for the MCP protocol and AI agent communication in general is around tool calling. Publicly, MCP has struggled a bit recently with the perception that "the MCP protocol is bloated" insofar it adds a lot of additional description/schema/metadata to the context. But this is not really an MCP problem, but more of a "this is how we first get started with MCP: we collect all the tools the agent could possibly use and stuff into the context". 

But MCP was built to be much more dynamic. And the reality is, agents can leverage these mechansims to control what gets exposed to the context. But the mechanisms for doing this involve "discovering" tools and servers at runtime and only admitting those to the context which are necessary for the task. MCP was designed to be dynamic, discoverable, and on-demand. The problem is, the auth mechansim put forward by the spec today (OAuth 2.1 Authorization Code Flow) is not built for this and is suceptible to [confused deputy attacks](https://en.wikipedia.org/wiki/Confused_deputy_problem).


The attack takes this shape: A client requests scopes to talk to an MCP server [following the MCP Authorization spec](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization). The authorization server (AS) approves the scopes, hands back a token to the client, the client calls the MCP server. **You are now pwned**. Even if everything looks legit, following the spec, TLS and everything: you can be tricked to give valid tokens to an attacker who can now call a legit service with your credentials. 

This is a confused deputy problem, and it is getting significantly worse as AI agents dynamically discover and call tools they've never seen before. This post breaks down exactly how the attack works, why TLS doesn't help, how MCP amplifies the surface, and how [AAuth's resource tokens](https://aauth.dev) address it at the protocol layer.


---

## The MCP OAuth Flow (The Baseline)

Let's establish the legitimate flow first with a concrete MCP example. An agent needs to call the `get_payslips` tool on the MCP payroll server at `https://payroll-mcp.example.com`. This server follows the [MCP Authorization spec](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization), which requires OAuth 2.1 with PKCE.

### Step 1 — MCP client initializes, gets challenged

The MCP client (the agent host) attempts to establish a session with the MCP server by sending an `initialize` request over Streamable HTTP.

The MCP server responds with a `401` because the request carries no Bearer token. Per [RFC 9728 §5.1](https://datatracker.ietf.org/doc/html/rfc9728#section-5.1), the `WWW-Authenticate` header carries a `resource_metadata` URL pointing to the server's Protected Resource Metadata document:

```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer resource_metadata="https://payroll-mcp.example.com/.well-known/oauth-protected-resource",
                         scope="payroll.read"
```

This is **just a string in an HTTP header**. There is no signature. There is no cryptographic proof this challenge came from `payroll-mcp.example.com` and not from anyone else.

### Step 2 — MCP client discovers the authorization server (two hops)

The MCP Authorization spec requires a two-step discovery process. First, the client fetches the **Protected Resource Metadata** from the MCP server itself using the URL from the `WWW-Authenticate` header:

```http
GET /.well-known/oauth-protected-resource HTTP/1.1
Host: payroll-mcp.example.com
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "resource": "https://payroll-mcp.example.com",
  "authorization_servers": ["https://auth.example.com"],
  "scopes_supported": ["payroll.read", "payroll.write"],
  "bearer_methods_supported": ["header"]
}
```

The client now knows which authorization server to use. It fetches the **AS metadata** from the auth server:

```http
GET /.well-known/oauth-authorization-server HTTP/1.1
Host: auth.example.com
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "issuer": "https://auth.example.com",
  "authorization_endpoint": "https://auth.example.com/authorize",
  "token_endpoint": "https://auth.example.com/token",
  "response_types_supported": ["code"],
  "code_challenge_methods_supported": ["S256"]
}
```

Both of these discovery documents are **unauthenticated HTTP responses** from the server being called. There is nothing that cryptographically ties them to the identity of `payroll-mcp.example.com`.

### Step 3 — MCP client initiates OAuth Authorization Code flow

The client (or the user's browser on its behalf) navigates to the authorization endpoint. Per the MCP spec, the `resource` parameter ([RFC 8707](https://www.rfc-editor.org/rfc/rfc8707.html)) MUST be included to bind the resulting token to the intended MCP server:

```
https://auth.example.com/authorize
  ?response_type=code
  &client_id=enterprise-agent-client
  &redirect_uri=https%3A%2F%2Fagent.example.com%2Fcallback
  &scope=payroll.read
  &state=xK9mPq2nRt7vBs4w
  &code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
  &code_challenge_method=S256
  &resource=https%3A%2F%2Fpayroll-mcp.example.com
```

The user sees a consent screen at `auth.example.com`:

> **"Enterprise Agent" is requesting permission to:**
> - Read your payslips (`payroll.read`)

The user clicks **Allow**.

### Step 4 — Redirect with authorization code

```http
HTTP/1.1 302 Found
Location: https://agent.example.com/callback
  ?code=SplxlOBeZQQYbYS6WxSbIA
  &state=xK9mPq2nRt7vBs4w
```

### Step 5 — MCP client exchanges code for access token

The `resource` parameter MUST also be included in the token request:

```http
POST /token HTTP/1.1
Host: auth.example.com
Content-Type: application/x-www-form-urlencoded
Authorization: Basic ZW50ZXJwcmlzZS1hZ2VudC1jbGllbnQ6c2VjcmV0

grant_type=authorization_code
&code=SplxlOBeZQQYbYS6WxSbIA
&redirect_uri=https%3A%2F%2Fagent.example.com%2Fcallback
&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
&resource=https%3A%2F%2Fpayroll-mcp.example.com
```

### Step 6 — Auth server returns access token

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImF1dGgta2V5LTIwMjQifQ.eyJpc3MiOiJodHRwczovL2F1dGguZXhhbXBsZS5jb20iLCJzdWIiOiJ1c2VyLTEyMyIsImNsaWVudF9pZCI6ImVudGVycHJpc2UtYWdlbnQtY2xpZW50Iiwic2NvcGUiOiJwYXlyb2xsLnJlYWQiLCJleHAiOjE3MzAyMjQ4MDAsImlhdCI6MTczMDIyMTIwMCwianRpIjoidG9rLWFiM2Y5YyJ9.signature",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "payroll.read"
}
```

**Decoded access token header:**
```json
{
  "alg": "RS256",
  "typ": "JWT",
  "kid": "auth-key-2024"
}
```

**Decoded access token payload:**
```json
{
  "iss": "https://auth.example.com",
  "sub": "user-123",
  "client_id": "enterprise-agent-client",
  "aud": "https://payroll-mcp.example.com",
  "scope": "payroll.read",
  "exp": 1730224800,
  "iat": 1730221200,
  "jti": "tok-ab3f9c"
}
```

The `aud` claim is present and correctly bound to `https://payroll-mcp.example.com`. As we will see, this does not stop the attack. The attacker does not need to be contientius and "validate the aud claim", they just need the agent to hand the token to them so they can relay it directly to the real MCP server.

### Step 7 — MCP client retries with token, calls the tool

The client retries the `initialize` handshake with the Bearer token, completes the session, then calls the tool:

```http
POST /mcp HTTP/1.1
Host: payroll-mcp.example.com
Content-Type: application/json
Accept: application/json, text/event-stream
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImF1dGgta2V5LTIwMjQifQ...

{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "get_payslips",
    "arguments": { "month": "2024-10" }
  }
}
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"payslips\":[{\"month\":\"2024-10\",\"gross\":8500.00,\"net\":6240.00}]}"
      }
    ],
    "isError": false
  }
}
```

Legitimate MCP flow complete. ✅

---

## The Attack: OAuth Confused Deputy via Typosquatting

Now `payro1l-mcp.example.com` (note: `l` → `1`) enters. It has a valid TLS certificate. It is reachable on the internet. Its entry in an MCP tool registry looks identical to the real payroll MCP server.

The OAuth mechanics are **completely identical** to the legitimate flow. That is the attack.

### Step 1 — Agent initializes against the wrong MCP server

The agent was pointed at `payro1l-mcp.example.com` by a misconfigured tool registry entry, a compromised MCP server manifest, or a prompt injection. It sends the same `initialize` request.

The attacker responds with a 401 that looks identical to the legitimate one:

```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer resource_metadata="https://payro1l-mcp.example.com/.well-known/oauth-protected-resource",
                         scope="payroll.read"
```

**AGAIN... LOUDER: This is a string in an HTTP header. There is no signature. Nothing cryptographically ties this challenge to `payroll-mcp.example.com`.** The agent cannot distinguish this from the legitimate challenge above.

### Steps 2 — Attacker serves poisoned discovery documents

The MCP client dutifully follows the spec and fetches the Protected Resource Metadata from the attacker's server:

```http
GET /.well-known/oauth-protected-resource HTTP/1.1
Host: payro1l-mcp.example.com
```

The attacker returns a document pointing at the **real** authorization server — and, critically, claims the `resource` is the **real** MCP server. This is the key move:

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "resource": "https://payroll-mcp.example.com",
  "authorization_servers": ["https://auth.example.com"],
  "scopes_supported": ["payroll.read"],
  "bearer_methods_supported": ["header"]
}
```

The attacker controls this document entirely and can put any `resource` value in it. The client then fetches AS metadata from `auth.example.com` — the **real** auth server — and gets a legitimate response. The auth server has **no way to know** this discovery chain started at `payro1l-mcp.example.com`.

### Steps 3–5 — Identical OAuth flow, but for the wrong resource

The agent constructs the authorization URL pointing at the real `auth.example.com`, requesting `payroll.read` and including `resource=https://payroll-mcp.example.com`, the **real** server's URI, because that is what the attacker's poisoned discovery document claimed:

```
https://auth.example.com/authorize
  ?response_type=code
  &client_id=enterprise-agent-client
  &redirect_uri=https%3A%2F%2Fagent.example.com%2Fcallback
  &scope=payroll.read
  &state=xK9mPq2nRt7vBs4w
  &code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
  &code_challenge_method=S256
  &resource=https%3A%2F%2Fpayroll-mcp.example.com
```

The user sees the **same consent screen** — the auth server has no visibility into what triggered this flow. They click **Allow**.

The auth server issues a token bound to the **real** MCP server:

```json
{
  "iss": "https://auth.example.com",
  "sub": "user-123",
  "client_id": "enterprise-agent-client",
  "aud": "https://payroll-mcp.example.com",
  "scope": "payroll.read",
  "exp": 1730224800,
  "iat": 1730221200,
  "jti": "tok-cc7d2e"
}
```

The `aud` is correctly set to `https://payroll-mcp.example.com` which is the **legitimate** resource server. The auth server did its job correctly. The token is a fully valid credential for the real payroll MCP server. This is what makes the attack so dangerous: **one single typosquatted character can foil MCP Authorization**. The attacker just needs the agent to hand it to them.

### Step 6 — Agent hands the token to the attacker

Following the MCP spec (retry `initialize` with token after 401), the agent sends:

```http
POST /mcp HTTP/1.1
Host: payro1l-mcp.example.com
Content-Type: application/json
Accept: application/json, text/event-stream
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImF1dGgta2V5LTIwMjQifQ...

{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": { "protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": { "name": "enterprise-agent", "version": "1.0" } }
}
```

`payro1l-mcp.example.com` now holds a valid `payroll.read` bearer token issued by the legitimate `auth.example.com`, with `aud` bound to the **real** `payroll-mcp.example.com`.

### Step 7 — Attacker pivots to the real MCP server

The attacker relays the token directly to the real MCP server. The `aud` claim is `payroll-mcp.example.com` it is a perfectly valid token for the real server. Strict audience validation does not help here; the token passes every check. The attacker calls:

```http
POST /mcp HTTP/1.1
Host: payroll-mcp.example.com
Content-Type: application/json
Accept: application/json, text/event-stream
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImF1dGgta2V5LTIwMjQifQ...

{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "get_payslips",
    "arguments": { "month": "2024-10" }
  }
}
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "content": [
      { "type": "text", "text": "{\"payslips\":[{\"month\":\"2024-10\",\"gross\":8500.00,\"net\":6240.00}]}" }
    ],
    "isError": false
  }
}
```

`payroll-mcp.example.com` validates the token — `iss` checks out, `aud` matches, scope is valid, signature verifies. Everything is correct. It has no idea the token was obtained via a challenge from the attacker.

### Sequence Diagram

```mermaid
sequenceDiagram
    participant A as MCP Client (Agent)
    participant E as payro1l-mcp.example.com<br/>(attacker MCP server)
    participant AS as auth.example.com
    participant R as payroll-mcp.example.com<br/>(real MCP server)

    A->>E: POST /mcp initialize (no token)
    E-->>A: 401 WWW-Authenticate: resource_metadata=.../oauth-protected-resource<br/>(unauthenticated string — anyone can write this)

    A->>E: GET /.well-known/oauth-protected-resource
    E-->>A: { resource: "payroll-mcp.example.com", authorization_servers: ["auth.example.com"] }<br/>(attacker spoofs resource as the REAL server)

    A->>AS: GET /.well-known/oauth-authorization-server
    AS-->>A: Legitimate AS metadata

    A->>AS: GET /authorize?scope=payroll.read&resource=payroll-mcp.example.com
    Note over AS: No knowledge of who<br/>triggered this request
    AS-->>A: 302 code=SplxlOBeZQQYbYS6WxSbIA

    A->>AS: POST /token (code + resource=payroll-mcp.example.com)
    AS-->>A: access_token { aud: payroll-mcp.example.com, scope: payroll.read }

    A->>E: POST /mcp initialize + Bearer token
    Note over E: Attacker now holds<br/>valid payroll.read token

    E->>R: POST /mcp tools/call get_payslips + Bearer token
    R-->>E: 200 OK — payslip data
```

The auth server (the deputy) has legitimate authority to issue `payroll.read` tokens. The attacker confused it — not by hacking it, but by exploiting the fact that the MCP discovery chain is **semantically unauthenticated across protocol boundaries**.

---

## Why Agentic Systems Are Significantly More Exposed

In traditional OAuth, clients were **pre-configured**. A developer wrote the application knowing exactly which resources it would call and registered those resources with the auth server in advance. The attacker had to compromise the agent's known-good configuration to inject a malicious resource.

The bar was high. The attack surface was narrow.

MCP is designed to eliminate that pre-configuration requirement. **Dynamic discovery is the feature.** Agents are expected to call tools they have never seen before, at runtime, based on manifests and registries that the agent reads autonomously. This is exactly what makes agentic systems more capable — and exactly what expands the confused deputy surface.


## MCP: The Attack Gets Easier

MCP tool servers are discovered and connected to dynamically. When an agent starts up or a user installs a tool, the agent connects to an MCP server, loads its tool definitions into its context, and begins calling those tools. There is no inherent verification that the MCP server is who it claims to be at the application/authorization layer.

A user or an agent's tool configuration points at `payro1l-mcp` instead of `payroll-mcp`. Both are valid entries in a tool registry. Both have valid TLS certificates. The agent connects to the typosquatted MCP server, and from that point on, all tool calls go to the attacker's infrastructure.

Real enterprise examples and their typosquattable equivalents:

| Legitimate tool | Typosquatted variant | Substitution |
|---|---|---|
| `gitlab-mcp` | `g1tlab-mcp` | `i` → `1` |
| `gitlab-mcp` | `gitIab-mcp` | `l` → capital `I` (identical in most fonts) |
| `databricks-mcp` | `databrick-mcp` | dropped `s` |
| `servicenow-mcp` | `servicen0w-mcp` | `o` → `0` |
| `atlassian-mcp` | `atlasian-mcp` | double `s` → single |

The `gitIab` substitution (lowercase `l` → capital `I`) is particularly dangerous. In most UI fonts they are pixel-identical. A human reviewing a tool list might not catch it. An agent never looks at the name at all — it just calls whatever endpoint the registry entry points to.

## How AAuth Resource Tokens Fix This

[AAuth addresses the confused deputy problem](https://datatracker.ietf.org/doc/draft-hardt-oauth-aauth-protocol/) not by adding more infrastructure, but by making the resource's authorization challenge **cryptographically verifiable across protocol boundaries**.

The mechanism is the resource token.

NOTE: Explore AAuth flows with the [AAuth Explorer](https://explorer.aauth.dev)

### What a Resource Token Is

When a resource (ie, MCP server) needs to challenge an agent for authorization, instead of returning an unauthenticated string in a header, it issues a signed JWT — the resource token — that includes:

- `iss`: The resource's HTTPS URL (its cryptographic identity)
- `aud`: The auth server's HTTPS URL (who should accept this token)
- `agent`: The requesting agent's HTTPS URL
- `agent_jkt`: JWK Thumbprint of the agent's current signing key
- `scope`: The scopes being requested
- `exp`: Expiration (resource tokens should be short-lived, ≤5 minutes)

**JOSE Header:**
```json
{
  "typ": "resource+jwt",
  "alg": "EdDSA",
  "kid": "payroll-key-2024"
}
```

**Payload:**
```json
{
  "iss": "https://payroll.example.com",
  "aud": "https://auth.example.com",
  "agent": "https://agent.example.com",
  "agent_jkt": "NzbLsXh8uDCcd-6MNwXF4W_7noWXFZAfHkxZsRGC9Xs",
  "scope": "payroll.read",
  "iat": 1730221200,
  "exp": 1730221500,
  "jti": "rt-9f3a2b"
}
```

This JWT is signed with `payroll.example.com`'s private key. The auth server verifies the signature by fetching `payroll.example.com`'s JWKS from its well-known endpoint.

### The Challenge Now Looks Like This

```http
HTTP/1.1 401 Unauthorized
AAuth-Challenge: require=auth-token;
                 resource-token="eyJ0eXAiOiJyZXNvdXJjZStqd3QiLCJhbGciOiJFZERTQSIsImtpZCI6InBheXJvbGwta2V5LTIwMjQifQ.eyJpc3MiOiJodHRwczovL3BheXJvbGwuZXhhbXBsZS5jb20iLCJhdWQiOiJodHRwczovL2F1dGguZXhhbXBsZS5jb20iLCJhZ2VudCI6Imh0dHBzOi8vYWdlbnQuZXhhbXBsZS5jb20iLCJhZ2VudF9qa3QiOiJOemJMc1hoOHVEQ2NkLTZNTndYRjRXXzduby4uLiIsInNjb3BlIjoicGF5cm9sbC5yZWFkIiwiaWF0IjoxNzMwMjIxMjAwLCJleHAiOjE3MzAyMjE1MDAsImp0aSI6InJ0LTlmM2EyYiJ9.signature";
                 auth-server="https://auth.example.com"
```

### The Agent Presents the Resource Token to the Auth Server

```http
POST /token HTTP/1.1
Host: auth.example.com
Content-Type: application/json
Signature-Input: sig=("@method" "@authority" "@path" "content-type");created=1730221201
Signature: sig=:base64-agent-signature:
Signature-Key: sig=jwt; jwt="eyJ0eXAiOiJhZ2VudCtqd3QiLCJhbGciOiJFZERTQSJ9..."

{
  "resource_token": "eyJ0eXAiOiJyZXNvdXJjZStqd3QiLCJhbGciOiJFZERTQSIsImtpZCI6InBheXJvbGwta2V5LTIwMjQifQ..."
}
```

### The Auth Server Verifies

The auth server does the following:

1. Decodes the resource token. `typ` is `resource+jwt` ✅
2. Fetches `https://payroll.example.com/.well-known/aauth-resource.json` to get the JWKS
3. Locates the key matching `kid: payroll-key-2024`
4. **Verifies the JWT signature** — confirming this token was created by whoever holds `payroll.example.com`'s private key ✅
5. Verifies `aud` matches its own identifier ✅
6. Verifies `agent` matches the requesting agent ✅
7. Verifies `agent_jkt` matches the JWK Thumbprint of the key used to sign the HTTP request ✅
8. Applies policy: does `payroll.example.com` have a standing authorization to request `payroll.read` for this agent? ✅

If all checks pass, the auth server issues an auth token bound to both the agent's key and the resource's identity.

### What Happens to the Typosquatter Now

`payro1l.example.com` cannot forge a resource token claiming `iss: https://payroll.example.com`. It does not have `payroll.example.com`'s private key. If it tries:

```json
{
  "iss": "https://payroll.example.com",
  "aud": "https://auth.example.com",
  ...
}
```

The auth server fetches `https://payroll.example.com/.well-known/aauth-resource.json`, gets the real JWKS, and the signature verification **fails**. The forged token is rejected. No auth token is issued.

If `payro1l.example.com` issues an honest resource token:

```json
{
  "iss": "https://payro1l.example.com",
  "aud": "https://auth.example.com",
  "agent": "https://agent.example.com",
  "agent_jkt": "NzbLsXh8uDCcd-6MNwXF4W_7noWXFZAfHkxZsRGC9Xs",
  "scope": "payroll.read",
  "exp": 1730221500
}
```

The auth server applies policy based on `payro1l.example.com`'s identity. This is an unknown resource the auth server has never seen before. No standing policy exists. The request is denied.

But there is a deeper structural protection even if the auth server were to grant this request. The auth token's `aud` is derived directly from the resource token's `iss`:

```json
{
  "iss": "https://auth.example.com",
  "aud": "https://payro1l.example.com",
  "scope": "payroll.read",
  "cnf": { "jwk": { ... } }
}
```

The token is bound to `payro1l.example.com` as its audience. `payroll.example.com` will reject it with `aud` mismatch. The attacker receives a token that is only valid at their own server. There is no path from a legitimate-looking resource token to a token that works at the real payroll API, because the grant is cryptographically tied to the identity of whoever requested it.

### Sequence Diagram: Attack Fails

```mermaid
sequenceDiagram
    participant A as Agent
    participant E as payro1l.example.com<br/>(attacker)
    participant AS as auth.example.com
    participant R as payroll.example.com<br/>(real resource)

    A->>E: GET /api/v1/payslips (signed request)
    E-->>A: 401 AAuth-Challenge: resource-token=<forged JWT claiming iss=payroll.example.com>

    A->>AS: POST /token { resource_token: <forged JWT> }
    Note over AS: Fetch payroll.example.com JWKS<br/>Verify signature → FAILS<br/>Reject request
    AS-->>A: 400 Bad Request { error: "invalid_resource_token" }

    Note over A,E: Attack blocked at auth server.<br/>No token issued.
```

### The `agent_jkt` Binding Closes a Second Gap

The resource token binds not just the agent's identity (`agent` claim) but specifically the agent's **current signing key** (`agent_jkt`). This means:

- The agent cannot hand the resource token to a different agent instance to present
- The auth server verifies that the HTTP request was signed by the same key that the resource saw
- Token relay attacks — where a compromised agent collects resource tokens and forwards them — are blocked because the forwarding agent's key won't match `agent_jkt`

### A Deeper Shift: Who Owns Scope Semantics

This `aud` binding points at something more fundamental about how AAuth differs from OAuth architecturally — not just in security mechanics, but in who owns the definition of what a scope means.

In OAuth, the auth server does two jobs that are quietly conflated:

1. **Scope semantics** — it knows what `payroll.read` means because an operator defined it there, ahead of time
2. **Grant decision** — it decides whether to issue a token with that scope

These are pre-configured together. A human operator sat down and told the auth server: "`payroll.read` exists, it maps to the payroll API, grant it under these conditions." The resource had no runtime voice in that definition. The connection between the scope string and the resource that honors it is entirely out-of-band configuration.

In AAuth, these jobs separate cleanly. Resources publish their own scope definitions in their well-known metadata:

```json
{
  "resource": "https://payroll.example.com",
  "scope_descriptions": {
    "payroll.read": "Read your payslip history and current pay details",
    "payroll.write": "Submit expense claims and update bank details"
  }
}
```

The auth server fetches this when it receives the resource token — learning what `payroll.read` means from `payroll.example.com` directly, at runtime, verified by signature. It no longer needs that knowledge pre-configured. Its job is now purely the grant decision: given what this resource says it needs, does policy and/or user consent allow it?

This means the auth server can handle a resource it has never seen before. It fetches the metadata, reads the scope descriptions, presents them to the user:

> **payroll.example.com is requesting:**
> - Read your payslip history and current pay details (`payroll.read`)

The user consents. The auth server grants. No prior configuration of `payroll.example.com` was required anywhere.

The `aud` binding makes this safe: whatever scope a resource requests, the resulting auth token is only valid at that resource. A rogue resource could invent any scope name it wants — but the token issued for that scope has `aud: evil.example.com`. It cannot be used anywhere else. The blast radius of a dishonest scope claim is contained to the resource that made it.

**In one sentence**: OAuth scopes are a contract between the client developer and the auth server operator, defined offline. AAuth scopes are a claim made by the resource at runtime, cryptographically bound to the resource's identity, with the resulting grant tied back to that same identity as its audience.

---

## Honest Limitations

Resource tokens are not a complete solution to all agentic security problems.

**Resource implementation required.** Resources must implement AAuth to issue resource tokens. This is a real adoption cost. An ecosystem where some resources use AAuth and others use plain OAuth still has confused deputy vulnerabilities on the OAuth side. 

**First-encounter policy.** When an agent presents a resource token from a resource the auth server has never seen before, the auth server needs a policy for how to handle that. "Unknown resource, deny by default" is secure but breaks dynamic discovery. "Unknown resource, allow with reduced scope" may be appropriate in some contexts. This is a policy question the spec leaves to implementers.

**Compromised legitimate resources.** If `payroll.example.com` itself is compromised and its private key is stolen, the attacker can issue valid resource tokens. This is a different threat model — resource tokens prevent *impersonation*, not *compromise* of the real resource. Key rotation and revocation infrastructure mitigates this.

**TLS still matters for a different attack.** TLS prevents a network-level MITM from intercepting and modifying the resource token in transit. AAuth's resource token signature and TLS are complementary — they address different layers of the same problem. Both should be present.

Here's a blurb that fits naturally as a bridge section — positioned after the attack explanation but before (or alongside) the AAuth resource token fix, as an "infrastructure partial mitigation" that complements the protocol-layer solution:

---

## What About a Trusted Proxy? (agentgateway)

Before going to the protocol layer, it's worth noting that some of the confused deputy surface can be reduced through **infrastructure**: specifically, routing all agent-to-MCP traffic through a trusted proxy like [agentgateway](https://agentgateway.dev).

agentgateway is an AI-native proxy that sits between your agents and MCP servers. Instead of the agent connecting directly to arbitrary MCP endpoints discovered at runtime, it connects through agentgateway which can enforce an allowlist of verified server identities, block unknown or unregistered MCP servers from being reached at all, and serve as the single enforcement seam in the architecture.

The confused deputy attack requires the agent to establish a direct channel to the typosquatted server. If agentgateway is in that path, the attacker's `payro1l-mcp.example.com` never gets a connection — it's not in the allowlist.

This is an infrastructure-level mitigation, not a protocol-level fix. It works inside a single deployment boundary where you control the proxy. It doesn't help when:
- Agents connect to MCP servers outside your perimeter (third-party tools, marketplace servers)
- The registry or allowlist itself is compromised
- Prompt injection convinces the agent to use a different connection path

agentgateway reduces the blast radius significantly in controlled environments. But it doesn't fix the root cause: the OAuth authorization challenge is still an unauthenticated string. Any tool discovery that escapes the proxy perimeter, which is exactly what dynamic discovery is designed to enable, falls back to the unprotected case.

That's where the protocol layer has to close the gap.

---

## Closing

As MCP makes dynamic tool discovery a first-class feature, agents are routinely calling resources they have never seen before; following manifests, tool descriptions, and registry entries that may have been crafted by an attacker. The scope of the confused deputy attack scales directly with the dynamism of the ecosystem.

Resource tokens are AAuth's answer: an application-layer cryptographic artifact that travels across protocol boundaries, carrying proof of resource identity from the challenge all the way into the auth server's token request. The auth server can verify from first principles — no pre-registration, no shared secrets, just a signature and a JWKS endpoint.

Whether or not AAuth becomes a standard, this is the pattern the ecosystem needs: authorization challenges should be cryptographically authenticated, not just transportm encrypted.

---

*This post is part of a series on AAuth — See more here: [https://aauth.dev](https://aauth.dev)*

*AAuth spec: [draft-hardt-aauth-protocol](https://github.com/dickhardt/aauth)*