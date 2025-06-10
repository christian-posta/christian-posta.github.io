---
layout: post
title: Agent Identity - Impersonation or Delegation?
modified:
categories: 
comments: true
tags: [ai, rest, agents, agentic, capabilities, llm, architecture, mcp, tools, openapi, swagger, oas]
image:
  feature:
date: 2025-06-09T17:34:30-07:00
---

In a [recent blog post](https://blog.christianposta.com/do-we-even-need-agent-identity/), I discussed whether AI agents need their own identity. I ended with “yes, they do”, but how do we end up doing that? In this blog, we’ll look at a very important concept when it comes to agent identity: impersonation or delegation. Should your marketing agent simply "become" the end user when calling the GDPR compliance agent? Or should it clearly identify itself as acting on the user's behalf?

This isn't just a technical detail, it's fundamental to building secure, auditable, and responsible AI systems. Let me walk through why delegation is essential for autonomous agents using some real-world scenarios (the same examples from my [earlier blog](https://blog.christianposta.com/do-we-even-need-agent-identity/)). I’ll loosely be referring to OAuth Token Exchange as defined in [RFC 8693](https://www.rfc-editor.org/rfc/rfc8693.html) to illustrate the concepts. In my next blog post I go into much more detail (with working demos) on how to implement all of this. Follow along if interested ([@christianposta](https://x.com/christianposta) or [/in/ceposta](https://linkedin.com/in/ceposta)).

## The Agent Identity Challenge

Unlike traditional applications where a human directly clicks buttons and makes decisions, AI agents can operate autonomously. They interpret user requests, make their own decisions about what actions to take, and often call other agents or services to complete tasks.

This creates a unique identity challenge: who is actually responsible when an AI agent does something?

## Impersonation: "The Agent Becomes the User"

With impersonation, an agent just uses your authorization token, or exchanges it to better match the intended audience, but at the end of the day just assumes the user's identity. For simple, [“tool agents”](https://blog.christianposta.com/apis-and-ai-agents-follow-the-same-layered-pattern/) this works perfectly.

### The Simple Case: A K8s Agent

Take a Kubernetes [debugging agent](https://www.solo.io/blog/ai-reliability-engineering-aire-creating-dependable-humans). When a user asks "why is my pod failing?", the agent digs into pod events, logs, etc. to figure it out. But it's really doing this *as the user,* ultimately adhering to Kubernetes RBAC.

```
POST /token HTTP/1.1

grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&subject_token=<user_token>
&audience=kubernetes-api
```

In the above case, the agent might exchange the user’s token for a token that’s valid on the Kubernetes API server. Note, we send in the user’s token (subject\_token) as part of the exchange. 

#### Resulting token:

```json
{
  "sub": "christian",
  "aud": "kubernetes-api",
  "scope": "pods:read events:read"
}
```

The end result after the token exchange is a new token intended for the Kubernetes API that the agent can use. What Kubernetes sees**:** Christian is directly debugging his pod.

This works great because the user asked a question, the agent performed some actions, but the user is still doing the debugging. The agent is just a really smart intermediary. These types of “tool agents” are where most people start and they can give the biggest bang for the buck .

## Challenges with Impersonation with AI Agents

Allowing the agent to impersonate the user has its limits though. For example, if a marketing manager (call her Alice) asks her AI agent to check whether the latest field-marketing campaign is GDPR compliant.

Alice has permissions to **read** marketing campaigns and write campaign content. But the GDPR compliance agent needs to:

* Scan ALL marketing data across departments (not just hers)  
* Access audit logs to see who touched what data  
* Cross-reference customer data with privacy regulations  
* Check historical compliance patterns

She doesn't have these permissions and she shouldn't have them.

### With Impersonation (Problematic):

```json
{
  "sub": "alice", 
  "aud": "gdpr-compliance-service",
  "scope": "marketing:read marketing:write"
}
```

#### Problems:

* ❌ GDPR agent can't access what it needs (fails)  
* ❌ OR we give Alice overly broad permissions she doesn't need  
* ❌ Alice gets blamed for autonomous agent decisions

As mentioned above, the user may not have the permissions to access all of the tools or systems needed to perform the task. On the other hand, giving the user all of the permissions is likely not the right answer. In either case, the target service/tool cannot distinguish between a user calling the service directly or that the agent did this. For compliance reasons, this could be a big issue. 

## Delegation: "The Agent Acts On Your Behalf"

With delegation, the agent maintains its own identity while clearly showing it's acting for the user.

```
POST /token HTTP/1.1

grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&subject_token=<user_token>
&actor_token=<agent_token>
&audience=gdpr-compliance-service
```

In the token exchange, notice that we include the subject’s token (alice) AND the  “actor\_token” which is the token that represents the agent. We specify the right audience for this token. 

### Resulting token:

```json
{
  "sub": "alice",
  "act": {
    "sub": "gdpr-compliance-agent"
  },
  "aud": "gdpr-compliance-service",
  "scope": "compliance:audit:cross_dept compliance:privacy:check"
}
```

In the response, what we see here is that the “act” claim has been set which identifies the “actor” in this case. The act claim is set to the gdpr-compliance-agent and can now be audited. 

**What the GDPR service sees:** The GDPR agent is checking compliance on behalf of Alice.

#### Benefits:

* ✅ Agent gets specialized permissions Alice doesn't need  
* ✅ Clear attribution: Alice authorized it, agent performed it  
* ✅ Appropriate security boundaries

## The Decision Attribution Problem

Delegation becomes critical as agents get more autonomous. Can we explain why a decision was made and by whom?  Let me use my [earlier supply chain example](https://blog.christianposta.com/do-we-even-need-agent-identity/) to show why.

**User request:** "Optimize the company’s laptop supply to enable timely employee onboarding and refresh"

The supply chain agent interprets this to mean it should:

* Analyze supplier performance data  
* Access financial records to evaluate cost structures  
* Integrate with external vendor APIs  
* Make automated purchase orders

**I never explicitly said "access financial records" or "integrate with vendor APIs."** The agent made those decisions based on its understanding of what "optimize supply" means.

### With Impersonation (Bad):

```json
{
  "sub": "christian",
  "aud": "purchase-order-service"
}
```

**Audit trail:** "Christian placed order for 50 MacBook Pros"

#### Problems:

* ❌ I get blamed/attributed to a decision I never made  
* ❌ No way to trace the agent's *autonomous reasoning*  
* ❌ Agent has all my permissions unnecessarily

### With Delegation (Good):

```json
{
  "sub": "christian",
  "act": {
    "sub": "supply-chain-optimizer-agent"
  },
  "aud": "purchase-order-service",
  "scope": "orders:create:hardware"
}
```

**Audit trail:** "Supply chain agent placed order for 50 MacBook Pros on behalf of Christian, who is an IT admin"

#### Benefits:

* ✅ Clear attribution: I authorized optimization, agent chose implementation  
* ✅ Agent has only the permissions it needs  
* ✅ Can trace autonomous decisions back to specific agents

What if the call to the purchase-order-service was initiated by the supply-chain-optimizer-agent, but who authorized that agent? We should also be able to track and validate the entire chain of calls through agent communication:

### With Delegation Chains:

```json
{
  "sub": "christian",                    // Who authorized the original request
  "act": {                              // Current actor
    "sub": "supply-chain-optimizer-agent",
    "act": {                            // Previous actor  
      "sub": "supply-chain-planner"
    }
  },
  "aud": "purchase-order-service",
  "scope": "orders:create:hardware"
}
```

In this case, we can chain the aud claim to which agents delegated authority. Now we have a clear chain of responsibility. I may have authorized the initial request, but each agent individually authorized the next steps. 

## Pre-Authorization: The may\_act Pattern

Smart delegation systems can use pre-authorization to define agent boundaries:

```json
// User's original token includes:
{
  "sub": "christian",
  "may_act": {
    "sub": "supply-chain-agent",
    "constraints": [
      "suppliers:analyze",
      "budget:read:q4_hardware", 
      "orders:create:max_5000_per_item"
    ]
  }
}
```

This means: "Christian pre-authorizes the supply chain agent to act on his behalf, but only for specific operations within defined limits."

Again, in my next blog post I go into much more detail (with working demos) on how to implement all of this. Follow along if interested ([@christianposta](https://x.com/christianposta) or [/in/ceposta](https://linkedin.com/in/ceposta)).

## Wrapping Up

User identity propagation works great for tool-like agents. But as agents become more autonomous and capable, **we need identity patterns that match their behavior**. Impersonation treats agents like invisible proxies which may be fine for simple tools, but dangerous for decision-making systems.

Delegation treats agents as responsible actors which is essential for autonomous systems that need clear accountability, appropriate permissions, and audit trails. When an AI agent makes an autonomous decision, it should own that decision in the identity and security model. **The user authorized the goal; the agent chose the implementation.**

