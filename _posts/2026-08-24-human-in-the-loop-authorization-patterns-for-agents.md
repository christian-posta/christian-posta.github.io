---
title: "Human-in-the-loop Authorization Patterns for Agents"
date: 2026-08-24T23:17:52Z
categories: []
tags: []
description:
# Uncomment if this post includes Mermaid diagrams:
# mermaid: true
# Uncomment to add a feature image:
# image:
#   path: /images/path/to/image.png
#   alt: Description of the image
---

In my work with customers adopting and securing AI agents at scale in enterprise environments, we are running into "human in the loop" usecases. For example, usecases where a sensitive operation MUST be approved by a human; sometimes even a different human than the one on whose behalf the agent is acting. As part of my work on Agent Identity and Access Management here at Solo.io, I research various patterns and options. I want to distill some of the patterns/spec drafts that exist to address these types of usecases. 

## Two kinds of human in the loop

There are two types of "Human in the Loop" (HitL) we'll call out. The first is a **harness check** based HitL. The harness classifies some action as "looks risky" and asks its user (or some representation of the user), “Is this okay?” This is useful because it gives the user a chance to review risky behavior as determined by the agent/harness.

In the organizations we've been working with, this is not the only type of HitL needed.

If the model, prompt, or tool description decides when to ask, the agent is largely policing itself. What if the harness doesn't? What if, across harnesses, it's inconsistent? Another execution path may call an API directly. A plugin or sub-agent may bypass the harness. Prompt injection may convince the agent that approval is unnecessary or already happened. Even after the click, the agent may execute something different from what it displayed.

Organizations under compliance regulation must be able to enforce HitL as part of policy enforcement:

> Policy requires an authorized principal (or multiple) to approve this exact action before an enforcement point will permit it to execute.

Here, asking is not optional. The agent does not decide when a human decision is required, the authorization boundary does that.

![HITL](/images/hitl/hitl.png)

In this blog we'll look at the following options to solve this problem:

* MCP Multi Round-Trip Requests (MRTR)
* MCP Tasks
* Agent Auth (AAuth)

## What Enterprise HitL must provide

Before looking at implementations, let's establish a baseline for what needs to be supported. An enterprise HitL mechanism should provide:

- **Accountable authority.** Identify the agent, requester, approver, and workload. Policy determines who may approve and whether duties must be separated. 
- **Exact binding.** Bind the decision to the operation, parameters, destination, requester, policy, expiry, and the semantic display reviewed by the approver.
- **Revalidation at enforcement.** Before execution, re-check identity, policy, schema, credentials, destination, and the exact operation. Drift requires a new decision. Stale credentials require re-acquisition.
- **Bounded execution.** Define whether approval covers one invocation, a reusable scope, a session, or a mission. 
- **Durable evidence.** Record what was requested, what the approver saw, who decided, which policy applied, what executed, and what happened.

