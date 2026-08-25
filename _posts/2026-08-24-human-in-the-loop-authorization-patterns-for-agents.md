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

In my work with customers adopting and securing AI agents at scale in enterprise environments, we are running into "human in the loop" usecases. For example, usecases where a sensitive operation MUST be approved by a human; sometimes even a different human than the one on who's behalf the agent is acting. As part of my work on Agent Identity and Access Management here at Solo.io, I research various patterns and options. I want to distill some of the patterns/spec drafts that exist to address these types of usecases. 

## Two kinds of human in the loop

There are two types of "Human in the Loop (HitL) we'll call out. The first is a **harness check** based HitL. The harness classifies some action as "looks risky" and asks its user, “Is this okay?” This is useful because it gives the user to review risky behavior as determined by the agent/harness.

In the organizations we've been working with, this is not the only type of HitL needed.

If the model, prompt, or tool description decides when to ask, the agent is largely policing itself. Another execution path may call an API directly. A plugin or sub-agent may bypass the harness. Prompt injection may convince the agent that approval is unnecessary or already happened. Even after the click, the agent may execute something different from what it displayed.



Enterprise HitL has a stronger meaning:

> Policy requires an authorized principal to approve this exact action before an enforcement point will permit it to execute.

Here, asking is not optional. The agent does not decide when a human decision is required, the authorization boundary does that.

![HITL](/images/hitl/hitl.png)

In this blog we'll look at the following options to solve this problem:

* Confirmation with Human Exchange of Qutoations (CHEQ)
* Transaction Authorization Challenge tokens (TAC)
* Agent Auth (AAuth)
* MCP Multi Round-Trip Requests (MRTR)
* MCP Tasks

## What Enterprise HitL must provide

Before comparing protocols, we need criteria. A serious HitL authorization system should provide:

- **Accountable authority.** Identify the agent, requester, approver, workload, and any delegation chain. Policy determines who may approve and whether duties must be separated. 
- **Exact binding.** Bind the decision to the operation, parameters, destination, requester, policy, expiry, and the semantic display reviewed by the approver.
- **Revalidation at enforcement.** Before execution, re-check identity, policy, schema, credentials, destination, and the exact operation. Drift requires a new decision. Stale credentials require re-acquisition.
- **Bounded execution.** Define whether approval covers one invocation, a reusable scope, a session, or a mission. 
- **Durable evidence.** Record what was requested, what the approver saw, who decided, which policy applied, what executed, and what happened.

These properties are what make HitL critical for compliance. No protocol is inherently “SOX compliant" for example, and the [Sarbanes-Oxley Act](https://www.govinfo.gov/content/pkg/COMPS-1883/pdf/COMPS-1883.pdf) does not prescribe an agent approval flow. But when agents can affect systems involved in financial reporting, HitL can support internal controls.

With those requirements in hand, we can evaluate the leading patterns.

## CHEQ: memorialize what the human confirmed

