---
layout: post
title: Understanding MCP Recent Change Around HTTP+SSE
modified:
categories: ai
comments: true
tags: [ai, inference, mcp, agentic, agents, testing]
image:
  feature:
date: 2025-03-27T07:27:47-07:00
---

[Anthropic introduced](https://www.anthropic.com/news/model-context-protocol) the [Model Context Protocol](https://spec.modelcontextprotocol.io/specification/2024-11-05/) (MCP) to standardize the way an LLM communicates with the "outside world" to extend its capabilities through [tool/function support](https://platform.openai.com/docs/guides/function-calling?api-mode=chat). The idea is if we could simplify that integration, then we could focus on powerful tools not on custom integration code. MCP is thriving, new MCP servers are popping up hourly, and even Anthropic's rival, OpenAI, [is adopting MCP](https://techcrunch.com/2025/03/26/openai-adopts-rival-anthropics-standard-for-connecting-ai-models-to-data/).

Recently (March 2025), based on feedback from the community, [MCP updated its speccification to add](https://spec.modelcontextprotocol.io/specification/2025-03-26/changelog/) an authorization framework, replace HTTP+SSE transport with a Streamable HTTP transport, add tool annotations for describing behavior, and support for JSON-RPC batching. I was very curious about the security and transport changes, so in this blog we dig into what happened on the transport side, and in a later blog we'll dig into the security additions. Follow me ([@christianposta](https://x.com/christianposta) [/in/ceposta](https://linkedin.com/in/ceposta)) if interested in upcoming blog posts. 

## Communicating with an MCP Server

I won't go into too much detail as there is already a [lot of information on this](https://modelcontextprotocol.io/docs/concepts/transports#built-in-transport-types), but MCP servers which expose tools / resources / prompts, can be deployed and queried with two main transports:

* stdio
* HTTP+SSE

I'd argue that for "real world usage" you'd likely communicate with MCP servers over some kind of remote transport like HTTP, but to do that, it's a little awkward using SSE (Server Sent Events). Let's see why. 

## HTTP + SSE

[SSE (Server Sent Events)](https://en.wikipedia.org/wiki/Server-sent_events) is a mechanism for the _server_ to send events to the client. It is a _one way only_ direction. The way it would work with MCP is:

* client connects to an "http://example.com/sse" endpoint on a server
* the server responds with an "endpoint event" telling the client what URI (ie, http://example.com/messages) to use for sending messages
* the client uses this URI to communicate with the server
* the server communicates to the client with streaming events/messages

![](/images/streamable/httpsse.png)

Let's look at a code example. On the server side you'd have these API endpoints: `/sse` and `/messages`

NOTE: You will probably have more house keeping code and a way to send messages to the client through a streaming response, but that's not shown here. The code here is "conceptual" to line up with the previous paragraph concepts.

```python

@app.get("/sse")
async def sse_endpoint(request: Request):

    endpoint_event = f"event: endpoint\ndata: /messages?client_id={client_id}\n\n"
    
    return StreamingResponse(
        endpoint_event,
        media_type="text/event-stream",
        headers={
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
        }
    )

@app.post("/messages")
async def receive_message(request: Request):
    data = await request.json()
    
    # Extract client ID from query params
    client_id = request.query_params.get("client_id")
    
    # In a real impl, you'd actually handle the client message
    # and then return something....

    return {"jsonrpc": "2.0", "id": data.get("id"), "result": {"status": "received"}}
```

On the client you'd have something to handle the SSE events. You'd have a different method to call the server on `/messages`

```python
    def handle_sse_events(self):
        headers = {'Accept': 'text/event-stream'}
        response = self.session.get(f"{self.server_url}/sse", 
                                   headers=headers, 
                                   stream=True)
        
        client = sseclient.SSEClient(response)
        
        for event in client.events():
            if event.event == "endpoint":
                self.message_endpoint = event.data
                self.connected = True
                print(f"Connected to server, message endpoint: {self.message_endpoint}")
            
            elif event.event == "message":
                try:
                    message = json.loads(event.data)
                    self.handle_message(message)
                except json.JSONDecodeError:
                    print(f"Error decoding message: {event.data}")
```

This approach has some limitations. First, it requires keeping two separate connections and endpoints 

* requires maintaining two separate connections/endpoints
* necessitates persistent connections, making stateless implementations difficult
* has limited compatibility with some infrastructure and middleware
* lacks resumability of connections in case of network issues. This created challenges for remote MCP servers that need to be accessible over the internet with potential connection disruptions.


## MCP Changes: Streamable HTTP

MCP introduces [Streamable HTTP](https://github.com/modelcontextprotocol/specification/pull/206) for remote servers in it's recent updates. In simple terms what this means is we don't need to have two separate endpoints like we did above. The client can stream responses from the server directly from the `/messages` endpoint. And the server can decide whether it will respond withe a streamable response or standard HTTP response. If the server decides to respond with a streaming response (ie, it doesn't have to be on the first response, it can be later in the connection), then it can send notifications. 

![](/images/streamable/stream.png)

The benefits of this design include:

* plain HTTP implementation: MCP can now be implemented in a plain HTTP server without requiring separate SSE support, simplifying server implementation 
* better infrastructure compatibility: being "just HTTP" ensures compatibility with standard middleware and infrastructure
* flexible implementation options: supports both stateless and stateful server implementations
* simplified client architecture: removes the need for MCP clients to send messages to a separate endpoint than the one they initially connect to; makes it easier for "non developers" to grok this

To implement this in the sever, we'd have a single endpoint `/messages` that can return either a standard HTTP response, or potentially a streamable response. In this particular example, if you send a HTTP GET request to `/messages` the server will respond with a streamable response. If you send a POST, it will respond with a standard HTTP response (code has been condensed to be more readable -- ie, removed exception handling, etc). 

```python
@app.get("/message")
async def stream_messages(request: Request, response: Response):
   
    async def event_generator():
        session = active_sessions[session_id]
        queue = session["queue"]
        
        try:
            # Send initial event for endpoint
            yield {
                "event": "message",
                "data": json.dumps({
                    "jsonrpc": "2.0", 
                    "method": "notify",
                    "params": {"type": "ready"}
                })
            }
            
            while True:
                # the rest of the code would need to support sending
                # messages to this queue
                message = await queue.get()
                if message == "CLOSE":
                    break
                
                yield {
                    "event": "message",
                    "data": json.dumps(message)
                }
    
    return EventSourceResponse(event_generator())

@app.post("/message")
async def handle_message(request: Request, response: Response):
   
    # Extract session ID from header
    session_id = request.headers.get("Mcp-Session-Id")

    body = await request.json()
    rpc_request = JsonRpcRequest(**body)

    try:
        if rpc_request.method == "initialize":
            response_obj = await handle_initialize(rpc_request.id, rpc_request.params or {})
        elif rpc_request.method == "toolList":
            response_obj = await handle_tool_list(rpc_request.id)
        elif rpc_request.method == "callTool":
            response_obj = await handle_call_tool(rpc_request.id, rpc_request.params or {})
        else:
            response_obj = JsonRpcResponse(
                id=rpc_request.id,
                error={
                    "code": -32601,
                    "message": f"Method '{rpc_request.method}' not found"
                }
            )
        
        # Return standard HTTP response
        return response_obj.dict(exclude_none=True)
    except Exception as e:
        return JsonRpcResponse(
            id=rpc_request.id,
            error={
                "code": -32603,
                "message": f"Internal error: {str(e)}"
            }
        ).dict()
```


## Is this not the same thing as HTTP+SSE??

Well, it's similar, but simplified. Let's break it down one last time:

#### In the previous HTTP+SSE transport:

* clients would connect to a dedicated /sse endpoint specifically for receiving server messages
* the server would immediately send back an "endpoint event" with a URL for the client to send messages to
* two separate connections were maintained: one for server→client (SSE) and one for client→server (HTTP POST)

#### In the new Streamable HTTP transport:

* there's only one endpoint (typically /message)
* any client request can be responded to with either a standard HTTP response or an upgraded SSE stream
* the upgrade happens dynamically based on the server's needs for that particular interaction
* the client initiates the connection with a standard HTTP request, and the server decides whether to make it "streamable"

#### This is a significant architectural improvement because:

* simplifies the protocol by using a single connection point
* allows servers to be more flexible about when to use streaming vs. one-time responses
* enables completely stateless server implementations when appropriate (which wasn't possible before)
* It follows standard HTTP patterns more closely, making it easier to implement and deploy