These properties are what make HitL critical for compliance. No protocol is inherently "SOX compliant" for example, and the [Sarbanes-Oxley Act](https://www.govinfo.gov/content/pkg/COMPS-1883/pdf/COMPS-1883.pdf) does not prescribe an agent approval flow. But when agents can affect business systems, HitL can support internal controls.

With those requirements in hand, we can evaluate the leading patterns, starting with what MCP gives us out of the box.

## MCP MRTR: retry the original operation

Models can reason about things, and they can make decisions, but actions actually happen by calling APIs and data systems. One of the prevailing ways agents do that today is with MCP and MCP tools. If we're going to look at approval and human in the loop for enterprise authorization, we should start where the action can execute, and MCP is the natural place because of how widely adopted it is. It's not the only way, and there are many ways, but let's start somewhere!

MCP's [multi-round-trip request pattern](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr) is a pattern made concrete in the most recent (7-2026) update of MCP. The idea is simple: the agent (via its MCP client) calls a tool, the MCP server decides it needs more input before it can proceed, and it pauses that operation instead of executing it. A human decision can be one of those inputs. The human gets involved through whatever interaction the server asks the client to present, often a URL-mode elicitation that opens an approval page out of band. Once that input is available (or the human has at least completed the interaction), the client retries the *same* tool call, carrying enough state for the server to pick up where it left off. If approval is still pending, the server can ask it to retry again. Once approved, the server revalidates and executes the current operation.

For HitL, when the missing input *is* a human approval, the human sits between the first attempt and the successful retry, and the original client is expected to stay engaged the whole time. MRTR is ultimately built for approvals that can happen pretty quickly (seconds to minutes, not days). Whether that matches how enterprises actually approve sensitive actions is a different question, and we'll come back to it.

![MCP multi-round-trip request flow](/images/hitl/mcp-mrtr.png)

The protocol flow looks like this:

1. **The client makes the original tool call.**

   ```json
   {
     "jsonrpc":"2.0",
     "id":1,
     "method":"tools/call",
     "params":{
       "name":"initiate_payment",
       "arguments":{"amount":"5000.00","currency":"GBP","recipient":"Example Ltd"}
     }
   }
   ```

2. **The server terminates that request with `input_required`.** Here it asks the client to present a URL-mode elicitation and returns opaque continuation state. Because that state will influence authorization, the server must integrity-protect it and bind it to the requester and operation. The server can send this request only if the client advertised support for URL elicitation.

   ```json
   {
     "jsonrpc":"2.0",
     "id":1,
     "result":{
       "resultType":"input_required",
       "inputRequests":{
         "approval":{
           "method":"elicitation/create",
           "params":{
             "mode":"url",
             "message":"Review this GBP 5,000 payment",
             "url":"https://approve.example/requests/abc123"
           }
         }
       },
       "requestState":"<opaque-integrity-protected-state>"
     }
   }
   ```

3. **The client presents the interaction to the human.** For URL elicitation, an `accept` response means the human agreed to open the URL, not that they approved the payment. The approval itself happens out of band.

4. **The client retries the original method with a new JSON-RPC ID.** It sends the operation again, echoes `requestState` exactly, and includes the elicitation response.

   ```json
   {
     "jsonrpc":"2.0",
     "id":2,
     "method":"tools/call",
     "params":{
       "name":"initiate_payment",
       "arguments":{"amount":"5000.00","currency":"GBP","recipient":"Example Ltd"},
       "inputResponses":{"approval":{"action":"accept"}},
       "requestState":"<opaque-integrity-protected-state>"
     }
   }
   ```

5. **The server either asks for another retry or completes the call.** A still-pending decision can produce another `input_required`, even with only refreshed `requestState`. Once approved, the server revalidates the retried operation, executes it, and returns the ordinary tool result.

   ```json
   {
     "jsonrpc":"2.0",
     "id":2,
     "result":{
       "resultType":"input_required",
       "requestState":"<refreshed-opaque-state>"
     }
   }
   ```

   ```json
   {
     "jsonrpc":"2.0",
     "id":3,
     "result":{
       "resultType":"complete",
       "content":[{"type":"text","text":"Payment initiated"}],
       "isError":false
     }
   }
   ```

MRTR's key benefit is that the original operation returns to the enforcement point before execution. The server can detect changed arguments rather than blindly executing a stored snapshot. Continuation state can also remain much smaller than a durable work object.

But MRTR supplies only the client/server pause-and-resume exchange. The approver system, policy, protected state, operation binding, audit trail, and delayed decision store are custom work. The protocol as written doesn't really support a good retry pacing option, and assumes the client will resume faithfully rather than re-plan.

So we come back to the timing question. MRTR works when the interaction is short and the original client remains engaged. For longer lived approval flows (ie, another party that may take hours or days), that assumption breaks, and MRTR is not an appropriate solution.

## MCP Tasks: represent durable asynchronous work

Where MRTR assumes the client stays engaged for a short pause, MCP [Tasks](https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/seps/2663-tasks-extension.md) are meant to be asynchronous. A Task-capable operation returns a durable work record instead of an immediate result, and that work can stretch across a long period of time, potentially days. The client can poll status, supply requested input, cancel, and retrieve the eventual result later. The client and the approver do not have to remain online together.

Tasks are also not very opinionated about what happens while the work is open. A Task can pause, something else can happen outside the MCP exchange (an approval workflow, a second reviewer, a ticket in a queue, etc), and later the Task continues. If you're thinking about HitL (one human approval, or multiple), MCP doesn't really say anything about that workflow. You can build a pretty powerful and custom approval path behind the Task, but Tasks become the mechanism the client or agent knows how to speak. That's important, because this kind of long-running approval interaction is not very well nailed down yet in any widely adopted protocol.

![MCP Tasks human-in-the-loop flow](/images/hitl/mcp-task.png)

The main protocol flow is:

1. **The client and server advertise the Tasks extension.** The server declares support through `server/discover`; the client includes its support on the tool call. That means the client can handle a Task, but the server still decides whether this particular call becomes one.

   ```json
   {
     "jsonrpc":"2.0",
     "id":1,
     "method":"tools/call",
     "params":{
       "name":"initiate_payment",
       "arguments":{"amount":"5000.00","currency":"GBP","recipient":"Example Ltd"},
       "_meta":{
         "io.modelcontextprotocol/clientCapabilities":{
           "extensions":{"io.modelcontextprotocol/tasks":{}}
         }
       }
     }
   }
   ```

2. **The server durably creates a Task before returning its handle.** `pollIntervalMs` tells the client how often to check; `ttlMs` bounds the Task's lifetime.

   ```json
   {
     "jsonrpc":"2.0",
     "id":1,
     "result":{
       "resultType":"task",
       "taskId":"task-abc123",
       "status":"working",
       "createdAt":"2026-08-18T17:00:00Z",
       "lastUpdatedAt":"2026-08-18T17:00:00Z",
       "ttlMs":3600000,
       "pollIntervalMs":5000
     }
   }
   ```

3. **The client polls with `tasks/get`.** Unlike MRTR, it does not resend the original `tools/call`. Each response is a snapshot of the server-held Task.

   ```json
   {
     "jsonrpc":"2.0",
     "id":2,
     "method":"tasks/get",
     "params":{"taskId":"task-abc123"}
   }
   ```

   ```json
   {
     "jsonrpc":"2.0",
     "id":2,
     "result":{
       "resultType":"complete",
       "taskId":"task-abc123",
       "status":"working",
       "createdAt":"2026-08-18T17:00:00Z",
       "lastUpdatedAt":"2026-08-18T17:00:00Z",
       "ttlMs":3600000,
       "pollIntervalMs":5000
     }
   }
   ```

4. **If the Task needs client input, it reports `status: "input_required"`.** The outstanding request appears in a later `tasks/get` result, and the client answers it with `tasks/update` keyed by `taskId`. This is not MRTR: the client does not retry the original method. The update is only an acknowledgement path; an `accept` response is not, by itself, authoritative human approval.

   ```json
   {
     "jsonrpc":"2.0",
     "id":3,
     "result":{
       "resultType":"complete",
       "taskId":"task-abc123",
       "status":"input_required",
       "createdAt":"2026-08-18T17:00:00Z",
       "lastUpdatedAt":"2026-08-18T17:00:05Z",
       "ttlMs":3600000,
       "pollIntervalMs":5000,
       "inputRequests":{
         "approval":{
           "method":"elicitation/create",
           "params":{
             "mode":"url",
             "message":"Review this GBP 5,000 payment",
             "url":"https://approve.example/requests/abc123"
           }
         }
       }
     }
   }
   ```

   The client then sends `tasks/update`:

   ```json
   {
     "jsonrpc":"2.0",
     "id":4,
     "method":"tasks/update",
     "params":{
       "taskId":"task-abc123",
       "inputResponses":{"approval":{"action":"accept"}}
     }
   }
   ```

   The server acknowledges `tasks/update`; the client then resumes polling because the Task update may be eventually consistent.

   ```json
   {"jsonrpc":"2.0","id":4,"result":{"resultType":"complete"}}
   ```

5. **The client keeps polling until the Task reaches a terminal state.** After a separate authorization system has approved the operation and the server has executed it, `tasks/get` returns the stored tool result inline.

   ```json
   {
     "jsonrpc":"2.0",
     "id":5,
     "result":{
       "resultType":"complete",
       "taskId":"task-abc123",
       "status":"completed",
       "createdAt":"2026-08-18T17:00:00Z",
       "lastUpdatedAt":"2026-08-18T17:01:00Z",
       "ttlMs":3600000,
       "pollIntervalMs":5000,
       "result":{
         "content":[{"type":"text","text":"Payment initiated"}],
         "isError":false
       }
     }
   }
   ```

The other terminal states are `failed` and `cancelled`. A client can request cooperative cancellation with `tasks/cancel`; the acknowledgement does not guarantee that the server stopped the work.

```json
{"jsonrpc":"2.0","id":6,"method":"tasks/cancel","params":{"taskId":"task-abc123"}}
```

For HitL, a server can create a Task and hold it while a separate approval process runs. After authorization, a server-side executor dispatches the stored or reconstructed operation and records the result.

Tasks standardize only the MCP client-to-server work lifecycle. They do not define:

- who the agent, requester, or approver is;
- which actions require approval;
- how the human is authenticated and authorized;
- what the human must see;
- how the decision binds to the operation;
- how delayed execution is secured; or
- what evidence satisfies an auditor.

Those pieces require a decision service, policy model, approval API and UI, secure store, single-use state transition, dispatcher, drift checks, reconciliation, and audit system. MCP Tasks are a good primitive, but the surrounding authorization control plane is out of scope for MCP Tasks. Which is a good place to start, but not the final solution (at least not without a little bit of elbow grease!)

## AAuth: an authorization architecture for agents

So what if more of that control plane were standardized? These kinds of agentic interactions (pausing for human approval, binding a decision to an exact action, then continuing) are core to how agents will behave in the enterprise, and something should standardize them. MCP can help with a subsection of that story (MRTR for short pauses, Tasks for durable work), but MCP is not a more generic agent communication or authorization protocol. That's where [AAuth](https://datatracker.ietf.org/doc/draft-hardt-oauth-aauth-protocol/) comes into the picture.

AAuth is an emerging spec (from [Dick Hardt](https://www.aauth.dev)) trying to solve a real problem, and it doesn't arrive blank or in a vacuum. It shows up with multiple pieces aimed at the broader agentic protocol story: portable per-instance agent identity, dynamic registration, how authorization happens between agents and resources, and proof-of-possession signatures so you're not carrying bearer tokens around. Resources can authorize by agent identity, manage authorization themselves, rely on the agent's Person Server (the entity that represents a person), or federate that Person Server with a resource's Access Server. See the complete draft for more.

Let's see how AAuth can help with human in the loop.

![AAuth human-in-the-loop authorization flow](/images/hitl/aauth.png)

To keep it simple, let's start with AAuth's **resource-managed** mode:

1. **The agent signs a request with its agent identity.** `Signature-Key` carries an agent token bound to the key used for the HTTP Message Signature.

   ```http
   POST /payments
   Host: resource.example
   Content-Type: application/json
   Signature-Input: sig=("@method" "@authority" "@path" "signature-key");created=1787094000
   Signature: sig=:<signature-bytes>:
   Signature-Key: sig=jwt;jwt="<aa-agent-jwt>"

   {"amount":"5000.00","currency":"GBP","recipient":"Example Ltd"}
   ```

2. **The resource requires human interaction.** It returns `202 Accepted`, a same-origin pending URL, polling guidance, and an AAuth requirement containing a human-facing URL and correlation code. AAuth also supports a back-channel human approval, discussed below.

   ```http
   HTTP/1.1 202 Accepted
   Location: https://resource.example/pending/abc123
   Retry-After: 5
   Cache-Control: no-store
   AAuth-Requirement: requirement=interaction;
     url="https://resource.example/interaction"; code="A1B2-C3D4"
   Content-Type: application/json

   {"status":"pending"}
   ```

3. **The agent directs the human to the interaction.** It opens or displays the URL with the code appended. The resource authenticates the human and collects the decision. The code locates the pending request; it does not authorize approval by itself.

   ```text
   https://resource.example/interaction?code=A1B2-C3D4
   ```

4. **The agent polls the pending URL with signed `GET` requests.** While the decision is open, the resource returns `202` with `pending` or `interacting`. After approval, it returns `200` and may issue an opaque `AAuth-Access` token.

   ```http
   GET /pending/abc123
   Host: resource.example
   Signature-Input: sig=("@method" "@authority" "@path" "signature-key");created=1787094030
   Signature: sig=:<signature-bytes>:
   Signature-Key: sig=jwt;jwt="<aa-agent-jwt>"
   ```

   ```http
   HTTP/1.1 200 OK
   AAuth-Access: <opaque-access-token>
   Cache-Control: no-store
   Content-Type: application/json

   {"status":"authorized","scope":"payments.initiate"}
   ```

5. **The agent retries the operation with that authorization.** The `AAuth-Access` token is covered by the agent's HTTP signature, so stealing the token alone is not enough to use it.

   ```http
   POST /payments
   Host: resource.example
   Authorization: AAuth <opaque-access-token>
   Content-Type: application/json
   Signature-Input: sig=("@method" "@authority" "@path" "authorization" "signature-key");created=1787094040
   Signature: sig=:<signature-bytes>:
   Signature-Key: sig=jwt;jwt="<aa-agent-jwt>"

   {"amount":"5000.00","currency":"GBP","recipient":"Example Ltd"}
   ```

For approval happening elsewhere, ie, an administrator, resource owner, or compliance queue, the same deferred flow uses `requirement=approval` without asking the agent to present a URL or code. The agent simply polls for the decision.

This two-party example is only the shortest AAuth path. The full protocol defines [four resource-access modes](https://datatracker.ietf.org/doc/html/draft-hardt-oauth-aauth-protocol-10#section-4.1), a [Person Server](https://datatracker.ietf.org/doc/html/draft-hardt-oauth-aauth-protocol-10#section-7) that can govern remote resources and local actions such as tool calls or file writes, and optional [missions](https://datatracker.ietf.org/doc/html/draft-hardt-oauth-aauth-protocol-10#section-8) carrying broader intent and history. Those pieces reuse the same deferred-response pattern for interaction, approval, clarification, revision, and cancellation.

Similar to MRTR, the original operation comes back to the enforcement point after the decision (the agent polls the pending URL, then retries the call), but here the `AAuth-Access` token is bound to the agent's signed request so it can't be replayed as a bearer token. The simple resource-managed grant is still intended for subsequent calls; exact, single-use approval for one high-impact invocation may require a stricter profile.

Of the patterns here, AAuth is the most complete attempt at a general agent authorization architecture.

## Where does that leave us?

If HitL is protecting something that matters (moving money, changing production, touching systems in scope for SOX, etc), the enforcement point has to own the decision: it requires the approval, binds it to the exact operation, revalidates before executing, and keeps enough evidence to show an auditor what happened. Those are the requirements we started with. So what can you actually do today? I see two realistic paths, and which one fits depends mostly on whether you're optimizing for MCP compatibility or for a more general agent authorization architecture.

### Path one: MCP plus a custom authorization control plane

If your agents mostly act through MCP tools, you can use MRTR or Tasks as the part the client knows how to speak, and build the policy, identity, approval UI, operation binding, execution, and audit pieces behind it yourself. Which one you pick comes back to the timing question: MRTR fits a quick approval while the original client is still engaged (seconds to minutes), and Tasks fit when the approval goes to another person or a queue and may take hours or days.

This works with the MCP clients people already run, and since you own the approval path you can make it as strict as you need (ie, single-use approval per invocation). The catch is that the hardest security and compliance pieces are now your own custom code, and none of it interoperates past the MCP boundary.

### Path two: AAuth

If your agents call more than MCP tools (APIs directly, other agents, local actions like file writes, etc), I think AAuth is worth a hard look. It standardizes a lot more of the picture: agent identity, how resources and Person Servers authorize, how a human gets pulled into the interaction, and the deferred responses that let a request wait on that human. The cost is that it's an emerging draft, it's much broader than anything MCP defines, it has to be integrated with the identity and policy systems you already run, and for one-shot approval of a single high-impact call you may need a tighter profile than the resource-managed mode we walked through.

So which one? If MCP compatibility and keeping control of the approval path are what you care about most, building around MRTR/Tasks is reasonable, just go in knowing you're building the authorization control plane yourself. If you want a general, interoperable way to do agent authorization (of which HitL is one piece), I'd look hard at AAuth, keeping in mind it's still early.

If you disagree, have alternative view points, or want to share encouragement, I would love to know!! Please share in the comments or social: (My LinkedIn: [/in/ceposta](https://linkedin.com/in/ceposta))
