---
layout: post
title: "Application Network Functions With ESBs, API Management, and Now.. Service Mesh?"
modified:
categories: microservices  
comments: true
tags: [microservices, network, distributed systems, circuit breaker, tracing, security]
image:
  feature:
date: 2017-08-03T18:08:48-07:00
---

I've [talked quite a bit](http://blog.christianposta.com/microservices/the-hardest-part-of-microservices-calling-your-services/) recently about the evolution of microservices patterns and how [service proxies like Envoy from Lyft](http://blog.christianposta.com/microservices/00-microservices-patterns-with-envoy-proxy-series/) can help push the responsibility of resilience, service discovery, routing, metrics collection, etc down a layer below the application. Otherwise we risk hoping and praying that the various applications will correctly implement these critical functionalities or depend on language-specific libraries to make this happen. Interestingly, this service mesh idea is related to other concepts that our customers in the enterprise space know about and I've gotten a lot of questions about this relationship. Specifically, how does a service mesh relate to things like ESBs, Message Brokers, and API Management? There definitely is overlap, so here's my attempt to untangle this and put things in perspective.

## Four assumptions

#### Services communicate over a network
First point to make: We're talking about services communicating and interacting with each other over asynchronous networks. This means they are running in their own processes and in their own "time boundaries" (thus the notion of asynchronicity here). These applications send "messages" to each other asking each other to "do something" or alert each other that "something happened", etc. Unfortunately, there are no guarantees about asynchronous network interaction: we can end up with failed interactions, stalled/latent interactions, etc, and these scenarios are indistinguishable from each other. 

#### If we look closely, these interactions are non-trivial
Second point to make: how these services interact with each other is non-trivial; we have to deal with things like failure/partial success, retries, duplicate detection, serialization/deserialization, transformation of semantics/formats, polyglot protocols, routing to the correct service to handle our messages, dealing with floods of messages, service orchestration, security implications,  etc, etc. Many things can, and do, go wrong. 

#### There is a lot of value in understanding the network
Third: there is a lot of value in understanding how applications communicate with each other, how message get exchanged, and potentially a way to control this traffic; this point is very similar to how we look at Layer 3/4 networking; it's valuable to understand what TCP segments and IP packets are transversing our networks, controlling the rules around how to route them, what's allowed, etc. 

