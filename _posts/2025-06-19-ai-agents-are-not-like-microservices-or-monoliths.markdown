---
layout: post
title: Will AI Agents Force Us to Finally Do Auth Right?
modified:
categories: 
comments: true
tags: [ai, rest, agents, agentic, capabilities, llm, architecture, mcp, tools, openapi, swagger, oas]
image:
  feature:
date: 2025-06-19T10:49:57-04:00
---

At first glance, AI agents seem very similar to [microservices when it comes to security and identity](https://nordicapis.com/how-to-control-user-identity-within-microservices/). You need to secure the channel and authorize who is calling whom. Communication happens over the network through some HTTP transport. When a user is involved, you can potentially leverage the user's identity. The [same is true for AI agents](https://blog.christianposta.com/do-we-even-need-agent-identity/), but with one big caveat: we can no longer be [as sloppy as we've been with microservices](https://www.solo.io/blog/jwts-authenticate-services-api-gateways) when deploying AI agents.

AI agents introduce two properties that fundamentally break the assumptions we've made in traditional service architectures:

* They are **autonomous and probabilistic**: they make decisions independently and may take different actions given the same prompt, depending on available context or reasoning paths.
* They can dynamically reach out to other agents, building **emergent call graphs** where each vertex has autonomy and the graph itself evolves at runtime.



These properties force us to take internal "API to API" or service to service communication more seriously. 

## The Illusion of Safety in Microservices

We tricked ourselves into into thinking our identity and permission models for microservices were “good enough.” Take a basic user-facing UI service with a backend that queries a few internal APIs to collect data for display. Its behavior is deterministic. A user clicks a button, the request goes to service A, then to service B, and finally to the database. The flow is linear, the code is predictable, and the permissions required are relatively static.

![](/images/agent-security/static-graph.png)

In this world, we got away with shortcuts. Service accounts with broad permissions. Impersonation patterns that skipped proper delegation and audience checking. Trusting what the sender of a service sends you in its headers (e.g., "user = Alice" headers). Maybe we thought these were acceptable risks because we thought we could model every execution path. If something went wrong, we had the logs and spans to hopefully trace it all back.

But the truth is, we were relying on the illusion of discipline, not design. If a microservice with broad permissions was ever compromised, or misused, the potential damage was serious. We just convinced ourselves it wouldn't happen because the system's behavior was constrained by code we wrote and understood.

## Agents Break the Predictability Contract

AI agents violate the foundational assumption that behavior is fully known at deploy time. Ask an agent to “diagnose a pod failure,” and it might start by inspecting logs or checking events. Or it might decide to query metrics from an unrelated namespace, consult documentation, or delegate part of the task to another agent entirely. And that's with the same input.

Where a microservice might make three pre-planned calls, an agent might make ten different ones depending on how it interprets the task, how much context it has, and whether it decides to invoke another agent. The result is a probabilistic execution graph, not a static call tree.

![](/images/agent-security/emergent-graph.png)

That means any permission the agent has is live and active. If you give an agent access to sensitive APIs “just in case,” it will eventually find a reason to use them. Not because it's malicious, but because it's designed to explore options to fulfill its goal. And if it calls another agent with its own autonomous behavior, the blast radius expands rapidly and unpredictably.

## What We Should Have Been Doing All Along

Microservices always needed clear delegation boundaries, just-in-time/down-scoped permissions, and auditable delegation chains. But because their behavior was deterministic, we convinced ourselves it was okay to skip those. We trusted static analysis, code review, and manual scoping. Those adopting service mesh were able to close some of the gaps here, but that's certainly not everyone.

Agents don't afford us that luxury. You can't “read the code” of an LLM-backed agent and know what it will do in production. The only way to control behavior is by enforcing what it is allowed to do, not trying to predict what it will choose to do.

