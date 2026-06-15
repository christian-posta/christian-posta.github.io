---
title: "The Differences Between Microservices and AI Agents"
date: 2026-06-15T22:40:22Z
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

Microservices and AI agents are not the same thing. And just because you introduce an LLM doesn't make a microservice an AI agent. Not realizing this will lead to catastrophic security and infrastructure mistakes. We have become accustomed to building service style architectures over the past 15+ years. Actually, probably much longer. This diagram probably resonates quite strongly with modern architectures:

![](/images/microservices-aiagents/api-gw-architecture.png)

An app takes some user input (button clicks) and executes some pre-defined logic. That is, logic that was hand coded by developers, tested under various scenarios, and deployed into production. The app may call into APIs and services passing through API gateways that would check for security tokens, rate limitng, logging, etc. When an API was called, it may turn around and call another service (ie, Service A calling Service B). 

There is actually a lot going on here which we've not really had to think about in the past. Assumptions that get broken when building AI agents. And it's not strictly the introduction of the LLM that causes this. 

For example, a microservice could introduce an LLM to do some basic summarization and return a response. The service still has all execution paths pre-defined in code, but calling to an LLM similar to an API call to get a result. This is not an AI agent. The reasons why AI agents break the microservices assumption is because they use an AI model to implement the behavior of the "application". And that is where assumptions start breaking. 

## Broken Assumptions

When a developer sits down to build a service, they don't do so because they invented an idea and want to code it. Not in enterprises. Usually there is some kind of business project that has scoped requirements, expectations, and deadlines for what functionality to build. This gets translated by the developer into working code/tests. The developer figures out what data they will need (database access), what enterprise APIs they may need to call, what technology to use, etc. Then they plan out an implementation, design tests and code it. For call paths that need security, they open tickets to get access to credentials (API keys / OAuth clients, username/passwords, service accounts, etc). Someone reviews the request and grants/denies it. At runtime these permissions get enforced. 

This process obscures 4 big assumptions that break with AI agents:

* *Intent* declaration
* *Fixed Paths* to solve the problem in code
* *Known APIs and dependencies* that may get exercised
* *Faux delegation* mostly service to service


![](/images/microservices-aiagents/assumptions.png)


### Intent declaration vs interpretation

Microservice developers translate the business requirements to code. The "intent" of the service is defined explicitly in code. You can test it and verify it under various scenarios. 

AI agents are very different. They are given some kind of "natural language" prompt and pass that to an AI model to decipher it. Intent and end-goal is interpreted at run time. The same inputs over multiple runs are likely to produce different results. And any additional context included may influence the result. This kind of "application" cannot be "audited" ahead of time. 

### Fixed paths vs exploration

Microservices know what if-else/while loop, for loop expressions and paths the code can take because they baked them into the code, statically. 

AI agents, again, are very different. AI agents use the intent/goal they've interprted for a task and explore their abilities/tools/APIs etc at runtime. It does things to "optimize" its path forward and may do things a human didn't even think of. This is very important because it significantly closes the gap between what permissions an app has been given and what actually gets exercised. 

An excellent illustration of this illustration is Codex finding a workaround to 'sudo' in a developers environment. The developer, realizing an action required sudo to complete (and they did not have it), was surprised when the agent completed its task. It asked the [agent how it did it](https://news.ycombinator.com/item?id=48348578):

![](/images/microservices-aiagents/codex.png)   

To be clear: this is not a prvilege execution or anything nefarious. This is either an oversight or simply an example of how an agent would explore far more sophisticated that a human would. 

### Fixed dependencies vs runtim discovery 

Developers spend a lot of time "integrating" with other systems over APIs, remote procedure calls, etc. Identifying API contracts, requesting scopes/permissions defined a head of time for access, etc. Each RPC/API call is explicitly coded. 

AI agents can dynamically discover APIs, tools, and system access as part of its exploration or tool access. Tools are looked up from registries, APIs are found and invoked dynamically, and the authority surface itself may be negotiated mid-execution, including human approvals that happen inline, consent prompts, step-up authorization. The scope of what the agent can reach isn't knowable until it's already reaching. Authorizatio systems weren't really built for this.


### Delegated authority

Microservices typically run with their own authority: that is, they are provisioned service accounts with permissions and the authority to execute is baked into the code. Again, statically and well known ahead of time. These calls may take users into account, but the calls are usually done "service to service".

Agents on the other head are designed from the ground up to act for a user. Agents carry human authority through a principal chain that wasn't defined at deploy time. The authority a user grants must be well scoped (scoped down), approved by an enterprise, and live within constraints (for this purpose, with these limitations, time bounded, etc). An AI agent may need to spawn its own sub-agent or call out to another agent. Does the authrity extend to these delegations? e request. Any decisions that get made, or actions that happen as a result of these delgations must recognize the user as the origin authority and attribute the actions to the chain not just the last hop. 

## Wrapping Up

The mistake many organizations are making right now is treating AI agents as "microservices with an LLM attached." That mental model is comforting because it lets us reuse the infrastructure, security controls, and operational assumptions we've spent the last two decades refining.

Unfortunately, those assumptions no longer hold.

Traditional application security and infrastructure was built around answering questions like:

* What code will execute?
* Which APIs will be called?
* What permissions does this service need?
* Which principal performed this action?

With agents, those questions become:

* What goal is the agent trying to achieve?
* What capabilities might it discover and use while pursuing that goal?
* What authority is it exercising right now?
* Can that authority be delegated further?
* How do we constrain, audit, and attribute actions across an entire chain of agent decisions?

This is why agent security cannot simply be an extension of API security. API gateways, OAuth scopes, service accounts, and network policies remain necessary, but they are no longer sufficient. We need systems that understand intent, delegated authority, dynamic tool use, consent, approvals, and attribution across chains of human and agent actions.

