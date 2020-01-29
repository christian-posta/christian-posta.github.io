---
layout: post
title: Do I Need an API Gateway if I Use a Service Mesh?
modified:
categories: microservices
comments: true
tags: [microservices, istio, envoy, service mesh, resilience, sidecar, api gateway, solo.io]
image:
  feature:
date: 2020-01-23T18:27:37-05:00
---

This post may not be able to break through the noise around API Gateways and Service Mesh. However, it's 2020 and there is still abundant confusion around these topics. I have chosen to write this to help bring real concrete explanation to help clarify differences, overlap, and when to use which. Feel free to [@ me on twitter (@christianposta)][ceposta] if you feel I'm adding to the confusion, disagree, or wish to buy me a beer (and these are not mutually exclusive reasons). 

> **First disclosure:** [I work][about-solo] for a company, [Solo.io][solo], that is invested in this topic. I mention this ahead of the "your view is biased" reaction. Everyone's view is biased. But to be sure, I came to work at Solo.io **because** I want to see these thoughts implemented and brought to market, not the other way around. 

> **Second disclosure**: I'm writing [a book called "Istio in Action"][istio-in-action] which is the service mesh with which I've spent the most time. The point of view in this article when I discuss "service mesh" is admittedly from an Istio perspective, but I'll try point out when I refer to service mesh more generically. 

## Why another blog on this topic?

