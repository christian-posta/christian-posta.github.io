---
layout: post
title: Does Platform Engineering Solve the People Problem
modified:
categories: 
comments: true
tags: [platform engineering, kubernetes, networking, devops]
image:
  feature:
date: 2024-03-04T14:05:18-07:00
---


Platform engineering has emerged recently in part because organizations recognize the value in improving developer experience and the need to improve app developer delivery speed. And in typical organizational fashion, spinning up a new team to own this effort is their answer. We've seen folks talk about how platform engineering is primarily motivated by the complexity of software architectures (think, Microservices, and the underlying infrastructure to support that e.g., Kubernetes, containers, etc). In fact Gartner specifically says that:

"Platform engineering emerged in response to the increasing complexity of modern software architectures."

So while there is truth in this viewpoint, I think we are missing an even bigger challenge within enterprise organizations.

Enterprise IT organizations are highly silo'd. Do we think spinning up a new team will solve this people problem? What happened to "DevOps"? Wasn't that supposed to help here?

We've seen organizations think about this problem in terms of "Dev" and "Ops" and getting them to work closer together. But what we see in the organizations we work with here at Solo.io is far more complex than just "Devs" or "Ops". For example, what we label as "Ops" in a typical organization includes teams like:

- Network operations
- Information security (InfoSec)
- API Management 
- Cloud Infrastructure (usually one team for on-premises, and another one for public cloud)
- DevOps / DevSecOps (yes, these are teams)

What we see is the communication between these teams is broken. These teams often make decisions independently for their specific silos without regard for any wholistic picture or outcome. This causes duplication and integration friction with other parts of the organization. Oftentimes, “integration” between these teams is through ticketing systems and manual processes. Teams can become confused which technology to use as inevitably there will be overlap. Attempts at integration and automation will be slow, brittle, and very expensive. Lead times for changes in support of app developer productivity will get longer and longer. We see Conway's law rears its ugly head.

![](/images/plat-eng-people/complex-org-silos.png)

Some times, one of these teams will impose its decisions on others. For example, if the Security teams require all traffic go through their chosen Deep Packet Inspection / Firewall technology, then all other proposed technology choices or infrastructure architectures must take this into account (or risk being out of compliance). Or if an API Management team choses some inflexible, monolithic, outdated API Gateway, all teams must use it.

Isolated decision making, brittle and expensive integration through proprietary extensions/UIs, forced to use a specific technology which may not fit your needs, ticketing systems, error-prone manual processes, delays/lead-time/frustration..... sound familiar?

On the other hand, we see organizations "modernizing" parts of their technology infrastructure by adopting containers, Kubernetes, Functions as a Service, etc and leaning into what has settled into the current incarnation of "DevOps" teams. That is, what we've observed each lines of business will have their own "DevOps" teams. We've even seen developer teams include "SRE" type or "DevOps" roles directly in their team. For some of these teams, this means actually standing up their own Kubernetes clusters and trying to manage all of their own infrastructure. They claim to be following the "you build it, you run it" ethos all they way down to their own VMs and container orchestration systems. This approach within large enterprise organizations leads to terrible inefficiencies, snowflake deployment, testing, and security practices, and causes teams to make decisions based on what the "easiest" path is regardless of whether it fits within the technology strategy or is "best" for the business. In many ways, some organizations have taken the "you build it, you run it" to an extreme. 

![](/images/plat-eng-people/network-islands.png)

Some organizations have come to the conclusion that a loosely centralized "Platform Engineering" team can help. At Solo.io we've seen many variants of this and the organizations that have figured it out -- and wow is it a refreshing perspective. While others are trapped trying to decide where platform team decisions should live (ie, is it infrastructure? is it line of business "DevOps" teams? is it some centralized SRE type team? Who's going to fund all of this?), the ones succeeding are working with their developers to co-develop a platform that is measured and based on outcomes. 

![](/images/plat-eng-people/platform-engineering-abstraction.png)

For example, we keep hearing that a Platform Engineering team needs a product manager to treat this effort as an internal product. We recently met one of these organizations and not only did they have a product manager (which is key), they also had "ex-app developers?" on their team to give deep application developer perspective. They also had representatives from the info sec team and networking teams that they regularly met with. Their platform team wasn't just abstracting the details of the underlying cloud-native technology, but they were integrating with the rest of the organization to get aligned and focused on improving developer workflows, experience, and delivery speed.

With the influence of "you build it ,you run it" and mis-implementation of DevOps, we've shifted "too far left". Application developers should not have to know about Docker, Kubernetes, cert-manager, service mesh, network policy, metric collection, container scanning, API gateway, etc. They definitely should not need to know how to configure AVI/F5 load balancers, Palo Alto Firewalls, VPC security groups, DNS or network alerting tools. All of this should be abstracted away through APIs, workflows, and tooling that are specific to an organizations needs. Even so, the hardest part of platform engineering is aligning the "people silos" in these organization. 