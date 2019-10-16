---
layout: post
title: Challenges of Adopting Service Mesh in Enterprise Organizations
modified:
categories: 
comments: true
tags: []
image:
  feature:
date: 2019-10-16T12:04:28-04:00
---

Recently I [wrote a piece for DZone and their Migrating to Microservices Report](https://dzone.com/trendreports/migrating-to-microservices-2) on the challenges of adopting service mesh in an enterprise organization. One of the first things we tackle in that piece is "whether or not you should go down the path of adopting a service mesh" Here's what I said:

> Start with an answer of "no". If you're just getting started with microservices and a handful of services, make sure you have the foundational pieces in place first. Microservices and its associated infrastructure are an optimization enabling you to make changes to your application faster. You can make a lot of strides toward going faster without a service mesh. You may even want some of the goodness that a service mesh brings without all of the complexity. Check out something like Gloo, an API Gateway built on Envoy proxy.

I think this is a very important consideration at present time for two big reasons:

1. Generally, service mesh implementations are not ready for production
2. The complexities of going all-in on a service mesh are still high

This doesn't mean there are teams who are using a service mesh successfully, or that you should stay away from it. I do think you should be building the capabilities to eventually bring a mesh in _when you're ready_ and _when your situation could benefit from it_. For example, in the report I list these reasons why you _may want to use_ a service mesh:

> * Large deployment of microservices across multiple clusters
> * Hybrid deployment of containers/k8s and VMs
> * Heterogeneous deployment of languages used to build services
> * Incomplete and inconsistent view of network observability

Even then, you'll confront these challenges:

> * Which one to choose?
> * Who's going to support it?
> * Multi-tenancy issues within a single cluster
> * No good way to manage multiple clusters
> * Fitting with existing services (sidecar lifecycle, race conditions, etc)
> * What's the delineation between developers and operations
> * Non container environments / hybrid env
> * Centralization vs decentralization

Through my work over the last 2+ years with both [Red Hat](https://blog.christianposta.com/moving-on-from-red-hat/) and now [Solo.io](https://blog.christianposta.com/career/new-adventure-starts-at-solo-io/) I've been helping folks navigate through those hard questions (incidentally, reach out [@christianposta](http://twitter.com/christianposta?lang=en) if you want to chat/need help on these fronts), but one thing I've consistently observed in our customers/users as well as have been suggesting for a while is that your adoption of a service mesh should always start with adopting the data plane technology at some level of isolation (ie, on its own) to understand how it works, how to operationalize it, debug it, etc.

For example, in a recent talk I did, I said start with Envoy (Envoy being the underlying dataplane technology for a lot of service mesh implementations). Here's the slide:

![](/images/gateway-first/start-slow-slide.png)

From an architecture standpoint, that could look something like this:

![](/images/gateway-first/single-gateway.png)

Of course, if you're going to use Envoy, I [recommend starting with Gloo](https://medium.com/solo-io/getting-started-with-a-service-mesh-starts-with-a-gateway-96384deedca2), which is basically an [Enterprise Envoy distribution with edge and API Gateway](https://gloo.solo.io) functionality that plugs nicely into a service mesh. Once you have that in place, are comfortable with it, then you are ready to grow the usage and maybe even introduce some isolation through a layering of proxies:

![](/images/gateway-first/multi-tier-gw.png)

The next successive approach is to push the gateways down into your application architecture. We're seeing our users adopt a gateway per application boundary approach as well, which starts to give the "feeling of a mesh" but with some structure to the application (following, eg, the [API Gateway pattern](https://medium.com/solo-io/api-gateways-are-going-through-an-identity-crisis-d1d833a313d7)). I've started calling this the "waypoints" architecture. Just like a pilot uses waypoints to guide their flight plan, these gateways add structure to your architecture while solving for north/south traffic concerns like security and API decoupling, while laying the foundation for a successful service mesh adoption. 

![](/images/gateway-first/bc-gw.png)

Lastly, you can begin to introduce service-mesh proxies in the applications independent of boundary to solve the tough service-to-service communication challenges that service mesh is best suited for:


![](/images/gateway-first/push-down-gw.png)
![](/images/gateway-first/push-down-gw2.png)

The important part here is the gateways still serve a very useful purpose! They add structure and waypoints to your architecture while decoupling and hiding certain implementation details from the rest of the services where needed. In many ways, this follows the DDD bounded context model with the gateways providing an 'anti-corruption' layer. Otherwise, if you just treat all the services as peers you start to march steadfastly toward the death star:

![](/images/gateway-first/deathstar.png)


Hope this helps lay an approach to being successful with a service mesh by starting small, slowing expanding where it makes sense, and bring the full power of the mesh to your apps as you're able to consume and get value from doing so. Otherwise, you risk introducing too much complexity all at once which will overtake your intention to modernize your applications and infrastructure. Reach out ([@christianposta](http://twitter.com/christianposta?lang=en)) if you have any additional thoughts or comments here!
