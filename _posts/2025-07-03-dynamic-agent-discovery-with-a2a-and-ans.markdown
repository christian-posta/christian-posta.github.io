---
layout: post
title: Agent Discovery, Naming, and Resolution - the Missing Pieces to A2A
modified:
categories: 
comments: true
tags: []
image:
  feature:
date: 2025-07-07T12:44:54-04:00
---

The [Agent-to-Agent (A2A) protocol](https://a2aproject.github.io/A2A/v0.2.5/specification/) is emerging as the de-facto standard for how autonomous AI agents talk to each other. While most of the interest around A2A has been around stateful messaging, one of its most powerful ideas remains largely unexplored: [discovery, naming, and resolution](https://a2aproject.github.io/A2A/v0.2.5/topics/agent-discovery/). While the A2A specification provides the critical first steps toward discovery with [Agent Cards](https://a2aproject.github.io/A2A/v0.2.5/specification/#5-agent-discovery-the-agent-card), the infrastructure for truly dynamic, scalable agent ecosystems requires additional components that the [spec intentionally leaves "up to you."](https://a2aproject.github.io/A2A/v0.2.5/topics/agent-discovery/)


## Why Dynamic Agent Discovery Matters

Agents cannot communicate if they cannot decide which agents to call and which agents are available to call. As organizations build out (or buy) more useful and more autonomous agentic solutions, we need a way for agents to leverage each other's skills and solve more difficult tasks. Dynamic discovery isn’t just a nice-to-have, it's critical in these real-world scenarios:

### 1. Supervisor/Planning Agents
A planning agent needs to discover and orchestrate available agents and tools based on environment and real-time context. Imagine a Tax Assistant agent tasked with generating customer-specific tax strategies. It likely shouldn't just hardcode which to call. It needs to discover the right specialist agents based on customer scenario: an agent to extract financials, analyze, and then decide how to proceed. Maybe calling a state-specific tax agent? Maybe one to handle private-company stock scenarios? Maybe one to manage land deals? This mirrors how a human CPA builds a plan by collaborating with other domain experts.

### 2. New Agents in Existing Environments
A newly deployed agent needs a way to quickly understand its environment. What other agents are running? What are their capabilities? How can it interact with them? This is no different than a new teammate joining to team and needing to understand the strengths and weaknesses of existing team members. Without discovery, onboarding agents becomes manual, brittle, and inefficient.

### 3. Third-Party Vendor Agent Integrations
Vendors are building their own chat systems and autonomous agents to make their platforms more powerful. But integration shouldn't mean static configuration files and long meetings with IT. These off the shelf systems become even more valuable (for both you and the vendor) when those agents can dynamically discover your own home-grown or existing agents. Think of an observability agent from a big-name vendor who can dynamically discover an existing alerting system and using that to issue alerts. 

## Agent Cards are the First Step

The A2A specification's [Agent Card](https://a2aproject.github.io/A2A/v0.2.5/specification/#5-agent-discovery-the-agent-card) serves as the first step toward discovery. This JSON document acts as a digital business card, containing everything needed to understand and interact with an agent. The A2A spec talks about hosting it at `/.well-known/agent.json` on the Agent's hostname. 

Here's a simple example of an A2A AgentCard:

```json
{
  "name": "Tax Optimization Agent",
  "description": "AI agent that analyzes expenses and suggests tax optimization strategies",
  "url": "https://tax-agent.example.com/a2a",
  "version": "1.0.0",
  "capabilities": {
    "streaming": true,
    "pushNotifications": false
  },
  "securitySchemes": {
    "bearerAuth": {
      "type": "http",
      "scheme": "bearer",
      "bearerFormat": "JWT"
    },
  },  
  "security": [
    {
      "bearerAuth": []
    },
  ],  
  "defaultInputModes": ["application/json", "text/plain"],
  "defaultOutputModes": ["application/json", "text/markdown"],
  "skills": [
    {
      "id": "analyze_deductions",
      "name": "Tax Deduction Analysis",
      "description": "Analyzes business and personal expenses to identify eligible tax 
      deductions according to current IRS regulations. Reviews expense categories, 
      validates deductibility requirements, calculates potential savings, and flags 
      any compliance concerns. Supports both individual and business tax scenarios with 
      detailed explanations of applicable tax codes.",
      "inputModes": ["application/json", "text/csv"],
      "outputModes": ["application/json", "text/markdown"],      
      "examples": [
        {
          "description": "Analyze business expenses for tax deductions",
          "input": {
            "tax_year": 2024,
            "entity_type": "sole_proprietorship",
            "expenses": [
              {"category": "office_supplies", "amount": 1200, "description": "Paper, ink, software licenses"},
              {"category": "travel", "amount": 3500, "description": "Client meetings, conferences"},
              {"category": "meals", "amount": 800, "description": "Business lunches with clients"}
            ]
          },
          "output": {
            "deductions_found": [
              {"category": "office_supplies", "deductible_amount": 1200, "tax_code": "Section 162", "confidence": "high"},
              {"category": "business_travel", "deductible_amount": 3500, "tax_code": "Section 162", "confidence": "high"},
              {"category": "business_meals", "deductible_amount": 400, "tax_code": "Section 274", "confidence": "medium", "note": "50% limit applies"}
            ],
            "total_deductions": 5100,
            "estimated_tax_savings": 1530,
            "recommendations": ["Keep detailed meal receipts", "Document business purpose for all travel"]
          }
        }
      ]
    }
  ]
}
```

**Key features:**

- **Identity information**: name, description, and provider details
- **Capabilities**: supported A2A protocol features like streaming or push notifications
- **Security schemes**: required security mechanisms
- **Skills catalog**: detailed descriptions of tasks the agent can perform, including input/output modes and examples

Note the heavy emphasis on the skills section of the Agent Card. We want to be as descriptive as possible about what the agent can do, cannot do, and even how it reasons about doing things. We want to provide a number of examples to make this skill description as concrete and clear as possible. The more an agent can discover about what a potential collaborating agent can do, the more accurate decisions it can make about whether to use an agent. 

Agent Cards answer the fundamental question: "What can this agent do and how do I talk to it?" But discovery requires more than just having business cards, you need a system to find the right card for your needs.

## The Missing Infrastructure

While Agent Cards provide the foundation, building a dynamic discovery system requires three additional components that A2A intentionally leaves to implementers:

### 1. Agent Registration

An Agent Registry serves as the central repository for approved A2A agents in your ecosystem. Think of it as an app store for agents, but with enterprise-grade curation and governance.

![](/images/a2a-discovery/agent-registration.png)

**Key features:**
- Providing APIs for registration, status, modification, deactivation
- Maintaining a catalog of curated, approved Agent Cards
- Implementing approval workflows for new agents, including things like skill attestation, scans for prompt injection, and issuing proofs or signatures 
- Supporting different access levels (public, organization-specific, team-specific)

The registry becomes the single source of truth for what agents are available and trusted within an environment.

### 2. Capability-Based Discovery: Agent Naming Service

An [Agent Naming Service](https://genai.owasp.org/resource/agent-name-service-ans-for-secure-al-agent-discovery-v1-0/) (ANS) provides intelligent, skill, security, and capability-based discovery that goes beyond simple catalogs. Instead of needing to know specific agent names, you can discover agents by describing what you need accomplished.

![](/images/a2a-discovery/agent-naming.png)

**Key features:**
- Semantic search across agent capabilities, skills, security schemes, etc
- Support for complex queries combining multiple requirements
- Can plug in and influence search results with agent scoring based on current availability and performance

Can we just build search into our registry? While a registry with basic search handles straightforward lookups well, a dedicated Agent Naming Service becomes valuable when discovery needs to get intelligent. 

Consider the difference between searching for agents tagged "currency" versus understanding that a query for "foreign exchange rates" should match agents with "forex," "FX," or "international money transfer" capabilities. An ANS can use semantic understanding, vector embeddings, or even LLM-powered query interpretation to bridge these gaps. More importantly, it can handle complex multi-dimensional queries like "Find agents that process financial PDFs, integrate with Salesforce, support real-time streaming, and have high availability in the US-East region" combining capability matching, integration requirements, technical features, and operational constraints in a single intelligent query. 

As your agent ecosystem grows, it may span multiple registries (internal tools, trusted partners, public marketplaces). An ANS becomes the unified intelligence layer that can search across all sources, apply consistent scoring based on performance metrics and trust levels, and even translate natural language requests like "I need help with crypto tax analysis" into structured capability queries. 

The ANS transforms agent discovery from a simple lookup problem into an intelligent matching problem.

### 3. Resolution and Policy Enforcement: Agent Gateway

An [Agent Gateway](https://agentgateway.dev) provides the critical infrastructure layer that can take a unified agent name understood by ANS and can lookup the correct network endpoints, apply security and policy decisions, and join tracing and observability. This piece is crucial in production environments.

![](/images/a2a-discovery/agent-discovery.png)

**Key features:**
- **Name resolution**: Converting logical agent names to actual endpoints
- **Security enforcement**: Applying authentication, authorization, and policy controls
- **Resilience**: Handling routing, failures, retries, and fallback routing
- **Observability**: Comprehensive tracing, logging, and monitoring
- **Load balancing**: Distributing requests across multiple instances of the same agent type

The agent gateway ensures that the agents "just talk to another agent" works reliably and securely at scale.

## Wrapping Up

We're moving toward a world where AI agents collaborate as fluidly as human teams. Dynamic discovery is the infrastructure that makes this possible, enabling agents to find each other, understand each other's capabilities, and work together to solve complex problems.

The A2A protocol gives us the standards and building blocks. Agent Cards provide the first step for capability description, but the vision of truly autonomous, collaborative AI systems requires us to build the discovery infrastructure that brings it all together.