There's a trove of information on this topic. We've seen ["API Gateway is for north/south traffic while service mesh is for east/west"][generic-north-south]. Some have written about ["API Gateways as managing business functionality, while service mesh for service-to-service communication"][business-notion]. Others have pointed out [specific functionality that an API Gateway does that service mesh doesn't][not-true-anymore] some of which may no longer be the case. On the other hand, some [get closer to the way I think about them][good-blog-ibm]. 

There is still, however, a palpable confusion in the market.

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">I also would like to see serious discussion about how people see the trade offs between different approaches. For example, there is overlap in responsibility/advocacy between a service meshes and api gateways. People are confused and overwhelmed with choices.</p>&mdash; Andrew Clay Shafer 雷启理 (@littleidea) <a href="https://twitter.com/littleidea/status/1138882324752265216?ref_src=twsrc%5Etfw">June 12, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>


## What's the confusion

About a year ago I wrote [about the Identity Crisis of the API Gateway][identity] which evaluated the differences in API Management, Kubernetes Ingresses, and API Gateways (with associated definitions). At the end of that article, I tried to explain how service mesh fits into the equation, but without enough detail on how they're different or when to use one or the other. I highly recommend [reading that post][identity] as in some ways, that's the "part one" to this post being a "part two". 

I believe the confusion arises because the following:

* there is overlap in technologies used (proxies)
* there is overlap in capabilities (traffic control, routing, metric collection, security/policy enforcement, etc.)
* a belief that "service mesh" replaces API management
* a misunderstanding of the capabilities of a service mesh
* some service meshes have their own gateways

The last bullet is especially confusing to the discussion. 

If service mesh is just for east-west traffic (within a boundary), then why do some service meshes, say Istio, [have an Ingress Gateway](https://istio.io/docs/reference/config/networking/gateway/) for north/south (and is part of the mesh)? For example, from the Istio Ingress Gateway docs:

> Gateway describes a load balancer operating at the edge of the mesh receiving incoming or outgoing HTTP/TCP connections. 

Aren't our API's HTTP? If we can get HTTP requests into the cluster/mesh with Istio's Gateway (which, btw is built on the amazing [Envoy Proxy][envoy] project), isn't that sufficient?


## Assumptions 

The rest of this article will assume Istio and Istio's Gateway when we say "service mesh". I'm picking this scenario because it's the one that best illustrates the overlap and confusion. Other service meshes [also have a Gateway][consul-gateway], while some [don't have an explicit gateway][linkerd-ingress] yet. YMMV.

## Where they overlap

The first order of business is to recognize the areas where the capabilities of an API Gateway and a service mesh seem to overlap. Both handle application traffic, so overlap should not be surprising. The following listing enumerates some of the overlapping capabilities:

* Telemetry collection
* Distributed tracing
* Service discovery
* Load balancing
* TLS termination/origination
* JWT validation
* Request routing
* Traffic splitting
* Canary releasing
* Traffic shadowing
* Rate limiting


Okay, so they overlap. So do you need one? Both? Neither?

## Where they diverge

The service mesh operates at a lower level than the API Gateway and on all of the individual services within the architecture. The service mesh gives "more detail" to service clients about the topology of the architecture (client-side load balancing, service discovery, request routing), the resilience mechanisms they should implement (timeouts, retries, circuit breaking), telemetry they should collect (metrics, tracing), and security flows they participate (mTLS, RBAC). All of these implementation details are provided to applications typically by some sidecar process (think [Envoy][envoy]), though they don't have to. See my talk on the [evolution of the service-mesh data plane][evolution] from ServiceMeshCon. 

From the [API Identity Crisis][identity] article:

> The goal of the service mesh is to solve these problems [those listed above] generically for any service/application by doing so transparently at L7. In other words, the service mesh wishes to blend into the service (without actually being coded into the service’s code). 

__Bottom line__: service mesh gives more details/fidelity to the services/clients about the implementation of the rest of architecture. 

![](/images/mesh-details.png)

The API Gateway on the other hand serves a different role: "abstract away details" and decouple implementations. The API gateway  provides a cohesive abstraction across all of the services in an application architecture -- as a whole, while solving some of the edge/boundary problems on behalf of specific APIs. 

![](/images/abstract-api.png)


API gateways live _above_ the applications/services regardless of whether a service mesh exists and provides an abstraction to other groups. They do things like aggregate APIs, abstract APIs and expose them differently than they're implemented, and add more sophisticated zero-trust security policies at the edge based on the user. The _issues at the boundary of an application architecture_ are not the same as those within the boundary. 

![](/images/infra-layers.png)

## Edge issues are not the same as service-to-service challenges

At the boundary of a microservices/cloud-native architecture, an API Gateway provides three main capabilities that a service mesh does not solve to the same degree:

* Boundary decoupling
* Tight control over data are allowed in and out
* Bridging security trust domains

Let's see:

### Boundary decoupling

A core functionality of the API Gateway is to provide a stable API interface to clients outside of the boundary. From [Chris Richardson's Microservices Patterns Book][crichardson], we could paraphrase the "API Gateway pattern" as:

> explicitly simplifying the calling of a group of APIs/microservices 

> emulate a cohesive API for an “application” for a specific set of users, clients, or consumers. 

> The key here is the API gateway, when it’s implemented, becomes the API for clients as a single entry point to the application architecture

Example API Gateway implementations from the [API Gateway Identity Crisis][identity] article:

* [Solo.io Gloo](https://gloo.solo.io)
* [Spring Cloud Gateway](http://spring.io/projects/spring-cloud-gateway)
* [Netflix Zuul](https://github.com/Netflix/zuul)
* [IBM-Strongloop Loopback/Microgateway](https://strongloop.com)

From a functionality standpoint, what would an API Gateway need to support? And what real-life usecases do enterprises see that would require an API Gateway [where a service mesh isn't well suited]:

* Request / response transformation
* Application protocol transformation like REST/SOAP/XSLT
* Error / Rate limit custom responses
* Direct responses
* Precise control over api/proxy pipelining 
* API composition/grouping

Let's take a look at each.

#### Request / response transformation 
As part of exposing an API on an API gateway, you may wish to hide the details of how the backend API is implemented. This could be some combination of changing the shape of the request, removing/adding headers, placing headers into the body or vice versa. This provides a nice decoupling point from clients when backend services are making changes to the API or when clients cannot update as fast as the provider. 

#### Application protocol transformations 
Many enterprises have investments into technology like XML over HTTP, SOAP, or JSON over HTTP. They may wish to expose these with a tighter, client-specific API and continue to have interoperability. Additionally, service providers may wish to take advantage of new RPC mechanisms like gRPC or streaming protocols like rSocket. 

#### Error / Rate limit custom responses
Transforming requests from upstream services is a vital capability of an API Gateway, but so too is customizing responses coming from the gateway itself. Clients that adopt the API Gateway's virtual API for request/response/error handling expect the gateway to customize its responses to fit that model as well.

#### Direct responses
When a client (trusted or nefarious) requests a resource that is not available, or is blocked from going upstream for some reason, it's best to be able to terminate proxying and respond with a pre-canned response. 

#### Precise control over Proxy pipeline 
There is no one-size fits all proxying expectation. An API Gateway should have the ability to both change the order in which its capabilities get applied (rate limiting, authz/n, routing, transformation, etc) as well as offer a way to debug when things go wrong. 

#### API composition
Exposing an abstraction over multiple services often comes with the expectation of mashing up multiple APIs into a single API. Something like GraphQL could fit this bill.


As you can see, providing a powerful decoupling point between clients and provider services involves more than just allowing HTTP traffic into the cluster. 

## Tight control over what's allowed in/out of services

Another important functionality of an API Gateway is that of "governing" what data/requests are allowed into the application architecture and which data/responses are allowed out. This means, the gateway will need deep understanding of the requests coming into the architecture or those requests coming out. For example, a common scenario is Web Application firewalling to prevent SQL injection attacks. Another is "data loss prevention" techniques to prevent SSN or PII to be returned in requests for PCI-DSS/HIPPA/GDPR. The edge is a natural place to help implement these policies. 

Again, defining and enforcing these capabilities aren't as simple as just allowing HTTP traffic into a cluster.

## Custom security / bridging trust domains

The last major piece of functionality that an API Gateway provides is edge security. This involves challenging users and services that exist outside of the application architecture to provide identity and scope policies so that access to specific services and business functionality can be restricted. This ties into the previous section.

A common example is to be able to tie into OAuth/SSO flows including Open ID Connect. The challenge with these "standards" is that they may not be fully implemented or implemented incorrectly. The API Gateway needs a way to flexibly fit into these environments _as well as provide customization_. 

In many enterprises there are already existing identity/trust/auth mechanisms and a big part of the API Gateway is to be able to integrate natively for backward compatibility. Although new standards like [SPIFEE](https://spiffe.io) have emerged, it will take a while for enterprises to adopt and in the meantime an API Gateway (even one for applications running on their next-generation architecture) is a hard requirement. Again, you can kind of squint and say this is also related to the transformation/decoupling point made above. 


## How to go about adopting one/other/both/neither?

In a previous blog I outlined some of the [challenges of adopting this type of technology (API Gateways and Service Mesh)](https://blog.christianposta.com/challenges-of-adopting-service-mesh-in-enterprise-organizations/) and gave some tips on how best to adopt. 

Re-iterating here: Start with the edge. It's a familiar part of the architecture. Picking one that best fits is also something to consider. Assumptions have changed since we've introduced cloud infrastructure and cloud-native application architectures. For example, if you're going to adopt Kubernetes, I would highly recommend considering application networking technology built from the ground up to live in that world (ie, check out [Envoy Proxy][envoy] vs something that's been lifted and shifted. For example, at [Solo.io](https://www.solo.io), we've built an open-source project leveraging Envoy called Gloo for this purpose.

Do you need a service mesh? If you're deploying to a cloud platform, have multiple types of languages/frameworks implementing your workloads, and building a microservices architecture, then you may need one. There are many options. I have done talks on comparing and contrasting various, with my [OSCON presentation being the most recent](https://www.slideshare.net/ceposta/navigating-the-service-mesh-landscape-with-istio-consul-connect-and-linkerd). Feel free to [reach out for guidance][ceposta] on which one is best for you.

## Wrapping up

Yes, API Gateways have an overlap with service mesh in terms of functionality. They may also have an overlap in terms of technology used (e.g., Envoy). Their roles are quite a bit different, however, and understanding this can save you a lot of pain as you deploy your microservices architectures and discover unintended assumptions along the way. 


[evolution]: https://www.slideshare.net/ceposta/the-truth-about-the-service-mesh-data-plane
[envoy]: https://www.envoyproxy.io
[crichardson]: https://microservices.io/book
[linkerd-ingress]: https://linkerd.io/2/tasks/using-ingress/
[consul-gateway]: https://www.consul.io/docs/connect/mesh_gateway.html
[istio-in-action]: https://www.manning.com/books/istio-in-action
[identity]: https://blog.christianposta.com/microservices/api-gateways-are-going-through-an-identity-crisis/
[about-solo]: https://www.solo.io/company/about-us/]
[idit]: https://twitter.com/Idit_Levine
[solo]: https://solo.io
[ceposta]: http://twitter.com/christianposta?lang=en
[generic-north-south]: https://aspenmesh.io/api-gateway-vs-service-mesh/
[not-true-anymore]: https://blog.getambassador.io/api-gateway-vs-service-mesh-104c01fa4784
[business-notion]: https://medium.com/microservices-in-practice/service-mesh-vs-api-gateway-a6d814b9bf56
[good-blog-ibm]: https://developer.ibm.com/apiconnect/2018/11/13/service-mesh-vs-api-management/