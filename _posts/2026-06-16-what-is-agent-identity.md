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


In previous posts, I've covered the [reasons why an AI agent needs an identity][need-agent-identity]. I recommend reading that first. In this post I want to nail down "what is agent identity" because I've seen a lot of different interpretations from smart people such as "[use OAuth](https://mayakaczorowski.com/blogs/ai-agent-authentication)" to "[it's just workload identity](https://www.linkedin.com/pulse/agentic-identity-control-framework-you-already-have-pieces-o-dell-61b5e/?trackingId=h6%2FLz63kR%2BCX8UZDsycg3Q%3D%3D)", and [new protocols cropping up](https://www.aauth.dev), etc. But what "is" an agent identity in concrete terms?

An **AI agent** is something a legal person commissions with a reason for existence e.g., an expense-report agent, supply-chain optimizer, personal assistant, etc. It can be described with a name, rich description, models it may use, skills/capabilities it offers, approved tools, admin-consented permissions, and the policies it operates under. Those details live in a registry somewhere. But at runtime, when the agent is making decisions about how to accomplish a task and actually executing calls, we need a stable, verifiable principal. This principal is used to make authorization decisions, attribute actions to the agent and lastly to revoke an agent. How do we get from the rich definition of an AI agent to verifiable runtime identity? 

## Are Agents like Humans? Like Workloads?

Agents are not human. Giving them human identities would give them the standing of a human with none of the built-in human-ness/constraints. Agents kinda look like workloads, so something like service account or workload identity may be appropriate here, but agents don't exhibit the behavior we typically see from workloads and that's something we'll need to work through. 

Should an agent identity be a "new thing", i.e, a layer on top of workload identity? Or can we just use existing workload identity?

The answer to both questions simultaneously is "yes" .... but how can that be?

## Agent Identity as Workload Identity

The truth is, an AI agent "is" an executable piece of software. It runs somewhere. If you look at what identity primitives are available in common execution environments (Kubernetes, containers in general, VMs, etc), SPIFFE/WIMSE/Workload Identity is a natural fit. SPIFFE implementations attest a running workload using attributes of the workload, trusting its runtime platform, and then issuing an x509 certificate or JWT-SVID/WIT. For example, in Kubernetes, it's a common practice for a SPIFFE implementation to trust the Kubernetes platform, service account tokens, and exchange those for SPIFFE credentials. 

For a microservice (ie, `payment-service` with SPIFFE ID `spiffe://cluster.local/ns/payments/sa/payment-service-sa`) **the deployment itself is the binding**. A microservice gets deployed 1:1 with a pod (ie, one service per pod), may scale up/down its replicas, and each replica is exactly the same as the next. Any time a `payment-service` Pod gets scheduled, it will have the same stable and cryptographically verifiable identity as determined by the runtime attestations and SPIFFE.

How does this work for AI agents? If you deploy your AI agent 1:1 with a Kubernetes Deployment (ie, Pods), then this "workload identity == agent identity" probably works fine. In fact, this is how the [kagent open-source project is built](https://kagent.dev). Think of kagent as like AWS Agent Core but for Kubernetes-native deployments on any Kubernetes/cloud. In kagent, an agent is a single deployment, with a stable identity based on SPIFFE (from [Istio Ambient Mesh](https://ambientmesh.io)), and all agent executions, user contexts, memory, etc is handled by the agent framework within those worklods. The binding is owned by the agent runtime (kagent in this case).

But the reality is, an agent doesn't have to be bound to a specific workload. 

The challenge is, in practice, AI agents don't behave like long-lived server/microservice workloads. They are bursty. They are ephemeral. They churn, sometimes violently. They pause/resume. They spawn sub-agents or tools. And in the kagent community, we have experienced pressure from our users to pursue more light-weight alternatives to Kubernetes Pods, and to bind executions for individual users in more hardened execution environments (sandboxing). 

This starts to look like "actors" more than Kubernetes pods. 

With a model like this, agent identity _starts to look like a layer on top of workload identity_. 

## Agent Identity as a Separate Layer

Let's look at a concrete example. At [Solo.io](https://solo.io), we recently contributed to [kagent support for a new actor sandboxing project](https://www.solo.io/blog/agent-substrate-powers-kubernetes-agents-with-kagent) released by Google, called [agent substrate](https://github.com/agent-substrate/substrate/). Agent substrate solves some of the aforementioned pressure from kagent users. I'll give a quick overview here, but it may be useful to review the [agent substrate architecture docs](https://github.com/agent-substrate/substrate/blob/main/docs/architecture.md) or a [companion deep-dive learning site](https://learn.agentsubstrate.dev). 

Agent substrate uses two Kubernetes custom resources (CRs) and implements a new control layer on top of Kubernetes. The `WorkerPool` CR defines a template for what a set of generic pre-warmed "workers" (pods) looks like. The `ActorTemplate` defines what an agent/actor "class" looks like. At runtime, agent substrates schedules actor instances wrapped in hardened sandboxes (Firecracker/microVM/gVisor/etc) into the pre-warmed workers. These actors align with the lifecycle of an AI agent including bursty-ness/pause/suspend, etc. Substrate can snapshot the actor's entire sandbox/memory to durable storage. It can then remove the actor from the workload when they suspend which clears the worker for another actor to be scheduled/resumed into. Substrate tracks this actor:worker mapping in its registry which is able to handle millions of suspend/resume operations and boot actors significantly faster that what the Kuberentes control plan can for pods. This model allows to run orders of magnitude more actors/agents than workers by multi-plexing them into worker pods at runtime. 

![](/images/identity/substrate.png)

The "worker" pods carry a workload identity such as `spiffe://cluster.local/ns/substrate/sa/worker-pool-default` but that does not represent the running agent or actor. The workload identity may still be useful for traffic authorization policy (ie, "only traffic originating from worker-pool pods for these endponts is allowed"), but it tells you nothing about the specific agent or actor.

Each of the actors will need an identity that gets bound to them at schedule time (ie, when it is brought back to life within a worker). For example,  `spiffe://substrate.local/ns/substrate/actortemplate/actor-foo/actor/actor-id-xyz`, and remains the same throughout the lifecycle of the actor/agent. Each time the actor/agent gets scheduled/paused/resumed, it must continue with the same identity. The binding between the actor and the actor's identity would be maintained by agent substrate's runtime registry. It would maintain the continuity of identity for all actors. 

<div style="background-color: #e7f3ff; border-left: 4px solid #308cbc; border-right: 1px solid #b8daff; border-top: 1px solid #b8daff; border-bottom: 1px solid #b8daff; padding: 1em 1.5em; margin: 1.5em 0; border-radius: 0 5px 5px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.06); font-size: 1.05em; line-height: 1.6;">
<strong>Note:</strong> The agent substrate project doesn't handle this yet, <a href="https://github.com/agent-substrate/substrate/issues/124" style="color: #0066aa; text-decoration: underline; font-weight: 600;"> but we have designs in place and are working on it</a>.
</div>

So if you squint with your right eye, this looks like a separate agent-identity layer on top of workload identity. But, if you ask "well, isn't this still workload identity attested to the micro VM level"? Then you squint with your left eye, and this looks like a more-fine grained workload identity ... but workload identity none-the-less. 

And what you're seeing through both eyes is correct. 

If you own the infrastructure, within a trust domain and can control the following invariants, you can collapse agent identity into workload identity:

1. One-to-one mapping agent/actor to workload
2. A registry which maps agents/actors to workloads at runtime; becomes the source of truth
3. Agent/actor identity continuity across restarts/resumes/reschedules regardless of workload

## Other Examples?

This pattern of "an agent/worklkoad identity on TOP of workloads" is not unique to Kubernetes, kagent, or agent substrate. In fact it's a very common pattern across implementations. 

Agent Core does something similar to what kagent/substrate just that AWS owns the complete stack. When you deploy an agent to Agent Core, it runs in a container in a hardened sandboxed microVM (Firecracker?). Under the covers, this sandbox has a real "workload identity" similar to the substrate generic worker pod identity, but it's never exposed to the user (it's probably used for AWS tenant isolation and underlay policy enforcement). In fact this underlying workload could churn (e.g. every 900s if inactive) but you don't see it because what you see is the Agent's "workload ARN". What Agent Core calls "workload identity" in its docs is not really the microVM/sandbox, it's the singular agent ARN such as:

`arn:aws:bedrock-agentcore:us-west-2:111122223333:workload-identity-directory/default/workload-identity/my-agent-a1b2c3d4e5`

Yes it has the word "workload identity" in it, but it's really a more stable identity that continues along with an Agent Core agent regardless of what underlying container/microVM it runs in. You can even get this Agent identity through the Metadata Service running within the micrVM -- it'll be the agent's identity, not the container's workload identity. The point here is: it's a layer on top of the underlying infrastructure and, critically, the Agent Core control plane maintains the mapping and issuance/attestation and continuity of identity to the runtime.

Microsoft Entra Agent ID is also a layer on top of the workload. I've written a significant mutli-part "Entra Agent ID on Kubernetes" series of posts. I [highly recommend reviewing that](https://blog.christianposta.com/entra-agent-id-agw/). 

Lastly for this section, Karl McGuiness has done an excellent job writing up the need for "actors" in the OAuth world. OAuth has the notion of "clients" but it's a generic "class" of Agent if using it for agent identity. Agents likely need a more fine-grained primitive such as an "actor" and have that mapped into its tokens. Again, this would be a layer on top of workload identity (but if you squint, could be mapped again direclty to workload identity with SPIFFE support for Oauth clients like some IdPs)

Let's call out the main point clearly: In kagent with agent-per-pod, we see workload identity and agent identity collapse. With kagent+substrate the layer is visibly distinct, but since it holds to the three invariants (1:1, registry, continuity), you can still treat it as workload identity (its an available mental model, but not "automatic"). In the AgentCore/Entra/OAuth examples, the agent identity is a layer above the running workload identity.  

>> need to think about this seam point, how to rephrase it and set up the next section / blog ?
What every one of these still shares: a single control plane maintains that continuity, inside a single trust domain. The agent identity separates from the workload — but it doesn't yet leave home. The harder problem starts the moment an agent has to act somewhere its issuing platform doesn't reach.




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
- each of the examples (AWS agent core, entra agent id, etc) are actually another layer on TOP of workload identity; agent core ties back into their IAM roles.... entra agent id ties back into their service principal which is more closely linked with OAuth (which closely ties into Karl's framing)
- so the conclusion i have at the moment about "it;s all workload identity" is not the case...or maybe i need to clarify:
- workload identity can be agent identity if certian properties hold (1:1 actor/agent to workload, lifetime continuity invariant, fully owned control/registry/attestation layer, etc)
- but in those other examples, continutiy is maintined on top  ... but by a trusted registry and attestation process 
- we need to directly address the "under one control / trust domain/ boundary" argument which sets up AAuth


Any others you're thinking about? [Follow / Connect](https://www.linkedin.com/in/ceposta) to stay up on this series. 



[need-agent-identity]: https://blog.christianposta.com/do-we-even-need-agent-identity/
[impersonation-delegation]: https://blog.christianposta.com/agent-identity-impersonation-or-delegation/
[explore-permissions]: https://www.defakto.security/blog/ais-security-problem-isnt-ai-its-everything-around-it/

Stash paragraphs, may want to come back to this:

---
In an enterprise, it's not just the user that decides authority delegation: the enterprise sets the outer boundaries and allowable delegations. So they're constrained even further. Policy governs what agents are eleigble to receive delegation, live within scope claims, where admin/user must consent, etc. Delegation and grants are addressed to stable, verifiable principals. Enterprises need to know "who" is acting. 
---
Agents act in two modes. The first mode is "on behalf of a person". That is, a user which has permissions and can decide to invoke their "authority" to complete a task by delegating a limited form of it to an agent. The second mode is "autonomous". That is, a person deploys an agent to respond and react to an environment (events, messages, etc) as itself (ie, with its own grants, authority, permissions, etc). 

These two modes have different implications for identity. Autonomous mode is the simpler case: the agent acts as itself, needs a stable credential, and authorization decisions are made against it directly. This maps reasonably well onto workload identity. On-behalf-of mode is harder: the agent is carrying delegated authority, constrained by enterprise policy, potentially handed across a chain of agents and needs to prove not just *who it is*, but *what it's been authorized to do on someone else's behalf* at every hop. That chain has to be verifiable and tamper-evident.

This distinction turns out to show the crux of the question. Within a closed system such as an internal platform, a single cloud, etc you can often paper over it. But when delegation chains need to cross organizational boundaries, the on-behalf-of mode is where workload identity starts to strain. We'll return to this. 
