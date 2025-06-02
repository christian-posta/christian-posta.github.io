---
layout: post
title: Do AI Agents Need Their Own Identity?
modified:
categories: 
comments: true
tags: [ai, rest, agents, agentic, capabilities, llm, architecture, mcp, tools, openapi, swagger, oas]
image:
  feature:
date: 2025-06-02T10:33:05-07:00
---


In our recent engineering face-to-face, one of our engineers raised what seemed like a simple question: "Why can't we just pass the user's OIDC token through to the agent? Why complicate things with separate agent identities if we don't need to?"

It's a fair question. But the more we dug into it, the more I realized this seemingly straightforward approach opens up a can of worms. I do believe agentic AI systems are fundamentally different from traditional applications. They are highly dyanamic, reason about context, and make decisions. Traditional applications are more static: reasoning and decisioning have been made by the developer that programed them. 

*Part 1 of "Thinking Out Loud: Identity in Agentic Systems"* -- the more I think about this, this will likely be a series of blogs digging into this topic. Follow along if interested ([@christianposta](https://x.com/christianposta) or [/in/ceposta](https://linkedin.com/in/ceposta)). 

So let me think out loud about this identity puzzle, because I suspect we're all going to be confronting it a lot more in the coming months.

## The Simple Case: When User Identity Works Just Fine

Let's start with where my colleague was absolutely right. For simple, tool-like agents, user identity propagation works perfectly. For example on a project that I work, https://kagent.dev a lot of the out-of-the box agents that get shipped are simple tool-like agents (and this question came up within that context). For example, the [k8s-agent](https://kagent.dev/agents/k8s-agent), which is very powerful, works on a Kubernetes cluster on behalf of a user (in the typical use case). The user may ask the `k8s-agent` 

> why is my pod failing?

And the agent will dig into pod events, logs, etc to try and figure it out. But it's really doing this on behalf of the user adhering to Kuberentes RBAC. 

The user asked a question, the agent went and performed some actions, but the user is still doing the debugging. The agent is just a really smart intermediary. This makes sense for the user identityt to be used / propagated to the end tool (Kubernetes in this case). 

This works great when:
- The agent operates within the user's session timeframe
- All actions are clearly user-initiated
- The agent is essentially an extension of the user's direct interaction
- The user maintains full responsibility for outcomes

The last bullet point is critical. When we start talking about more complicated systems, responsibility, attribution, and causality are core tenants for compliance. Especially with some of the larger organziation I work with (financial, health, retail, etc). 

## Where User Identity Propagation Isn't Enough

But here's where I started seeing cracks in the "just use user tokens" approach. There are scenarios where this simple model breaks down, and they're becoming increasingly common as agents get more sophisticated and independent (for some definition of independence...).

### The Capability Gap

Picture this: the [solo.io](https://solo.io) marketing manager asks her AI agent to check whether the latest field-marketing campaign is GDPR compliant. She has permissions to read marketing campaigns and write campaign content. Pretty standard stuff.

But the GDPR compliance agent needs to:
- Scan ALL marketing data across departments (not just hers)
- Access audit logs to see who touched what data
- Cross-reference customer data with privacy regulations
- Check historical compliance patterns

She doesn't have these permissions. She shouldn't have them. But the agent needs them to do its job effectively.

Using her token would either:
1. Fail because the agent can't access what it needs, or
2. Require giving her overly broad permissions she doesn't need

Neither is great. The agent has _specialized capabilities_ that are distinct from a individual user's permissions. In this case, an agent should hold its own identity in order to correctly authorize any of its actions. 

### The Decision Attribution Problem

This is a bigger problem the more autonomous agents get. These agents are out there analyzing context and making decisions. I just recently received a new laptop from our hardware team, but it took 2 months to get. I was wondering if we built a supply chain agent that helped predict supply/demand/re-issue of hardware within the company what would that look like. It would likely need to analyze re-fresh schedules, supplier availability, prices, budget, target inventory etc etc. We would tell the agent "optimize the hardware supply to enable timely onboarding and refresh" which would require:

- Analyzing supplier performance data
- Accessing financial records/budget allowances to evaluate cost structures  
- Integrating with external vendor APIs
- Making automated purchase orders

I never explicitly said "access financial records" or "integrate with vendor APIs." The agent made those decisions based on its understanding of what "optimize supply" means.

Now, if something goes wrong with an automated purchase order, who's responsible? Me? I just asked the agent to "optimize supply"? Or the agent, who made the specific decision to place that order? With user identity only, everything gets attributed to me. Understanding *what an agent did* and **why** requires us to be able to identify it independt of any user. 


## The Accountability Chain Problem

This is where the identity question becomes really critical. In traditional systems, we have clear accountability. If I log into our inventory app, spec out a laptop and click "order" then obviously I'm responsible for that. 

But with autonomous agents:

- User says "optimize supply chain"
- Agent interprets what that means
- Agent spawns sub-agents (or calls other agents) for market analysis and vendor management
- Sub-agent makes decision to access restricted data
- Something goes wrong

Who's responsible for what? If we only have user identity, I would get blamed for a decision I never made, executed by a system I didn't directly control, based on reasoning I never saw.

But that doesn't feel right when the agent made autonomous decisions I never explicitly approved. More importantly, if we build security and governance systems around these interactions, it wouldn't make sense to decide authorization based on my identity. The agent would definitely need its own identity in this case. 

We need a way to trace and authorize the decision chain: User intent → Agent interpretation → Agent decision → Sub-agent action.


## Both Identities Matter

I've been working on service mesh for the last 8 years, and one thing that struck me is that this is very similar to user vs workload identity. In that world, to establish real zero trust (RZT), you need to consider both the user and the workload. I feel like we're going to end up with something similar in the agent world. 

The agent operates within the user's delegated authority but maintains its own identity for the specific decisions it makes within that scope.

As I think through this, a few questions keep coming up:

1. How do we design delegation mechanisms that are both secure and usable?
2. What happens when agents start delegating to other agents? (Agent identity chains?)
3. How do we handle agent-to-agent authentication?
4. What does revocation look like in a world of autonomous agent identities?

What will this look like in practice? I'm not sure yet, but we have some good ideas. As I continue to chew on this, I'll share more thoughts. Like, could we just use SPIFFE for this? Or would keeping something like OAuth 2.0 for this be useful? Or other? I know some have floated the idea of an agent identity framework. Follow along for more!

