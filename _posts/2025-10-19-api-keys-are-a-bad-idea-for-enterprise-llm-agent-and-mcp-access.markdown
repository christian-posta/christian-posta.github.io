---
layout: post
title: API Keys Are a Bad Idea for Enterprise LLM, Agent, and MCP Access
modified:
categories: 
comments: true
tags: []
image:
  feature:
date: 2025-10-19T10:48:13-07:00
---

Do you use API keys to protect your enterprise APIs? If you work in a large enterprise organization, you probably do. This is a very common pattern. A developer can get access to an API for the application that they're writing by requesting (tickets, self-service portal, etc) an API key. They [then are responsible for keeping this key safe](https://cloud.google.com/docs/authentication/api-keys-best-practices). The key gives the caller (their application) access to the API. 

As you adopt AI agents, LLMs, and MCP servers, you may think using API keys for communicating to LLMs, AI agents, or MCP services is a good idea. It's a terrible idea. If you take anything away from this blog:

<div style="background-color: #fff3cd; border-left: 4px solid #ffc107; border-right: 1px solid #ffeaa7; border-top: 1px solid #ffeaa7; border-bottom: 1px solid #ffeaa7; padding: 1em 1.5em; margin: 1.5em 0; border-radius: 0 5px 5px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1); font-size: 1.1em; line-height: 1.6;">
⚠️ API keys should not be used for security within the boundaries of an enterprise for <strong>LLM, AI agent, MCP tools, etc</strong> including for hosted LLM calls. API keys should be avoided altogether. There are better, more secure alternatives.
</div>

## How are API Keys Used

The way API keys are used in enterprise applications/environments is as long-lived, rarely rotated, service-to-service credentials. If an API key gives access to APIs and services, anyone/anything that possesses them can access those systems and services. They are like real "keys". If you have a key, you can unlock something. 

Another fact about how API keys are used in enterprise environments is these keys are used to permit "coarse grained" access. That is, you either have access to something or you don't. Like a lock to the front door of a house. Once you're in, you have access to everything. More sophisticated implementations try to map API keys to "roles" where a role has some limited static permissions to a pre-defined group of resources. 

![](/images/api-keys/initial-api-key.png)