#### It's ultimately the application's responsibility
Lastly: As we know through the [end to end argument](http://web.mit.edu/Saltzer/www/publications/endtoend/endtoend.pdf), it's the applications themselves that are responsible for the safety and correct semantic implementation of their purported business logic; anything that helps support this is implementation/optimization details. Unfortunately, there is no way around this. 

### Application Network Functions

I think no matter what services architecture you prefer (microservices, SOA, object request brokers, client/server, etc, etc) these points are all valid -- however, in the past we've blurred the lines about what optimizations belong where. In my mind, there are horizontal **application networking functions** that are fair game to optimize out of our applications (and put into infrastructure -- just like we do at lower levels of the stack), and there are others that are more closely **related to our business logic** that should not be so readily "optimized" out.  

Let's take a quick step back and understand what the networking looks like (at a super trivial and high level :)) below our applications.  When we send a "message" from one service to another, we pass it to the networking stack of our operating system which then figures out how to put it onto the network. The network, depending on what level, deals with *transmission units* (frames, datagrams, packets) etc. These *transmission units* are sent through different points in the network which decide things like whether or not to allow the unit through, whether to route it to a different network, or to deliver it to its intended recipient. At any point along the path, these *transmission units* can be dropped, duplicated, reordered, or delayed. We have higher-level "reliability" functions like TCP that exist in the networking stack in our OS that can track things like duplicates, acknowledgements, timeouts, ordering, lost units etc and can retry on failures, re-order packets and so on. These types of functions are provided by the infrastructure and are not mixed with business logic -- and this scales quite well (internet scale!)  I just ran into a [blog from Phil Calcado that explains this nicely as well](http://philcalcado.com/2017/08/03/pattern_service_mesh.html). 
  
At the application level, we do something similar except our transmission unit is application "messages" (requests, events, etc). When we make calls over the network, we have to be able to do things like timeout, retry, acknowledge, apply backpressure and so on for our application messages. These are universal application-level problems and will always crop up when we build services-style architectures. We need to solve them somehow. We need a way to implement application network functions. In some cases, we left them out altogether (e.g., Java RMI) and/or abstracted away the network completely (DCOM, CORBA, EJB, etc). 

For example: In the past we tried solving these problems with messaging brokers. We had a centralized set of messaging oriented middleware (maybe even with multi protocol support so we could transform message payloads and "integrate" clients) that was responsible for delivery of messages between clients. In a lot of examples I've seen, the pattern was to basically do Request/Reply (RPC) over the messaging system. This actually helped solve some of these problems around application network functionality: things like load balancing, service discovery, back pressure, retries, etc were all delegated to the messaging brokers. Since all traffic was intended to flow through these brokers we had a central spot from which to observe and control network traffic. However, as [@tef_ebooks points out on twitter](https://twitter.com/tef_ebooks/status/875888701246722048) this approach is quite heavy handed/overkill. It also tends to be a big bottleneck in an architecture and wasn't really as easy as we thought when it came to traffic control, routing, policy enforcement, etc.  

So we tried to do that too. We thought "well, let's just add routing, transformation, policy control" to the centralized message bus we already had.  This was a natural evolution actually -- we could use the messaging backbone to provide centralization/control and application network functions like service discovery, load balancing, retries, etc -- but, we'd also layer on top more things like protocol mediation, message transformation, message routing, orchestration, etc. We felt if we could push these seemingly horizontal things down into the infrastructure, our applications could be lighter/leaner/more agile etc. These concerns were definitely real and we needed solutions and the ESB seemingly helped fill those.

As a colleague of mine pointed out "Regarding ESB-the-concept, IBM’s white paper from 2005 regarding SOA architectures (http://signallake.com/innovation/soaNov05.pdf chapter 2.3.1) defines ESBs as follows:"


    The enterprise service bus (ESB) is a silent partner 
    in the SOA logical architecture. Its presence in the 
    architecture is transparent to the services of your 
    SOA application. However, the presence of an ESB is 
    fundamental to simplifying the task of invoking 
    services – making the use of services wherever they 
    are needed, independent of the details of locating 
    those services and transporting service requests 
    across the network to invoke those services wherever 
    they reside within your enterprise.

Seems legit!

Unfortunately, especially in the days of SOA as envisioned by the big vendors (writing endless specs upon specs via committee etc, rebranding EAI etc.), what we found was three things that contributed to the undelivered promises of the "ESB":
 
 * organization structure (let's build another silo!)
 * technology was complicated (SOAP/WS-*, JBI, Canonical XML, proprietary formats, etc)
 * business logic was needed to implement things like routing, transformation, mediation, orchestration, etc
 

The last bullet point is what overdid things. We wanted to be agile but we distributed vital business logic away from our services and into an integration layer owned by another team. Now when we wanted to make changes (agile) to our services, we couldn't; we had to stop and synchronize significantly with the ESB team (brittle). As this team, and this architecture, became the center of the universe for many applications we can understand how the ESB team became inundated with requests (agile) but were unable to keep up (brittle). So although the intentions were good, we found that mixing core application networking functions with functions that are much more related to business logic is not a good idea. We end up with bloat and bottlenecks.   

Then along came the REST revolution and the API-first mindset. This movement was partly a backlash against the complexity of SOAP/ESB/SOA coupled with a genuinely new way to think about turning our date inside out (via APIs) to spark new business models and scale existing ones. We also introduced a new piece of infrastructure to our architecture: the API management gateway. This gateway provided us a centralized way of controlling outside access to our business APIs through security ACLs, access quotas and plans for API usage, metrics collection, billing, documentation etc. However, just like we saw in the previous examples with the message brokers, when we have some kind of centralized governance we run the risk of wanting to accomplish too many things with it. For example, as API calls are coming through our gateway why don't we just add things like routing, transformation, and orchestration? In fact, we do see this happening in practice. The problem with this is we start going down the path of building an ESB which combines infrastructure level networking concerns with business logic. And this is a dead end.   

But we still had to solve for the points listed above between our services (not just the so-called "North-South" traffic, but we needed to solve for the "East-West" traffic interactions). Even more challenging, we needed to figure out a way to use commodity infrastructure environments (aka, cloud) which tended to exacerbate these problems. Traditional message brokers, ESBs, etc would not fit this model very well. We ended up just writing the application network functions alongside our business logic ... we started seeing things like the Netflix OSS stack, Twitter Finagle, and even our own Fabric8 (the original, Java-based impl -- not the current version) crop up to solve some of these problems. These were typically libraries or frameworks that aimed to solve some of the points made above. There were problems with this model as well. This approach required a massive amount of investment in each language/framework/runtime. We basically had to duplicate efforts across languages/frameworks and expect all of the different implementations to work efficiently, correctly, and consistently. 

What has emerged through these trials and tribulations is something that allows us to push application network functions down into the infrastructure with minimal overhead and high decentralization with the ability to control/configure/monitor -- tackling some of the earlier issues. We've been calling this the "service mesh". A nice example of this is the [istio.io](https://istio.io) project. 

### So how is this related to...

With the service mesh, we're explicitly separating application network functions from application code, from business logic, and we're pushing it down a layer (into the infrastructure -- similar to how we've done with the networking stack, TCP, etc.). The network functions in question include:

- simple, metadata-based routing
- adaptive/client-side loadbalancing
- service discovery
- circuit breaking
- timeouts / retries / budgets
- rate limiting
- metrics/logging/tracing
- fault injection
- A/B testing / traffic shaping / request shadowing

Things that are specifically NOT included (and are more appropriate in your business logic/applications, not some centralized infrastructure):

- message transformation
- message routing (content based routing)
- service orchestration 



So how's a service mesh different than...

#### ESBs

* Overlap in some of the network functions
* Decentralized control points
* Application-specific policies
* Does not try to deal with business-logic concerns (mapping, transformation, content-based routing, etc)

#### Message Brokers

* Overlap in service discovery, load balancing, retries, backpressure
* Decentralized control points
* Application-specific policies
* Does not take responsibility for messages

### API Management

* Overlap in certain aspects of policy control, rate limiting, ACLs, Security
* Does not deal with the business aspects of APIs (pricing, documentation, user-to-plan mapping, etc)
* Similar in that it DOES NOT IMPLEMENT BUSINESS LOGIC
* 

