---
layout: post
title: APIs and AI Agents Follow the Same Layered Pattern
modified:
categories: 
comments: true
tags: []
image:
  feature:
date: 2025-06-05T06:05:05-07:00
---

As API adoption matured in enterprise organizations, a natural pattern emerged and we are [seeing something similar in AI agent](https://www.anthropic.com/engineering/building-effective-agents) architectures: using layers to contain complexity. Dealing with team boundaries, business flows, communication patterns, etc can get complex very fast. Starting with basic building blocks and then layering in concepts around reusability, encapsulation and separation of responsibilities help to reduce cognitive overload. 

[MuleSoft popularized the three-layer API](https://dzone.com/articles/mulesoft-api-led-connectivity-architectural-and-de) taxonomy that's now industry standard, while AI practitioners are converging on a strikingly similar three-tier agent classification. The parallels are so similar they beg a question around universal principles governing how we organize intelligent systems.

## Layer One: System APIs and Tool Agents

**System APIs** sit at the foundation, providing direct access to core systems like databases, ERP platforms, or legacy applications. They handle basic CRUD operations and abstract away the complexity of underlying data sources.

**Tool Agents** occupy the identical architectural position in AI systems: they're simple, [reflexive agents](https://www.ibm.com/think/topics/ai-agent-types) that provide direct access to specific capabilities. Like a calculator agent or a web search agent, they respond to immediate inputs with bounded outputs, without memory or planning.

![](/images/layers/layer1.png)

Tool agents also tend to work closely with users. They are often triggered directly by the user and act within the user's identity context. This makes them ideal for simple, interactive use cases where oversight is naturally built in.

Both serve as the "plumbing" of their respective ecosystems. System APIs become the reusable building blocks that prevent every new application from reinventing database connections. Tool agents become the reliable, testable components that prevent every AI workflow from reimplementing basic functions.

## Layer Two: Process APIs and Planner Agents

**Process APIs** combine multiple system APIs to implement business logic. They might aggregate customer, order, and payment data from different sources to create a unified order processing workflow. This layer is where business rules live and where simple components become meaningful business capabilities.

**Planner Agents** perform the same orchestration role for AI systems. They maintain internal models of the world, memory, plan sequences of actions, and decompose complex goals into manageable sub-tasks. A planner agent might coordinate multiple tool agents, calling a search agent, then a summarization agent, then a formatting agent to accomplish a research task.

![](/images/layers/layer2.png)

This middle layer is where the real business value gets created. It's complex enough to encode meaningful workflows but simple enough to remain maintainable. Both process APIs and planner agents solve the same fundamental challenge: how do you combine simple capabilities into complex behaviors without creating an unmaintainable mess?

While planner agents operate more autonomously than tool agents, they're often subject to human oversight (Human In the Loop \- HItL). In practice, this means a planner might propose a course of action but still wait for user approval before executing, especially in high-stakes or regulated environments.

## Layer Three: Experience APIs and Workflow Agents

**Experience APIs** sit at the top, tailoring data and processes for specific consumers: mobile apps, web portals, partner dashboards. They handle the messy reality that different channels need different data formats, different performance characteristics, and different security models. Experience APIs also coordinate business workflows and orchestration. 

**Workflow agents** play the role of orchestrators in agentic systems. They manage the sequencing, coordination, and oversight of complex, multi-step processes that may involve multiple tools, API calls, or even sub-agents. These agents are especially useful when a task cannot be reliably completed by a single tool agent in isolation. Workflow agents actively plan and adapt workflows based on runtime feedback, delegate subtasks to specialized agents, manage intermediate state, and determine when to pause for human input. In this sense, they resemble a conductor in a symphony: not performing each task directly, but ensuring all components come together coherently. This makes them well-suited for long-running, stateful workflows like claims processing, automated incident response, or complex customer onboarding — especially when those processes require both reasoning and frequent checkpoints for human oversight.

![](/images/layers/layer3.png)

Because they often execute complex tasks on behalf of indirect users, or even trigger based on system events rather than direct user input, workflow agents require their own identity and access boundaries. And while they may operate independently, most organizations begin by keeping a human in the loop: users review outputs, approve critical steps, or intervene when confidence is low.

## Why Three Layers Keep Appearing

We gravitate toward layered architectures not by accident, but because they map to how we manage complexity cognitively, organizationally, and technically. Layers reduce mental overload by chunking functionality into digestible abstractions. They enforce separation of concerns, making systems easier to evolve, reason about, and debug. They promote reuse: lower layers provide stable building blocks that higher layers can compose into richer behaviors. And they align with how teams scale: one group can own infrastructure, another the orchestration logic, another the user experience. Just as layering has helped us structure networks, operating systems, and organizations, it now shapes how we build APIs and AI agents. It's a universal strategy for making complex systems comprehensible, resilient, and scalable.

## Standing on the shoulders of Giants

As AI agents become more integrated into enterprise systems, we’re seeing history repeat itself. The same layered approach that brought clarity and scalability to APIs is now helping us manage the complexity of intelligent, agentic systems. Interestingly enough,  we’re not replacing our API infrastructure per-se, we’re building AI agents on top of it. 

Tool agents invoke system APIs. Planner agents orchestrate existing process APIs. Workflow agents operate over the same experience APIs that power customer-facing applications. The layers don’t just mirror each other, they build on each other. This alignment means we can extend, not reinvent, our architecture to support intelligent behavior.
