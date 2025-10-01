---
layout: post
title: Can You Use an API Gateway as an MCP Gateway?
modified:
categories: 
comments: true
tags: []
image:
  feature:
date: 2025-09-26T01:07:11-07:00
published: false
---

The organizations I work with are rapidly adopting the Model Context Protocol (MCP) to connect their services and data to AI models through AI agents, but they're running into _familiar_ challenges: securing access to MCP servers and tools while providing routing, rate limiting, observability, and developer portals. The early days of API adoption taught us painful lessons about security breaches, performance disasters, and operational chaos when services were exposed without proper gateway controls.

If you're building and exposing MCP servers in your enterprise, you're probably asking the a question I hear all the time:

<blockquote>
Can we just use our existing API gateway for MCP? 
</blockquote>

The short answer is "maybe" but the real question is **should you**? API gateways were not built for the MCP usecases. In fact, what you will eventually see is most API gateway vendors will build dedicated MCP gateways. 

In this post, we take a look at the fundamental paradigm difference between APIs and MCP and why the existing infrastructure (API gateway) must evolve. 

## APIs are stateless, MCP is stateful

Before we dig into what the infrastructure should do, we need to understand the obvious differences between these two approaches. APIs are "stateless" services that operate on each request individually in isolation. REST APIs heavily leverage the underlying transport (HTTP) for the _semantics_ of the protocol. What this means, practically, is that all the information needed to route, authorize, and enforce policy in an API gateway lives in the HTTP headers and URL structure.

Your API gateway can make intelligent decisions by examining:

* Method (`GET`, `POST`, `PUT`, `DELETE`)
* Path (`/users/123/orders`)
* Headers (`Authorization: Bearer xyz`, `Content-Type`)
* Query parameters (`?limit=10&offset=50`)

The API gateway rarely operates on the request body. If it does, it's to do some minor transformations or pull pieces out into headers or metadata that can be used for routing. The body typically follows a predictable schema (e.g., Open API Spec) that can be validated and transformed using straightforward mapping rules when needed. Most importantly, each request stands alone. There's no session state to maintain between calls.

Remote MCP servers flips this model completely on its head. First, an MCP client will connect to an MCP server with an "initialize" message and negotiate various protocol settings. Second, the server assigns a session ID (ie, `Mcp-Session-Id`) that can be used to coordinate all subsequent interactions for that client. This session maintains critical context/state including:

* Protocol capabilities negotiated between client and server (which optional features are available)
* Tool result / context from previous tool calls and responses
* Asynchronous tool call state; streaming updates/notifications
* State about requested information from the server to the client

Unlike REST APIs where each request carries complete context in headers, MCP requests contain minimal routing information in the HTTP layer. The entire protocol is in the body of the HTTP request. A typical MCP request looks like this:

```bash
POST /mcp
Mcp-Session-Id: session_abc123
Content-Type: application/json

{
  "jsonrpc": "2.0", 
  "method": "tools/call",
  "params": { 
    "name": "database_query",
    "arguments": { /* complex nested structure */ }
  },
  "id": "call_456"
}
```

Everything meaningful lives in the JSON-RPC body: the method type, the specific tool being called, and the parameters. The HTTP layer is just a "dumb" transport.

Even more challenging, MCP servers can initiate communication back to clients through Server-Sent Events (SSE), sending progress updates, streaming results, or even new requests (elicitations, sampling, etc). This bidirectional, session-aware communication pattern is fundamentally different from the request-response model that API gateways were designed around.

## Can You use Your API Gateway as an MCP Gateway?

As we can see, there are fundamental differences between the two models. But there are similarities, right? They're both over HTTP. We can apply JWT/token/Oauth style security. And it's not a stretch that API gateways can operate on a request body. So can you use your API gateway to govern your MCP services?

![](/images/apigw-for-mcp/apigw-for-mcp.png)

Here is a non-exhaustive list of what you MAY need your API gateway to do:

* Parse request body and responses (JSON-RPC), implement protocol semantics
* Inject policy decisions (allow/deny) on pieces of the body (ie, tool lists, tool calls, resource requests, etc)
* A single HTTP POST from MCP client can result in multiple responses, streamed back (SSE)
* Need a way to inject policy enforcement in the stream
* Once stream established, proxy requests from MCP server to MCP client
* Broker differences between MCP clients and MCP servers
* Present a single logical MCP server to an MCP client (Virtual MCP Server) which may be multiple MCP servers in the backend

An API Gateway can do *some* of this, so let's look at the common MCP gateway patterns from simple to more complex:

* Simple passthrough proxy
* Partial protocol understanding
* MCP brokering
* MCP multiplexing

## Simple Passthrough Proxy

At the most basic level, your API gateway can act as a passthrough proxy for MCP traffic. In this scenario, the gateway treats MCP requests like any other HTTP POST with a JSON payload. It doesn't understand the JSON-RPC structure or MCP semantics, but it can still provide some value:

**What works well:**
- HTTP-level authentication (API keys, OAuth tokens)
- Basic rate limiting per client or IP
- TLS termination and certificate management
- Request/response logging and metrics

![](/images/apigw-for-mcp/simple-passthrough.png)

For example, you may want to check that a JWT is included in the HTTP `Authorization` header and validate the JWT against a trusted IdP. This is basic HTTP handling and any API gateway can do this. What happens if the response is an SSE stream? Luckily most modern API gateways can also return a stream of events. If we want to implement some policy on the response (for example, what tools a client can see), then we need to understand the SSE events. A simple passthrough proxy approach wouldn't allow us to do that. 

**Gateway limitations with SSE:**
- **No streaming policy enforcement**: The gateway can't inspect or filter individual SSE events
- **Limited observability**: Can't track progress, detect errors, or measure per-event latency  
- **No mid-stream authorization**: Can't revoke access or apply policies as the stream progresses
- **Session context lost**: Multiple SSE events are part of one logical MCP operation, but the gateway sees them as independent chunks

