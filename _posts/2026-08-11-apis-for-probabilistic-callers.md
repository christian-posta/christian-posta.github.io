---
title: "APIs for Probabilistic Callers"
date: 2026-08-11T21:34:28Z
categories: [AI Agents, Identity]
tags: [agents, authorization, api-security]
description: APIs designed for AI agents need to enforce resource-owned invariants or surface them into the enforcement path, not just expose operations guarded by caller-side authorization checks.
# Uncomment if this post includes Mermaid diagrams:
# mermaid: true
# Uncomment to add a feature image:
# image:
#   path: /images/path/to/image.png
#   alt: Description of the image
---



Intent is not an authorization problem. That's what [James Carman suggests in this recent post](https://www.callibrity.com/articles/ai-agent-authorization-why-intent-is-not-an-authorization-problem). We keep trying to turn open-ended intent into a "type" problem, and for critical, sensitive, destructive, or compliance-bound actions, that's the right move: a refund has an amount, a destination account, and a ticket number, so you can bind a grant to that specific transaction (ie, with [RFC 9396, OAuth RAR](https://datatracker.ietf.org/doc/html/rfc9396)) and reject anything that doesn't match. 

![](/images/api-for-prob/fig-1-context-asymmetry.png)

But a lot of what we do with agents doesn't look nice and neat like that. "Clean up staging before the demo" has no 'amount' field or 'type', and James's staging example is the one that stuck with me: the agent deletes databases while cleaning up databases, hits one that looks temporary but actually holds tomorrow's demo fixtures, and it passes all auth checks. The difference between "drop the staging junk" and "drop the one database that matters" is about purpose and context. James's prescription is not "make a better token", it's a combination of containment to bound blast radius, evaluation suites, and trajectory observability to measure agent judgment. For the typed intent or actions that can't be undone, use deterministic authz and human supervision/approval. I agree with that. 

I want to build on that though, because I think there's another aspect of this problem where what James says applies directly: [the API design itself](https://blog.christianposta.com/from-apis-to-capabilities-what-ai-agents-mean-for-application-architecture/). If open-ended intent is not something we can cleanly turn into a type, then the next question is what the enforcement path needs when the agent actually tries to do something. We spend a lot of time asking whether the agent, the gateway, or the authorization layer can understand the user's intent well enough to police the agent's actions. That's obviously important, but it also feels incomplete. Some of the most important context about whether an action is safe comes from __the resource itself__, and the resource needs a way to feed that context into the enforcement layer (or do the enforcement itself). I chatted with [Dick Hardt](https://www.linkedin.com/in/dickhardt/) (OAuth, AAuth, etc.) about this a while back, and this is exactly the design pressure [AAuth](https://aauth.dev) is responding to (more on that below). 

An agent may work on the goal: "clean up staging before tomorrow's demo." An [agent gateway](https://www.linkedin.com/in/dickhardt/) may know the identity and authority: this is Agent A, acting for Christian, with permission to manage staging resources. But neither knows much about the specific database the agent decided to delete. The database service knows a lot about it though. It knows the database is owned by Sales Engineering, has active dependencies, hasn't been backed up recently, is tagged `demo-critical`, and contains tomorrow's demo fixtures. That asymmetry is why I'm toying around with the following principle to wrap my head around this:

> **Agents bring goal context. Resources bring invariant context. You need both for enforcement.**

Said another way, authorization can decide whether the caller may attempt a _class of action_, but enforcement still has to decide whether this specific operation against this resource should proceed. This could be enforced locally in the resource or surfaced as relevant context to a gateway, PDP, AS/PS, approval system, or some other enforcement point. 

## Authorization Allows the Wrong Action

Let's use the staging database example because it captures the problem cleanly. An agent decides that `demo-fixtures-db` looks temporary and should be deleted as part of a cleanup task. The request may be perfectly authorized:

* the agent has a valid identity;
* the user delegated database-management authority;
* `DROP DATABASE` on staging is an allowed operation;
* the database lives in staging.

![](/images/api-for-prob/fig-2-grant-correct-action-wrong.png)

This is the class of failure James is pointing at: the action itself is not suspicious. What makes it wrong is the "meaning" of the resource in the current situation.

We can ask the agent to reason harder about that meaning. We can evaluate it, monitor it, shape the mission more carefully, and require stronger typing or human approvals for irreversible actions. But we should also ask a more basic systems question: why is the database relying on the agent, or on a policy engine without fresh database context, to know everything required to safely destroy it?

## The Resource Has the Other Half of the Context

We need strong agent identity, user identity, delegation, task-bound credentials, short-lived tokens, audience restrictions, scopes, claims, policy engines, and approval flows. All of that matters, and I think AI agents are actually [forcing us to clean up a lot of sloppy authorization patterns](https://blog.christianposta.com/ai-agents-are-not-like-microservices-or-monoliths/) we tolerated with microservices. But all of that is caller-side context, and the resource side is not something a policy engine can infer from a scope, an audience, or a resource URI. So the split I want to keep clear is something like this:

* identity tells us who is acting;
* delegation tells us on whose behalf;
* authorization tells us what class of action is within bounds;
* runtime alignment asks whether the agent still appears to be pursuing the approved task;
* the resource supplies the invariant context for the specific operation;
* the enforcement point turns all of that into allow, deny, challenge, approval, or safe alternative.

Karl McGuinness's [mission-bound authorization](https://notes.karlmcguinness.com/mission-handbook/) work has a [four-layer model](https://notes.karlmcguinness.com/notes/the-mission-shaping-problem/) that covers most of this: mission shaping, authorization, containment, and runtime alignment. A shaped mission gives the system a governable record of the approved work, and [containment is the blast radius](https://notes.karlmcguinness.com/notes/mission-shaping-is-not-enough/) when that record turns out to be incomplete, which is close to what James is getting at. I'd put resource-owned context in the enforcement path, right alongside those containment controls. Narrow credentials, mediated tool calls, and release gates all sit between the agent and the resource, but the resource is the only one that knows its own state __right now__: what depends on it, whether it was backed up recently, whether it's part of tomorrow's demo, whether the operation is reversible, and what would break if the agent is wrong. Ownership, classification, and sensitivity can be copied into tokens or inventory systems, but the risky decisions usually turn on the fresher version of those facts, and no centralized authorization system is going to maintain them at that fidelity.

The resource can turn those facts into defensive behavior. A delete operation doesn't have to mean "authorized, execute." It can mean "authorized, now evaluate the resource's own safety invariants" and then either enforce locally, return a structured challenge, or send resource-supplied context to a policy decision point. A critical database might require owner approval, an unbacked-up database might snapshot itself before accepting a destructive operation, and a resource with active dependencies might reject deletion or return the dependency list as part of the policy input.

![](/images/api-for-prob/fig-3-where-facts-come-from.png)

## But How Does the Resource Know?

The resource knows because we can make these facts part of the resource model and API design. It does not magically understand the enterprise, and if the metadata is stale, missing, or politically unowned, this whole idea falls apart pretty quickly. Some of the knowledge is declared when the resource is created:

```yaml
owner: sales-engineering
environment: staging
classification: demo-critical
data_sensitivity: internal
recovery_tier: low
delete_policy: owner_approval_required
```

Some of it is derived continuously by the platform:

```yaml
active_connections: 12
downstream_dependencies: 4
last_backup_at: 2026-08-11T03:15:00Z
last_restored_test_at: null
recent_query_volume: high
change_freeze: true
```

Some of it comes from adjacent systems. A service catalog can say which application owns the database, a data catalog can say whether it contains sensitive data, a dependency graph can say which services still call it, a backup system can say whether it is recoverable, and a change-management system can say whether the environment is in a freeze window. None of that is agent-specific. These are facts the platform should want anyway.

The difference with agentic callers is that these facts become part of the API's safety and enforcement contract. They become live inputs to resource behavior and policy evaluation, especially for operations that are destructive, irreversible, externally visible, or expensive.

For example, a database service could implement invariants like:

```yaml
database.delete:
  deny_if:
    - classification in ["demo-critical", "regulated", "production"]
    - active_connections > 0
    - last_backup_age > "24h"
    - downstream_dependencies > 0
  require_approval_if:
    - recoverability == "low"
    - change_freeze == true
  safe_alternatives:
    - snapshot
    - archive
    - disable_new_connections
```

Where that evaluation runs is a deployment detail. In a simple system, the database API may just evaluate those rules itself and reject the call. In a larger enterprise system, the database API might emit a signed resource claim, a resource token, a policy-input document, or a structured challenge that carries those facts to a gateway or policy engine. The important property is provenance: the enforcement layer knows these facts came from the resource that owns the state, not from the agent trying to act on it.

![](/images/api-for-prob/fig-4-two-deployment-shapes.png)

The important thing is that these are resource invariants, not guesses about the agent's intent. The resource is not trying to determine whether `DROP DATABASE demo-fixtures-db` helps clean up staging. It is saying: this database, in this state, cannot be deleted without satisfying these conditions, and here is the context the enforcement layer needs to know that.

## APIs for Probabilistic Callers

This points to a bigger API design question. Most APIs were designed for deterministic callers: the caller knows what it wants, the API checks permission, validates the input, and performs the operation. An agent is different. It is reasoning its way toward an outcome, and it can be wrong while remaining fully authorized. That means agent-facing APIs should not expose only operations; they should either enforce resource-owned invariants or surface resource-supplied context that can be used by the agent, the gateway, and the policy layer. Instead of a plain:

```text
403 Forbidden
```

the resource might return something the enforcement path can actually use:

```json
{
  "error": "operation_denied",
  "operation": "database.delete",
  "resource": "demo-fixtures-db",
  "reason": "resource_invariant_failed",
  "constraints": [
    {
      "id": "demo_critical",
      "detail": "resource is tagged demo-critical",
      "resolution": "owner_approval_required"
    },
    {
      "id": "backup_stale",
      "detail": "no successful backup in the last 24 hours",
      "resolution": "snapshot_required"
    }
  ],
  "safe_alternatives": [
    {
      "operation": "database.archive",
      "requires": []
    },
    {
      "operation": "database.snapshot_then_delete",
      "requires": ["owner_approval"]
    }
  ]
}
```

Now the resource isn't merely rejecting the agent. It is giving the rest of the system structured constraints it can use. The agent can re-plan, the gateway can route an approval, and a policy engine can evaluate resource facts it did not have before the call. A deterministic caller may treat a `403` as a terminal failure, but a probabilistic caller can treat a structured refusal as new context: archive instead of delete, snapshot first, ask the owner for approval, or skip this database and continue cleaning up other resources.

This suggests a few API patterns that become interesting for AI agents:

* `preflight` endpoints that evaluate an operation without executing it;
* `dry_run` modes that return expected impact;
* `impact` summaries that list dependencies, blast radius, and recoverability;
* resource-provided claims or tokens that carry invariant context to a policy engine;
* `approval_required` responses that route to the right owner or policy system;
* `safe_alternatives` that expose lower-risk operations;
* `rollback` or `recovery` metadata that tells the caller whether the operation is reversible;
* operation handles for delayed execution, where a resource can hold an action until approval arrives.

None of this requires the resource to trust the model, and it doesn't require every API to become its own policy engine. It requires the API to assume the caller may be wrong, and then either enforce its own invariants or make resource context available at the point where enforcement happens. That's a different posture than the one most APIs have taken historically.

## Be Careful What You Reveal

There is a security tradeoff here. Structured refusals help agents recover, but they can also leak information. A response that says `reason: demo-critical` and `owner: sales-engineering` may reveal more about the environment than some callers should know.

So resource guidance needs its own policy. Trusted internal agents may get detailed constraints, third-party agents may get coarse reasons, sensitive labels may be replaced with policy identifiers, approval links may require separate authentication, and repeated probing should be rate-limited and audited. Agent-friendly does not mean verbose by default. The resource should reveal enough for a legitimate caller to make progress, not enough for an attacker to map the environment.

## Standards Are Starting to Circle This

Current IETF work is beginning to explore pieces of this direction. The June 2026 [AI Agent Authentication and Authorization](https://www.ietf.org/archive/id/draft-klrc-aiagent-auth-02.html) Internet-Draft describes an agent receiving a mission and translating that mission into authorization requirements, but explicitly leaves that translation process out of scope. Once an access token exists, the resource server still evaluates the token, its claims, and other authorization context before completing the request.

[AAuth](https://datatracker.ietf.org/doc/draft-hardt-oauth-aauth-protocol/) is even more directly relevant to this point. In AAuth, a resource can enforce access itself or delegate policy evaluation to a Person Server or Access Server, but either way the resource has a first-class role in the authorization path. A resource that cannot safely proceed from the presented token alone can return an `AAuth-Requirement` challenge carrying a signed resource token. That token is issued by the resource and binds the resource identity, the agent identity, and the requested authorization context. This is basically the resource saying, in a cryptographically verifiable way: "here is what I know about this requested access, and here is what I require before it proceeds."

The companion [AAuth Rich Resource Requests (R3)](https://dickhardt.github.io/AAuth/draft-hardt-aauth-r3.html) draft pushes this further. R3 lets a resource publish vocabulary-based authorization definitions for things the agent already understands, like MCP tools, OpenAPI operations, gRPC methods, GraphQL operations, and so on. But the semantic richness is for the authorization layer, not just the agent. The resource publishes what the operation means, what data it touches, what side effects it has, and what is irreversible; the PS and AS can fetch that resource-authored document, verify its hash, and evaluate policy or consent against those semantics. For per-call sensitive operations, R3's proposal model lets the resource build a content-addressed document from the actual parameters and require approval for that concrete call before a per-call auth token is issued.

This is still authorization machinery, of course. AAuth resource tokens, R3 documents, auth tokens, approvals, and grants all live in the authorization path. But this does not make open-ended intent an authorization problem. It makes the specific operation against the resource more evaluable. The resource is not telling the AS/PS whether the mission is good; it is telling them what this call would actually do and what invariants it would cross. That is the part I think matters for agent-facing APIs generally, whether the mechanism is AAuth/R3, a gateway-specific policy input, a signed resource claim, or a boring internal API contract.

The direction here is worth watching: resource servers are not just passive recipients of bearer tokens. They are starting to look like active participants that can describe their operations, supply invariant context, challenge unsafe calls, shape approvals, and preserve audit provenance for what was actually approved.

## Resource Context

Agent security is often discussed as if we need one layer capable of understanding the user's intent well enough to police everything the agent does. Different parts of the system know different things, and pretending one layer can know all of it just pushes complexity into the wrong place. The agent knows the goal and develops a plan. The gateway knows who the agent is, whom it represents, and what authority was delegated. The authorization layer knows which classes of operations are permitted. The policy engine knows organization-wide rules. The resource knows what it is, why it matters, and what must be true before it allows itself to be modified. The mistake is assuming the policy engine can do its job with only caller-side context.

The more consequential agent actions become, the less comfortable I am with architectures where passive resources simply obey any request carrying a sufficiently powerful token. Agent-facing APIs need a different contract: an authorized caller may still be mistaken, so the API must either enforce its own invariants directly or expose resource-owned context in a form the enforcement layer, and sometimes the agent, can act on. The world agents operate on should have defenses of its own.
