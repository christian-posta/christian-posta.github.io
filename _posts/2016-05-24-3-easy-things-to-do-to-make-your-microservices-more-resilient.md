---
layout: post
title: "3 Easy Things to Do to Make Your Microservices More Resilient"
modified:
categories: microservices
comments: true
tags: [microservices, resiliency, architecture, cqrs]
image:
  feature:
date: 2016-05-24T13:22:16-07:00
---

One of the advantages of building distributed systems as [microservices][microservices] is the ability of the system as a whole to withstand faults and unexpected failures of components, networks, compute resources, etc.  These systems are resilient even in the face of faults. The idea behind this resiliency seems simple: if our monolith fails, everything for which it's responsible fails along with it; so let's break things into smaller chunks so we can withstand individual pieces of our app failing without affecting the entire system. This sounds great in theory, but does simply breaking things into smaller chunks give us this?

One way to test this is to use what Netflix calls ["chaos monkey"][chaosmonkey] or similar "chaos" strategies: introduce perturbations in the system on purpose to prove the resilience (or fragility) or your system. Systems show their true colors during failures, not happy-path processing, so purposefully introducing failures is a great way to find out what you've really built. Actually, what you really want to do is build [antifragile][antifragile] systems, but that's a topic for a different post :)
 
Breaking things into smaller pieces _can_ give you some of these qualities of resilient systems, but not without some fore-thought. For example, the smaller we break our systems the more we may need to "orchestrate" them or rely on "downstream" services for data, functionality, or both. If these downstream services go down, what does our service do? The more we have these types of dependencies the more interconnected our services are at runtime. If a service on which we depend makes a change to its contract, payload, or event structure, how does that affect our service? Are we forced to change when our collaborators do? This sounds quite brittle if we do. Will the service provider run multiple versions of their service for us? A lot of times we rely (or imply) on once-and-only invocation of a service for a given event. Or at least once-and-only-once processing. What happens if an upstream service experiences network latencies and retries? We may end up with multiple invocations. What do we do?
 
 
These are all the details of microservices that get ignored at in all the hand-wavvy hype at conferences and such, but they're real situations.  Saying we're "doing microservices" doesn't make these distributed-problems go away. So let's look at three fairly well-understood patterns that you should probably always practice when building your microservices to add resiliency.

![fragile](/images/fragile.jpg)


## Promises and Fall backs

Promise theory, first [introduced by Mark Burgess][promises] to describe how IT systems interact with each other, shows us that our systems may or may not be as well-behaved as we'd like. A service provider publishes its "intent" to "do something" and it may or may not do that "something". In many ways it's how we as humans interact with each other as well. The more we look at microservices as independent, autonomous "agents" in a complex system, the more we have to respect this autonomy by understanding these systems are voluntarily intending to provide some service and at times will be unable. 

So what happens when things don't go as planned? Let's look at a non-computer example for a second. Say for a moment that I'm a consultant and I provide a service to my customers. Maybe I'm an architect that helps you build microservices architectures and I've promised to deliver an on-site architecture workshop. This is me volunteering to provide this service to you. What if my flight to your company site is cancelled (ie I was trying to fly through O'Hare :) )? Do I just call you up and say "sorry, cannot deliver the workshop, my flight was cancelled." I suppose I could. Then next time you ask me to deliver a workshop you may second guess things. But maybe I say "sorry, my flight was cancelled, maybe I can find another flight?" or "maybe I can deliver it remote", or "can we reschedule"? I've voluntarily promised to deliver a workshop on microservices so it's incumbent on me to do what I can to fulfill that service. 
  
 It's important to think this way when providing a service in a microservice architecture. What happens when collaborator services are unavailable? What fallback procedures are available to me? A lot of times this fallback may be dictated by the business. Maybe you returned a canned response. Maybe you call a different service as a back up. Maybe you do a simplified calculation yourself. Either way, in the face of some unexpected fault, you should think through what alternatives there are to help fulfill (or partially fulfill) the service promise. 
 
[Apche Camel][camel] and [Netflix Hystrix][hystrix] helps with this.

