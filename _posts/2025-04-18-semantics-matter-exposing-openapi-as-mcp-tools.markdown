---
layout: post
title: Semantics Matter - Exposing OpenAPI as MCP Tools
modified:
categories: 
comments: true
tags: [ai, rest, agents, agentic, capabilities, llm, architecture, mcp, tools, openapi, swagger, oas]
image:
  feature:
date: 2025-04-21T03:00:00-07:00
---

I was recently chatting with [Matt McLarty](https://www.linkedin.com/in/mattmclartybc/) and [Mike Amudsen](https://www.linkedin.com/in/mamund/) on [their podcast](https://podcasts.apple.com/us/podcast/the-api-experience-podcast/id1698168565) about a recent blog I wrote about [describing APIs in terms of capabilities](https://blog.christianposta.com/from-apis-to-capabilities-what-ai-agents-mean-for-application-architecture/). One thing that came up was the idea of describing APIs with semantic meaning direclty in the OpenAPI spec. I think I made a comment that "ideally, you'd go from your OpenAPI spec to generating an MCP server to expose your capabilities to an Agent or AI model". I wanted to go into a little more detail here since there is something very interesting there. 

![](/images/mcp-openapi/visual.png)

The first thought I had is that sure, people may use OpenAPI spec docs today to describe their APIs, but they probably fall short in terms of semantic descriptions and describing the API in terms of capabilities. When building with APIs directly, humans decided which APIs to use and were able to informally fill in the "semantic context" gaps on their own. But in the case of AI agents and tools, the LLM will need as much context as possible to make appropriate decisions about which tools to use. But we don't want to have bifurcation: where we have two different sources of truth for an API description, one for MCP and one for human's building with APIs directly. We want a single unified source:  and that should be the [OpenAPI spec](https://swagger.io/specification/). But this means we'll have to invest just a little more in building rich semantic meaning and capability descriptions into our OpenAPI spec. 

## APIs to Capabilities

Enterprises have invested 10-15+ years into exposing enterprise capabilities (internal and external) with APIs. That is not going away. MCP, as exciting as it is, is really just a simple protocol _shim_ for AI models to call tools. But to expose the tools correctly to the model, we need to [describe capabilities](https://blog.christianposta.com/from-apis-to-capabilities-what-ai-agents-mean-for-application-architecture/):

* tool names should be unique, action oriented (e.g., "listAllTodoTasks" vs just "list")
* include detailed _purpose explanations_
* give examples of when to call with example requests/responses
* preconditions for using the tool

## Using OpenAPI Spec

The OpenAPI Specification contains a number of fields and structures to support adding rich semantic meaning to our APIs:

* Using the `info` section
* A number of sections offer the ability to link out to `externalDocs`
* Most sections provide a `title`, `summary`, and `description` field
* You can link out to industry accepted (or enterprise specific) data fields using JSON-LD for very deep semantic meaning
* If none of these are adequate, you can extend the spec with "x-properties"

Let's take a quick look at an example.

To specify a rich `info` for a Todo API could look like this:

```yaml
openapi: 3.0.3
info:
  title: Enhanced Todo API
  description: >
    This API exposes the capability to manage personal or team todos, including creating,
    updating, organizing, and retrieving tasks with rich metadata such as due dates,
    priorities, and tags. It is designed to support systems and AI agents in dynamically
    coordinating tasks, tracking progress, and planning workflows. Ideal for scenarios
    where task orchestration and contextual decision-making are required, such as goal
    tracking, workflow assistants, or productivity tools.
  version: 1.0.0
  termsOfService: https://example.com/terms/
  contact:
    name: API Support Team
    url: https://example.com/support
    email: support@example.com
  license:
    name: Apache 2.0
    url: https://www.apache.org/licenses/LICENSE-2.0.html
```

We can also (and probably should) include a link to any documentation that may go with this API / tool. 

```yaml
externalDocs:
  description: Find detailed documentation for all use cases related to this API
  url: https://example.com/docs
```

For specific API paths, we can add detailed capabilities to the descriptions and summaries:

```yaml
  /todos:
    get:
      summary: Discover existing todos for contextual task awareness and planning
      description: >
        Allows clients or AI agents to retrieve a list of existing todo items, optionally filtered 
        by completion status and constrained by pagination parameters. This capability is useful 
        for understanding the current state of tasks, identifying pending work, and planning next 
        actions. It enables dynamic task awareness within workflows such as productivity tracking, 
        personal assistants, or automated planning systems that rely on real-time context.
      operationId: listAllTodoTasks
      tags:
        - todos
      parameters:
        - name: limit
          in: query
          description: Maximum number of items to return
          schema:
            type: integer
            format: int32
            minimum: 1
            maximum: 100
            default: 20
        - name: completed
          in: query
          description: Filter by completion status
          schema:
            type: boolean
      responses:
        '200':
          description: A JSON array of todo items
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/Todo'
                  pagination:
                    $ref: '#/components/schemas/Pagination'
```

JSON-LD ([JSON Linked Data](https://json-ld.org)) gives us a very powerful opportunity to give exact meaning and semantic contex to the data model we use in requests or responses. We can link to industry established and agreed-upon terms (ie, https://schema.org or https://w3.org/) or to commpany-specific data model ontologies or definitions. This means our API not only describes these data models very explicitly, but the responses from our API will also include very detailed semantic information. A client is free to dig deeper into these semantic meanings (which we'll talk about in the next section). Here's an example of using JSON-LD in our schema info:

```yaml
openapi: 3.0.3
info:
  <omitted for clarity>
  x-linkedData:
    "@context":
      schema: "https://schema.org/"
      hydra: "http://www.w3.org/ns/hydra/core#"
      vocab: "https://api.example.com/vocab#"
    "@type": "schema:WebAPI"
    "@id": "https://api.example.com/v1"
    "schema:name": "Enhanced Todo API"
    "schema:description": "A comprehensive API to manage todos with rich metadata and semantic annotations"
    "schema:provider":
      "@type": "schema:Organization"
      "schema:name": "Example Organization"
      "schema:url": "https://example.com"
    "schema:dateModified": "2025-04-15"
```


If none of these good options are suitable for you, you can also choose to [extend the OpenAPI spec](https://swagger.io/docs/specification/v3_0/openapi-extensions/) with your own custom properties. For example, maybe you have some backward compatibility issues with the `description` or `summary` fields for your paths. You can add a custom property that adds a more robust description like this:

```yaml
  /todos:
    get:
      summary: Discover existing todos for contextual task awareness and planning
      description: Simple description here
      tags:
        - todos
      x-company-mcp:
        name: very-descriptive-name-here
        description: much more descrptive description here

    ...

```

## Converting to MCP

Now we need to think about how to convert our OpenAPI spec to an MCP tool. We can use `operationId` to specify our tool name, but what about for descriptions? MCP tools are described in terms of capabilities with enough context for the AI model to decide which tool to use and when. When mapping from the OpenAPI spec, you can map operation description and parameter descriptions directly, or you can enhance them when you map them to the MCP tools. You can even follow JSON-LD URIs to populate data structures with more complete semantic meaning. Here's an example of what an MCP tools response looks like:


```json
{
  "jsonrpc": "2.0",
  "id": 123,
  "result": {
    "tools": [
      {
        "name": "listAllTodoTasks",
        "description": "Allows clients or AI agents to retrieve a list of existing todo items, optionally filtered 
        by completion status and constrained by pagination parameters. This capability is useful 
        for understanding the current state of tasks, identifying pending work, and planning next 
        actions. It enables dynamic task awareness within workflows such as productivity tracking, 
        personal assistants, or automated planning systems that rely on real-time context.",
        "inputSchema": {
          "type": "object",
          "properties": {
            "limit": {
              "type": "integer",
              "description": "Maximum number of items to return (1-100)",
              "minimum": 1,
              "maximum": 100,
              "default": 20
            },
            "completed": {
              "type": "boolean",
              "description": "Filter by completion status"
            }
          }
        },
        "annotations": {
          "title": "Enhanced Todo API",
          "readOnlyHint": true,
          "openWorldHint": false
        }
      }
    ]
  }
}
```

Treating the OpenAPI spec as the single source of truth for your API—and any derived interactions like MCP shims—is critical. Neglecting the quality and consistency of your OpenAPI specs can cause serious downstream issues, especially when integrating with AI agents, LLMs, or MCP-based tools. Inconsistent or underspecified specs can lead to mismatches across services, complicate MCP tool generation, and create versioning or backend compatibility issues that break agent workflows. For AI models, vague or incomplete tool descriptions can cause misinterpretations—selecting the wrong tool, using invalid parameters, or misunderstanding intent (e.g., creating a record when it should query one). This not only degrades the quality of agent behavior but can result in hallucinations, off-goal actions, or complete failure.

Let's try to summarize this:

| MCP Tool Element   | OpenAPI Source Field(s)         | Notes                                             |
|--------------------|---------------------------------|---------------------------------------------------|
| Tool Name          | `operationId`                   | Unique, machine-friendly; fallback to method/path |
| Tool Description   | `summary` / `description`       | Prefer `summary` for brevity, `description` for detail |
| Input Schema       | `parameters`, `description`     | Structured input; includes types, constraints     |
| Output Schema      | `responses`                     | Structured output; success and error responses    |
| Invocation Details | `servers`, path, method         | URL, HTTP verb, server base                       |
| Security           | `security`, `components.securitySchemes` | Auth context for protected endpoints     |

An important note about security here. LLM prompt injection is a top security concern [as published by OWASP](https://owasp.org/www-project-top-10-for-large-language-model-applications/). [Tool poisoning](https://invariantlabs.ai/blog/mcp-security-notification-tool-poisoning-attacks) attacks can happen when a tool's description (or parameter descriptions) get poisoned with malicious instructions. It's very important that the OpenAPI spec get reviewed and checked sanitized. This ideally happens during API governance workflows, but a failsafe option can be to perform similar sanitization checks during OpenAPI to MCP conversion. I'll be writing more about this problem in a future blog. Follow along if interested ([@christianposta](https://x.com/christianposta) or [/in/ceposta](https://linkedin.com/in/ceposta)). 

## Where should this mapping happen?

As mentioned earlier, although there may be some native MCP implementations, an enterprise is going to expose MCP tools by leveraging their existing API investment. So where should this mapping happen? You may find AI native tools to do this conversion that take into account these factors described here; you may find an API gateway that can expose REST endpoints as an MCP server. You may also build some custom mapping tools yourself. Some combination of this is what I would expec to see in the enterprise. If you have thoughts or comments on this [please let me know]((https://linkedin.com/in/ceposta))!