[CHEQ](https://datatracker.ietf.org/doc/draft-rosenberg-aiproto-cheq/) was an early draft which brough the idea of a "confirmation server" to familiar entities like clients and resource servers. When an operation needs confirmation, the resource returns a set of URIs. The confirmation service obtains a signed CHEQ object describing the operation, renders it to an authenticated human, adds the confirmation, and returns it to the resource. The agent polls a result URI.

![CHEQ human confirmation protocol flow](/images/hitl/cheq.png)

The flow looks roughly like this:

1. **The agent calls the resource.** For example, booking a flight with some of its details:

   ```http
   POST /api/v1/book-flight
   Authorization: Bearer <agent-access-token>
   Content-Type: application/json

   {"flight_number":"UA23","date":"2026-09-08","cost_usd":1200}
   ```

2. **The resource's policy requires confirmation.** It returns `202 Accepted` with a URI pack. The agent remembers the result URI and passes the pack to its user-facing application.

   ```http
   HTTP/1.1 202 Accepted
   Content-Type: application/json

   {
     "confirmation uri":"https://confirm.example",
     "resource uri":"https://api.airline.example/confirmations/8asdjd8g9g0as",
     "result uri":"https://api.airline.example/results/nn88kak0s0d8jj39sla"
   }
   ```

3. **The user application starts the browser interaction.** It sends the resource URI to the confirmation service. The confirmation service authenticates the human, then uses its own service credential to retrieve the signed CHEQ object from the resource server. The draft does not finish the exact parameter or retrieval URI syntax.

   ```http
   GET {resource-server}/cheq
   Authorization: Bearer <confirmation-service-token>
   ```

   ```json
   {
     "version": 1.0,
     "operation": "https://airline.example/api/v1/book-flight",
     "operation name": "Book airline",
     "inputs": {
       "parameters": [
         {"parameter name":"flight number","parameter value":"UA23"},
         {"parameter name":"flight date","parameter value":"8 September 2026"},
         {"parameter name":"flight cost","parameter value":"$1200 USD"}
       ]
     },
     "date": "18 August 2026, 15:00 UTC"
   }
   ```

4. **The human accepts or rejects.** On acceptance, the confirmation service adds its signature and posts the signed CHEQ object to the transaction-specific resource URI.

   ```http
   POST https://api.airline.example/confirmations/8asdjd8g9g0as?accept
   Authorization: Bearer <confirmation-service-token>

   <resource-and-confirmation-server-signed CHEQ object>
   ```

   The draft leaves the signed-object body, signature, and multi-signature formats undefined.

5. **The agent polls the result URI.** Once the resource has recorded the decision, it returns the final application result. CHEQ specifies polling but does not define the HTTP method, pending response, cadence, or replay behavior; this `GET` is illustrative.

   ```http
   GET /results/nn88kak0s0d8jj39sla
   Authorization: Bearer <agent-access-token>
   ```

   ```json
   {"booking_ref":"F7K2Q","status":"confirmed"}
   ```

Notice what does—and does not—cross the agent. The agent receives the URI pack and final result. The signed CHEQ object and human decision travel between the confirmation service and resource server, outside the agent's control.

CHEQ's strongest idea is that the human should review a representation protected from manipulation by the agent or confirmation UI. It also explores privacy patterns where sensitive values need not pass through the agent.

The evaluated draft is incomplete, however, and at time of writing expired. CHEQ gives us a valuable trusted-confirmation model, but not a complete enterprise authorization architecture.

## TAC: authorize a challenged transaction

The [OAuth Transaction Authorization Challenge](https://datatracker.ietf.org/doc/draft-rosomakho-oauth-txn-challenge/) is a recent draft (more thought through than CHEQ) which also starts at the protected resource. When a client requests a sensitive operation, the resource returns a signed challenge describing that transaction and its authorization details. The client submits the challenge to an authorization server, which applies policy and obtains any required approval out of band. Once approved, the server issues an access token bound to the transaction. The client retries the operation with that token.

![TAC transaction authorization challenge flow](/images/hitl/tac.png)

The flow looks roughly like this:

1. **The agent calls the protected resource and opts into TAC.** 

   ```http
   POST /payments
   Authorization: Bearer <initial-access-token>
   Accept-Txn-Challenge: ?1
   Content-Type: application/json

   {"amount":"5000.00","currency":"GBP","recipient":"Example Ltd"}
   ```

2. **The resource challenges the transaction.** It returns an OAuth error containing a signed JWT. The JWT identifies the resource (`iss`), trusted authorization server (`aud`), transaction (`txn`), expiry, requested authorization details, reason, and optional actor/delegation context.

   ```http
   HTTP/1.1 401 Unauthorized
   WWW-Authenticate: Bearer error="transaction_authorization_required",
     transaction_challenge="<signed-challenge-jwt>"
   ```

   The decoded challenge payload looks like:

   ```json
   {
     "iss":"https://resource.example.com",
     "aud":"https://as.example.com",
     "iat":1787094000,
     "exp":1787094300,
     "jti":"f1f7c8c4-2f8c-4c6a-83d1-example",
     "txn":"97053963-771d-49cc-a4e3-20aad399c312",
     "authorization_details":[{
       "type":"payment",
       "actions":["initiate"],
       "locations":["https://payments.example.com/accounts/123"],
       "instructedAmount":{"currency":"GBP","amount":"5000.00"},
       "creditorName":"Example Ltd"
     }],
     "reason":"Approval is required before initiating this payment.",
     "act":{"sub":"spiffe://example.com/aiagent/6526f880"}
   }
   ```

3. **The agent relays the challenge and the client submits it to the authorization server.** The agent must relay the challenge without modification. Confidential clients authenticate as they would at an OAuth token endpoint; public clients identify themselves with `client_id`.

   ```http
   POST /txn-authorization
   Host: as.example.com
   Content-Type: application/x-www-form-urlencoded

   client_id=s6BhdRkqt3&transaction_challenge=<signed-challenge-jwt>
   ```

4. **The authorization server accepts the request for processing.** This does not mean the payment is approved. It gives the client a transaction authorization ID, expiry, polling interval, and optionally a URI for human interaction. How the human or organizational workflow authenticates and decides is owned by the authorization server.

   ```json
   {
     "transaction_authorization_id":"txn-authz-abc123",
     "authorization_uri":"https://as.example.com/txn-authorization/txn-authz-abc123",
     "expires_in":300,
     "interval":5
   }
   ```

5. **The client polls the authorization server.** It posts the transaction authorization ID. While the decision is open, it receives `authorization_pending` or `slow_down`. After approval, it receives a short-lived access token and the granted authorization details.

   ```http
   POST /txn-authorization
   Host: as.example.com
   Content-Type: application/x-www-form-urlencoded

   client_id=s6BhdRkqt3&transaction_authorization_id=txn-authz-abc123
   ```

   ```http
   HTTP/1.1 400 Bad Request
   Content-Type: application/json

   {"error":"authorization_pending"}
   ```

   After approval, the same poll returns:

   ```json
   {
     "access_token":"<transaction-bound-access-token>",
     "token_type":"Bearer",
     "expires_in":120,
     "authorization_details":[{
       "type":"payment",
       "actions":["initiate"],
       "locations":["https://payments.example.com/accounts/123"],
       "instructedAmount":{"currency":"GBP","amount":"5000.00"},
       "creditorName":"Example Ltd"
     }]
   }
   ```

6. **The agent retries the challenged operation with the new token.** The resource verifies the token issuer, audience, expiry, `txn`, granted authorization details, requester context, and—where required—single-use state before executing.

   ```http
   POST /payments
   Authorization: Bearer <transaction-bound-access-token>
   Content-Type: application/json

   {"amount":"5000.00","currency":"GBP","recipient":"Example Ltd"}
   ```

Unlike CHEQ, TAC deliberately sends the artifact that authorizes execution through the client and agent. The signed challenge protects what was requested; the access token represents what was granted; the resource must ensure the retried operation matches both.

This draft may fit orgs nicer where policy and human workflows at an OAuth authorization server. The resource, not the agent, defines the operation being authorized, and structured authorization details can support policy evaluation and trustworthy display.

The tradeoff is that the authorizing token passes through the client. High-impact operations need short lifetimes, sender constraints, exact transaction matching, and durable replay detection. TAC also brings OAuth machinery into protocols and local-tool environments where it may not fit naturally.

TAC is strongest when the authorization server is already the natural enterprise decision point.

## AAuth: an authorization architecture for agents

[AAuth](https://datatracker.ietf.org/doc/draft-hardt-oauth-aauth-protocol/) is broader than a confirmation protocol. It begins with portable, per-instance agent identity, dyanmic registration, and proof-of-possession signatures (ie, no bearer tokens anywhere). Resources can authorize by agent identity, manage authorization themselves, rely on the agent's Person Server (entity that represents a person), or federate that Person Server with a resource's Access Server. See the complete draft for more. 

![AAuth human-in-the-loop authorization flow](/images/hitl/aauth.png)

To compare it directly with CHEQ and TAC, start with AAuth's simplest **resource-managed** mode:

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

Like TAC, this flow polls for authorization and then retries the operation. Unlike TAC's bearer-token example, `AAuth-Access` is bound to the agent's signed request. The simple resource-managed grant is still intended for subsequent calls; exact, single-use approval for one high-impact invocation may require a stricter profile.

Of the patterns here, AAuth is the most complete attempt at a general agent authorization architecture.

## MCP MRTR: retry the original operation

MCP's [multi-round-trip request pattern](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr) lets a server pause an operation by returning `input_required` with input requests and protected `requestState`. The client performs the requested interaction, then retries the original MCP method with that state. If approval is still pending, the server can ask it to retry again. Once approved, the server revalidates and executes the current operation.

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

But MRTR supplies only the client/server pause-and-resume exchange. The approver system, policy, protected state, operation binding, audit trail, and delayed decision store are custom work. The protocol as writen doesn't really support a good retry pacing option, and assumes the client will resume faithfully rather than re-plan.

MRTR works best when the interaction is short and the original client remains engaged. For longer lived approval flows (ie, like another party -- which may take days), MRTR is not an appropriate solution.

## MCP Tasks: represent durable asynchronous work

MCP [Tasks](https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/seps/2663-tasks-extension.md) let a Task-capable operation return a durable work record instead of an immediate result. The client can poll status, supply requested input, cancel, and retrieve the eventual result. The client and approver do not have to remain online together.

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

   The server acknowledges `tasks/update`; the client then resumes polling because the Task update may be eventually consistent.

   ```json
   {"jsonrpc":"2.0","id":4,"result":{"resultType":"complete"}}
   ```

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

Those pieces require a decision service, policy model, approval API and UI, secure store, single-use state transition, dispatcher, drift checks, reconciliation, and audit system. MCP Tasks are a good primitive, but the surrounding authorization control plane is most of the solution.

## Where does that leave us?

When HitL protects consequential enterprise actions, the agent cannot decide whether the control applies. The enforcement point must require the decision, bind it to the exact operation, consume it safely, and preserve the evidence.

### Path one: MCP plus a custom authorization control plane

Use MRTR or Tasks for the MCP-facing lifecycle, then build the mandatory policy, identity, approval, binding, execution, and evidence systems around it.

This path fits existing MCP clients, supports a tailored user experience, and can be optimized for strict per-invocation approval. It also means the hardest security and compliance pieces are local implementation work, and interoperability ends at the MCP lifecycle boundary.

MRTR and Tasks serve different interactions. MRTR favors short, client-driven pause and resume. Tasks favor durable, out-of-band work that can survive the initiating client. Neither replaces the authorization control plane.

### Path two: AAuth

Use AAuth's agent identity, resource access modes, Person Server governance, requirements, and deferred responses as the broader architecture.

This path addresses agents calling arbitrary tools, APIs, MCP, etc. More of the identity, authorization, interaction, and governance model is standardized. The cost is adopting an emerging and much broader protocol, integrating it with existing identity and policy systems, and defining tighter profiles where one-shot transaction semantics matter.

Organizations optimizing for MCP compatibility and local control may reasonably build around the MCP spec. Organizations seeking a general, interoperable agent authorization architecture should look hard at AAuth.

