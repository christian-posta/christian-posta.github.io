---
title: "What 'is' Agent Identity? Human? Workload? A new Layer?"
date: 2026-06-16T02:35:18Z
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


In previous posts, I've covered the [reasons why an AI agent needs an identity][need-agent-identity]. I recommend reading that first. In this post I want to nail down "what is agent identity" because I've seen a lot of different interpretations from smart people such as "[use OAuth](https://mayakaczorowski.com/blogs/ai-agent-authentication)" to "[it's just workload identity](https://www.linkedin.com/pulse/agentic-identity-control-framework-you-already-have-pieces-o-dell-61b5e/?trackingId=h6%2FLz63kR%2BCX8UZDsycg3Q%3D%3D)", and [new protocols crop up](https://www.aauth.dev), etc. But what "is" an agent identity in concrete terms?

An **AI agent** is something a legal person commissions with a reason for existence - an expense report agent, code review, personal assistant, etc. It can be described with a name, rich description, models it may use, skills/capabilities it offers, tools it might use, and the policies it operates under. That detail lives in a registry somewhere. But at runtime, when the agent is deciding how to accomplish a task and actually executing calls, we need a stable, verifiable principal we can make authorization decisions against. That binding is important. How do we get from the rich definition of an AI agent to verifiable runtime identity? 

## Are Agents like Humans? Like Workloads?

Agents are not human. Giving them human identities would give them the standing of a human with none of the built in human-ness/constraints. Agents kinda look like workloads, so something like service account or workload identity may be appropriate here, but agents don't exhibit the behavior we typically see from workloads and that's something we'll need to work through. 

Agents act in two modes. The first mode is "on behalf of a person". That is, a user which has permissions and can decide to use their "authority" to complete a task when they are doing the clicking, but when delegating to an agent, they are scoping down their authority and handing it to an agent (under constraints) to complete a task. The second mode is "autonomous". That is, a person deploys an agent to respond and react to an environment (events, messages, etc) as itself (ie, with its own grants, authority, permissions, etc). 

These modes look slightly different depending on context. In an enterprise, it's not just the user that decides authority delegation: the enterprise sets the boundaries and allowable delegations. So they're constrained even further. Policy governs what agents are eleigble to receive delegation, live within scope claims, where admin/user must confirm, etc. Delegation and grants can only be addressed to a stable, verifiable principal. On the open web, with personal AI agents, the user holds more of the authority and can choose to delegate how they wish.

So should an agent identity be a "new thing", i.e, a layer on top of workload identity? Or can we just use existing workload identity?

The answer to both questions simultaneously is "yes" .... but how can that be?

## Agent Identity as Workload Identity

The truth is, an AI agent "is" an executable piece of software. It runs somewhere. If you look at what identity primitives are available in common execution environments (Kubernetes, containers in general, VMs, etc), SPIFFE/WIMSE is a natural fit. SPIFFE implementations attest a running workload using attributes of the workload, trusting its runtime platform, and then issuing an x509 certificate or JWT-SVID/WIT. For example, in Kubernetes, it's a common practice for a SPIFFE implementation to trust the Kubernetes platform, any service account tokens it issues, and exchange those for SPIFFE credentials. 

For a microservice (ie, `payment-service` with SPIFFE ID `spiffe://cluster.local/ns/payments/sa/payment-service-sa`) **the deployment itself is the binding**. A microservice gets deployed 1:1 with a pod (ie, one service per pod), may scale up/down its replicas, and each replica is exactly the same as the next. Any time a `payment-service` gets scheduled, it will have the same stable and cryptographically verifiable identity as determined by the runtime attestations.

How does this work for AI agents? If you deploy your AI agent 1:1 with a Deployment (ie, Pods in Kubernetes), then this "workload identity == agent identity" probably works well. In fact, this is what we did for the initial development of the [kagent open-source project](https://kagent.dev). An agent is a single deployment, with a stable identity based on SPIFFE (from [Istio Ambient Mesh](https://ambientmesh.io)), and all agent executions, user contexts, memory, etc was handled by the agent framework within those worklods. The binding is owned by the agent runtime (kagent in this case) 

But the reality is, an agent doesn't have to be bound to a specific workload. We have seen significant pressure from our users to pursue more light-weight alternatives to Kubernetes Pods, and to bound executions for individual users in more hardened execution environments (sandboxing). This starts to look like "actors" more than workloads. 

What is the distinction? These "actors" don't behave like traditional service workloads. They are bursty. They are ephemeral. They churn, sometimes violently. They pause/resume. And all through all of this, the stateful nature of the actor's context must be preserved. The underlying infrastructure now has pressure and usage patterns it hadn't seen before. Any implementation that solves for this must also take into account an agent's identity. Agent identity _starts to look like a layer on top of workload identity_. 

## Agent Identity as a Separate Layer

Let's look at a concrete example. At [Solo.io](https://solo.io), we recently contributed [kagent support for a new actor sandboxing project](https://www.solo.io/blog/agent-substrate-powers-kubernetes-agents-with-kagent) released by Google, called [agent substrate](https://github.com/agent-substrate/substrate/). It solves a number of the pressures we got from our kagent users. I'll give a quick overview here, but it may be useful to review the [Architecture Docs](https://github.com/agent-substrate/substrate/blob/main/docs/architecture.md) or a [companion deep-dive learning site](https://learn.agentsubstrate.dev). 

The agent substrate runs as a layer on top of Kubernetes. It starts with a layer of pre-warmed "workers" or generic "Pod workloads" that happen to be hardened sandboxes (Firecracker microVM or gVisor). With agent substrate, the runtime can schedule Agent actors into these generic workloads. It will also snapshot to durable storage / pause and remove the actors when they suspend. That clears the generic workload for another agent actor to be scheduled/resumed into. This model allows to run orders of magnitude more actors/agents than there are workloads by multi-plexing them into worker Pods at runtime. 

![](/images/identity/substrate.png)

The "worker" Pods carry a workload identity such as `spiffe://cluster.local/ns/substrate/sa/worker-pool-default` but they do not represent the running agent or actor. The workload identity may still be useful for traffic authorization policy (ie, "only traffic originating from worker-pool pods for these endponts is allowed"), but it tells you nothing about the specific agent or actor.

Each of the actors will need an identity that gets bound to them at schedule time, and remains the same throughout the lifecycle of the actor/agent. Each time the actor/agent gets scheduled/paused/resumed, it must continue with the same identity. The binding between the actor and the actor's identity would be maintained by agent substrate's runtime registry. It would maintain the continutiy of identity for all actors. As we can see, similar to Kubernetes, the runtime platform handles this mapping and continutiy. In practice, this could be a SPIFFE/WIMSE identity. 

<ntoe>
The agent substrate project doesn't handle this yet, [but we are working on it](https://github.com/agent-substrate/substrate/issues/124). 
</note>

You might say "well, isn't this still workload identity attested to the micro VM level"? Yes, but the important bit is about the identity continutity. The key difference from traditional workload identity is that the continuity invariant is maintained by the substrate's runtime registry, not by Kubernetes. It's a layer on top of Kubernetes, but it's still "a platform" doing it.

## Other Examples?

This pattern of "an agent/worklkoad identity on TOP of workloads" is not unique to Kubernetes, kagent, or agent-substrate. In fact it's a very common pattern across implementations. 

Agent Core does something similar to kagent/substrate just that AWS owns the complete stack. When you deploy an Agent to Agent Core, it runs in a hardened sandboxed microVM (Firecracker?). Under the covers, this sandbox has a real "workload identity" similar to the substrate generic worker pool identity, but it's never exposed to the user (it's probably used for AWS tenant isolation and underlay policy enforcement). In fact this underlying workload could churn but you don't see it because what you see is the Agent's "workload ARN". What Agent Core calls "workload identity" in its docs is not really the microVM/sandbox, it's the singular agent ARN such as:

`arn:aws:bedrock-agentcore:us-west-2:111122223333:workload-identity-directory/default/workload-identity/my-agent-a1b2c3d4e5`

Yes it has the word "workload identity" in it, but it's really a more stable identity that continues along with an Agent Core agent regardless of what micrVM it runs in. You can even get this Agent identity through the Metadata Service running within the micrVM -- it'll be the agent's identity, not the container's workload identity. The point here is: it's a layer on top of the underlying infrastructure and, critically, the Agent Core control plane maintains the mapping and issuance/attestation of identity to the runtime.

Microsoft Entra Agent ID is also a layer on top of the workload. I've written a significant mutli-part "Entra Agent ID on Kubernetes" series of posts. I [highly recommend reviewing that](https://blog.christianposta.com/entra-agent-id-agw/). 

Agent Auth (AAuth) is another agent identity implementation on top of workload. In fact, AAuth specifically uses workload identity in server environments (ie, Kubernetes) to bootstrap identity. AAuth actually plays a much larger role in this agent identity story as we'll uncover. 

Lastly for this section, Karl McGuiness has done an excellent job writing up the need for "actors" in the OAuth world. OAuth has the notion of "clients" but it's a generic "class" of Agent if using it for agent identity. Agents likely need a more fine-grained primitive such as an "actor" and have that mapped into its tokens. Again, this would be a layer on top of workload identity (but if you squint, could be mapped again direclty to workload identity with SPIFFE support for Oauth clients like some IdPs)


So based on this review of various implementations, what can we conclude? Yes, agent idenitty probably naturally wans to live above the workload layer BUT in practical implementations, it does collapse to workload identity. 

At least for the class of agent / platform that we've considered so far. But that's just part of the story.









Okay .... note time...

so far we've covered closed systems. Our own kubernetes platforms. Aws Agent Core, etc. We concede that within closed agent systems, agent identity can be collapsed to workload identity and be fine. Even where layers start to emerge like agent substrate, the actual undelrying object looks like a workload, so keep it with the same ideas we have for workload identity.

But the goal is a more open ecosystem. <-- here we need to dig into this.... where the workload identity pattern breaks down. And this is squarely where AAuth is trying to play. 

Example, an "expense report agent" doens't have an identity if it needs to talk to 10 different oauth protected APIs/tools and each IdP requires it to have a separate client id. this is not an agent identity. this is fragmented agent identity. 

And we need to continue to dig into the auto-discovery/registration aspect. Maybe check Dick Hardt's recent intervew. Maybe he touches on that? 

Extending this outside of the trusted domain becomes tricky. Here's where ahead of time registration/trust establishment is needed. How do we do this with all of the intermediate signers?

A true "open" agent identity and authorization protocol may be appropriate here. Here's where AAuth fits into the picture.

Describe AAuth capabiliteis here in detail.

So bottom line: yes, if you preserve the following invariants:
- list 
- goes
- here
Then you can collapse agent identity into workload identity 

But as you build more sophisitcated systems, the reality that agent identity IS a layer on top of traditional workload identity will become apparent.

- Open questions: how to account for the delegation aspects? how does this factor into the design of the identity mechanism?
- How does the "binding" fit into the picture? this is probably crucial: binding of an agent description to a key / actor
- How are we describing the agent? what does a registry look like?
- How do "actors' vs "class/client-id" fit into the picture? <-- make sure we get this right because Karl will rip it apart
- inside enterprise vs outside open internet world
- say something about spinning up tools/sub agents in substrate/sandbox
- need to link to Uber implemenattion and run it against this framing -- and even leave "open todo" items for uber in the blog

Any others you're thinking about? [Follow / Connect](https://www.linkedin.com/in/ceposta) to stay up on this series. 



[need-agent-identity]: https://blog.christianposta.com/do-we-even-need-agent-identity/
[impersonation-delegation]: https://blog.christianposta.com/agent-identity-impersonation-or-delegation/
[explore-permissions]: https://www.defakto.security/blog/ais-security-problem-isnt-ai-its-everything-around-it/

