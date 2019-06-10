---
layout: post
title: Moving the Service-mesh Community Forward
modified:
categories: servicemesh
comments: true
tags: [serivce mesh, istio, linkerd, app mesh, consul, SMI]
image:
  feature:
date: 2019-06-09T21:12:19-07:00
---

Service mesh is an important set of capabilities that solve some difficult service-to-service communication challenges when operating a services-style architecture. Just as Kubernetes and containers helped to provide a nice set of abstractions to deploying and running workloads on a fleet of computers, so too is service mesh emerging to abstract the network in a way that gives operators and developers control over request routing, observability, and policy enforcement. This provides a lot of *potential*. 

The only problem is, although Kubernetes has emerged as a powerful API for abstracting underlying infrastructure for scheduling workloads, there is no one, single pragmatic API that surfaces the capabilities needed in a service mesh.


The [announcement of the “Service Mesh Interface”](https://cloudblogs.microsoft.com/opensource/2019/05/21/service-mesh-interface-smi-release/) at KubeCon EU 2019 was proposed recently to help address this. Full disclosure: I work for Solo.io, one of the co-founders of SMI and leaders of the [original vision of unified service mesh](https://medium.com/solo-io/https-medium-com-solo-io-supergloo-ff2aae1fb96f).

Although it’s very early days, the [SMI spec](https://github.com/deislabs/smi-spec) is intending to unify the capabilities and APIs expected of a service mesh running on Kubernetes (although this can help lay the ground work for a service mesh running outside of k8s as well). 

Doing so has several direct benefits to the service-mesh community:

* Service mesh implementations can  be complicated; focusing on an API that surfaces key capabilities independent of implementation improves overall understandability
* In a world of turbulence in the service-mesh community, focusing on capabilities and adopting them through a standard interface reduces the reliance on any on particular implementation; when just getting started, this is a powerful position for the end user.
* Service mesh exposes a set of powerful knobs and levers for manipulating and defining rules (programming the network); *something* will need to orchestrate these knobs and levers; whether it's extensions provided by vendors or extensions you write yourself -- programming the network to any one particular implementation and its assumptions ties you to this implementation and potentially complicates your implementation
* Laying the ground work for stability at lower layers (like a service mesh) opens up the door for further innovation in which the entire ecosystem wins

## Lowest Common Denominator
There are folks in the community who have doubts about the viability of an approach like this, and IMHO their voices are incredibly important. For example, Tim Hockin, for whom I have tremendous respect, has referred to the possibility that the SMI approach becomes a [“lowest common denominator” and serves to please nobody](https://twitter.com/chanwit/status/1137265809988890624) 

Service mesh capabilities are still emerging for sure (as seen in the differing feature sets *at this point in time* of the different service mesh implementations), but the capabilities from Istio, LinkerD, Consul, App Mesh and others seem to be converging around the following:

* Traffic request routing (weighted routing, L7 request-level matching, etc) which can enable capabilities like canary release. The purpose of this is to reduce the blast radius of change impact. 
    * See Istio, App Mesh currently; Linkerd and Hashicorp Consul have traffic-routing implementations landing very soon
* Top-level metric collection like latency percentiles, throughput, error rates
    * See Istio, App Mesh, Linkerd; Consul will be making it easy to configure this in the near future
* Policy enforcement anchored on service identity 
    * See Istio, Consul, with Linkerd and App Mesh to add this in the near future


### Semantics are not all that different
At the moment, Istio has a  mature and developed implementations for these features but there are several other implementations that also implement these capabilities and are coming on strong. In fact, the direction in which these implementations are going is very similar to each other with key differences around ease of use, user experience, management, integrations, etc. But the point is, the semantics of “what capabilities a service mesh provides” are not all that different. IMHO an API around these not so divergent capabilities might be possible with the help of the community including those in the Istio, linkerd, consul, App Mesh communities including any and all vendors interested in their respective success.

### Envoy Proxy is becoming universal
Another very important part of this service mesh discussion is the clear convergence (for the most part?) around a common data-plane proxy. Envoy proxy is the core proxy in 3 out of the 4 prominent service-mesh implementations with other service mesh providers looking to build on top of Envoy as well. Again, I am finding that each implementation’s control plane may differ in some ways, but the underlying feature set in terms of the network API will be derived from Envoy and a common abstraction across service meshes with the the same data plane isn’t that far fetched. The real trouble, as Tim points out is in divergent implementations.

### Based on existing implementations
Lastly, SMI is being derived in part from the existing service-mesh implementations. It’s not a dreamed-up, consortium driven, pie in the sky effort led by folks who’ve not implemented, operated or even used a service mesh. On the contrary, the community at the moment is contributed by vendors and organizations that have real-life, deployed-in-production, service mesh implementations. The ability to derive a pragmatic API from these experiences is not all that far fetched. 

## SMI is lead by vendors
Another prominent voice in the community that I respect is Zack Butcher who voices his opinion that SMI doesn’t pass the smell test because it’s led by vendors that want to sell something.  He specifically says 

  ["What are their motives, and do they align with giving me, a user, a more usable mesh?”](https://twitter.com/ZackButcher/status/1137718684829437952)


Brendan Burns, one of the founders of the SMI Spec [has an interesting take](https://twitter.com/brendandburns/status/1137478260382547968):

  "The current state of the art in service mesh where you have to lock yourself into an implementation is bad. Further, no one can build shared tools for all service meshes which is worse. And no one can build Helm charts that include service mesh apis w/o chosing an impl.”


At Solo.io, where I work, we're interested in seeing a single interface for service mesh emerge because we constantly meet with customers that need to solve:

* Not sure which mesh to pick
* Want to build on top of a mesh, but want to hedge their bets in a turbulent landscape
* Want a more friendly user experience for managing their service mesh
* Need to integrate their north/south traffic with their east-west mesh decision
* Want a vendor to help them, but...
* Not sure of the motives of any one mesh vendor

Our customers and prospects welcome the opportunity to converge on a “service mesh interface” to help them navigate these challenges.

Additionally, enterprises find a lot of value in playing vendors against each other to meet their end needs (and find a lot of value in this!) We’ve seen this play out in communities like Java and Java EE in the past (my background — I’m sure there are other examples). Standard APIs give enterprises the leverage to have these discussions and there is a LOT of value in that (just ask some of the proprietary vendors up against competitive open-source vendors). 


## Winner take all
The last area to explore with respect to SMI is this idea that, just like the container-orchestration wars, a single vendor or a single mesh implementation will ultimately be declared the winner. If this is the case, and you wish to make use of a service mesh implementation today, something like the SMI is even more important as you don’t want to be caught picking the wrong one. 

The reality, in my opinion, is that we’ll end up with multiple service mesh implementations (by design, or not) and we’ll need unify them in some way (either at the level of their capabilities, at the level of integrations with them, or the level of managing them or all the above). 

For example, a real usecase we see with our customers and prospects is the current investment in Istio for their deployments on premises but with other groups going to AWS and going all in including using AWS App Mesh. They have a real situation where they need to build tooling on top of these meshes and they are building their own abstraction. If a community-led abstraction existed, they would use and and see a lot of value in doing so (at the minimum not having to do it themselves!).


## Moving the service-mesh community forward
At the moment, the healthy debate in the community is necessary to surface the concerns and objections and opportunities we can explore and overcome to bring the powerful capabilities of a service mesh to end users and platform builders. Service mesh represents a powerful set of application-networking capabilities but in reality this is not the end game. 

Just like  containers and orchestration systems like Kubernetes have made “containers boring” so too will service mesh make application networking boring. The interesting opportunities to create value for users, the community, as well as the constituent vendors that participate in this community will be higher up the stack including on top of service mesh. If the service-mesh ecosystem ends up in a winner-take all situation, then that’s great! We’ll have a single API against which to build our systems. If not, and I think this will be the higher-probability proposition, then it’s best we all work together to figure out the right API to surface these important capabilities that can be offered with a service mesh, regardless of implementation. 