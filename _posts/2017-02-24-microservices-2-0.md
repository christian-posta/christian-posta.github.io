---
layout: post
title: "Excited about a '2.0' tech stack for microservices"
modified:
categories: microservices 
comments: true
tags: [microservices, data, debezium, CQRS, distributed systems]
image:
  feature:
date: 2017-02-24T12:24:56-07:00
---

Technology moves fast! At the same time, the old becomes new. 

When we talk about microservices architectures, [we've come to realize][not-gonna] that the organization and [communication structures of your teams][real-microservices] greatly influence the design of your technology systems.  When we actually start implementing these architectures, we find that we're knee deep in distributed systems. We also find that lots of technology and lots of the methodologies of yesterday and the day before have greatly contributed to this evolution in which we've found ourselves. In many ways, we may be at the beginning of a yet new evolutionary cycle with Lambda/Function as a service style applications, but I don't want to distract too much here.

What I've observed recently is that we're finding new ways to iterate and improve on what we called microservices just a few years ago. Maybe I should rephrase that. What we're doing isn't really new by any stretch. Maybe we're just finding more elegant solutions to *some* of those old problems?
 
 
When building microservices, we really just diving deeper into distributed systems -- a topic that's been studied in technology for >40 years and has deep rootes in complex adaptive systems theory which has been around much longer. But from a technology stand point some of the things we need to solve for these types of systems are things we hear about quite a bit:

* deployment
* delivery
* APIs
* versioning
* contracts
* scaling/autoscaling
* service discovery
* load balancing
* routing / adaptive routing
* health checking
* configuration
* circuit breaking
* bulk-heads
* TTL/deadlining
* latency tracing
* service causal tracing
* distributed logging
* metrics exposure, collection


I may have missed some -- feel free to reach out (@christianposta) anytime if you think I've missed something glaring there. 

Netflix and other internet companies have been AMAZING at revealing some of the things they've done to solve some of these problems (like opensourcing their software, or writing papers). What they implemented (pick a compnay, story is the same) they had to implement from scratch because there wasn't anything like it out there. But privately, each would tell you that they'd love another shot at redoing it because they'd change some things. 

What I'm really excited about is that in some cases we're starting to see that. We're starting to see the next wave of technologies that help solve some of those problems, but in a more elegant way.

For example, Kubernetes is Google's and Red Hat's (each) 3rd time at building a platform with  a set of application-level primitives for running cloud-native applications that have been built on containers. There were previous iterations (either at Google, or in opensource), but Kubernetes has greatly simplified doing things like service discovery, scaling, deployments etc. Building simple things is not easy. And seems like others in the community agree as Kubernetes is the hotest project on github right now with over 1000 committers. That's insane! If Kubernetes was around 5 years ago, you'd not see as many of these "microservices" frameworks solving service-discovery, deployment, failover, load balancing, etc.

![kube](/images/little-kube.png)

Another example is something like circuit breaking. Anyone can write a circuit breaker (and many have). Netflix even released their circuit breaker ([the Hystrix library][https://www.google.com/search?client=safari&rls=en&q=hystrix&ie=UTF-8&oe=UTF-8]) as OSS. The hystrix circuit breaker library gets used by an application to implement that functionality when it makes outgoing network calls and wants to protect itself from downstream anomalies and try to contain the blast radius of failures. The drawback to this (for circuit breaking, service discovery, tracing, metrics, and the list goes on) is that it's incumbent upon the developer to pull in the right libraries and actually get all of these things right. That's really hard. 
   
I'm really loving a different way to solve this. What we'd really like is to not make our applications more complicated with more libraries/frameworks and hope that each developer uses them / applies them properly across projects or even more importantly, across programming languages. Trying to maintain many different implementations of the same thing across developers across projects is just madness. 

![envoy](/images/envoy.png)

The "more elegant" way of doing this, IMHO, is put these things in a client-side proxy that gets deployed as a ["sidecar"](http://blog.kubernetes.io/2015/06/the-distributed-system-toolkit-patterns.html) with your application. A great little project that helps with this is the [Envoy](https://lyft.github.io/envoy/) project from Lyft. Envoy is a very small, C++ client-proxy that handles things like circuit breaking/bulkheading/service discovery/metrics collection/tracing etc. This means a single Envoy proxy gets deployed alongside each application (1-1). This allows the apps to take advantage of this functionality regardless of what programming language. The app basically talks to other services through "localhost" and Envoy does all of the proxying to the actual service. It knows how to find the backend services, do adaptive routing, retries, tracing, throttling, etc.  And as a developer, I can keep my application code clean and get all of these conveniences for free.

![grpc](/images/grpc.png)

Lastly, building microservices with REST is definitely de-facto. Stand up a service, expose a REST endpoint and use that for all interactions/integrations between services. I'm seeing two things about this that's not "new" per-se, but it's evolving into something a bit more elegant. Some of the problems with REST at scale include tracking breaking changes between services, understanding type-safety across services, and that there's considerable overhead when comapred to alternative binary RPC style services (at least with HTTP 1.x). What I'm excited about is that things like non-blocking communication frameworks (ie, RxJava, [Vert.x][http://vertx.io]), asynchronous communication patterns (I'm a messaging guy at heart!), and even things like RPC ([yay gRPC!][http://www.grpc.io]) are becoming more elegant.

I guess what I'm excited about is the new tools that are coalescing in the open-source community (just checkout Kubernetes community!!) that further improve the experience of building applications by pushing more of the complicated stuff down a layer (and implementing it with best-of breed technology). 
 
 
 





[not-gonna]: http://blog.christianposta.com/microservices/youre-not-going-to-do-microservices/
[real-microservices]: http://blog.christianposta.com/microservices/the-real-success-story-of-microservices-architectures/