The problem is, [API keys were NOT DESIGNED for security purposes](https://nordicapis.com/why-api-keys-are-not-enough/). Their intended purpose is like a "label" on HTTP requests that can be used for analytics, observability, quota/rate limiting, etc. Unfortunately, enterprises use them as security credentials. This blog from the folks at SPIRL/Defakto Security calls these types of [credentials "toxic", and they are right](https://www.defakto.security/blog/from-oauth-tokens-to-api-keys-the-toxic-data-behind-the-salesloft-drift-salesforce-breach/). 

## Why should API keys not be used for AI?

API keys present unique dangers in AI agent environments because AI is probabilistic. Agent decisions, dependencies, and call flows are emergent. API keys only prove possession, not legitimacy or appropriate use rights. In other words, if an agent possesses the key, how would the target API/Agent/Service know this is a legitimate use? How would the enterprise know whether any communication as a result of this is legitimate? Is the agent allowed to hold that API key? The called service/agent just sees someone with a key show up asking to do something that the key unlocks. 

For AI agents in enterprise, this is particularly problematic especially for compliance. API keys grant "long standing, coarse grained privilege", that is, persistent access that remains active regardless of changing context or need. The autonomous nature of AI agents amplifies these risks. **Any permission granted via API key becomes "live and active"**: the agent will *eventually find a reason to use it*. Or worse. Agents may pass API keys between each other, store them in unexpected ways, or expose them through prompts and completions. It's already quite difficult for human developers to protect API keys and avoid revealing them unintentionally, but now we have to trust a probabilistic agent to do this right? If an agent with broad API key access delegates keys to other agents, permissions spread unpredictably and dangerously and becomes impossible to track and control.

![](/images/api-keys/wide-access.png)

What about for LLMs? Hosted LLM providers almost all use API keys to give access. Again, this is typically broad ranging access to multiple models and services. Enterprises need much more fine grained policy control for compliance, data leakage, privacy, and audit requirements, for example:

* **Model-specific permissions**: Different LLMs have varying capabilities and risk profiles - enterprises need to restrict which specific models (GPT-5, Claude 4, etc.) each user/department/agent/tool can access
* **Context-aware authorization**: Access decisions must consider the user's context, the specific prompt content, and intended use case - not just a static API key
* **Token/usage quotas**: Fine-grained policies allow setting different usage limits per department, project, or use case to prevent cost overruns
* **Data classification boundaries**: Policies must enforce which classification levels of enterprise data can be used with which LLMs (e.g., confidential data might be restricted to private LLM deployments only)
* **Delegated agent permissions**: When AI agents act on behalf of users, policies must define exactly what LLM capabilities they can access and under what conditions

## What Alternatives Should we Pursue?

Enterprises deploying AI agents/chat bots and consuming hosted LLMs should **strive** for the following security posture:

1. **Ephemeral, Just-in-Time Identity**: Generate short-lived cryptographic identities for every connection that automatically expires and can be automatically renewed
2. **Continuous Verification**: Verify the legitimacy of each request rather than relying on a token that grants persistent access
3. **Contextual Access Control**: Adapt permissions based on runtime context, identtiy, agent intent, and risk levels

![](/images/api-keys/good.png)

In my opinion these are some of the most promising approaches:

### Mutual TLS (mTLS) with SPIFFE/SPIRE/Ambient Mesh
Instead of using API keys or traditional long-lived authentication tokens, [SPIFFE](https://spiffe.io) (Secure Production Identity Framework For Everyone) assigns each service a cryptographic identity that uniquely identifies workloads in a zero-trust architecture. This can be used for LLM clients/chat bots/AI agents on both the caller and potentially the target side. If the target is a hosted/external service, we have other options (see below)

* **Workload-based identity**: Services/agets are identified based on what they are, not just what they possess or where the are deployed
* **Automatic certificate rotation**: Short-lived credentials (SPIFFE SVIDs) that expire automatically and rotated frequently
* **No secrets distribution**: SPIFFE implementations validate/attest workload identity before issuing credentials
* **Transport-level security**: Leverage mTLS ensures both parties authenticate each other (mutual auth)

SPIFFE/SPIRE can dramatically reduce security breaches caused by leaked passwords or API keys by using the actual identity of code that can be cryptographically verified. [Ambient Mesh](https://ambientmesh.io) is probably the easiest way to quickly implement SPIFFE in your workloads. 


### Dynamic, Runtime-Based IAM / Policy Enforcement

With workload identity in place, and the ability to "prove" identity, not just assume it based because api keys, we can build a robust access-management system based on identity, context, and policy:

* **User Identity federation**: Pass user identity context from enterprise SSO systems to all AI services
* **On Behalf Of**: Cryptographically tie together relationships between users and agents, based on policy
* **Agent identity attestation**: Require AI agents to have their own verifiable identity separate from user identity (ie, SPIFFE)
* **Centralized policy management**: Decouple access decisions from application code using policy engines like OPA, Cedar, Cerbos, etc
* **Context-aware authorization**: Make access decisions based on the combined context of user identity, agent identity, on-behalf-of, and call chain for resource being accessed, and request details
* **Real-time policy evaluation**: Enable dynamic updates to access policies without requiring code changes


## AI / LLM Gateways with Enhanced Security

API keys are often used because they are "easy" to get started. But just because something is easy doesn't mean you should take it to production. Identity and access management based on context and policy can be more involved to set up and implement, but [agent gateways](https://www.linkedin.com/pulse/why-agentgateway-might-right-abstraction-john-willis-blnbe/?trackingId=2waH3WUBGddgRSGu%2Fo23AQ%3D%3D) can help manage / simplify things here: 

![](/images/api-keys/better.png)

* Validate identity tokens: Verify and validate SSO tokens from enterprise identity providers
* Enforce consistent policies: Apply uniform access controls across all AI systems, even reaching out to policy engines
* Implement advanced authentication: Support mTLS, token exchange, and other cryptographic methods
* Provide audit trails: Log all AI interactions with full identity context for compliance and security
* Handle token enrichment: Add additional claims and context for downstream services


## How to secure Hosted LLM providers?

So far, we've mostly focused on securing communications and access within the enterprise and not using API keys to do so. But what about for calling external/provider hosted LLM services? Those services almost always use API keys to enable auth. In my opinion these providers take the "lowest common denominator" or "easiest for us" approach and leave the heavy lifting of making this approach secure TO YOU. 

The key here is to not let provider API keys proliferate in the enterprise. The fact that API keys need to be used must be shielded from enterprise users and isolated to a single place in the security architecture. The right approach is to have strong identity and access policy within the enterprise, and then use an AI/LLM gateway to shield callers to the upstream LLM calls. The AI gateway can mediate access and only if approved, inject/exchange the right upstream credentials to allow calls to proceed. The calling applications within the enterprise don't need to know anything about this. 

This gives the enterprise:

- **Single Point of Access**: All LLM requests flow through this gateway architecture
- **Internal Authentication**: Use your preferred authentication method (SPIFFE, JWT, mTLS, etc.) for internal services
- **API Key Isolation**: Only the gateway holds and uses the provider API keys
- **Enhanced Security Controls**: Add additional security layers like content filtering, prompt validation, and response screening
- **Unified Logging/Auditing**: Centralized visibility into all LLM usage

![](/images/api-keys/best.png)

## Wrapping Up

The growing adoption of AI agents and LLMs within enterprises demands a fundamental shift in our approach to authentication and authorization. API keys—with their static, coarse-grained nature and tendency to proliferate as "toxic data" create unacceptable security risks that are magnified by the probabilistic, autonomous behavior of AI systems.
By implementing a modern security approach based on cryptographic workload identity, dynamic policy enforcement, and enterprise managed AI gateways, enterprises can gain the fine-grained control they need while eliminating the vulnerabilities of API keys. This approach provides the foundation for secure AI adoption that meets regulatory requirements, prevents data leakage, and enables proper governance.

For public LLM providers that continue to rely on API keys, enterprises must contain this risk through proper gateway architectures that shield internal systems from these toxic credentials. This creates a clean separation between the enterprise's robust internal security model and the limitations imposed by external providers.
The [time to address these security fundamentals is now](https://blog.christianposta.com/ai-agents-are-not-like-microservices-or-monoliths/) before AI agents become more prevalent and before the next major breach exposes the inherent weaknesses of API keys. By embracing identity-first security based on "what you are" rather than "what you possess," enterprises can build AI systems that are both powerful and secure.