## Consumer contracts

From our SOA days we've been ingrained to think of service contracts as something the service provider publishes. In the above discussion about promises, it would be the "intent" of the provider. However, from the above, we also see that the provider may also run into situations where it cannot fulfill its promise and maybe it returns something else. How should the consumers react?

The service provider provides a contract of some form (ie documents or schemas that describe the payload of the request and expected responses) and the consumers conform to these documents and implement their internal data models in terms of what the provider has decreed. Then consumers would unmarshall and maybe even validate the contents of the payload during these service interactions. Now if the provider ends up changing the contract (ie adding new fields) the unmarshalling and validation of these data payloads may break. That's not good because we value our service autonomy. We should be able to make changes to a service without forcing ripple effect of changes on other services. 

A solution to this is based on the principle to be "conservative in what we send to a service and liberal in what we accept." Basically, we do "just enough" validation of the response and pull out just the data we need instead of trying to do full data validation. This means our unmarshalling logic should be smart enough to work around the parts of the data model/response that it doesn't know (or care) about. Moreover, if we can capture the parts of the response that consumers really care about, we can begin to return this in a feedback loop to the service providers to help them understand what's actually being used across the service consumers and when they make changes what changes may be breaking changes. Ian Robinson from Thoughtworks covers this well in [Consumer Driven Contracts: A Service Evolution Pattern][consumer-contracts]  

[Schema registries](https://github.com/confluentinc/schema-registry) can [help with this](http://www.confluent.io/blog/schema-registry-kafka-stream-processing-yes-virginia-you-really-need-one)

## Idempotent consumers

What happens when things go wrong? Or when services fail? A service may go down in the middle of a transaction. A mis-behaving service may be inadvertently pounding our service with requests. A consuming service may experience latency in the network (expect this in cloud deployments!) and may have timed-out and retried. A system that expects to receive once-and-only once delivery of a message is brittle by definition. If you build your services to be able to deal with these kinds of "unexpected" behavior they will be far more resilient. We need [idempotent services][idempotent]. 
 
One example is to not exchange messages between systems as "deltas". These are not idempotent messages; if you receive a message multiple times that says "increment X by 20" , you will probably end up with an inconsistent value. Maybe prefer "current-value" type messages where if you recieve them multiple times, they don't add to any inconsistencies in the data. 

Another option is to employ infrastructure that can filter out duplicates. For example, in a failover scenario, [Apache ActiveMQ][activemq] can filter out duplicates when a producer sends a message to the broker and then ends up failing over to a different broker for some reason; the broker index can track and identify duplicates and discard them. 

Yet another option is to track unique identifiers in your services and reject those that have been processed successfully. Storing this information in a LRU cache is helps you quickly diagnose whether you've seen a message and either return a canned response, the original response, or ignore it. [Apache Camel][camel] makes it really easy to build services that use this idempotent-consumer pattern. 




However you implement these patterns doesn't really matter, but we need systems that can deal with failures gracefully. All of these are tried and true patterns. None of these ideas are new, but I don't see them implemented that often. IMHO they should always be implemented. Following these three suggestions will help you build resilient services, although they're not the only things. Other things to consider include isolation, bulkhead patterns, load-balancing, service discovery, apologies, eventual consistency, et.al. to help with resiliency. If one of the advantages of microservices is the resiliency aspect, we should design our microservices architecture with these concepts at the forefront.  


[promises]: https://en.wikipedia.org/wiki/Promise_theory
[microservices]: http://martinfowler.com/articles/microservices.html
[chaosmonkey]: http://fabric8.io/guide/chaosMonkey.html
[antifragile]: http://www.amazon.com/Antifragile-Things-That-Disorder-Incerto/dp/0812979680
[consumer-contracts]: http://martinfowler.com/articles/consumerDrivenContracts.html
[hystrix]: https://github.com/Netflix/Hystrix
[idempotent]: http://camel.apache.org/idempotent-consumer.html
[activemq]: http://activemq.apache.org
[camel]: http://camel.apache.org