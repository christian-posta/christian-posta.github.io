---
layout: post
title: AI Agent Delegation - You Can’t Delegate What You Don’t Control
modified:
categories: 
comments: true
tags: [ai, rest, agents, agentic, capabilities, llm, architecture, mcp, tools, openapi, swagger, oas]
image:
  feature:
date: 2025-06-17T10:10:47-04:00
---

I've been digging into [Agent Identity](https://blog.christianposta.com/do-we-even-need-agent-identity/), [authentication/authorization patterns](https://blog.christianposta.com/agent-identity-impersonation-or-delegation/), and how it fits in with [existing technology](https://blog.christianposta.com/ai-agents-and-oidc-ciba/) patterns (OAuth 2.0, OIDC, SPIFFE, etc) and where it may need new solutions. Someone made a point around identity and delegation to me recently that shines a bit of reality on an area of the problem people don't like talking about much because it's inconvenient:

> You can’t delegate what you don’t control.

That is, AI agents are revealing cracks in our authorization foundations faster than we can cover them. 

Let’s walk through what’s actually going wrong.

## Identity is a Mess—and That’s Being Generous

Imagine Sarah’s a marketing manager at a mid-size enterprise. She logs into her laptop (using Active Directory/LDAP). She reviews data, and runs campaigns in Salesforce and HubSpot. She accesses internal reports through an internal analytics dashboard. Somewhere in the past, someone gave her access to an AWS S3 bucket to migrate some data for a project. Nobody remembers that. Sarah probably doesn’t either.

So who *is* Sarah?

In theory, when an AI agent acts “on behalf of Sarah,” we want it to inherit her permissions. But that assumes there’s a unified idea of “Sarah” that the system understands.

In practice, “Sarah” is scattered across half a dozen systems, each with its own login, authorization logic, and roles. Her identity isn’t a person, it’s a patchwork of artifacts that drift/rot over time. There’s no clean interface to delegate from. No coherent definition of what “acting on behalf of Sarah” even means.

This is the first structural problem: 

> We don’t have real user identities 

We have identity fragments, and agents can’t delegate cleanly across fragments.

## Who Actually Owns Access? No One and Everyone!

Let’s say we move past identity and ask a harder question: 

> Who decides what an agent is allowed to do?

Take customer data. Is it owned by Sales? Marketing? Support? Legal?

Each team will argue their position. And each application (and sprawl of applications) will reflect that local decision. In one app, Sarah can approve \$5K purchases. In another, \$50K. Somewhere else, she has no limit at all. There’s no global truth. Just a series of disconnected authorization decisions baked into code, APIs, spreadsheets, and tribal knowledge.

So when you build an agent to access customer data or spend money or initiate campaigns, what does it inherit? Who sets the limits?

Most enterprises can list which users *have* access to a resource, but very few can explain why they have it, where that policy is defined, or who is responsible for it.

This is the second major problem: *authorization is not governed*. And if no one owns access, you can’t safely delegate it.

## Agents Break IAM at a Scale We’re Not Ready For

The third problem isn’t about correctness, it’s about scale.

IAM systems were designed for a world of humans. HR adds a few employees each month. Maybe a contractor comes on board. Credentials are provisioned and revoked in cycles that humans can handle.

Now picture a world where an AI system spins up thousands of ephemeral agents every hour. Each agent needs credentials to call APIs, authenticate to services, read from databases, and update systems. Most of them only live for a few minutes. AI copilots for developers, marketers, and support reps are being embedded in every tool. These agents don’t just read, they act. _And they will try every permission you give them_.

Existing IAM systems simply can’t keep up. Secrets can’t be issued fast enough. And even if they can, do you want them to hand out passwords? Credentials linger. Revocation is too slow. Worst of all, there's no contextual throttle on what agents *should* be able to do in the first place.

We’re using human-scale tools to solve machine-scale problems. It doesn’t work.

## So Where Do We Start?

Despite all this, organizations *can* build useful, secure AI agents today. But they need to be strategic about scope.

### Start with Single-System Impersonation

The most practical approach right now is to stay within a single system. Let the agent inherit the user’s credentials and work inside familiar guardrails.

For example, an engineer’s Kubernetes token can be used by a debugging agent. A sales agent can use the user’s Salesforce credentials to update leads. A DBA can launch an optimization agent that operates within the known constraints of the database.

No fancy delegation. No cross-system identity stitching. Just practical value inside one trusted boundary.

### Gradually Expand to Multi-System Agents

As organizations build confidence, they can stretch these boundaries.

You might have a marketing agent that uses Sarah’s Salesforce token to pull leads, her HubSpot credentials to run a campaign, and her Google Analytics access to generate a report.

Yes, it’s still credential sprawl. But it works. And it delivers immediate value while respecting existing auth boundaries.

### Aim for Delegation Later, When You’re Ready

Eventually, as enterprises mature their IAM practices, they’ll be able to support real cross-system delegation. That means consistent identity, governed authorization, scalable credential management, and context-aware policies.

But that’s not something you start with. That’s something you earn by solving the foundational issues first. When you're ready, there are some interesting delegation patterns ([OAuth RFC 8693](https://www.rfc-editor.org/rfc/rfc8693.html)) and distributed identity and delegation ([MCP-I](https://modelcontextprotocol-identity.io)) that may be useful. 

