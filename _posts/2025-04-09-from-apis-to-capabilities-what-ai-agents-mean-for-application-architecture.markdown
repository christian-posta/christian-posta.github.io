---
layout: post
title: From APIs to Capabilities to Support AI Agents
modified:
categories: 
comments: true
tags: [ai, rest, agents, agentic, capabilities, llm, architecture]
image:
  feature:
date: 2025-04-09T20:30:57-07:00
---

Enterprise application architecture is once again on the verge of transformation. We've moved from mainframes to client-server, and recently from monoliths to microservices. Each evolution has been driven by the need to enable faster, safer, and more independent changes to an organizations applications and architecture to support competitive innovation. 

[AI Agents](https://news.microsoft.com/source/features/ai/ai-agents-what-they-are-and-how-theyll-change-the-way-we-work/) are the next transformation, but agents are different. They aren't yet another decomposition problem. Agents kind of change the game. They reason, plan, and act toward goals, dynamically, using their context and environment. And for this to work in real enterprise systems, we need to rethink how to expose what our enterprise systems can do. 

## APIs Are Not Enough

We've been building APIs for the last decade (or more?) to expose functionality to other parts of our enterprise. Can we do the same thing for Agents? 

APIs provide a machine-executable contract: you know exactly what you need to pass in, what you'll get back, and how to invoke it. That’s perfect if you already know what you want to do, what API to call, and what the parameters should be. Up until now, "knowing that" has always been done by humans. Humans program clients, servers, and services to make network calls to APIs in the right order and with the right parameters. 

But that’s not how AI agents operate. Agents don’t start with an API spec. They start with a goal and some context. Then they figure out what steps they need to take to achieve that goal. That means they need to discover what the system is capable of, decide which capability to use, and know how and when to invoke it. 

That’s a completely different model than traditional API-first development.

## Enter Capabilities

Instead of exposing APIs and contracts, we need systems to expose capabilities. Think of a "capability" as a self-describing, semantically rich declaration of what a system can do, not just how to invoke it.

A capability might say:
> "I can generate an invoice for a customer based on a list of purchased items."

And it would include:
- A natural language description of what it does
- The inputs and outputs described in structured form
- Preconditions for execution (e.g., customer must exist)
- Examples of how it might be used in different contexts


This is discoverable. This is interpretable by an LLM. This is how an agent can reason: _“I need to create an invoice. I see a capability for that. Here’s what I need to pass. Let’s do it.”_

## Why This Matters: Agents Are Dynamic

Unlike traditional applications, agents operate with dynamic context. They begin by analyzing the current state of the environment or system. Based on what they observe, they infer what actions are required to progress toward a goal. They then plan a sequence of steps and execute those steps while adapting in real-time to any changes or unexpected results. This behavior is goal-directed, context-aware, and inherently adaptive.

This has a profound impact on how we design and expose systems. You can't hardcode workflows ahead of time because the agent may need to make different decisions based on the situation. You also don’t know at build time what combination of services or tools the agent might choose to use. Instead, you must expose your system in a way that gives agents the freedom and information to figure out what’s possible and appropriate at runtime.

That’s why semantically rich capabilities—not raw APIs—are so essential.


## The Role of MCP: Model Context Protocol

The Model Context Protocol (MCP) is a critical building block for this capability-based world. MCP provides a standardized format for describing tools, functions, and services in a way that LLMs and agents can understand. MCP tools include a natural language description of what the tool "can do", input and output schemas, how to invoke the tool (ie, over a transport), etc.  You can think of it as OpenAPI format designed not just for machines to execute, but for LLM models to interpret and reason with.

MCP effectively turns traditional services into agent-readable capabilities.

How an enterprise implements this will be interesting however. There already is a large investment into APIs that delivers a lot of real value. Changing this won't be a wholesale replacement of what's already there. Leveraging [MCP to wrap APIs is one possibility](https://www.layered.dev/mcp-the-ultimate-api-consumer-not-the-api-killer) at least in the near term. Starting to natively support this approach is another. I'd be curious to hear how you're thinking about this situation ([@christianposta](https://x.com/christianposta) or [/in/ceposta](https://linkedin.com/in/ceposta)). 





