---
layout: post
title: Understanding MCP Authorization, Step by Step, Part Two
modified:
categories: 
comments: true
tags: [ai, rest, agents, agentic, capabilities, llm, architecture, mcp, tools, openapi, swagger, oas]
image:
  feature:
date: 2025-06-30T16:05:02-07:00
---

In this post (part two of three), we'll dig into the [June 2025 MCP Authorization](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization) specification more closely. See Part One for setting up the [MCP Server using HTTP Transport](https://blog.christianposta.com/understanding-mcp-authorization-step-by-step/). 

---

Generally, in this series of blog posts (three parts + [source code](https://github.com/christian-posta/mcp-auth-step-by-step)), we'll walk "step-by-step" through the latest MCP Authorization spec and implement it. I have made all of the [source code for each of the steps available on GitHub](https://github.com/christian-posta/mcp-auth-step-by-step).

* Part 1: [Implement a spec compliant remote MCP server with HTTP Transport](https://blog.christianposta.com/understanding-mcp-authorization-step-by-step/)
* Part 2: (This) Layer in Authorization specification with OAuth 2.1
* Part 3: Bring in a production Identity Provider (Keycloak)

Follow ([@christianposta](https://x.com/christianposta) or [/in/ceposta](https://linkedin.com/in/ceposta)) for the next parts. 

---

## MCP Authorization

I had been critical of the MCP Authorization Spec in the past (see: [The MCP Authorization Spec Is...A Mess for Enterprises](https://blog.christianposta.com/the-updated-mcp-oauth-spec-is-a-mess/)) but recent revisions have corrected a lot of what I pointed out. The MCP Authorization spec heavily leverages existing standards ([OAuth 2.1](https://oauth.net/2.1/)) and treats the MCP server as an OAuth [Resource Server](https://www.oauth.com/oauth2-servers/the-resource-server/) with respect to the MCP client. That means, we can leverage existing Identity Provider implementations (Auth0, Okta, Keycloak, etc) to protect the MCP server. 

In this post, we'll go through the spec, and implement using a local IdP (ie, local keys). In the third post in this series, we'll connect everything up to a production IdP ([Keycloak](https://www.keycloak.org)).

This is the overview of the MCP Authorization Spec:

<blockquote>
Authorization servers MUST implement OAuth 2.1 with appropriate security measures for both confidential and public clients.<br>
<br>
Authorization servers and MCP clients SHOULD support the OAuth 2.0 Dynamic Client Registration Protocol (RFC7591).<br>
<br>
MCP servers MUST implement OAuth 2.0 Protected Resource Metadata (RFC9728). MCP clients MUST use OAuth 2.0 Protected Resource Metadata for authorization server discovery.<br>
<br>
Authorization servers MUST provide OAuth 2.0 Authorization Server Metadata (RFC8414). MCP clients MUST use the OAuth 2.0 Authorization Server Metadata.<br>
</blockquote>

We will pick up from Step 4 in the previous blog where we had a functional MCP server using the HTTP transport. Remember, the MCP specification recommends HTTP transport MCP servers SHOULD use the Authorization spec. The [stdio](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports#stdio) should not use the Authorization spec. 

## Step 5: Preparing to implement MCP Authorization

Follow along with the source code [for this step](https://github.com/christian-posta/mcp-auth-step-by-step/blob/main/src/mcp_http/step5.py). 

Since the latest spec refers to the MCP server as a resource server all the MCP server has to do is respect a few of the metadata RFCs and check/verify the OAuth access token that gets passed along with the request. If a request does not have an access token, the server will respond to the client telling it where to get an access token and pointing it to the authorization server details. To prepare are step-by-step example, we'll set up the MCP server to find a local public key and expose it as a JWKS. This is just for local testing; when using a production authorization server (AS), the AS will host the JWKS for the public keys used to verify JWT. 

The first change we'll do to prepare our MCP server to implement Authorization is to organize things a little nicer. We're going to wrap the FastAPI server in a JWTMCPServer class:

```python
class JWTMCPServer:
    """MCP Server with basic JWT infrastructure."""
    
    def __init__(self):
        self.app = FastAPI(title="JWT MCP Server", version="0.1.0")
        self.server = Server("mcp-echo")
        self.public_key = None
        self.public_key_jwk = None
        self.load_public_key()
        self.setup_middleware()
        self.setup_routes()
```

We do this so we don't end up with a lot of public variables and could potentially reuse this server elsewhere. 

We will load a public key from a local file system, looking for a file called `mcp_public_key.pem`. If you see [in the source code for this project](https://github.com/christian-posta/mcp-auth-step-by-step), we have that file and the private key. 

```python
    def load_public_key(self):
        """Load RSA public key for JWT validation."""
        key_file = "mcp_public_key.pem"
        
        if os.path.exists(key_file):
            logger.info("Loading RSA public key...")
            try:
                from cryptography.hazmat.primitives import serialization
                
                with open(key_file, "rb") as f:
                    self.public_key = serialization.load_pem_public_key(f.read())
                
                logger.info("✅ RSA public key loaded successfully")
                self.generate_jwk()
```

In the last step, we generate the JWKS and we will make this available to clients. 

```python
    @self.app.get("/.well-known/jwks.json")
    async def jwks_endpoint():
        """JSON Web Key Set endpoint."""
        if self.public_key_jwk:
            return {"keys": [self.public_key_jwk]}
        else:
            return JSONResponse(
                status_code=503,
                content={"error": "JWKS not available - no public key loaded"}
            )
```

From a terminal at the root of the source code, we can run this step to verify the JWKS:

```bash
❯ uv run step5
```

From a second terminal, we can curl the server:

```bash
❯ curl -s localhost:9000/.well-known/jwks.json | jq .
{
  "keys": [
    {
      "kty": "RSA",
      "use": "sig",
      "kid": "mcp-key-1",
      "alg": "RS256",
      "n": "yM7y7i_XdC96d-obyP7TG-KBB9ccRvd7lD9WhQjTySRKHVaHoz5d0sHePl6jiecyl9-Q3K15ylS0CRepcnLbtpGZBGLPcGw1mbWa-mTfHQmcRt51ctW5Ipm23brQ7YLyuqavVEP66jatzePzzL68UALbbEm-QpwaaKzeWvL-gYSSPDtXY0YX6rmCDDlfWyVcSOUHdtUeI49jDz4yEU9cJgCwKFmQU-whKYIDAsdor07dmyDiRyLJT3YZDxccVD3sP8dp2wR79ngVyVtuSL3-Kr-E6SwrVOnIBjebP8h1tcR41i9BtSowVMQrf1A_Mb27PPztStzCo-CiurhsePEpyw",
      "e": "AQAB"
    }
  ]
}
```

At this point, we have a public key that we can use to verify a JWT bearer token. Let's start implementing the MCP Authorization spec.

## Step 6: Implement Token Verification, Expose Metadata

Follow along with the source code [for this step](https://github.com/christian-posta/mcp-auth-step-by-step/blob/main/src/mcp_http/step6.py). 

In this step, we get to the meat of the MCP Authorization spec. In this step, we'll require a JWT bearer token gets passed to the `/mcp` endpoint. The bearer token will validated for things like audience, expiration, issuer, etc. If the JWT is missing, or is invalid, the MCP Authorization spec says the following:

<blockquote>
MCP servers MUST use the HTTP header WWW-Authenticate when returning a 401 Unauthorized to indicate the location of the resource server metadata URL as described in RFC9728 Section 5.1 “WWW-Authenticate Response”. <br>
<br>
MCP clients MUST be able to parse WWW-Authenticate headers and respond appropriately to HTTP 401 Unauthorized responses from the MCP server.
</blockquote>

If we look closer at [the protected resource spec (RFC 9728)](https://datatracker.ietf.org/doc/html/rfc9728#name-protected-resource-metadata), 401 responses should return something like this:

```bash
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer resource_metadata="https://resource.example.com/.well-known/oauth-protected-resource"
```

This is important, because if a client is not authenticated or authorized, it will need to discover how to do so. By responding like this, the client should be able to follow the `resource_metadata` to find more about the protected resource. 

Our MCP server implementation will need to respond correctly with WWW-Authenticated header and expose a `/.well-known/oauth-protected-resource`. 

Let's see how we implement this. First, we define a parameter to the `handle_mcp_request` on an HTTP POST that `Depends` on the `self.verify_token` function. This means, the `verify_token` function will be called and the response passed to the handler. 

```python
    @self.app.post("/mcp")
    async def handle_mcp_request(
        request: Request,
        token_info: Dict[str, Any] = Depends(self.verify_token)
    ):
```

In our `verify_token` function is where we will find [verification steps and the correct responses](https://github.com/christian-posta/mcp-auth-step-by-step/blob/main/src/mcp_http/step6.py#L132) (401 with `WWW-Authenticated` header):

```python
  async def verify_token(
      self,
      credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
  ) -> Dict[str, Any]:
      """Verify JWT token."""
      
      ... omitted for clarity, see source code ...
          
      except Exception as e:
          logger.error(f"Token validation error: {e}")
          raise HTTPException(
              status_code=401,
              detail="Invalid token",
              headers=self.get_www_authenticate_header()
          )
```

The `get_www_authenticated_header()` looks like this:

```python
  def get_www_authenticate_header(self) -> Dict[str, str]:
      """Get WWW-Authenticate header for 401 responses."""
      return {
          "WWW-Authenticate": f'Bearer realm="mcp-server", resource_metadata="http://localhost:9000/.well-known/oauth-protected-resource"'
      }
```

If you look closely, you'll see our `resource_metadata` response points to `/.well-known/oauth-protected-resource`. We haven't implemented that, but we will do so in the next step.

We should be able to test our implementation up until this point. In a terminal run the following:

```bash
❯ ./test_step6.sh
```

This will start the server and run steps against it to verify it is working correctly. You should see something similar to the following when the tests complete:

```bash
echo "🎉 Step 6 tests completed successfully!"
echo "✅ JWT token validation is working"
echo "✅ Authentication is enforced for MCP requests"
echo "✅ Authenticated users can access all MCP functionality"
echo "✅ User context is included in responses"
echo "✅ Invalid tokens are properly rejected"
echo "✅ WWW-Authenticate headers are set correctly"
echo "✅ Ready for next step: OAuth 2.0 metadata" 
```

We are almost there! We need to implement the `oauth-protected-resource` response. 


## Step 7: Implementing Protected Resource Metadata

Follow along with the source code [for this step](https://github.com/christian-posta/mcp-auth-step-by-step/blob/main/src/mcp_http/step7.py). 

In the previous step, we implemented part of [the protected resource spec (RFC 9728)](https://datatracker.ietf.org/doc/html/rfc9728#name-protected-resource-metadata). The other part we need to implement for our MCP server is returning a response for the `/.well-known/oauth-protected-resource` which gets returned with the `HTTP 401` response when a client is not authorized to call the MCP server. This allows MCP clients to dynamically discover how to authorize. 

Since we are using local keys to implement the JWT checking, we will have a very simple (and not very descriptive) response to this protected resource metadata request. 

```python
    @self.app.get("/.well-known/oauth-protected-resource")
    async def protected_resource_metadata():
        """OAuth 2.0 Protected Resource Metadata (RFC 9728)."""
        return {
            "resource": MCP_SERVER_URL,
            "authorization_servers": [JWT_ISSUER],
            "scopes_supported": ["mcp:read", "mcp:tools"],
            "bearer_methods_supported": ["header"],
            "resource_documentation": f"{MCP_SERVER_URL}/docs",
            "mcp_protocol_version": "2025-06-18",
            "resource_type": "mcp-server"
        }
```

Let's run this step locally and check:

```bash
❯ uv run step7
INFO:mcp_http.step7:Loading RSA public key...
INFO:mcp_http.step7:✅ RSA public key loaded successfully
INFO:mcp_http.step7:✅ JWK generated successfully
INFO:     Started server process [20873]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:9000 (Press CTRL+C to quit)
```

In another terminal try querying for the resource directly:

```bash
❯ curl -s localhost:9000/.well-known/oauth-protected-resource | jq .
{
  "resource": "http://localhost:9000",
  "authorization_servers": [
    "mcp-simple-auth"
  ],
  "scopes_supported": [
    "mcp:read",
    "mcp:tools"
  ],
  "bearer_methods_supported": [
    "header"
  ],
  "resource_documentation": "http://localhost:9000/docs",
  "mcp_protocol_version": "2025-06-18",
  "resource_type": "mcp-server"
}
```

The most important part of the response is the `authorization_servers` list. This points to where the client should check to authorize and get a token. In this case, since we are using local keys, it doesn't point to a real server. In fact, it just points to our example MCP server. 

In section 2.3.2 of the MCP Authorization spec, it says:

> MCP clients MUST follow the OAuth 2.0 Authorization Server Metadata RFC8414 specification to obtain the information required to interact with the authorization server.

This means the MCP client will expect a `/.well-known/oauth-authorization-server` endpoint on the Authorization Server (AS). This has metadata indicating token endpoints, scopes, and more. Here's an example of what that might look like:

```json
{
  "issuer": "mcp-simple-auth",
  "token_endpoint": "http://localhost:9000/auth/token",
  "jwks_uri": "http://localhost:9000/.well-known/jwks.json",
  "scopes_supported": [
    "mcp:read",
    "mcp:tools"
  ],
  "response_types_supported": [
    "token"
  ],
  "grant_types_supported": [
    "password"
  ],
  "token_endpoint_auth_methods_supported": [
    "none"
  ],
  "resource_indicators_supported": true,
  "authorization_endpoint": "http://localhost:9000/auth/authorize"
}
```

In part three of this series, we'll connect up to a production IdP server and examine this more closely. To verify the implementation up until this point, stop the previous run of `uv run step7` and run the following tests:

```bash
❯ ./test_step7.sh
```

You should see something like:

```bash
echo "🎉 Step 7 tests completed successfully!"
echo "✅ OAuth 2.0 Protected Resource metadata is working"
echo "✅ OAuth 2.0 Authorization Server metadata is working"
echo "✅ JWKS endpoint continues to work"
echo "✅ All existing MCP functionality still works"
echo "✅ OAuth metadata is included in MCP responses"
echo "✅ Resource indicators are supported"
echo "✅ Authentication enforcement continues to work"
echo "✅ Ready for next step: Scope-based authorization" 
```


## Step 8: Checking Scopes

Follow along with the source code [for this step](https://github.com/christian-posta/mcp-auth-step-by-step/blob/main/src/mcp_http/step8.py). 

In this last step, we will leverage the scope information from the validated JWT to make access decisions. Unfortunately, OAuth scopes cover fairly broad access, are not hierarchical, and are fairly simple. Nevertheless, we can use them to control access to specific resources, MCP tools, prompts, etc. 

When we handle a request with a validated token, we can grab the scopes like this:

```python
    @self.app.post("/mcp")
    async def handle_mcp_request(
        request: Request,
        token_info: Dict[str, Any] = Depends(self.verify_token)
    ):
        """Handle MCP requests with JWT protection and scope-based authorization."""
        body = await request.json()
        mcp_request = MCPRequest(**body)
        
        username = token_info.get("preferred_username", "unknown")
        scopes = token_info.get("scopes", [])
        roles = token_info.get("roles", [])
```

In the implementation for each of the MCP capabilities, we can check whether the access token allows access to those capabilities:

```python
    elif mcp_request.method == "tools/list":
        if not self.check_permission(scopes, roles, "tools", "read"):
            return self.forbidden_response("Insufficient permissions for tools access")
        tools = await list_tools()
        result = {
            "tools": [tool.model_dump() for tool in tools]
        }
    elif mcp_request.method == "tools/call":
        if not self.check_permission(scopes, roles, "tools", "execute"):
            return self.forbidden_response("Insufficient permissions for tool execution")
        content = await call_tool(mcp_request.params["name"], mcp_request.params["arguments"])
        result = {
            "content": [item.model_dump() for item in content],
            "isError": False
        }
    elif mcp_request.method == "prompts/list":
        if not self.check_permission(scopes, roles, "prompts", "read"):
            return self.forbidden_response("Insufficient permissions for prompts access")
        prompts = await list_prompts()
        result = {
            "prompts": [prompt.model_dump() for prompt in prompts]
        }
```

To fully check the Step 8 implementation, run the following script:

```bash
❯ ./test_step7.sh
```

You should see something like this:

```bash
Checking scopes
echo "🎉 Step 8 tests completed successfully!"
echo "✅ Scope-based authorization is enforced (mcp:read grants read access to both tools and prompts)"
echo "✅ Users with mcp:read can access both tools and prompts"
echo "✅ Admin can access everything"
echo "✅ Users with no relevant scopes are forbidden"
echo "✅ All previous MCP and OAuth functionality still works"
echo "✅ Ready for next step!" 
```

We now have the foundation for a fully-compliant MCP server that implements the MCP Authorization spec! We used local keys for this implementation, but in the next post, we'll look at how to easily convert this to use a production IdP. 


## Last Considerations

When building real-world MCP clients and servers, following the MCP Authorization spec, we will want to consider the use of Dynamic Client Registration on the MCP client side. [Section 2.4](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization#dynamic-client-registration) of the spec gives great reasons for doing so:

* Clients may not know all possible MCP servers and their authorization servers in advance.
* Manual registration would create friction for users.
* It enables seamless connection to new MCP servers and their authorization servers.
* Authorization servers can implement their own registration policies.

Additionally, the spec in [section 2.5.1](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization#resource-parameter-implementation) says MCP clients MUST use resource indicators when requesting tokens from the Authorization Server with the following "MUSTS":

<blockquote>
MUST be included in both authorization requests and token requests.<br>
<br>
MUST identify the MCP server that the client intends to use the token with.<br>
<br>
MUST use the canonical URI of the MCP server as defined in RFC 8707 Section 2.<br>
<blockquote>

[RFC 8707 goes into detail about](https://www.rfc-editor.org/rfc/rfc8707.html) indicating resource/audience to the Authorization Server. This means MCP clients should very clearly state which MCP server they want to use. This is a great step to make clear the intended audience instead of potentially issuing tokens for broad audiences which can cause issues. It makes token scoping explicit and predictable, enables better multi-tenant behavior, supports fine-grained delegation, prevents accidentally using the same token across unrelated MCP servers. 

At this point we have a [MCP 6-18-25 compliant HTTP server that implements the Authorization spec](https://modelcontextprotocol.io/specification/2025-06-18). This server doesn't use a production IdP yet, but that's what we'll do in the next post. Stay tuned!