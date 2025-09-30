---
layout: post
title: Building an MCP Gateway with Apigee API Gateway
modified:
categories: 
comments: true
tags: [apigee, management, api, ai, rest, agents, agentic, capabilities, llm, architecture, mcp, tools, openapi, swagger, oas]
image:
  feature:
date: 2025-09-27T16:22:59-07:00
---

Organizations are working out how best to introduce implementations of the model context protocol (MCP) for their AI agents. One of the mistakes they want to avoid is letting MCP implementations sprawl uncontrollably without governance, security, and authorization policies. Many organizations already use an API management solution to implement governance around APIs, could they use the same gateways to implement governance, security, and authorization around MCP servers?

In this blog post we'll take a look at doing this with the Apigee API gateway.

## Apigee Does not Support MCP

Apigee does not support MCP. In a [recent blog post](https://developers.googleblog.com/en/the-agentic-experience-is-mcp-the-right-tool-for-your-ai-future/), Google published a "MCP server solution powered by Apigee", but if you read closely it had nothing to do with using Apigee as an MCP gateway. Apigee does not natively support the MCP protocol. But could it?

![](/images/apigee-mcp/apigee-proxy.png)

MCP represents quite a departure from typical stateless REST APIs. MCP is implemented in the body of the HTTP payloads. Apigee (and API gateways in general) shines best when enforcing policy on REST APIs. But can Apigee be extended to understand the MCP protocol? Apigee does support body parsing and manipulation. Apigee also supports [SSE (server sent events)](https://cloud.google.com/apigee/docs/api-platform/develop/server-sent-events) which is core to MCP server implementations. 

So what would an MCP implementation look like with Apigee?

## Starting with Simple JWT Validation

Apigee is an HTTP based API gateway, while MCP is fully implemented in the HTTP payloads. If we require an MCP client to send a JWT, we can do basic JWT checks for calls to a backend MCP server. For example, we can implement a JWT-Validation policy to validate JWTs:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<VerifyJWT continueOnError="false" enabled="true" name="JWT-Validate-Auth">
  <DisplayName>JWT-Validate-Auth</DisplayName>
  <Algorithm>ES256</Algorithm>
  <PublicKey>
    <JWKS ref="my-jwks"/>
  </PublicKey>
  <Issuer>https://okta.solo.io/agentgateway</Issuer>
  <Audience>company-mcp.solo.io</Audience>
</VerifyJWT>
```

You can attach this to a Proxy's `PreFlow` lifecycle. This will require any HTTP request to contain a valid JWT and will reject any requests without it. On the response side, if this request passes JWT validation, the MCP server may return a response and the Apigee proxy will send it back to the client. If the MCP server returns an HTTP streamable SSE stream, Apigee can send this along just fine. 

![](/images/apigee-mcp/apigee-passthrough.png)

So far, we have basic passthrough working with JWT validation enforced.

### Implementing JSON-RPC for MCP

Simple JWT validation is a good start, as it allows us to check the proper bearer token is available. But any enterprise will need to apply policies to tool access and tool execution (as well as prompts, resources, etc). This represents a more fine-grained approach to authorization. Just validating a JWT is not sufficient. To accomplish this, Apigee will need to understand the details of the **body** of the messages. The MCP protocol is implemented as JSON-RPC HTTP payloads, and Apigee today does not understand JSON-RPC or MCP.  This means we need configure Apigee to parse the body and evaluate specific parts/patterns. 

For example, for a tool/list message we could use an `<ExtractVariable>` policy in Apigee:

```xml
<ExtractVariables name="ExtractToolsList">
  <Source>request</Source>
  <JSONPayload>
    <Variable name="jsonrpc"><JSONPath>$.jsonrpc</JSONPath></Variable>
    <Variable name="method"><JSONPath>$.method</JSONPath></Variable>
    <Variable name="id"><JSONPath>$.id</JSONPath></Variable>
  </JSONPayload>
  <VariablePrefix>mcp</VariablePrefix>
  <IgnoreUnresolvedVariables>true</IgnoreUnresolvedVariables>
</ExtractVariables>
```


To process a tool call, your `<ExtractVariable>` policy could look like this:

```xml
<ExtractVariables name="ExtractToolCall">
  <Source>request</Source>
  <JSONPayload>
    <Variable name="jsonrpc"><JSONPath>$.jsonrpc</JSONPath></Variable>
    <Variable name="method"><JSONPath>$.method</JSONPath></Variable>
    <Variable name="id"><JSONPath>$.id</JSONPath></Variable>
    <Variable name="tool_name"><JSONPath>$.params.name</JSONPath></Variable>
    <!-- Extract entire arguments as string for further processing -->
    <Variable name="tool_arguments"><JSONPath>$.params.arguments</JSONPath></Variable>
  </JSONPayload>
  <VariablePrefix>mcp</VariablePrefix>
  <IgnoreUnresolvedVariables>true</IgnoreUnresolvedVariables>
</ExtractVariables>
```

As you can see, we basically use JSONPath expressions to pull specific parts of the body payload into flow variables. This approach may work well for simplistic, initial steps into decoding MCP messages:

* Simple field extraction from known paths
* Basic MCP message routing based on method
* Single tool calls with simple arguments
* Session ID extraction from headers

But for more complex message structures (tool, resource, prompt calls) this approach quickly runs into some issues. Consider this MCP tool call:


```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "id": "complex-call-123",
  "params": {
    "name": "database_analytics",
    "arguments": {
      "query": {
        "operation": "aggregate",
        "tables": ["users", "orders", "products"],
        "filters": [
          {
            "field": "user.role",
            "operator": "in",
            "values": ["premium", "enterprise"]
          },
          {
            "field": "order.date",
            "operator": "between",
            "values": ["2024-01-01", "2024-12-31"]
          }
        ],
        "groupBy": ["user.region", "product.category"],
        "metrics": {
          "revenue": {"function": "sum", "field": "order.amount"},
          "orders": {"function": "count", "field": "order.id"},
          "avgOrderValue": {"function": "avg", "field": "order.amount"}
        }
      },
      "outputFormat": {
        "type": "chart",
        "chartType": "bar",
        "dimensions": ["region", "category"],
        "exportOptions": {
          "formats": ["png", "pdf"],
          "resolution": "high",
          "includeData": true
        }
      },
      "permissions": {
        "dataRetention": "30days",
        "allowExport": false,
        "sensitiveFields": ["user.email", "user.phone"]
      }
    }
  }
}
```

The Apigee `<ExtractVariable>` policy falls apart for this more realistic case:

- **Multiple tool calls in arrays** - ExtractVariables can't iterate over `$.params.tool_calls[*]`
- **Complex nested arguments** - Deep object structures in tool arguments
- **Dynamic argument validation** - Tool-specific argument schema validation

To work around this, Apigee does offer a [JavaScript extension](https://cloud.google.com/apigee/docs/api-platform/reference/policies/javascript-policy) policy: meaning, you can write your protocol decoding in straight JavaScript.

We haven't really discussed the stateful nature of the protocol. A tool-list message without a valid session should not be accepted. And we haven't even talked about the responses yet. Which are also complex JSON-RPC structures, potentially in a streaming response:

- **Streaming responses** - SSE event processing requires EventFlow
- **Session state** - No built-in session persistence across requests

This last part is particularly problematic. Apigee treats each request independently (like any API gateway), with no way to tie session context together across requests. For example:

* "Was this session properly initialized?"
* "What capabilities were negotiated for this session?"
* "Does this user have permission to call this tool based on the session state?"
* "What resources is this session subscribed to?"


### Using JavaScript to Implement JSON-RPC

Since the built in controls in Apigee are inadequate for processing the MCP protocol, we're left to implement it by hand using JavaScript. 

For example, we could implement our `<PreFlow>` for our proxy like this:

```xml
  <PreFlow name="PreFlow">
    <Request>
      <Step>
        <Name>JWT-Validate-Auth</Name>
      </Step>
      <Step>
        <Name>JWT-Decode-Claims</Name>
      </Step>
      <Step>
        <Name>JS-MCP-Tool-Authorization</Name>
      </Step>
    </Request>
    <Response/>
  </PreFlow>
```

Here we have a policy to validate the JWT, we then decode the claims, and then pass it to the JavaScript policy which will parse the body and decode the method and arguments of the MCP call. 

The JavaScript policy looks like this:


```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Javascript continueOnError="false" enabled="true" timeLimit="200" name="JS-MCP-Tool-Authorization">
  <DisplayName>MCP Tool Authorization</DisplayName>
  <Properties/>
  <ResourceURL>jsc://mcpToolAuth.js</ResourceURL>
</Javascript>
```

And then implement the processing in our `mcpToolAuth.js` JavaScript file. This brings us to a core point: Apigee's JavaScript policies are designed as tactical utilities for simple transformations, not for complete protocol implementations. Trying to implement a full protocol with this approach leads to the following drawbacks:

*  **Performance Impact**: JSON parsing + complex iteration on every request
*  **Maintenance Nightmare**: Tool-specific logic hardcoded in gateway  
*  **Error Prone**: Complex nested object traversal is brittle
*  **No Type Safety**: Easy to make mistakes with dynamic JSON structures
*  **Scaling Issues**: JavaScript execution limits under high load


### Implementing Authorization Policy on Tool Lists / Calls

So far we've only covered basic JWT validation and primitive/naive implemention of the MCP JSON-RPC protocol with Apigee. What about implementing policy to filter out tools that a particular user can see based on claims/groups/entitlements? For example, those found in a JWT? In the MCP protocol, these responses can/are treated as SSE streamed results. For example

```bash
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive

data: {"jsonrpc":"2.0","id":"call-456","result":{"content":[{"type":"text","text":"Weather analysis complete. Temperature: 72°F, Conditions: Partly cloudy"}],"isError":false}}
```

Apigee does handle SSE nicely, and if we want to hook into the SSE stream, we need to use the `<EventFlow>` [handler](https://cloud.google.com/apigee/docs/api-platform/develop/server-sent-events). Unfortunately, to process complex JSON-RPC responses in the SSE stream, we need to use a JavaScript callout again:


```xml
  <EventFlow content-type="text/event-stream">
    <Response>
      <Step>
        <Name>JS-MCP-Response-Filter</Name>
        <Condition>requires.response.filtering = "true"</Condition>
      </Step>
    </Response>
  </EventFlow>
```

In one of our `<PreFlow>` policies, we'd need to detect, for example, a `tools/list` message and set the `requires.response.filtering` variable to true. Then this condition would be met and we'd callout to the JavaScript processor. 

Then in our JavaScript processor we could handle the SSE events and parse the JSON-RPC structures:

```javascript
// Required JavaScript handling for SSE
if (eventContent.startsWith("data: ")) {
    var jsonPart = eventContent.substring(6);
    mcpResponse = JSON.parse(jsonPart);
    
    // Filter tools based on permissions
    if (mcpResponse.result && mcpResponse.result.tools) {
        mcpResponse.result.tools = mcpResponse.result.tools
            .filter(tool => hasPermission(tool.name));
            
        // Maintain SSE format
        context.setVariable("response.event.current.content", 
            "data: " + JSON.stringify(mcpResponse));
    }
}
```

## When DIY Protocol Handling Breaks Down

While our previous section explored the challenges of SSE handling in Apigee, there's an even deeper layer of complexity when implementing the Model Context Protocol (MCP). Let's explore why attempting to handle this protocol with JavaScript policies can lead to subtle but significant issues.

### The JSON-RPC Error Handling Trap

Consider what seems like a straightforward error response:

```javascript
// What many implementations do
var mcpError = {
    "jsonrpc": "2.0",
    "id": mcpRequest.id,
    "error": {
        "code": -32603,  // Internal error
        "message": "Tool access denied",
        "data": { "denied_tools": ["restricted_tool"] }
    }
};
```

This looks reasonable, but it's actually incorrect according to the MCP specification. Tool-level errors should be successful responses with error content:

```javascript
// What MCP actually expects
const toolError = {
    "jsonrpc": "2.0",
    "id": mcpRequest.id,
    "result": {
        "isError": true,
        "content": [{
            "type": "text",
            "text": "Access denied"
        }],
        "structuredContent": {
            "denied_tools": ["restricted_tool"]
        }
    }
};
```

This distinction is crucial because:
- Clients/LLMs expect to handle tool errors differently from protocol errors
- Error responses may break SSE streams unexpectedly
- Monitoring systems may misclassify errors
- Tool orchestration becomes unreliable

### The Streaming State Nightmare

Here's a common pattern that seems innocent:

```javascript
// Typical implementation
if (eventContent.startsWith("data: ")) {
    var jsonPart = eventContent.substring(6);
    mcpResponse = JSON.parse(jsonPart);
    
    // Filter tools...
    filterTools(mcpResponse.result.tools);
}
```

But this breaks in multiple ways:

```javascript
// Real-world SSE can look like this
data: {"jsonrpc": "2.0", "id": "123",
data: "result": {
data:   "tools": [
data:     {"name": "tool1"}
data:   ]
data: }}
```

Our simple `startsWith()` check fails to handle:
- Multi-line SSE events
- Retry mechanisms
- Partial JSON messages
- Connection recovery

To be fair, a well-implemented MCP server should not implement multi-line, fragmented messages across SSE events, but this kind of thing does happen. Enterprise environments are notorious for "bending the spec" or using components that bend the spec. These kind of things are real and cannot be avoided. 


### The Schema Validation Void

Tool definitions in MCP are strictly typed:

```javascript
// MCP tool schema
{
    "name": "data_processor", 
    "inputSchema": {
        "type": "object",
        "properties": {
            "data_source": { "type": "string", "enum": ["source1", "source2"] },
            "parameters": {
                "type": "object",
                "properties": {
                    "batch_size": { "type": "number" }
                },
                "required": ["batch_size"]  
            }
        },
        "required": ["data_source", "parameters"] 
    }
}

// Typical JavaScript implementation
function validateToolInput(input) {
    return input.data_source && input.parameters; // Oversimplified
}
```

The MCP specification mandates proper JSON Schema validation through its security requirements, but many implementations skip this critical step. This creates:

* Security vulnerabilities (command injection, path traversal)
* Type safety issues (unexpected data types causing runtime errors)
* Business logic failures (invalid enum values, missing required fields)
* Non-compliant implementations that violate spec requirements


## Should you do this?

* How does this approach handle SOX/GDPR requirements for tool access logging? Traditional gateways have audit trails, but custom JavaScript policies create gaps.
* How would you handle different customers needing different tool access patterns?
* What happens when the JavaScript policy crashes mid-stream? How do you resume MCP sessions?

Apigee is a powerful API gateway, but it was not built with MCP protocol support. You could try to hand build this yourself, but this creates both immediate performance issues (every SSE event triggers JavaScript execution instead of declarative routing) and serious operational risk: authorization logic lives in custom code rather than proven gateway policies, creating potential security vulnerabilities where policy bugs could expose sensitive tools or data, while debugging requires specialized expertise instead of standard procedures, and the resulting maintenance overhead (careful versioning, specialized testing) is exactly what enterprises sought to avoid by using gateways in the first place.

The short answer is: **No, you should not do this**.

## Alternative Approach

The right approach is to use a MCP gateway that has been purpose built to handle the peculiarities of the MCP protocol. That is, that can natively parse and understand the underlying JSON-RPC messages, the protocol nuances and interactions, error handling, and enforcing fine-grained authentication and authorization on tool calls, resources and prompts. [Agentgateway](https://agentgateway) is a Linux Foundation OSS project that focuses on MCP, A2A, LLM and inference workloads. Agentgateway is built natively in Rust to support these type of usecases. 

If you already use Apigee, you can use agentgateway with Apigee. Apigee can call out to agentgateway for MCP related operations including complex, fine-grained authorizations. 

If you're building MCP solutions in your enterprise, checkout [agentgateway.dev](https://agentgateway.dev)