Think of it like putting a generic reverse proxy in front of a database. You get connection pooling and basic monitoring, but no query-level insights or policies. The moment you need to understand what's flowing through the proxy, you've outgrown this approach. 

## Partial Protocol Support

Here's where [things get interesting (and complex)](https://blog.christianposta.com/building-an-mcp-gateway-on-top-of-apigee/). With enough custom development, you can teach your API gateway to parse MCP JSON-RPC payloads and extract meaningful information for policy decisions. Most API gateways support custom body parsing through JavaScript/Lua/Template policies or similar scripting mechanisms. For example, [in Apigee](https://blog.christianposta.com/building-an-mcp-gateway-on-top-of-apigee/) you can call out to a JavaScript extension policy to implement custom parsing and policy. 

**What becomes possible:**
- Better understanding of JSON-RPC requests 
- Apply tool-level authorization ("marketing users can't call database_query")
- Basic request transformation and validation

![](/images/apigw-for-mcp/partial-protocol.png)

**The painful reality:**
This approach quickly becomes brittle and expensive to maintain:

- **Dynamic parsing complexity**: MCP tool lists have arbitrary tool lengths. Your JSONPath expressions become increasingly complex and fragile.
- **Performance overhead**: JavaScript policies are slower than native gateway policies
- **Maintenance burden**: Every new MCP tool may require updating gateway policies. Your infrastructure team becomes coupled to your MCP server development.
- **Limited streaming support**: While some gateways support Server-Sent Events, applying policy mid-stream becomes exponentially more complex.

What happens in practice is you end up building a gateway on top of an existing gateway and fight to try and implement new features or squeeze out performance improvements. 

## MCP Brokering

MCP brokering involves the gateway actively participating in the MCP protocol conversation not just proxying requests, but potentially modifying, filtering, or enhancing them based on policy decisions. For example, an MCP client can connect to the MCP gateway with one version of the MCP protocol and the MCP gateway can mediate/broker to a different version. A capability like this is critical in enterprise environments where it may be impossible to make updates to all MCP clients all at once when an MCP server updates to a new version of the protocol. 

Additional brokering usecases build on the previous pattern:

- **Version shielding**: Shielding an MCP client from breaking changes when performing an MCP server upgrade
- **Request filtering**: Remove tools from discovery responses based on backward compatibility requirements
- **Response sanitization**: Strip sensitive data from tool responses based on user clearance levels
- **Context injection**: Add enterprise context (user ID, tenant info) to tool calls
- **Error handling**: Convert MCP protocol errors into enterprise-compliant audit events

Traditional API gateways struggle with this because they lack native JSON-RPC understanding and session-aware policy engines.

![](/images/apigw-for-mcp/brokering.png)

## MCP Multiplexing

This is where traditional API gateways hit a wall. MCP multiplexing involves aggregating multiple backend MCP servers into a single logical endpoint—what we call "virtual MCP". 

For example, a client connects to one MCP endpoint but actually gets access to tools from multiple backend servers:
- Weather tools from weather-service.internal
- Database tools from analytics-service.internal  
- Email tools from notification-service.internal

Instead of AI agents needing to know about and connect to dozens of different MCP servers, they connect to one virtualized endpoint that provides a unified interface to all enterprise tools.

![](/images/apigw-for-mcp/multiplex.png)

**The complexity explosion:**
Implementing this requires capabilities that traditional API gateways simply don't have:

1. **Session fan-out**: When a client sends "tools/list", the gateway must query all backend servers and merge results
2. **Request routing**: Tool calls must be routed to the correct backend based on tool name
3. **Response multiplexing**: Streaming responses from multiple backends must be merged into a single SSE stream
4. **State coordination**: Session IDs and protocol negotiations must be managed across multiple backend connections
5. **Error handling**: Failures in one backend shouldn't break the entire virtual session


This level of protocol-aware aggregation and virtualization is beyond what traditional API gateways were designed to handle. You'd essentially need to rewrite the gateway's core request/response handling logic to support MCP session semantics.


## Agentgateway: Built for MCP from the Ground Up
Agentgateway, an open-source Linux Foundation project, was purpose-built in Rust for AI agent protocols like MCP, drawing on lessons learned from building API gateways. Unlike traditional API gateways optimized for stateless REST interactions, agentgateway natively understands JSON-RPC message structures, maintains stateful session mappings, and handles the bidirectional communication patterns inherent to MCP. This deep protocol awareness allows it to properly multiplex and demultiplex MCP sessions, fan out client requests across multiple backend MCP servers, aggregate tool lists, and maintain the critical two-way session mapping needed when servers initiate messages back to clients. Rather than fighting against an architecture designed for request-response APIs, agentgateway’s foundation aligns perfectly with MCP’s session-oriented, streaming communication model.

![](/images/apigw-for-mcp/multi-direction.gif)

Building on this foundation, agentgateway serves as a native MCP gateway, LLM gateway, and agent-to-agent (A2A) proxy, providing the security, observability, and governance capabilities that traditional API gateways cannot deliver. It supports MCP multiplexing to federate tools from multiple backend servers, applies fine-grained authorization policies to control which tools clients can access, and handles both stdio and HTTP Streamable transports seamlessly. And when integrated with CNCF project kgateway as a control plane, agentgateway becomes Kubernetes-native, enabling teams to manage MCP services using standard Gateway API resources while the proxy takes care of the protocol-specific complexities. This purpose-built approach delivers the performance, safety, and operational simplicity enterprises need for production MCP deployments—without the brittleness, maintenance burden, and architectural compromises of retrofitting an API gateway.



